extends GdUnitTestSuite
## The planet with life on several seeds, as the game runs it.
## Targets come from the design prototype and the planet report
## (docs/biosphere.md, "Balance"). Kept small: one tick costs ~0.4 ms.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const SEEDS := 3
const TICKS := 20000
const WARM_UP := 2000


class RunStats:
	var halted := false
	var trees_at := -1
	var oxygenated_at := -1
	var oxygen_high := 0.0
	var co2_high := 0.0
	var biomass_high := 0.0
	var ticks_at_zero := 0
	var alive_total := 0


func _run(seed_value: int) -> RunStats:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH).value, seed_value))
	manager.register_system(AtmosphereSystem.new(AtmosphereConfig.load_json(AtmosphereConfig.DEFAULT_PATH).value))
	var catalog: SpeciesCatalog = SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value
	var life := BiosphereSystem.new(BiosphereConfig.load_json(BiosphereConfig.DEFAULT_PATH).value, catalog, seed_value)
	manager.register_system(life)
	var stats := RunStats.new()
	for tick in TICKS:
		if not manager.step():
			stats.halted = true
			return stats
		var snapshot := manager.snapshot()
		var oxygen := snapshot.get_value(Param.OXYGEN)
		if stats.oxygenated_at == -1 and oxygen > 15.0:
			stats.oxygenated_at = tick
		if stats.trees_at == -1 and life.population(&"tree") > 1.0:
			stats.trees_at = tick
		stats.oxygen_high = maxf(stats.oxygen_high, oxygen)
		stats.co2_high = maxf(stats.co2_high, snapshot.get_value(Param.CO2))
		stats.biomass_high = maxf(stats.biomass_high, snapshot.get_value(Param.BIOMASS))
		if tick < WARM_UP:
			continue
		stats.ticks_at_zero += 1 if snapshot.get_value(Param.TEMPERATURE) <= 0.5 else 0
		for id: StringName in catalog.ids():
			stats.alive_total += 1 if life.population(id) > 5.0 else 0
	return stats


func test_life_shapes_a_bounded_varied_planet() -> void:
	var measured := TICKS - WARM_UP
	for seed_value in range(1, SEEDS + 1):
		var s := _run(seed_value)
		var label := "seed %d" % seed_value
		assert_bool(s.halted).override_failure_message(label + " halted").is_false()
		# The world oxygenates and forests follow, within a game-friendly time.
		assert_int(s.oxygenated_at).override_failure_message(label).is_between(1000, 15000)
		assert_int(s.trees_at).override_failure_message(label).is_between(s.oxygenated_at, TICKS)
		# Oxygen is held by fires and photorespiration; CO2 never pinned.
		assert_float(s.oxygen_high).override_failure_message(label).is_less(50.0)
		assert_float(s.co2_high).override_failure_message(label).is_less(98.0)
		# Forests and shrubs, not a full jungle and not a desert.
		assert_float(s.biomass_high).override_failure_message(label).is_between(30.0, 60.0)
		assert_int(s.ticks_at_zero).override_failure_message(label).is_less(int(measured * 0.01))
		# Several species coexist on average.
		assert_float(float(s.alive_total) / measured).override_failure_message(label).is_greater(2.0)
