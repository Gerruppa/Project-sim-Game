class_name TickPipeline
extends RefCounted
## The fixed order of one tick. No other module defines this order.
##
##   1. Begin       commands (added with CommandQueue)
##   2. Modifiers   effective coefficients (added with ModifierRegistry)
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
	return SimResult.success(system)


func system_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for system in _systems:
		ids.append(system.system_id())
	return ids


## Executes tick number `tick` (the first tick is 1).
func execute(tick: int) -> ApplyReport:
	# 3. Compute: every system sees the same snapshot, so call order
	# does not matter and no system observes another system's changes.
	var snapshot := _state.snapshot(tick - 1)
	var deltas: Array[Delta] = []
	for i in _systems.size():
		if TickScheduler.is_due(tick, _intervals[i]):
			deltas.append_array(_systems[i].compute(snapshot))

	# 4. Apply
	var report := _writer.apply(deltas)

	# 6. Dispatch
	var type := SimEvent.TICK_APPLIED if report.is_ok() else SimEvent.BATCH_REJECTED
	_bus.publish(SimEvent.new(type, tick, &"pipeline", {"report": report}))
	_bus.flush()
	return report
