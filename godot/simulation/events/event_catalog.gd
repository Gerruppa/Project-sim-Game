class_name EventCatalog
extends RefCounted
## Validated world event definitions, loaded from JSON.
##
## Parameters are checked against the schema, modifier targets against the
## coefficient specs and personality ids against the known archetypes, so a
## typo in data is an error at load time, not an event that never fires.

const DEFAULT_PATH := "res://resources/events/events.json"
const EVENT_KEYS := ["id", "name", "personality", "trigger", "end", "min_duration", "max_duration",
		"cooldown", "modifiers"]

var _defs: Array[EventDef] = []


static func load_json(path: String, schema: ParameterSchema, specs: Dictionary, archetype_ids: Array[StringName]) -> SimResult:
	var read := CoefficientLoader.read_json(path, "events")
	return from_data(read.value, schema, specs, archetype_ids) if read.is_ok() else read


## `specs`: system id -> coefficient spec. Reports all errors at once.
static func from_data(data: Dictionary, schema: ParameterSchema, specs: Dictionary, archetype_ids: Array[StringName]) -> SimResult:
	var raw_list: Variant = data.get("events")
	if typeof(raw_list) != TYPE_ARRAY:
		return SimResult.failure("event catalog needs an 'events' list")
	var result := SimResult.new()
	var catalog := EventCatalog.new()
	for i in (raw_list as Array).size():
		var raw: Variant = raw_list[i]
		if typeof(raw) != TYPE_DICTIONARY:
			result.add_error("event #%d must be an object" % i)
			continue
		var def := _parse_event(raw, i, schema, specs, archetype_ids, result)
		if def == null:
			continue
		if catalog.get_def(def.id) != null:
			result.add_error("event #%d: duplicate id '%s'" % [i, def.id])
			continue
		catalog._defs.append(def)
	if result.is_ok():
		result.value = catalog
	return result


static func _parse_event(raw: Dictionary, index: int, schema: ParameterSchema, specs: Dictionary,
		archetype_ids: Array[StringName], result: SimResult) -> EventDef:
	var label := "event #%d (%s)" % [index, raw.get("id", "?")]
	var errors_before := result.errors.size()
	var def := EventDef.new()
	for key: Variant in raw:
		if not key in EVENT_KEYS:
			result.add_error("%s: unknown key '%s'" % [label, key])
	if typeof(raw.get("id")) != TYPE_STRING or (raw["id"] as String).is_empty():
		result.add_error("%s: 'id' must be a non-empty string" % label)
	else:
		def.id = StringName(raw["id"])
	if typeof(raw.get("name")) != TYPE_STRING or (raw["name"] as String).is_empty():
		result.add_error("%s: 'name' must be a non-empty string" % label)
	else:
		def.name = raw["name"]
	_parse_personality(raw.get("personality", []), label, archetype_ids, def, result)

	var trigger := _parse_phase(raw.get("trigger"), label + ".trigger", schema, result)
	var end := _parse_phase(raw.get("end"), label + ".end", schema, result)
	def.min_duration = _whole(raw, "min_duration", 0, label, result)
	def.max_duration = _whole(raw, "max_duration", 1, label, result)
	def.cooldown = _whole(raw, "cooldown", 0, label, result)
	if def.max_duration <= def.min_duration and result.errors.size() == errors_before:
		result.add_error("%s: 'max_duration' must be greater than 'min_duration'" % label)

	var modifiers: Variant = raw.get("modifiers")
	if typeof(modifiers) != TYPE_ARRAY or (modifiers as Array).is_empty():
		result.add_error("%s: 'modifiers' must be a non-empty list (an event acts only through modifiers)" % label)
	else:
		for modifier: Variant in modifiers:
			Modifier.check_data(modifier, label, specs, result)
	if result.errors.size() > errors_before:
		return null

	def.trigger = trigger[0]
	def.trigger_ticks = trigger[1]
	def.end = end[0]
	def.end_ticks = end[1]
	for modifier: Dictionary in modifiers:
		def.modifiers.append({"target": modifier["target"], "operation": modifier["operation"],
				"value": float(modifier["value"])})
	return def


static func _parse_personality(raw: Variant, label: String, archetype_ids: Array[StringName], def: EventDef, result: SimResult) -> void:
	if typeof(raw) != TYPE_ARRAY:
		result.add_error("%s: 'personality' must be a list of archetype ids" % label)
		return
	for id: Variant in raw:
		if typeof(id) != TYPE_STRING or not archetype_ids.has(StringName(id)):
			result.add_error("%s: unknown archetype '%s'; known: %s" % [label, id, archetype_ids])
		else:
			def.personality.append(StringName(id))


## [condition, ticks] of a trigger or end block: {"condition": {...}, "for_ticks": N}.
static func _parse_phase(raw: Variant, label: String, schema: ParameterSchema, result: SimResult) -> Array:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("%s must be an object with 'condition' and 'for_ticks'" % label)
		return [null, 0]
	for key: Variant in raw:
		if not key in ["condition", "for_ticks"]:
			result.add_error("%s: unknown key '%s'" % [label, key])
	var condition := EventCondition.parse(raw.get("condition"), schema, label + ".condition", result)
	return [condition, _whole(raw, "for_ticks", 1, label, result)]


static func _whole(raw: Dictionary, key: String, minimum: int, label: String, result: SimResult) -> int:
	var value: Variant = raw.get(key)
	if not EventCondition.is_whole(value) or int(value) < minimum:
		result.add_error("%s: '%s' must be a whole number >= %d" % [label, key, minimum])
		return minimum
	return int(value)


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for def in _defs:
		result.append(def.id)
	return result


func all() -> Array[EventDef]:
	return _defs.duplicate()


func get_def(id: StringName) -> EventDef:
	for def in _defs:
		if def.id == id:
			return def
	return null
