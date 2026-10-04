extends GdUnitTestSuite

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

var _manager: SimulationManager


func before_test() -> void:
	_manager = _create()


func _create(overrides: Dictionary = {}) -> SimulationManager:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	return SimulationManager.create(config, P.project_schema(), overrides).value


func test_starts_at_tick_zero_with_initial_state() -> void:
	assert_int(_manager.tick()).is_equal(0)
	assert_float(_manager.snapshot().get_value(Param.TEMPERATURE)).is_equal(30.0)
	assert_bool(_manager.is_halted()).is_false()


func test_invalid_overrides_fail_creation() -> void:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	var result := SimulationManager.create(config, P.project_schema(), {"pressure": 1.0})
	assert_bool(result.is_ok()).is_false()


func test_run_ticks_applies_systems_each_tick() -> void:
	_manager.register_system(TestStubSystem.new(&"heater", Param.TEMPERATURE, 1.0))
	assert_int(_manager.run_ticks(5)).is_equal(5)
	assert_int(_manager.tick()).is_equal(5)
	assert_float(_manager.snapshot().get_value(Param.TEMPERATURE)).is_equal(35.0)


func test_register_system_passes_interval() -> void:
	var slow := TestStubSystem.new(&"slow")
	_manager.register_system(slow, 2)
	_manager.run_ticks(6)
	assert_int(slow.seen_ticks.size()).is_equal(3)


func test_register_system_reports_errors() -> void:
	_manager.register_system(TestStubSystem.new(&"heater"))
	assert_bool(_manager.register_system(TestStubSystem.new(&"heater")).is_ok()).is_false()


func test_rejected_batch_halts_simulation() -> void:
	_manager.register_system(TestStubSystem.new(&"broken", Param.TEMPERATURE, NAN))
	assert_int(_manager.run_ticks(10)).is_equal(0)
	assert_bool(_manager.is_halted()).is_true()
	assert_int(_manager.tick()).is_equal(0)
	assert_str("\n".join(_manager.errors())).contains("temperature")
	assert_bool(_manager.step()).is_false()


func test_advance_uses_real_time_and_speed() -> void:
	_manager.register_system(TestStubSystem.new(&"heater"))
	assert_int(_manager.advance(3.0)).is_equal(3)
	_manager.scheduler().set_speed(10)
	assert_int(_manager.advance(1.0)).is_equal(10)
	assert_int(_manager.tick()).is_equal(13)


func test_paused_simulation_does_not_advance() -> void:
	_manager.scheduler().pause()
	assert_int(_manager.advance(100.0)).is_equal(0)
	assert_int(_manager.tick()).is_equal(0)


func test_log_receives_header_and_every_tick() -> void:
	var text := MemoryLogSink.new()
	var jsonl := MemoryLogSink.new()
	_manager.attach_log(SimulationLog.new([text], [jsonl], true))
	_manager.register_system(TestStubSystem.new(&"heater"))
	_manager.run_ticks(2)
	assert_int(text.lines.size()).is_equal(5)
	assert_str(text.lines[3]).starts_with("[Tick 1] temperature")
	assert_str(text.lines[4]).starts_with("[Tick 2] temperature")
	assert_int(jsonl.lines.size()).is_equal(3)


func test_stop_closes_logs() -> void:
	var text := MemoryLogSink.new()
	_manager.attach_log(SimulationLog.new([text], [], true))
	_manager.run_ticks(1)
	_manager.stop()
	assert_bool(text.is_closed()).is_true()


func test_state_hash_matches_codec() -> void:
	_manager.register_system(TestStubSystem.new(&"heater"))
	_manager.run_ticks(3)
	var state: PlanetState = PlanetState.create(P.project_schema(), {"temperature": 33.0}).value
	assert_str(_manager.state_hash()).is_equal(PlanetStateCodec.state_hash(state))
