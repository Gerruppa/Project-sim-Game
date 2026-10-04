class_name EventDef
extends RefCounted
## Definition of one world event (or planet reaction), loaded from data.
##
## A new event needs no code: conditions, timing and modifiers all live in
## resources/events/events.json. Treat as read-only after loading.

var id: StringName
## Readable name used in logs.
var name: String
## Archetypes this event belongs to; empty = every planet.
var personality: Array[StringName] = []
var trigger: EventCondition
## Consecutive ticks the trigger must hold before the event starts.
var trigger_ticks := 1
var end: EventCondition
## Consecutive ticks the end condition must hold before the event ends.
var end_ticks := 1
## Ticks after the start during which the end condition is not checked.
var min_duration := 0
## Hard limit: no event lasts forever, whatever its feedback does.
var max_duration := 1
## Ticks after the end before the trigger is checked again.
var cooldown := 0
## Each entry: {"target", "operation", "value"}.
var modifiers: Array[Dictionary] = []


func applies_to(archetype: StringName) -> bool:
	return personality.is_empty() or personality.has(archetype)


## parameter id -> samples the conditions read.
func history_needs() -> Dictionary:
	var needs := {}
	trigger.collect_needs(needs)
	end.collect_needs(needs)
	return needs


## Samples needed before any condition of this event can be evaluated.
func required_samples() -> int:
	var needs := history_needs()
	var result := 1
	for id: StringName in needs:
		result = maxi(result, int(needs[id]))
	return result
