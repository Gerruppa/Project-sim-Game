class_name ParameterDef
extends RefCounted
## Immutable description of one planetary parameter.
##
## Values are private and exposed through getters only, because
## definitions are shared by every system for the whole run.

var _id: StringName
var _display_name: String
var _unit: String
var _min_value: float
var _max_value: float
var _initial_value: float
var _anchors: Dictionary[int, String]


func _init(
		id_value: StringName,
		display_name_value: String,
		unit_value: String,
		min_value_value: float,
		max_value_value: float,
		initial_value_value: float,
		anchors_value: Dictionary[int, String]) -> void:
	_id = id_value
	_display_name = display_name_value
	_unit = unit_value
	_min_value = min_value_value
	_max_value = max_value_value
	_initial_value = initial_value_value
	_anchors = anchors_value.duplicate()


func id() -> StringName:
	return _id


func display_name() -> String:
	return _display_name


func unit() -> String:
	return _unit


func min_value() -> float:
	return _min_value


func max_value() -> float:
	return _max_value


func initial_value() -> float:
	return _initial_value


## Meaning of a point on the normalized scale (0, 50 or 100).
func anchor(level: int) -> String:
	return _anchors.get(level, "")
