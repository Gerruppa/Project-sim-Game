class_name InterventionDef
extends RefCounted
## One player intervention as written in data. Read-only after loading.
##
## An intervention acts only through channels the simulation already has:
## modifiers (temporary coefficient changes, like events) and commands to
## other systems (seeding or culling a species). Never through deltas.

var id: StringName
var name: String
## One sentence for the player: what it does and what it costs.
var help := ""
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
## Optional strengths the player picks with the "level" argument:
## level id -> {"scale": 0..1, "name": word for the chronicle}. Empty when
## the intervention has one strength.
var levels: Dictionary[String, Dictionary] = {}
## Level used when the player names none.
var default_level := ""


## The level a command asks for (its "level" argument or the default).
func level_of(args: Dictionary) -> String:
	return str(args.get("level", default_level))


## A modifier value at a level: "add" scales the amount, "multiply" scales
## the distance from 1, so a weaker level always lies between no effect and
## full strength.
func scaled_value(modifier: Dictionary, level: String) -> float:
	var value: float = modifier["value"]
	if levels.is_empty() or not levels.has(level):
		return value
	var scale: float = levels[level]["scale"]
	return value * scale if modifier["operation"] == "add" else 1.0 + (value - 1.0) * scale


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
