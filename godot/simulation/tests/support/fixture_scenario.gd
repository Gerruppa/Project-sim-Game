class_name TestFixtureScenario
extends RefCounted
## Minimal tick loop for simulation tests: snapshot -> deltas -> StateWriter.
## Stands in for TickPipeline until it exists.

var state: PlanetState
var tick := 0
var errors := PackedStringArray()

var _writer: StateWriter
var _dynamics: TestFixtureDynamics


func _init(start_state: PlanetState, dynamics: TestFixtureDynamics, start_tick: int) -> void:
	state = start_state
	tick = start_tick
	_writer = StateWriter.new(state)
	_dynamics = dynamics


static func start(schema: ParameterSchema, global_seed: int) -> TestFixtureScenario:
	return TestFixtureScenario.new(PlanetState.create(schema).value, TestFixtureDynamics.new(global_seed), 0)


## RNG state is stored as text: JSON numbers are doubles and would
## drop the low bits of a 64-bit integer.
func save() -> Dictionary:
	return {
		"tick": tick,
		"rng_state": str(_dynamics.rng_state()),
		"planet": PlanetStateCodec.encode(state),
	}


static func restore(schema: ParameterSchema, global_seed: int, saved: Dictionary) -> TestFixtureScenario:
	var decoded := PlanetStateCodec.decode(schema, saved["planet"])
	assert(decoded.is_ok(), "fixture save must decode: %s" % [decoded.errors])
	var dynamics := TestFixtureDynamics.new(global_seed)
	dynamics.set_rng_state((saved["rng_state"] as String).to_int())
	return TestFixtureScenario.new(decoded.value, dynamics, int(saved["tick"]))


func rng_state() -> int:
	return _dynamics.rng_state()


func current_hash() -> String:
	return PlanetStateCodec.state_hash(state)


## Stops at the first rejected batch and keeps the errors.
func run(ticks: int) -> void:
	for i in ticks:
		var report := _writer.apply(_dynamics.compute(state.snapshot(tick)))
		if not report.is_ok():
			errors.append_array(report.errors)
			return
		tick += 1


## Returns "tick hash" lines, one per checkpoint.
func run_with_checkpoints(ticks: int, every: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for i in ticks / every:
		run(every)
		if not errors.is_empty():
			break
		lines.append("%d %s" % [tick, current_hash()])
	return lines
