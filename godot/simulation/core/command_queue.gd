class_name CommandQueue
extends RefCounted
## The only entry point from outside the simulation (Control channel).
##
## Holds commands until their tick; TickPipeline takes them in phase 1
## (Begin), in submission order. Commands never bypass StateWriter: systems
## turn them into internal changes, modifiers or later deltas.

var _pending: Array[SimCommand] = []
var _next_sequence := 0


func push(command: SimCommand) -> void:
	command.sequence = _next_sequence
	_next_sequence += 1
	_pending.append(command)


## Removes and returns the commands of `tick` in submission order.
## Commands for earlier ticks can no longer run and are dropped with them.
func take(tick: int) -> Array[SimCommand]:
	var due: Array[SimCommand] = []
	var rest: Array[SimCommand] = []
	for command in _pending:
		if command.tick == tick:
			due.append(command)
		elif command.tick > tick:
			rest.append(command)
	_pending = rest
	# Sequences are unique, so this order is total.
	due.sort_custom(func(a: SimCommand, b: SimCommand) -> bool: return a.sequence < b.sequence)
	return due


func pending() -> Array[SimCommand]:
	return _pending.duplicate()


func save_state() -> Dictionary:
	return {"next_sequence": _next_sequence, "pending": _pending.map(func(c: SimCommand) -> Dictionary: return c.to_dict())}


func load_state(data: Dictionary) -> SimResult:
	var next: Variant = data.get("next_sequence", 0)
	if not (typeof(next) in [TYPE_INT, TYPE_FLOAT]) or float(next) < 0.0:
		return SimResult.failure("commands: 'next_sequence' must be an integer >= 0")
	var raw: Variant = data.get("pending", [])
	if typeof(raw) != TYPE_ARRAY:
		return SimResult.failure("commands: 'pending' must be a list")
	var restored: Array[SimCommand] = []
	for item: Variant in raw:
		var read := SimCommand.from_dict(item)
		if not read.is_ok():
			return SimResult.failure("commands: " + read.errors[0])
		restored.append(read.value)
	_pending = restored
	_next_sequence = int(next)
	return SimResult.success(self)
