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


## Validates one modifier as written in data ({"target", "operation",
## "value"}). `specs`: system id -> coefficient spec, so a typo in a target
## is an error at load time, not a silent no-op.
static func check_data(modifier: Variant, label: String, specs: Dictionary, result: SimResult) -> void:
	if typeof(modifier) != TYPE_DICTIONARY:
		result.add_error("%s: every modifier must be an object" % label)
		return
	var target_value: Variant = modifier.get("target")
	var parts := String(target_value).split(".") if typeof(target_value) == TYPE_STRING else PackedStringArray()
	if parts.size() != 2 or not specs.has(StringName(parts[0])):
		result.add_error("%s: modifier target '%s' must be <system>.<coefficient>" % [label, target_value])
	elif not (specs[StringName(parts[0])] as Dictionary).has(parts[1]):
		result.add_error("%s: system '%s' has no coefficient '%s'" % [label, parts[0], parts[1]])
	if typeof(modifier.get("operation")) != TYPE_STRING or not OPERATIONS.has(StringName(modifier["operation"])):
		result.add_error("%s: modifier operation must be add or multiply" % label)
	var raw_value: Variant = modifier.get("value")
	if (typeof(raw_value) != TYPE_FLOAT and typeof(raw_value) != TYPE_INT) or not is_finite(float(raw_value)):
		result.add_error("%s: modifier value must be a finite number" % label)


func system_id() -> StringName:
	return StringName(String(target).get_slice(".", 0))


func coefficient() -> String:
	return String(target).get_slice(".", 1)


func _to_string() -> String:
	return "%s %s %s (%s)" % [target, operation, value, source]
