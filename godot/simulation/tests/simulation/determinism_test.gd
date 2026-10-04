extends GdUnitTestSuite
## Level L1 determinism: same build, same machine, same seed -> same states.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const TICKS := 3000
const EVERY := 100


func test_same_seed_gives_identical_trace() -> void:
	var first := TestFixtureScenario.start(P.project_schema(), 42).run_with_checkpoints(TICKS, EVERY)
	var second := TestFixtureScenario.start(P.project_schema(), 42).run_with_checkpoints(TICKS, EVERY)
	assert_int(first.size()).is_equal(TICKS / EVERY)
	assert_array(Array(first)).is_equal(Array(second))


func test_different_seeds_give_different_traces() -> void:
	var first := TestFixtureScenario.start(P.project_schema(), 1).run_with_checkpoints(TICKS, EVERY)
	var second := TestFixtureScenario.start(P.project_schema(), 2).run_with_checkpoints(TICKS, EVERY)
	assert_array(Array(first)).is_not_equal(Array(second))


func test_state_actually_evolves() -> void:
	# A trace of identical hashes would make determinism tests meaningless.
	var trace := TestFixtureScenario.start(P.project_schema(), 42).run_with_checkpoints(TICKS, EVERY)
	var unique := {}
	for line in trace:
		unique[line.get_slice(" ", 1)] = true
	assert_int(unique.size()).is_greater(TICKS / EVERY / 2)
