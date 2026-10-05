class_name SimulationSystem
extends RefCounted
## Contract of every domain system (Climate, Atmosphere, Biosphere, ...).
##
## A system is a function of the world: it reads a snapshot of the previous
## tick and returns deltas. It never writes PlanetState and never references
## other systems. One level of inheritance only; behaviour comes from
## composition inside each system.
##
## A system may also report facts (species emerged, species extinct) with
## emit_event(). TickPipeline collects them and publishes them in the
## Dispatch phase, after the tick event, only if the tick's batch was applied.

## Each entry: [type, data].
var _pending_events: Array[Array] = []


## Unique, stable id. Used as delta source, event source and SeededRng stream id.
func system_id() -> StringName:
	push_error("SimulationSystem.system_id must be overridden")
	return &""


func compute(_snapshot: PlanetSnapshot) -> Array[Delta]:
	push_error("SimulationSystem.compute must be overridden")
	return []


## Systems with a coefficient file return it here so modifiers (personality,
## events) can reach it. The pipeline keeps this object as the untouched base.
func coefficients() -> Object:
	return null


## name -> [min, max, integer] for every modifiable coefficient.
func coefficient_spec() -> Dictionary:
	return {}


## Receives an effective copy of coefficients() with modifiers applied.
func apply_coefficients(_effective: Object) -> void:
	pass


## Internal state that is not a planet parameter (populations, RNG streams,
## event phases), as plain JSON values. SaveSystem stores it under
## system_id(). A system without internal state keeps the empty default.
func save_state() -> Dictionary:
	return {}


## Restores save_state() output between ticks. On failure the system may be
## partly restored and must be discarded.
func load_state(data: Dictionary) -> SimResult:
	if not data.is_empty():
		return SimResult.failure("%s: has no state to load, got %s" % [system_id(), data.keys()])
	return SimResult.success(self)


## Queues a notification for the current tick. Data should be plain values.
func emit_event(type: StringName, data: Dictionary) -> void:
	_pending_events.append([type, data])


## Returns queued notifications as events of tick `tick` and clears the queue.
func take_events(tick: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for pending in _pending_events:
		events.append(SimEvent.new(pending[0], tick, system_id(), pending[1]))
	_pending_events.clear()
	return events
