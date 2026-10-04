class_name ParameterSchema
extends RefCounted
## Ordered, validated set of parameter definitions.
##
## The schema decides which parameters exist and where each value
## lives in PlanetState storage. Adding a parameter means adding data,
## not code.

const DEFAULT_PATH := "res://resources/planet/parameters.json"
const SCALE_MIN := 0.0
const SCALE_MAX := 100.0
const ANCHOR_LEVELS: Array[int] = [0, 50, 100]
const TEXT_FIELDS: Array[String] = ["id", "display_name", "unit"]
const NUMBER_FIELDS: Array[String] = ["min", "max", "initial"]

var _version: int
var _definitions: Array[ParameterDef] = []
var _index_by_id: Dictionary[StringName, int] = {}


func _init(version_value: int, definitions: Array[ParameterDef]) -> void:
	_version = version_value
	_definitions = definitions.duplicate()
	for i in _definitions.size():
		_index_by_id[_definitions[i].id()] = i


static func load_json(path: String) -> SimResult:
	if not FileAccess.file_exists(path):
		return SimResult.failure("schema file not found: %s" % path)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return SimResult.failure("schema JSON error in %s at line %d: %s"
				% [path, json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return SimResult.failure("schema root must be an object: %s" % path)
	return from_data(json.data)


## Validates everything and reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	var result := SimResult.new()
	var version_value := _read_version(data, result)
	var raw_parameters: Variant = data.get("parameters")
	if typeof(raw_parameters) != TYPE_ARRAY or (raw_parameters as Array).is_empty():
		result.add_error("schema needs a non-empty 'parameters' list")
		return result

	var definitions: Array[ParameterDef] = []
	var seen_ids: Dictionary[StringName, bool] = {}
	for i in (raw_parameters as Array).size():
		var raw: Variant = raw_parameters[i]
		if typeof(raw) != TYPE_DICTIONARY:
			result.add_error("parameter #%d must be an object" % i)
			continue
		var definition := _parse_parameter(raw, i, result)
		if definition == null:
			continue
		if seen_ids.has(definition.id()):
			result.add_error("parameter #%d: duplicate id '%s'" % [i, definition.id()])
			continue
		seen_ids[definition.id()] = true
		definitions.append(definition)

	if result.is_ok():
		result.value = ParameterSchema.new(version_value, definitions)
	return result


static func _read_version(data: Dictionary, result: SimResult) -> int:
	var raw: Variant = data.get("schema_version")
	if not _is_number(raw) or float(raw) != floorf(float(raw)) or float(raw) < 1.0:
		result.add_error("schema_version must be a positive integer")
		return 0
	return int(raw)


static func _parse_parameter(raw: Dictionary, index: int, result: SimResult) -> ParameterDef:
	var label := "parameter #%d (%s)" % [index, raw.get("id", "?")]
	var errors_before := result.errors.size()

	for field in TEXT_FIELDS:
		if typeof(raw.get(field)) != TYPE_STRING or (raw[field] as String).is_empty():
			result.add_error("%s: '%s' must be a non-empty string" % [label, field])
	for field in NUMBER_FIELDS:
		if not _is_number(raw.get(field)):
			result.add_error("%s: '%s' must be a number" % [label, field])
		elif not is_finite(float(raw[field])):
			result.add_error("%s: '%s' must be finite" % [label, field])
	var anchors := _parse_anchors(raw.get("anchors"), label, result)
	if result.errors.size() > errors_before:
		return null

	var min_value := float(raw["min"])
	var max_value := float(raw["max"])
	var initial_value := float(raw["initial"])
	if min_value < SCALE_MIN or max_value > SCALE_MAX:
		result.add_error("%s: limits must lie within the normalized scale 0..100" % label)
	if min_value >= max_value:
		result.add_error("%s: min must be lower than max" % label)
	if initial_value < min_value or initial_value > max_value:
		result.add_error("%s: initial value must lie within min..max" % label)
	if result.errors.size() > errors_before:
		return null

	return ParameterDef.new(StringName(raw["id"]), raw["display_name"], raw["unit"],
			min_value, max_value, initial_value, anchors)


static func _parse_anchors(raw: Variant, label: String, result: SimResult) -> Dictionary[int, String]:
	var anchors: Dictionary[int, String] = {}
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("%s: 'anchors' must be an object with keys 0, 50, 100" % label)
		return anchors
	for level in ANCHOR_LEVELS:
		var text: Variant = (raw as Dictionary).get(str(level))
		if typeof(text) != TYPE_STRING or (text as String).is_empty():
			result.add_error("%s: missing anchor '%d'" % [label, level])
		else:
			anchors[level] = text
	return anchors


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


func version() -> int:
	return _version


func size() -> int:
	return _definitions.size()


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in _definitions:
		result.append(definition.id())
	return result


## Returns -1 for unknown ids.
func index_of(id: StringName) -> int:
	return _index_by_id.get(id, -1)


func def_at(index: int) -> ParameterDef:
	return _definitions[index]


func def_of(id: StringName) -> ParameterDef:
	var index := index_of(id)
	return null if index == -1 else _definitions[index]


func initial_values() -> PackedFloat64Array:
	var values := PackedFloat64Array()
	for definition in _definitions:
		values.append(definition.initial_value())
	return values
