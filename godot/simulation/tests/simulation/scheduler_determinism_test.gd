extends GdUnitTestSuite
## Speed, pauses and frame timing must never change the simulation result.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const SEED := 42


func _manager() -> SimulationManager:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(TestFixtureSystem.new(SEED))
	return manager


func test_x1_x10_x100_reach_identical_state() -> void:
	var slow := _manager()
	for i in 600:
		slow.advance(1.0)
	var medium := _manager()
	medium.scheduler().set_speed(10)
	for i in 60:
		medium.advance(1.0)
	var fast := _manager()
	fast.scheduler().set_speed(100)
	for i in 6:
		fast.advance(1.0)

	assert_int(slow.tick()).is_equal(600)
	assert_int(medium.tick()).is_equal(600)
	assert_int(fast.tick()).is_equal(600)
	assert_str(medium.state_hash()).is_equal(slow.state_hash())
	assert_str(fast.state_hash()).is_equal(slow.state_hash())


func test_pauses_and_uneven_frames_do_not_change_result() -> void:
	var steady := _manager()
	steady.run_ticks(300)

	var bumpy := _manager()
	var frames := [0.016, 0.5, 0.033, 1.7, 0.25]
	var i := 0
	while bumpy.tick() < 300:
		if i % 7 == 3:
			bumpy.scheduler().pause()
		bumpy.advance(minf(frames[i % frames.size()], 300 - bumpy.tick()))
		bumpy.scheduler().resume()
		i += 1
	assert_int(bumpy.tick()).is_equal(300)
	assert_str(bumpy.state_hash()).is_equal(steady.state_hash())


func test_pipeline_matches_reference_loop() -> void:
	# The fixture scenario is the simple reference loop the golden trace
	# was recorded with. The real pipeline must produce identical states.
	var reference := TestFixtureScenario.start(P.project_schema(), SEED)
	reference.run(3000)
	var manager := _manager()
	manager.run_ticks(3000)
	assert_str(manager.state_hash()).is_equal(reference.current_hash())
