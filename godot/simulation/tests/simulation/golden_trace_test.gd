extends GdUnitTestSuite
## Compares this machine against the committed golden trace.
##
## Run on several platforms in CI to measure determinism levels L2/L3.
## After an intentional change regenerate with:
##   godot --headless --path . -s res://simulation/tests/tools/write_golden_trace.gd

const GoldenTrace := preload("res://simulation/tests/support/golden_trace.gd")


func test_trace_matches_golden_file() -> void:
	var expected := GoldenTrace.read_file()
	assert_bool(expected.is_empty()).override_failure_message(
			"golden trace missing: %s; generate it with tests/tools/write_golden_trace.gd" % GoldenTrace.PATH).is_false()
	var actual := GoldenTrace.generate()
	assert_int(actual.size()).is_equal(expected.size())
	for i in mini(actual.size(), expected.size()):
		if actual[i] != expected[i]:
			fail("first divergence at checkpoint %d\n expected: %s\n actual:   %s" % [i, expected[i], actual[i]])
			return
