extends GdUnitTestSuite
## Many seeds, long runs: the pipeline never produces invalid state.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const SEEDS := 20
const TICKS := 2000


func test_many_seeds_stay_valid() -> void:
	var schema := P.project_schema()
	for seed_value in range(1, SEEDS + 1):
		var scenario := TestFixtureScenario.start(schema, seed_value)
		scenario.run(TICKS)
		assert_array(Array(scenario.errors)).override_failure_message("seed %d" % seed_value).is_empty()
		assert_int(scenario.tick).is_equal(TICKS)
		for i in schema.size():
			var value := scenario.state.get_value_at(i)
			var definition := schema.def_at(i)
			assert_bool(is_finite(value)).is_true()
			assert_float(value).is_between(definition.min_value(), definition.max_value())
