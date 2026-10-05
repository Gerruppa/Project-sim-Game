extends GdUnitTestSuite
## The drought chain on the real planet: humidity falls -> drought starts
## -> its modifier lowers water availability -> ClimateSystem dries the air
## further -> the drought ends. Compared with the same seed without events.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")
const E := preload("res://simulation/tests/support/event_fixtures.gd")

const SEED := 1
const LIMIT := 6000


func _planet(with_events: bool) -> SimulationManager:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(SEED)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH).value, SEED))
	manager.register_system(AtmosphereSystem.new(AtmosphereConfig.load_json(AtmosphereConfig.DEFAULT_PATH).value))
	manager.register_system(BiosphereSystem.new(BiosphereConfig.load_json(BiosphereConfig.DEFAULT_PATH).value,
			SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value, SEED))
	if with_events:
		# Only the drought: other crises would start in the same run.
		manager.register_system(EventSystem.new(E.project_events(["drought"])))
	return manager


func test_drought_dries_the_planet_and_ends() -> void:
	var with_events := _planet(true)
	var without := _planet(false)
	var started: Array[SimEvent] = []
	var ended: Array[SimEvent] = []
	with_events.event_bus().subscribe(EventSystem.STARTED_EVENT, func(event: SimEvent) -> void: started.append(event))
	with_events.event_bus().subscribe(EventSystem.ENDED_EVENT, func(event: SimEvent) -> void: ended.append(event))

	var hash_at_start := ["", ""]
	var drought_humidity := [0.0, 0.0]
	var drought_ticks := 0
	while ended.is_empty() and with_events.tick() < LIMIT:
		with_events.step()
		without.step()
		if started.is_empty():
			continue
		if hash_at_start[0].is_empty():
			hash_at_start = [with_events.state_hash(), without.state_hash()]
			continue
		drought_humidity[0] += with_events.snapshot().get_value(Param.HUMIDITY)
		drought_humidity[1] += without.snapshot().get_value(Param.HUMIDITY)
		drought_ticks += 1

	assert_int(started.size()).override_failure_message("no drought in %d ticks" % LIMIT).is_equal(1)
	assert_str(started[0].data["id"]).is_equal("drought")
	# The cause is readable: every trigger leaf was met by the measured state.
	for fact: Dictionary in started[0].data["causes"]:
		assert_bool(fact["met"]).is_true()
	# Until its modifier acts, an event changes nothing.
	assert_str(hash_at_start[0]).is_equal(hash_at_start[1])
	assert_int(ended.size()).override_failure_message("drought never ended").is_equal(1)
	assert_float(drought_humidity[0] / drought_ticks).override_failure_message(
			"mean humidity during the drought: %.3f with events, %.3f without" % [
			drought_humidity[0] / drought_ticks, drought_humidity[1] / drought_ticks]) \
			.is_less(drought_humidity[1] / drought_ticks)
	assert_array(with_events.modifier_registry().modifiers()).is_empty()
