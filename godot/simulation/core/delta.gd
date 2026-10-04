class_name Delta
extends RefCounted
## A proposed change to one planetary parameter.
##
## Systems return deltas instead of writing state. The cause is
## mandatory: it is the basis of cause chains in logs and of the
## player's ability to learn why something happened.
## Treat as read-only after creation.

var parameter: StringName
var amount: float
var source: StringName
var cause: StringName


func _init(parameter_value: StringName, amount_value: float, source_value: StringName, cause_value: StringName) -> void:
	parameter = parameter_value
	amount = amount_value
	source = source_value
	cause = cause_value


func _to_string() -> String:
	return "%s %+f (%s: %s)" % [parameter, amount, source, cause]
