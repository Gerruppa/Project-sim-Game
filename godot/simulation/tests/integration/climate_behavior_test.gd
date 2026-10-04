extends GdUnitTestSuite
## ClimateSystem inside the real SimulationManager: chain reactions and regimes.

const C := preload("res://simulation/tests/support/climate_fixtures.gd")
const P := preload("res://simulation/tests/support/schema_fixtures.gd")


func _manager(climate: ClimateConfig, start: Dictionary, seed_value: int = 42) -> SimulationManager:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema(), start).value
	manager.register_system(ClimateSystem.new(climate, seed_value))
	return manager


func _value_after(climate: ClimateConfig, start: Dictionary, ticks: int, parameter: StringName) -> float:
	var manager := _manager(climate, start)
	manager.run_ticks(ticks)
	assert_bool(manager.is_halted()).is_false()
	return manager.snapshot().get_value(parameter)


func test_warmer_planet_becomes_more_humid() -> void:
	var warm := _value_after(C.calm(), {"temperature": 45.0}, 100, Param.HUMIDITY)
	var cold := _value_after(C.calm(), {"temperature": 20.0}, 100, Param.HUMIDITY)
	assert_float(warm).is_greater(cold)


func test_humid_air_builds_clouds_and_rain() -> void:
	var humid := _manager(C.calm(), {"temperature": 30.0, "humidity": 50.0})
	var dry := _manager(C.calm(), {"temperature": 30.0, "humidity": 10.0})
	humid.run_ticks(30)
	dry.run_ticks(30)
	assert_float(humid.snapshot().get_value(Param.CLOUD_COVER)).is_greater(dry.snapshot().get_value(Param.CLOUD_COVER))
	assert_float(humid.snapshot().get_value(Param.PRECIPITATION)).is_greater(dry.snapshot().get_value(Param.PRECIPITATION))


func test_ice_albedo_gives_two_stable_climates() -> void:
	# Without drift and seasons the same planet stays where it started:
	# frozen if it starts frozen, warm if it starts warm.
	var climate := C.calm()
	var frozen := _value_after(climate, {"temperature": 5.0, "humidity": 5.0, "cloud_cover": 5.0}, 5000, Param.TEMPERATURE)
	var warm := _value_after(climate, {"temperature": 40.0, "humidity": 30.0, "cloud_cover": 45.0}, 5000, Param.TEMPERATURE)
	assert_float(frozen).is_less(climate.ice_full)
	assert_float(warm).is_greater(climate.ice_free)


func test_seasons_are_visible_in_temperature() -> void:
	var climate := C.config({"drift_noise": 0.0})
	var manager := _manager(climate, {"temperature": 37.0, "humidity": 30.0, "cloud_cover": 45.0})
	manager.run_ticks(climate.season_period_ticks * 3)
	var lowest := 100.0
	var highest := 0.0
	for i in climate.season_period_ticks:
		manager.step()
		var t := manager.snapshot().get_value(Param.TEMPERATURE)
		lowest = minf(lowest, t)
		highest = maxf(highest, t)
	assert_float(highest - lowest).is_greater(2.0)


func test_longer_year_changes_the_season_rhythm() -> void:
	# Year length is data: a different planet character, not a code change.
	var short_year := _manager(C.config({"drift_noise": 0.0, "season_period_ticks": 360}), {})
	var long_year := _manager(C.config({"drift_noise": 0.0, "season_period_ticks": 1440}), {})
	short_year.run_ticks(540)
	long_year.run_ticks(540)
	assert_str(short_year.state_hash()).is_not_equal(long_year.state_hash())
