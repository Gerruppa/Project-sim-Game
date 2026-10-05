class_name EventSystem
extends ModifierProvider
## World events and planet reactions that emerge from the planet's state.
##
## Runs in tick phase 5 (Detect), on the state the tick just produced:
## records the history the conditions read, advances every event's
## lifecycle, and while an event is active keeps its modifiers registered.
## Those take effect from the next tick's phase 2. An event never writes
## PlanetState: a drought lowers how much water the land gives back, and
## ClimateSystem produces the drying itself (docs/events.md).
##
## Reactions are ordinary definitions limited to some archetypes. The
## archetype arrives as an id, so this system does not depend on
## PersonalitySystem.

const ID := &"events"
const FORMAT := "event_system"
const STARTED_EVENT := &"world_event_started"
const ENDED_EVENT := &"world_event_ended"
const NUMBER_FORMAT := "%.2f"

var _archetype: StringName
## Definitions that apply to this planet, in catalog order.
var _defs: Array[EventDef] = []
var _lifecycles: Array[EventLifecycle] = []
var _required: Array[int] = []
var _history: ParamHistory


## archetype: the planet's archetype id ("none" or empty for no personality).
func _init(catalog: EventCatalog, archetype: StringName = &"") -> void:
	_archetype = archetype
	var needs := {}
	for def in catalog.all():
		if not def.applies_to(archetype):
			continue
		_defs.append(def)
		_lifecycles.append(EventLifecycle.new())
		_required.append(def.required_samples())
		var def_needs := def.history_needs()
		for id: StringName in def_needs:
			needs[id] = maxi(int(needs.get(id, 0)), int(def_needs[id]))
	_history = ParamHistory.new(needs)


static func source_of(def: EventDef) -> StringName:
	return StringName("event:%s" % def.id)


func system_id() -> StringName:
	return ID


## Ids of the events this planet can have.
func event_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def in _defs:
		ids.append(def.id)
	return ids


func phase_of(id: StringName) -> StringName:
	for i in _defs.size():
		if _defs[i].id == id:
			return _lifecycles[i].phase
	return &""


func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for i in _defs.size():
		if _lifecycles[i].phase == EventLifecycle.ACTIVE:
			ids.append(_defs[i].id)
	return ids


func detect(snapshot: PlanetSnapshot, _tick: int, registry: ModifierRegistry) -> void:
	_history.record(snapshot)
	for i in _defs.size():
		var lifecycle := _lifecycles[i]
		var waiting := lifecycle.phase == EventLifecycle.INACTIVE or lifecycle.phase == EventLifecycle.PENDING
		if waiting and _history.recorded() < _required[i]:
			continue
		match lifecycle.advance(_defs[i], _history):
			EventLifecycle.STARTED:
				_start(_defs[i], registry)
			EventLifecycle.ENDED:
				_end(_defs[i], lifecycle, registry)


func _start(def: EventDef, registry: ModifierRegistry) -> void:
	var applied := _register_modifiers(def, registry)
	var facts := def.trigger.describe(_history)
	emit_event(STARTED_EVENT, {
		"id": String(def.id),
		"name": def.name,
		"causes": facts,
		"modifiers": applied,
		"story": def.story["start"],
		"summary": "%s started: %s" % [def.name, _facts_text(facts)],
	})


func _end(def: EventDef, lifecycle: EventLifecycle, registry: ModifierRegistry) -> void:
	registry.remove_source(source_of(def))
	var facts := def.end.describe(_history)
	var by_conditions := lifecycle.end_reason == EventLifecycle.END_CONDITIONS
	var why := "end conditions" if by_conditions else "time limit"
	emit_event(ENDED_EVENT, {
		"id": String(def.id),
		"name": def.name,
		"reason": String(lifecycle.end_reason),
		"duration": lifecycle.elapsed,
		"causes": facts,
		"story": def.story["end"] if by_conditions else def.story["end_time_limit"],
		"summary": "%s ended after %d ticks (%s): %s" % [def.name, lifecycle.elapsed, why, _facts_text(facts)],
	})


## Modifiers for systems the planet does not run are skipped (like personality).
func _register_modifiers(def: EventDef, registry: ModifierRegistry) -> Array[String]:
	var applied: Array[String] = []
	for entry in def.modifiers:
		var modifier := Modifier.new(StringName(entry["target"]), StringName(entry["operation"]), entry["value"], source_of(def))
		if registry.has_target(modifier.system_id()) and registry.add(modifier).is_ok():
			applied.append("%s %s %s" % [modifier.target, modifier.operation, modifier.value])
	return applied


static func _facts_text(facts: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for fact in facts:
		var measured := "%s %s" % [fact["param"], fact["measure"]] if fact["measure"] != "value" else String(fact["param"])
		if fact["window"] > 0:
			measured += "(%d)" % fact["window"]
		var comparison := "%s %s" % [fact["op"], fact["threshold"]]
		parts.append("%s %s %s" % [measured, NUMBER_FORMAT % fact["measured"],
				comparison if fact["met"] else "not " + comparison])
	return "; ".join(parts)


## Lifecycles and history; active modifiers are not stored, load_state
## registers them again from the phases (one source of truth).
func save_state() -> Dictionary:
	var events := {}
	for i in _defs.size():
		events[String(_defs[i].id)] = _lifecycles[i].to_dict()
	return {"format": FORMAT, "archetype": String(_archetype), "history": _history.to_dict(), "events": events}


func load_state(data: Dictionary, registry: ModifierRegistry) -> SimResult:
	if data.get("format") != FORMAT:
		return SimResult.failure("events: format must be '%s'" % FORMAT)
	if data.get("archetype") != String(_archetype):
		return SimResult.failure("events: saved for archetype '%s', this planet is '%s'" % [data.get("archetype"), _archetype])
	var events: Variant = data.get("events")
	if typeof(events) != TYPE_DICTIONARY or (events as Dictionary).size() != _defs.size():
		return SimResult.failure("events: 'events' must hold exactly %s" % [event_ids()])
	var history: Variant = data.get("history")
	if typeof(history) != TYPE_DICTIONARY:
		return SimResult.failure("events: missing 'history'")
	var restored: Array[EventLifecycle] = []
	for def in _defs:
		var lifecycle := EventLifecycle.new()
		var read := lifecycle.load_dict((events as Dictionary).get(String(def.id)))
		if not read.is_ok():
			return SimResult.failure("events: '%s': %s" % [def.id, read.errors[0]])
		restored.append(lifecycle)
	var history_read := _history.load_dict(history)
	if not history_read.is_ok():
		return history_read
	_lifecycles = restored
	for i in _defs.size():
		registry.remove_source(source_of(_defs[i]))
		if _lifecycles[i].phase == EventLifecycle.ACTIVE:
			_register_modifiers(_defs[i], registry)
	return SimResult.success(self)
