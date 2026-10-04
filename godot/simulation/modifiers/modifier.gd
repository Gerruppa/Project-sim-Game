class_name Modifier
extends RefCounted
## A change to one system coefficient, never to planet state.
##
## Personality (permanent) and, later, events (temporary) shape the planet
## only through modifiers. Target format: "<system_id>.<coefficient>".
## Treat as read-only after creation.

const ADD := &"add"
const MULTIPLY := &"multiply"
const OPERATIONS: Array[StringName] = [ADD, MULTIPLY]
## expires_at value for modifiers that never expire.
const PERMANENT := -1

var target: StringName
var operation: StringName
var value: float
var source: StringName
## Last tick the modifier is active in; PERMANENT for no expiry.
var expires_at: int


func _init(target_value: StringName, operation_value: StringName, value_value: float,
		source_value: StringName, expires_at_value: int = PERMANENT) -> void:
	target = target_value
	operation = operation_value
	value = value_value
	source = source_value
	expires_at = expires_at_value


func system_id() -> StringName:
	return StringName(String(target).get_slice(".", 0))


func coefficient() -> String:
	return String(target).get_slice(".", 1)


func _to_string() -> String:
	return "%s %s %s (%s)" % [target, operation, value, source]
