class_name InterventionSystem
extends ModifierProvider
## The player's hand: interventions requested through CommandQueue.
##
## Phase 1 (Begin) applies a command: starts the cooldown, queues the
## intervention's modifiers and returns follow-up commands for other systems
## (seeding asks the biosphere). Phase 2 registers the modifiers with an
## expiry tick and reports interventions that ran out. Never returns deltas:
## the planet answers through its own systems. Design: docs/gameplay.md.

const ID := &"interventions"
const FORMAT := "interventions_state"
const APPLIED_EVENT := &"intervention_applied"
const ENDED_EVENT := &"intervention_ended"
const REJECTED_EVENT := &"intervention_rejected"

var _catalog: InterventionCatalog
var _species: Array[StringName] = []
## cooldown group -> first tick it can be used again
var _ready_at: Dictionary[StringName, int] = {}
## Timed interventions in effect: {"id", "started", "ends", "args"}, in start order.
var _active: Array[Dictionary] = []
## Started this tick in Begin, registered in phase 2 of the same tick.
var _to_register: Array[Dictionary] = []


## species_ids: species the player may name (the planet's catalog).
func _init(catalog: InterventionCatalog, species_ids: Array[StringName]) -> void:
	_catalog = catalog
	_species = species_ids.duplicate()


func system_id() -> StringName:
	return ID


func catalog() -> InterventionCatalog:
	return _catalog


## First tick the intervention can be used again (0 = ready from the start).
func ready_at(intervention_id: StringName) -> int:
	var def := _catalog.get_def(intervention_id)
	return 0 if def == null else _ready_at.get(def.cooldown_group, 0)


func validate_command(command: SimCommand) -> SimResult:
	var def := _catalog.get_def(command.action)
	if def == null:
		return SimResult.failure("unknown intervention '%s'; known: %s" % [command.action, _catalog.ids_text()])
	var result := SimResult.new()
	for arg in def.args:
		var value: Variant = command.args.get(arg)
		if arg == "species" and (typeof(value) != TYPE_STRING or not _species.has(StringName(value))):
			result.add_error("%s: '%s' is not a species of this planet; known: %s"
					% [def.id, value, ", ".join(PackedStringArray(_species.map(func(id: StringName) -> String: return String(id))))])
	for arg: Variant in command.args:
		if arg == "level" and not def.levels.is_empty():
			if not def.levels.has(str(command.args[arg])):
				result.add_error("%s: unknown level '%s'; known: %s" % [def.id, command.args[arg], ", ".join(PackedStringArray(def.levels.keys()))])
		elif not def.args.has(arg):
			result.add_error("%s: unknown argument '%s'" % [def.id, arg])
	if command.tick < ready_at(def.id):
		result.add_error("%s is not ready: available from tick %d" % [def.name, ready_at(def.id)])
	if result.is_ok():
		result.value = command
	return result


func apply_command(command: SimCommand) -> Array[SimCommand]:
	var def := _catalog.get_def(command.action)
	if def == null:
		return []
	# A command queued for a later tick may meet a cooldown started since.
	if command.tick < ready_at(def.id):
		emit_event(REJECTED_EVENT, {"id": String(def.id), "name": def.name, "ready_at": ready_at(def.id)})
		return []
	_ready_at[def.cooldown_group] = command.tick + def.cooldown
	if not def.modifiers.is_empty():
		var entry := {"id": String(def.id), "started": command.tick, "ends": command.tick + def.duration - 1,
				"args": command.args.duplicate()}
		_active.append(entry)
		_to_register.append(entry)
	var data := {"id": String(def.id), "name": def.name, "story": def.story["applied"], "duration": def.duration}
	data.merge(command.args)
	if not def.levels.is_empty():
		data["level"] = def.level_of(command.args)
		data["level_name"] = def.levels[data["level"]]["name"]
	emit_event(APPLIED_EVENT, data)
	return def.follow_ups(command.tick, command.args)


func provide_modifiers(_snapshot: PlanetSnapshot, tick: int, registry: ModifierRegistry) -> void:
	for entry in _to_register:
		_register(entry, registry)
	_to_register.clear()
	var still_active: Array[Dictionary] = []
	for entry in _active:
		if entry["ends"] < tick:
			var def := _catalog.get_def(StringName(entry["id"]))
			var data := {"id": entry["id"], "name": def.name, "story": def.story["ended"]}
			data.merge(entry["args"])
			emit_event(ENDED_EVENT, data)
		else:
			still_active.append(entry)
	_active = still_active


func restore_modifiers(registry: ModifierRegistry) -> void:
	for entry in _active:
		registry.remove_source(_catalog.get_def(StringName(entry["id"])).source())
	for entry in _active:
		_register(entry, registry)


func _register(entry: Dictionary, registry: ModifierRegistry) -> void:
	var def := _catalog.get_def(StringName(entry["id"]))
	for raw in def.modifiers:
		var modifier := Modifier.new(StringName(raw["target"]), StringName(raw["operation"]),
				def.scaled_value(raw, def.level_of(entry["args"])), def.source(), entry["ends"])
		# Planets without the target system (e.g. no biosphere) skip it.
		if registry.has_target(modifier.system_id()):
			registry.add(modifier)


func save_state() -> Dictionary:
	var ready := {}
	for group in _ready_at:
		ready[String(group)] = _ready_at[group]
	return {"format": FORMAT, "ready_at": ready, "active": _active.duplicate(true)}


func load_state(data: Dictionary) -> SimResult:
	if data.get("format") != FORMAT:
		return SimResult.failure("interventions: format must be '%s'" % FORMAT)
	var ready: Variant = data.get("ready_at")
	var active: Variant = data.get("active")
	if typeof(ready) != TYPE_DICTIONARY or typeof(active) != TYPE_ARRAY:
		return SimResult.failure("interventions: needs 'ready_at' (object) and 'active' (list)")
	var restored_ready: Dictionary[StringName, int] = {}
	for group: Variant in ready:
		if not _is_tick(ready[group]):
			return SimResult.failure("interventions: ready_at '%s' must be a tick" % group)
		restored_ready[StringName(group)] = int(ready[group])
	var restored_active: Array[Dictionary] = []
	for raw: Variant in active:
		if typeof(raw) != TYPE_DICTIONARY or _catalog.get_def(StringName(str(raw.get("id")))) == null \
				or not _is_tick(raw.get("started")) or not _is_tick(raw.get("ends")) or typeof(raw.get("args")) != TYPE_DICTIONARY:
			return SimResult.failure("interventions: active entry %s is not a known intervention" % [raw])
		restored_active.append({"id": raw["id"], "started": int(raw["started"]), "ends": int(raw["ends"]), "args": raw["args"]})
	_ready_at = restored_ready
	_active = restored_active
	_to_register.clear()
	return SimResult.success(self)


static func _is_tick(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) == floorf(float(value)) and float(value) >= 0.0
