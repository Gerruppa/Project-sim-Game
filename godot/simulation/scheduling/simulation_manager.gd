class_name SimulationManager
extends RefCounted
## Wires the simulation together and runs ticks. Orchestration only:
## no business logic lives here.
##
## Owns PlanetState, TickScheduler, TickPipeline, EventBus and the logs it
## was given. Keeps references to attached logs because EventBus
## subscriptions do not keep objects alive.

var _config: SimConfig
var _state: PlanetState
var _bus := EventBus.new()
var _scheduler: TickScheduler
var _pipeline: TickPipeline
var _logs: Array[RunObserver] = []
var _tick := 0
var _started := false
var _halted := false
var _errors := PackedStringArray()


static func create(config: SimConfig, schema: ParameterSchema, overrides: Dictionary = {}) -> SimResult:
	var state_result := PlanetState.create(schema, overrides)
	if not state_result.is_ok():
		return state_result
	var manager := SimulationManager.new()
	manager._config = config
	manager._state = state_result.value
	manager._scheduler = TickScheduler.new(config)
	manager._pipeline = TickPipeline.new(manager._state, manager._bus)
	return SimResult.success(manager)


func register_system(system: SimulationSystem, interval: int = 1) -> SimResult:
	return _pipeline.register(system, interval)


## Any observer of the run: SimulationLog, PlanetChronicle, ...
func attach_log(log: RunObserver) -> void:
	_logs.append(log)
	log.attach(_bus)


## Writes run headers. Called automatically before the first tick.
func start() -> void:
	if _started:
		return
	_started = true
	for log in _logs:
		log.begin_run(_config.seed(), _state.snapshot(_tick))


## Continues a saved run: tick counter and planet state. Only before the
## first tick; SaveSystem restores the systems' own state.
func restore(tick_value: int, saved: PlanetState) -> SimResult:
	if _started:
		return SimResult.failure("restore: the run has already started")
	if tick_value < 0:
		return SimResult.failure("restore: tick must be >= 0")
	var restored := _pipeline.restore_state(saved)
	if restored.is_ok():
		_tick = tick_value
	return restored


func systems() -> Array[SimulationSystem]:
	return _pipeline.systems()


func is_started() -> bool:
	return _started


## Runs one tick. Returns false if the simulation is halted.
func step() -> bool:
	if _halted:
		return false
	start()
	var report := _pipeline.execute(_tick + 1)
	if not report.is_ok():
		_halted = true
		_errors.append_array(report.errors)
		return false
	_tick += 1
	return true


## Runs up to `count` ticks; stops early when halted. Returns ticks executed.
func run_ticks(count: int) -> int:
	var executed := 0
	while executed < count and step():
		executed += 1
	return executed


## Real-time driver: lets the scheduler decide how many ticks are due.
func advance(real_seconds: float) -> int:
	return run_ticks(_scheduler.advance(real_seconds))


func stop() -> void:
	for log in _logs:
		log.close()


func tick() -> int:
	return _tick


func is_halted() -> bool:
	return _halted


func errors() -> PackedStringArray:
	return _errors.duplicate()


func snapshot() -> PlanetSnapshot:
	return _state.snapshot(_tick)


## The live state, for SaveSystem. Everything else reads snapshot().
func current_state() -> PlanetState:
	return _state


func state_hash() -> String:
	return PlanetStateCodec.state_hash(_state)


func modifier_registry() -> ModifierRegistry:
	return _pipeline.modifier_registry()


func scheduler() -> TickScheduler:
	return _scheduler


func event_bus() -> EventBus:
	return _bus


func config() -> SimConfig:
	return _config
