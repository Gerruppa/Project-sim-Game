class_name PersonalityCatalog
extends RefCounted
## Validated planet archetypes, loaded from JSON.
##
## Modifier targets are checked against the coefficient specs of the systems
## at load time, so a typo in data is an error, not a silent no-op.

const DEFAULT_PATH := "res://resources/personality/personality.json"
## Choice values with a special meaning; never valid archetype ids.
const NONE := &"none"
const RANDOM := &"random"

var _archetypes: Array[PersonalityArchetype] = []


static func load_json(path: String, specs: Dictionary) -> SimResult:
	var read := CoefficientLoader.read_json(path, "personality")
	return from_data(read.value, specs) if read.is_ok() else read


## `specs`: system id -> coefficient spec. Reports all errors at once.
static func from_data(data: Dictionary, specs: Dictionary) -> SimResult:
	var raw_list: Variant = data.get("archetypes")
	if typeof(raw_list) != TYPE_ARRAY or (raw_list as Array).is_empty():
		return SimResult.failure("personality catalog needs a non-empty 'archetypes' list")
	var result := SimResult.new()
	var catalog := PersonalityCatalog.new()
	for i in (raw_list as Array).size():
		var raw: Variant = raw_list[i]
		if typeof(raw) != TYPE_DICTIONARY:
			result.add_error("archetype #%d must be an object" % i)
			continue
		var archetype := _parse_archetype(raw, i, specs, result)
		if archetype == null:
			continue
		if catalog.get_archetype(archetype.id) != null:
			result.add_error("archetype #%d: duplicate id '%s'" % [i, archetype.id])
			continue
		catalog._archetypes.append(archetype)
	if result.is_ok():
		result.value = catalog
	return result


static func _parse_archetype(raw: Dictionary, index: int, specs: Dictionary, result: SimResult) -> PersonalityArchetype:
	var label := "archetype #%d (%s)" % [index, raw.get("id", "?")]
	var errors_before := result.errors.size()
	if typeof(raw.get("id")) != TYPE_STRING or (raw["id"] as String).is_empty():
		result.add_error("%s: 'id' must be a non-empty string" % label)
	elif StringName(raw["id"]) in [NONE, RANDOM]:
		result.add_error("%s: id '%s' is reserved" % [label, raw["id"]])
	var weight: Variant = raw.get("weight")
	if (typeof(weight) != TYPE_FLOAT and typeof(weight) != TYPE_INT) or not is_finite(float(weight)) or float(weight) <= 0.0:
		result.add_error("%s: 'weight' must be a positive number" % label)
	if typeof(raw.get("description")) != TYPE_STRING:
		result.add_error("%s: 'description' must be a string" % label)
	if typeof(raw.get("modifiers")) != TYPE_ARRAY:
		result.add_error("%s: 'modifiers' must be a list" % label)
	else:
		for modifier: Variant in raw["modifiers"]:
			_check_modifier(modifier, label, specs, result)
	if result.errors.size() > errors_before:
		return null

	var archetype := PersonalityArchetype.new()
	archetype.id = StringName(raw["id"])
	archetype.weight = float(weight)
	archetype.description = raw["description"]
	for modifier: Dictionary in raw["modifiers"]:
		archetype.modifiers.append({"target": modifier["target"], "operation": modifier["operation"],
				"value": float(modifier["value"])})
	return archetype


static func _check_modifier(modifier: Variant, label: String, specs: Dictionary, result: SimResult) -> void:
	if typeof(modifier) != TYPE_DICTIONARY:
		result.add_error("%s: every modifier must be an object" % label)
		return
	var target: Variant = modifier.get("target")
	var parts := String(target).split(".") if typeof(target) == TYPE_STRING else PackedStringArray()
	if parts.size() != 2 or not specs.has(StringName(parts[0])):
		result.add_error("%s: modifier target '%s' must be <system>.<coefficient>" % [label, target])
	elif not (specs[StringName(parts[0])] as Dictionary).has(parts[1]):
		result.add_error("%s: system '%s' has no coefficient '%s'" % [label, parts[0], parts[1]])
	if typeof(modifier.get("operation")) != TYPE_STRING or not Modifier.OPERATIONS.has(StringName(modifier["operation"])):
		result.add_error("%s: modifier operation must be add or multiply" % label)
	var value: Variant = modifier.get("value")
	if (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT) or not is_finite(float(value)):
		result.add_error("%s: modifier value must be a finite number" % label)


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for archetype in _archetypes:
		result.append(archetype.id)
	return result


func all() -> Array[PersonalityArchetype]:
	return _archetypes.duplicate()


func get_archetype(id: StringName) -> PersonalityArchetype:
	for archetype in _archetypes:
		if archetype.id == id:
			return archetype
	return null
