extends GdUnitTestSuite
## Many seeds with the project climate: interesting, not flat, not stuck at limits.
## Targets come from the design prototype (docs/climate.md, "Balance").

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const SEEDS := 8
const TICKS := 15000
const WARM_UP := 2000
## Hysteresis band for regime detection.
const ICY_BELOW := 16.0
const WARM_ABOVE := 28.0


class RunStats:
	var halted := false
	var mean_temperature := 0.0
	var ticks_at_zero := 0
	var regime_switches := 0
	var icy_ticks := 0
	var precipitation_range := 0.0


func _run(seed_value: int) -> RunStats:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH).value, seed_value))
	var stats := RunStats.new()
	var regime := ""
	var total := 0.0
	var rain_low := 100.0
	var rain_high := 0.0
	for tick in TICKS:
		if not manager.step():
			stats.halted = true
			return stats
		if tick < WARM_UP:
			continue
		var snapshot := manager.snapshot()
		var t := snapshot.get_value(Param.TEMPERATURE)
		var rain := snapshot.get_value(Param.PRECIPITATION)
		total += t
		rain_low = minf(rain_low, rain)
		rain_high = maxf(rain_high, rain)
		if t <= 0.5:
			stats.ticks_at_zero += 1
		if t < ICY_BELOW:
			stats.icy_ticks += 1
		var now := "icy" if t < ICY_BELOW else ("warm" if t > WARM_ABOVE else regime)
		if not regime.is_empty() and now != regime:
			stats.regime_switches += 1
		regime = now
	stats.mean_temperature = total / (TICKS - WARM_UP)
	stats.precipitation_range = rain_high - rain_low
	return stats


func test_climate_is_varied_but_bounded_on_many_seeds() -> void:
	var seeds_with_ice_ages := 0
	for seed_value in range(1, SEEDS + 1):
		var stats := _run(seed_value)
		var label := "seed %d" % seed_value
		assert_bool(stats.halted).override_failure_message(label + " halted").is_false()
		# Mostly a temperate young planet, not frozen and not boiling.
		assert_float(stats.mean_temperature).override_failure_message(label).is_between(20.0, 40.0)
		# Hitting the lower limit is a rare extreme, never the normal state.
		assert_int(stats.ticks_at_zero).override_failure_message(label).is_less(int((TICKS - WARM_UP) * 0.01))
		# Ice ages happen, but the planet spends most of the time warm.
		assert_int(stats.icy_ticks).override_failure_message(label).is_less(int((TICKS - WARM_UP) * 0.5))
		# Rain varies: the water cycle is alive.
		assert_float(stats.precipitation_range).override_failure_message(label).is_greater(5.0)
		if stats.regime_switches >= 2:
			seeds_with_ice_ages += 1
	assert_int(seeds_with_ice_ages).override_failure_message(
			"ice ages on %d of %d seeds" % [seeds_with_ice_ages, SEEDS]).is_greater_equal(SEEDS - 2)


func test_same_seed_gives_same_climate() -> void:
	var hashes := PackedStringArray()
	for i in 2:
		var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
		var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
		manager.register_system(ClimateSystem.new(ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH).value, 42))
		manager.run_ticks(5000)
		hashes.append(manager.state_hash())
	assert_str(hashes[0]).is_equal(hashes[1])
