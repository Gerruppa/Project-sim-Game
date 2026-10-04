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
var _logs: Array[SimulationLog] = []
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


func attach_log(log: SimulationLog) -> void:
	_logs.append(log)
	log.attach(_bus)


## Writes run headers. Called automatically before the first tick.
func start() -> void:
	if _started:
		return
	_started = true
	for log in _logs:
		log.begin_run(_config.seed(), _state.snapshot(_tick))


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
