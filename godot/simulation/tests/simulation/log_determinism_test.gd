extends GdUnitTestSuite
## Same seed -> byte-identical text and JSON Lines logs.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const TICKS := 500


func _run(seed_value: int) -> Array[MemoryLogSink]:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(TestFixtureSystem.new(seed_value))
	var text := MemoryLogSink.new()
	var jsonl := MemoryLogSink.new()
	manager.attach_log(SimulationLog.new([text], [jsonl], true))
	manager.run_ticks(TICKS)
	manager.stop()
	return [text, jsonl]


func test_same_seed_gives_identical_logs() -> void:
	var first := _run(42)
	var second := _run(42)
	assert_array(Array(first[0].lines)).is_equal(Array(second[0].lines))
	assert_array(Array(first[1].lines)).is_equal(Array(second[1].lines))


func test_every_tick_is_in_both_logs() -> void:
	var logs := _run(42)
	# 3 header lines + at least one line per tick in text, 1 header + 1 per tick in JSONL.
	assert_int(logs[0].lines.size()).is_greater_equal(3 + TICKS)
	assert_int(logs[1].lines.size()).is_equal(1 + TICKS)


func test_every_jsonl_line_is_valid_json() -> void:
	for line in _run(7)[1].lines:
		assert_that(JSON.parse_string(line)).is_not_null()


func test_different_seeds_give_different_logs() -> void:
	assert_array(Array(_run(1)[1].lines)).is_not_equal(Array(_run(2)[1].lines))
