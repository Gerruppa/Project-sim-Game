class_name ApplyReport
extends RefCounted
## What StateWriter did in one apply call.
##
## The pipeline turns this report into events and log lines,
## so PlanetState and StateWriter never depend on EventBus.

var errors := PackedStringArray()
## One entry per parameter that received deltas, in schema order.
var changes: Array[ParameterChange] = []
## Accepted deltas in canonical order (the order they were summed in).
var applied_deltas: Array[Delta] = []


class ParameterChange:
	var parameter: StringName
	var old_value: float
	## old_value + sum of deltas, before clamping.
	var requested_value: float
	var new_value: float
	var saturated: bool


	func _init(parameter_value: StringName, old: float, requested: float, applied: float) -> void:
		parameter = parameter_value
		old_value = old
		requested_value = requested
		new_value = applied
		saturated = requested != applied


func is_ok() -> bool:
	return errors.is_empty()


func add_error_for(parameter: StringName, message: String) -> void:
	errors.append("%s: %s" % [parameter, message])


## Parameters pushed against their limits. Long saturation signals bad balance.
func saturations() -> Array[ParameterChange]:
	return changes.filter(func(change: ParameterChange) -> bool: return change.saturated)
