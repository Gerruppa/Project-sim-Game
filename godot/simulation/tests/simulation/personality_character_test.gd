extends GdUnitTestSuite
## Archetypes give measurably different planets ("two runs give different
## results", GENESIS_ERROR_MASTER_PLAN phase 4). Climate and atmosphere only,
## to stay fast; life statistics per archetype come from planet_report.gd.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")
const Q := preload("res://simulation/tests/support/personality_fixtures.gd")

const SEEDS := 3
const TICKS := 10000
const WARM_UP := 2000


## Standard deviation of temperature after warm-up, averaged over seeds.
func _temperature_spread(choice: StringName) -> float:
	var total := 0.0
	for seed_value in range(1, SEEDS + 1):
		var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
		var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
		manager.register_system(ClimateSystem.new(ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH).value, seed_value))
		manager.register_system(AtmosphereSystem.new(AtmosphereConfig.load_json(AtmosphereConfig.DEFAULT_PATH).value))
		manager.register_system(PersonalitySystem.create(Q.project_catalog(), choice, seed_value).value)
		var sum := 0.0
		var sum_squares := 0.0
		for tick in TICKS:
			manager.step()
			if tick >= WARM_UP:
				var t := manager.snapshot().get_value(Param.TEMPERATURE)
				sum += t
				sum_squares += t * t
		var count := float(TICKS - WARM_UP)
		var mean := sum / count
		total += sqrt(maxf(sum_squares / count - mean * mean, 0.0))
	return total / SEEDS


func test_chaotic_climate_swings_more_than_harmonious() -> void:
	var harmonious := _temperature_spread(&"harmonious")
	var chaotic := _temperature_spread(&"chaotic")
	assert_float(chaotic).override_failure_message("chaotic %.2f vs harmonious %.2f" % [chaotic, harmonious]) \
			.is_greater(harmonious * 1.1)
