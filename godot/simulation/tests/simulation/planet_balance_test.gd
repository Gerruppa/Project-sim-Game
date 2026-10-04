extends GdUnitTestSuite
## Climate and atmosphere together on many seeds, as the game runs them.
## Targets come from the design prototype (docs/climate.md, AtmosphereSystem).

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const SEEDS := 6
const TICKS := 15000
const WARM_UP := 2000
const ICY_BELOW := 16.0
const WARM_ABOVE := 28.0


class RunStats:
	var halted := false
	var mean_temperature := 0.0
	var ticks_at_zero := 0
	var icy_ticks := 0
	var ice_ages := 0
	var longest_ice_age := 0
	var co2_low := 100.0
	var co2_high := 0.0
	var oxygen_high := 0.0
	var crust_high := 0.0


func _run(seed_value: int) -> RunStats:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH).value, seed_value))
	manager.register_system(AtmosphereSystem.new(AtmosphereConfig.load_json(AtmosphereConfig.DEFAULT_PATH).value))
	var stats := RunStats.new()
	var regime := ""
	var ice_start := 0
	var total := 0.0
	for tick in TICKS:
		if not manager.step():
			stats.halted = true
			return stats
		if tick < WARM_UP:
			continue
		var snapshot := manager.snapshot()
		var t := snapshot.get_value(Param.TEMPERATURE)
		total += t
		stats.ticks_at_zero += 1 if t <= 0.5 else 0
		stats.icy_ticks += 1 if t < ICY_BELOW else 0
		stats.co2_low = minf(stats.co2_low, snapshot.get_value(Param.CO2))
		stats.co2_high = maxf(stats.co2_high, snapshot.get_value(Param.CO2))
		stats.oxygen_high = maxf(stats.oxygen_high, snapshot.get_value(Param.OXYGEN))
		stats.crust_high = maxf(stats.crust_high, snapshot.get_value(Param.CRUST_OXIDATION))
		var now := "icy" if t < ICY_BELOW else ("warm" if t > WARM_ABOVE else regime)
		if now == "icy" and regime != "icy":
			ice_start = tick
		if regime == "icy" and now == "warm":
			stats.ice_ages += 1
			stats.longest_ice_age = maxi(stats.longest_ice_age, tick - ice_start)
		regime = now
	stats.mean_temperature = total / (TICKS - WARM_UP)
	return stats


func test_planet_is_varied_bounded_and_self_regulating() -> void:
	var measured := TICKS - WARM_UP
	var seeds_with_ice_ages := 0
	for seed_value in range(1, SEEDS + 1):
		var s := _run(seed_value)
		var label := "seed %d" % seed_value
		assert_bool(s.halted).override_failure_message(label + " halted").is_false()
		assert_float(s.mean_temperature).override_failure_message(label).is_between(20.0, 40.0)
		assert_int(s.ticks_at_zero).override_failure_message(label).is_less(int(measured * 0.01))
		assert_int(s.icy_ticks).override_failure_message(label).is_less(int(measured * 0.5))
		# The carbon thermostat is active but never pinned to a limit.
		assert_float(s.co2_high - s.co2_low).override_failure_message(label).is_greater(15.0)
		assert_float(s.co2_high).override_failure_message(label).is_less(95.0)
		# Ice ages end through the carbon cycle within bounded time.
		assert_int(s.longest_ice_age).override_failure_message(label).is_less(3000)
		# Without life, oxygen stays prebiotic and the crust barely oxidizes.
		assert_float(s.oxygen_high).override_failure_message(label).is_less(2.0)
		assert_float(s.crust_high).override_failure_message(label).is_less(5.0)
		if s.ice_ages >= 1:
			seeds_with_ice_ages += 1
	assert_int(seeds_with_ice_ages).override_failure_message(
			"ice ages on %d of %d seeds" % [seeds_with_ice_ages, SEEDS]).is_greater_equal(SEEDS - 1)
