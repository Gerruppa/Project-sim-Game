extends GdUnitTestSuite
## Save at tick N, load, run M more ticks == continuous run of N + M ticks.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const SEED := 42
const BEFORE_SAVE := 1500
const AFTER_LOAD := 1500


func test_save_and_load_continue_bit_identically() -> void:
	var continuous := TestFixtureScenario.start(P.project_schema(), SEED)
	continuous.run(BEFORE_SAVE + AFTER_LOAD)

	var interrupted := TestFixtureScenario.start(P.project_schema(), SEED)
	interrupted.run(BEFORE_SAVE)
	# Through JSON text, exactly as a save file on disk.
	var save_text := JSON.stringify(interrupted.save(), "\t", true, true)
	var restored := TestFixtureScenario.restore(P.project_schema(), SEED, JSON.parse_string(save_text))
	restored.run(AFTER_LOAD)

	assert_array(Array(restored.errors)).is_empty()
	assert_int(restored.tick).is_equal(continuous.tick)
	assert_str(restored.current_hash()).is_equal(continuous.current_hash())


func test_rng_state_survives_json() -> void:
	# JSON numbers are doubles: a 64-bit RNG state stored as a number
	# would lose its low bits. The save must keep it exact.
	var scenario := TestFixtureScenario.start(P.project_schema(), SEED)
	scenario.run(10)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(scenario.save()))
	var restored := TestFixtureScenario.restore(P.project_schema(), SEED, saved)
	assert_int(restored.rng_state()).is_equal(scenario.rng_state())
