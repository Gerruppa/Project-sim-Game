class_name InterventionDef
extends RefCounted
## One player intervention as written in data. Read-only after loading.
##
## An intervention acts only through channels the simulation already has:
## modifiers (temporary coefficient changes, like events) and commands to
## other systems (seeding or culling a species). Never through deltas.

var id: StringName
var name: String
## Argument names in command-line order; "species" takes a species id.
var args: Array[String] = []
var cooldown := 0
## Interventions sharing a group share one cooldown (warm and cool mirrors).
var cooldown_group: StringName
## Ticks the modifiers stay active; 0 for instant interventions.
var duration := 0
## "applied" and, for timed interventions, "ended". {arg} placeholders
## are filled by the chronicle from the event data.
var story: Dictionary[String, String] = {}
## Each entry: {"target", "operation", "value"}.
var modifiers: Array[Dictionary] = []
## Each entry: {"target", "action", "args"}; "$<arg>" values are filled in.
var commands: Array[Dictionary] = []


func source() -> StringName:
	return StringName("intervention:%s" % id)


## Follow-up commands with "$<arg>" replaced by the player's arguments.
func follow_ups(tick: int, values: Dictionary) -> Array[SimCommand]:
	var result: Array[SimCommand] = []
	for entry in commands:
		var filled := {}
		for key: String in entry["args"]:
			var value: Variant = entry["args"][key]
			filled[key] = values[(value as String).substr(1)] if typeof(value) == TYPE_STRING and (value as String).begins_with("$") else value
		result.append(SimCommand.new(tick, StringName(entry["target"]), StringName(entry["action"]), filled))
	return result
