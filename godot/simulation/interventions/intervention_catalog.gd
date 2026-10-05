class_name InterventionCatalog
extends RefCounted
## Player interventions loaded from JSON and validated against what the
## planet can actually be asked to do: modifier targets come from system
## coefficient specs, commands from the systems' command lists. A typo is a
## load error, not an intervention that silently does nothing.

const DEFAULT_PATH := "res://resources/interventions/interventions.json"
const KEYS := ["id", "name", "args", "cooldown", "cooldown_group", "duration", "story", "modifiers", "commands"]
## Argument kinds the player can pass.
const ARG_KINDS: Array[String] = ["species"]

var _defs: Array[InterventionDef] = []
## Event types that stop a run waiting for the player (--until decision).
var decision_events: Array[StringName] = []
## Ticks after the run starts before a decision point counts, so the player
## first sees what their own action caused (seeding moss "emerges" moss).
var decision_grace := 0


## specs: system id -> coefficient spec (modifier targets).
## command_specs: system id -> {action: {argument: [min, max]}} (SimulationSystem commands).
static func load_json(path: String, specs: Dictionary, command_specs: Dictionary) -> SimResult:
	var read := CoefficientLoader.read_json(path, "interventions")
	return from_data(read.value, specs, command_specs) if read.is_ok() else read


## Reports all errors at once.
static func from_data(data: Dictionary, specs: Dictionary, command_specs: Dictionary) -> SimResult:
	var result := SimResult.new()
	var raw: Variant = data.get("interventions")
	if typeof(raw) != TYPE_ARRAY:
		return SimResult.failure("interventions: 'interventions' must be a list")
	var catalog := InterventionCatalog.new()
	_parse_decision_points(data.get("decision_points"), catalog, result)
	var seen: Array[StringName] = []
	for i in (raw as Array).size():
		var def := _parse(raw[i], i, specs, command_specs, result)
		if def == null:
			continue
		if seen.has(def.id):
			result.add_error("interventions: duplicate id '%s'" % def.id)
		seen.append(def.id)
		catalog._defs.append(def)
	if result.is_ok():
		result.value = catalog
	return result


static func _parse_decision_points(raw: Variant, catalog: InterventionCatalog, result: SimResult) -> void:
	if typeof(raw) != TYPE_DICTIONARY or typeof(raw.get("events")) != TYPE_ARRAY or (raw["events"] as Array).is_empty() \
			or not (raw["events"] as Array).all(func(e: Variant) -> bool: return typeof(e) == TYPE_STRING and not (e as String).is_empty()):
		result.add_error("interventions: 'decision_points' needs 'events' (a list of event types) and 'grace_ticks'")
		return
	for event: String in raw["events"]:
		catalog.decision_events.append(StringName(event))
	catalog.decision_grace = _whole(raw.get("grace_ticks"), "decision_points.grace_ticks", "interventions", result)


static func _parse(raw: Variant, index: int, specs: Dictionary, command_specs: Dictionary, result: SimResult) -> InterventionDef:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("interventions[%d] must be an object" % index)
		return null
	var data := raw as Dictionary
	var def := InterventionDef.new()
	var label := "interventions[%d]" % index
	for key: Variant in data:
		if not KEYS.has(key):
			result.add_error("%s: unknown key '%s'" % [label, key])
	if typeof(data.get("id")) != TYPE_STRING or (data["id"] as String).is_empty():
		result.add_error("%s: 'id' must be a non-empty string" % label)
	else:
		def.id = StringName(data["id"])
		label = "intervention '%s'" % def.id
	if typeof(data.get("name")) != TYPE_STRING or (data["name"] as String).is_empty():
		result.add_error("%s: 'name' must be a non-empty string" % label)
	else:
		def.name = data["name"]
	var args: Variant = data.get("args", [])
	if typeof(args) != TYPE_ARRAY or not (args as Array).all(func(a: Variant) -> bool: return typeof(a) == TYPE_STRING and ARG_KINDS.has(a)):
		result.add_error("%s: 'args' must list argument kinds from %s" % [label, ARG_KINDS])
	else:
		for arg: String in args:
			def.args.append(arg)
	def.duration = _whole(data.get("duration", 0), "duration", label, result)
	def.cooldown = _whole(data.get("cooldown"), "cooldown", label, result)
	var group: Variant = data.get("cooldown_group", data.get("id", ""))
	if typeof(group) != TYPE_STRING or (group as String).is_empty():
		result.add_error("%s: 'cooldown_group' must be a non-empty string" % label)
	else:
		def.cooldown_group = StringName(group)
	_parse_effects(data, def, label, specs, command_specs, result)
	_parse_story(data.get("story"), def, label, result)
	if def.cooldown < def.duration:
		result.add_error("%s: cooldown must be at least the duration (one copy active at a time)" % label)
	return def


