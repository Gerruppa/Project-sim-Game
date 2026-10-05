class_name SimCommand
extends RefCounted
## One request from outside the simulation (player, tests, debug), executed
## at the start of tick `tick` by the system with id `target`.
##
## Commands are data and part of the run: the same seed and the same
## commands give the same result, so they are saved and logged.

var tick: int
var target: StringName
var action: StringName
## Plain JSON values only (strings, numbers, booleans).
var args: Dictionary
## Submission order; breaks ties between commands of the same tick.
var sequence := 0


func _init(tick_value: int, target_value: StringName, action_value: StringName, args_value: Dictionary = {}) -> void:
	tick = tick_value
	target = target_value
	action = action_value
	args = args_value.duplicate(true)


func to_dict() -> Dictionary:
	return {"tick": tick, "target": String(target), "action": String(action), "args": args.duplicate(true),
			"sequence": sequence}


static func from_dict(data: Variant) -> SimResult:
	if typeof(data) != TYPE_DICTIONARY:
		return SimResult.failure("command must be an object")
	var raw := data as Dictionary
	for key: String in ["tick", "sequence"]:
		var number: Variant = raw.get(key)
		if not (typeof(number) in [TYPE_INT, TYPE_FLOAT]) or float(number) != floorf(float(number)) or float(number) < 0.0:
			return SimResult.failure("command '%s' must be an integer >= 0" % key)
	for key: String in ["target", "action"]:
		if typeof(raw.get(key)) != TYPE_STRING or (raw[key] as String).is_empty():
			return SimResult.failure("command '%s' must be a non-empty string" % key)
	if typeof(raw.get("args", {})) != TYPE_DICTIONARY:
		return SimResult.failure("command 'args' must be an object")
	var command := SimCommand.new(int(raw["tick"]), StringName(raw["target"]), StringName(raw["action"]), raw.get("args", {}))
	command.sequence = int(raw["sequence"])
	return SimResult.success(command)


func _to_string() -> String:
	return "%s.%s%s @%d" % [target, action, args if not args.is_empty() else "", tick]
