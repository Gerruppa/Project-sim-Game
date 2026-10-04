class_name SimEvent
extends RefCounted
## A notification about something that already happened in tick `tick`.
##
## Events inform; they never command. Data should be plain values
## (numbers, strings, arrays, dictionaries) so logs can serialize it.
## The pipeline's own events carry an ApplyReport under "report".
## Treat as read-only after creation.

## Published every tick after StateWriter accepted the batch.
const TICK_APPLIED := &"tick_applied"
## Published when StateWriter rejected the batch; the simulation halts.
const BATCH_REJECTED := &"batch_rejected"

var type: StringName
var tick: int
var source: StringName
var data: Dictionary


func _init(type_value: StringName, tick_value: int, source_value: StringName, data_value: Dictionary) -> void:
	type = type_value
	tick = tick_value
	source = source_value
	data = data_value