static func _parse_effects(data: Dictionary, def: InterventionDef, label: String, specs: Dictionary,
		command_specs: Dictionary, result: SimResult) -> void:
	var modifiers: Variant = data.get("modifiers", [])
	var commands: Variant = data.get("commands", [])
	if typeof(modifiers) != TYPE_ARRAY or typeof(commands) != TYPE_ARRAY:
		result.add_error("%s: 'modifiers' and 'commands' must be lists" % label)
		return
	if (modifiers as Array).is_empty() and (commands as Array).is_empty():
		result.add_error("%s: needs at least one modifier or command" % label)
	if not (modifiers as Array).is_empty() and def.duration < 1:
		result.add_error("%s: modifiers need a duration of at least 1 tick" % label)
	for modifier: Variant in modifiers:
		Modifier.check_data(modifier, label, specs, result)
		if typeof(modifier) == TYPE_DICTIONARY:
			def.modifiers.append(modifier)
	for command: Variant in commands:
		if _check_command(command, def, label, command_specs, result):
			def.commands.append(command)


static func _check_command(command: Variant, def: InterventionDef, label: String, command_specs: Dictionary, result: SimResult) -> bool:
	if typeof(command) != TYPE_DICTIONARY or typeof(command.get("args")) != TYPE_DICTIONARY:
		result.add_error("%s: every command needs 'target', 'action' and an 'args' object" % label)
		return false
	var target := StringName(str(command.get("target")))
	var action := StringName(str(command.get("action")))
	if not command_specs.has(target) or not (command_specs[target] as Dictionary).has(action):
		result.add_error("%s: '%s.%s' is not a command any system accepts" % [label, target, action])
		return false
	var spec: Dictionary = command_specs[target][action]
	var ok := true
	for name: Variant in command["args"]:
		if not spec.has(name):
			result.add_error("%s: %s.%s has no argument '%s'" % [label, target, action, name])
			ok = false
	for name: String in spec:
		var value: Variant = command["args"].get(name)
		if typeof(value) == TYPE_STRING and (value as String).begins_with("$"):
			if not def.args.has((value as String).substr(1)):
				result.add_error("%s: '%s' is not an argument of this intervention" % [label, value])
				ok = false
		elif (spec[name] as Array).is_empty() or not (typeof(value) in [TYPE_INT, TYPE_FLOAT]) \
				or float(value) < spec[name][0] or float(value) > spec[name][1]:
			result.add_error("%s: %s.%s '%s' must be %s" % [label, target, action, name,
					"an intervention argument ($...)" if (spec[name] as Array).is_empty() else "a number in %s..%s" % spec[name]])
			ok = false
	return ok


static func _parse_story(raw: Variant, def: InterventionDef, label: String, result: SimResult) -> void:
	var needed: Array[String] = ["applied"]
	if def.duration > 0:
		needed.append("ended")
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("%s: 'story' must be an object with %s" % [label, needed])
		return
	for key: Variant in raw:
		if not needed.has(key):
			result.add_error("%s: unexpected story key '%s'" % [label, key])
	for key in needed:
		var text: Variant = (raw as Dictionary).get(key)
		if typeof(text) != TYPE_STRING or (text as String).is_empty():
			result.add_error("%s: story '%s' must be a non-empty string" % [label, key])
		else:
			def.story[key] = text


static func _whole(value: Variant, key: String, label: String, result: SimResult) -> int:
	if not (typeof(value) in [TYPE_INT, TYPE_FLOAT]) or float(value) != floorf(float(value)) or float(value) < 0.0:
		result.add_error("%s: '%s' must be an integer >= 0" % [label, key])
		return 0
	return int(value)


func get_def(id: StringName) -> InterventionDef:
	for def in _defs:
		if def.id == id:
			return def
	return null


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for def in _defs:
		result.append(def.id)
	return result


func ids_text() -> String:
	return ", ".join(PackedStringArray(ids().map(func(id: StringName) -> String: return String(id))))


## "seed_species:moss" -> {"action": &"seed_species", "args": {"species": "moss"}}.
## Arguments follow the colon in the order the definition lists them.
func parse_text(text: String) -> SimResult:
	var parts := text.split(":")
	var def := get_def(StringName(parts[0]))
	if def == null:
		return SimResult.failure("unknown intervention '%s'; known: %s" % [parts[0], ids_text()])
	var values := parts.slice(1)
	if values.size() != def.args.size():
		return SimResult.failure("%s needs %s" % [def.id, "no arguments" if def.args.is_empty()
				else "%s, e.g. %s:%s" % [def.args, def.id, ":".join(PackedStringArray(def.args.map(func(a: String) -> String: return "<" + a + ">")))]])
	var args := {}
	for i in def.args.size():
		args[def.args[i]] = values[i]
	return SimResult.success({"action": def.id, "args": args})
