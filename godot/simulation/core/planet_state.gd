class_name PlanetState
extends RefCounted
## Single source of truth for the planet.
##
## Values live in a PackedFloat64Array ordered by the schema.
## Only StateWriter may change them (through _commit). Domain systems
## never receive this object, only PlanetSnapshot.

var _schema: ParameterSchema
var _values: PackedFloat64Array


## Expects values that are already validated. Use create() or
## PlanetStateCodec to build a state from untrusted input.
func _init(schema_value: ParameterSchema, values: PackedFloat64Array) -> void:
	_schema = schema_value
	_values = values.duplicate()


## Builds a state from initial values plus optional overrides
## (keys: parameter ids as String or StringName).
static func create(schema_value: ParameterSchema, overrides: Dictionary = {}) -> SimResult:
	var result := SimResult.new()
	var values := schema_value.initial_values()
	for key: Variant in overrides:
		var id := StringName(str(key))
		var index := schema_value.index_of(id)
		if index == -1:
			result.add_error("unknown parameter '%s'" % id)
			continue
		var error := validate_value(schema_value.def_at(index), overrides[key])
		if not error.is_empty():
			result.add_error(error)
			continue
		values[index] = float(overrides[key])
	if result.is_ok():
		result.value = PlanetState.new(schema_value, values)
	return result


## Returns an empty string for a valid value.
static func validate_value(definition: ParameterDef, value: Variant) -> String:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return "parameter '%s': value must be a number" % definition.id()
	var number := float(value)
	if not is_finite(number):
		return "parameter '%s': value must be finite" % definition.id()
	if number < definition.min_value() or number > definition.max_value():
		return "parameter '%s': value %s outside %s..%s" % [
				definition.id(), number, definition.min_value(), definition.max_value()]
	return ""


func schema() -> ParameterSchema:
	return _schema


func get_value(id: StringName) -> float:
	var index := _schema.index_of(id)
	if index == -1:
		push_error("PlanetState: unknown parameter '%s'" % id)
		return NAN
	return _values[index]


func get_value_at(index: int) -> float:
	return _values[index]


func values_copy() -> PackedFloat64Array:
	return _values.duplicate()


func snapshot(tick: int) -> PlanetSnapshot:
	return PlanetSnapshot.new(_schema, _values, tick)


## Write access for StateWriter only. Enforced by an architecture test.
func _commit(values: PackedFloat64Array) -> void:
	_values = values.duplicate()
