class_name PlanetSnapshot
extends RefCounted
## Read-only copy of PlanetState at the end of a tick.
##
## This is the only view of the planet that domain systems receive.
## The values are copied, so later state changes never leak in.

var _schema: ParameterSchema
var _values: PackedFloat64Array
var _tick: int


func _init(schema_value: ParameterSchema, values: PackedFloat64Array, tick_value: int) -> void:
	_schema = schema_value
	# Packed arrays are passed by reference in Godot 4; copy explicitly.
	_values = values.duplicate()
	_tick = tick_value


func tick() -> int:
	return _tick


func schema() -> ParameterSchema:
	return _schema


func size() -> int:
	return _values.size()


## Unknown ids return NAN so a typo poisons the result and gets rejected
## by StateWriter instead of silently reading zero.
func get_value(id: StringName) -> float:
	var index := _schema.index_of(id)
	if index == -1:
		push_error("PlanetSnapshot: unknown parameter '%s'" % id)
		return NAN
	return _values[index]


func get_value_at(index: int) -> float:
	return _values[index]
