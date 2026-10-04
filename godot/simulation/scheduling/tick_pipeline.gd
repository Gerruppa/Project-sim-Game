class_name TickPipeline
extends RefCounted
## The fixed order of one tick. No other module defines this order.
##
##   1. Begin       commands (added with CommandQueue)
##   2. Modifiers   providers add/remove modifiers, expired ones drop,
##                  effective coefficients reach systems
##   3. Compute     due systems read the snapshot of tick N-1, return deltas
##   4. Apply       StateWriter validates, sorts, sums, clamps, commits
##   5. Detect      event conditions (added with EventSystem)
##   6. Dispatch    tick event published, EventBus flushed
##   7. End         report returned to SimulationManager

var _state: PlanetState
var _writer: StateWriter
var _bus: EventBus
var _systems: Array[SimulationSystem] = []
var _intervals: Array[int] = []
var _registry := ModifierRegistry.new()
## system id -> untouched base coefficients
var _base_coefficients: Dictionary[StringName, Object] = {}
var _applied_version := 0


func _init(state: PlanetState, bus: EventBus) -> void:
	_state = state
	_writer = StateWriter.new(state)
	_bus = bus


func register(system: SimulationSystem, interval: int) -> SimResult:
	var id := system.system_id()
	if id.is_empty():
		return SimResult.failure("system needs a non-empty system_id")
	if interval < 1:
		return SimResult.failure("system '%s': interval must be >= 1 tick" % id)
	if system_ids().has(id):
		return SimResult.failure("system '%s' is already registered" % id)
	_systems.append(system)
	_intervals.append(interval)
	if system.coefficients() != null:
		_base_coefficients[id] = system.coefficients()
		_registry.register_target(id, system.coefficient_spec())
	return SimResult.success(system)


func modifier_registry() -> ModifierRegistry:
	return _registry


func system_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for system in _systems:
		ids.append(system.system_id())
	return ids


## Executes tick number `tick` (the first tick is 1).
func execute(tick: int) -> ApplyReport:
	var snapshot := _state.snapshot(tick - 1)

	# 2. Modifiers
	_update_modifiers(snapshot, tick)

	# 3. Compute: every system sees the same snapshot, so call order
	# does not matter and no system observes another system's changes.
	var deltas: Array[Delta] = []
	for i in _systems.size():
		if TickScheduler.is_due(tick, _intervals[i]):
			deltas.append_array(_systems[i].compute(snapshot))

	# 4. Apply
	var report := _writer.apply(deltas)

	# 6. Dispatch: the tick event first, then facts reported by systems
	# (in registration order). A rejected batch never happened, so its
	# system events are dropped.
	var type := SimEvent.TICK_APPLIED if report.is_ok() else SimEvent.BATCH_REJECTED
	_bus.publish(SimEvent.new(type, tick, &"pipeline", {"report": report}))
	for system in _systems:
		var events := system.take_events(tick)
		if report.is_ok():
			for event in events:
				_bus.publish(event)
	_bus.flush()
	return report


## Providers run first (all of them, in registration order), then modifiers
## past their last tick drop, then effective coefficients are rebuilt only
## if the set of modifiers changed. With no modifiers nothing is touched,
## so a planet without personality runs bit-identically.
func _update_modifiers(snapshot: PlanetSnapshot, tick: int) -> void:
	for system in _systems:
		if system is ModifierProvider:
			(system as ModifierProvider).provide_modifiers(snapshot, tick, _registry)
	_registry.expire(tick - 1)
	if _registry.version() == _applied_version:
		return
	_applied_version = _registry.version()
	for system in _systems:
		var id := system.system_id()
		if _base_coefficients.has(id):
			system.apply_coefficients(_registry.resolve(id, _base_coefficients[id]))
