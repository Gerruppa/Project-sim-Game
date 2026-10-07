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
## An early warning: a looser condition than the trigger, true well before the
## crisis. Null = this event is not announced.
var warning: EventCondition
## Consecutive ticks the warning condition must hold before the player is told.
var warning_ticks := 20
## Consecutive ticks it must fail before an issued warning is withdrawn.
var warning_clear_ticks := 100
var warning_text := ""
var warning_cleared_text := ""
## Perks and actions that help against the crisis (their ids).
var warning_counters: Array[StringName] = []
## Ticks after the start during which the end condition is not checked.
var min_duration := 0
## Hard limit: no event lasts forever, whatever its feedback does.
var max_duration := 1
## Ticks after the end before the trigger is checked again.
var cooldown := 0
## Each entry: {"target", "operation", "value"}.
var modifiers: Array[Dictionary] = []
## Sentences for the planet chronicle: "start", "end" (end conditions met)
## and "end_time_limit" (max_duration reached).
var story: Dictionary[String, String] = {}


func applies_to(archetype: StringName) -> bool:
	return personality.is_empty() or personality.has(archetype)


## parameter id -> samples the conditions read.
func history_needs() -> Dictionary:
	var needs := {}
	trigger.collect_needs(needs)
	end.collect_needs(needs)
	if warning != null:
		warning.collect_needs(needs)
	return needs


## Samples needed before the trigger and end conditions can be evaluated (the
## early warning is not counted: it must never delay the crisis itself).
func required_samples() -> int:
	var needs := {}
	trigger.collect_needs(needs)
	end.collect_needs(needs)
	return _most(needs)


## Samples needed before the early warning can be evaluated (0 = no warning).
func warning_required_samples() -> int:
	if warning == null:
		return 0
	var needs := {}
	warning.collect_needs(needs)
	return _most(needs)


static func _most(needs: Dictionary) -> int:
	var result := 1
	for id: StringName in needs:
		result = maxi(result, int(needs[id]))
	return result
