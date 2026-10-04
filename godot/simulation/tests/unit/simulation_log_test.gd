extends GdUnitTestSuite

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

var _state: PlanetState
var _writer: StateWriter
var _bus: EventBus
var _text: MemoryLogSink
var _jsonl: MemoryLogSink
## The bus does not keep subscribers alive; the test must.
var _log_instance: SimulationLog


func before_test() -> void:
	_state = PlanetState.create(P.schema()).value
	_writer = StateWriter.new(_state)
	_bus = EventBus.new()
	_text = MemoryLogSink.new()
	_jsonl = MemoryLogSink.new()


func _log(include_deltas: bool = true) -> SimulationLog:
	_log_instance = SimulationLog.new([_text], [_jsonl], include_deltas)
	_log_instance.attach(_bus)
	return _log_instance


func _apply_tick(tick: int, deltas: Array[Delta]) -> void:
	var report := _writer.apply(deltas)
	var type := SimEvent.TICK_APPLIED if report.is_ok() else SimEvent.BATCH_REJECTED
	_bus.publish(SimEvent.new(type, tick, &"pipeline", {"report": report}))
	_bus.flush()


func _json(line: String) -> Dictionary:
	return JSON.parse_string(line)


func test_run_header_lists_seed_and_initial_values() -> void:
	_log().begin_run(42, _state.snapshot(0))
	assert_str(_text.lines[0]).is_equal("# Genesis Error simulation log")
	assert_str(_text.lines[1]).contains("seed: 42")
	assert_str(_text.lines[1]).contains("schema: v1")
	assert_str(_text.lines[2]).is_equal("[Tick 0] initial temperature=35.000 biomass=0.000")
	var start := _json(_jsonl.lines[0])
	assert_str(start["record"]).is_equal("run_start")
	assert_int(int(start["seed"])).is_equal(42)
	assert_array(start["parameters"]).is_equal(["temperature", "biomass"])
	assert_float(start["initial"]["temperature"]).is_equal(35.0)


func test_change_line_shows_values_and_causes() -> void:
	_log()
	_apply_tick(1, [
		Delta.new(&"temperature", 0.25, &"climate", &"greenhouse"),
		Delta.new(&"temperature", -0.125, &"biosphere", &"shading")])
	assert_str(_text.lines[0]).is_equal(
			"[Tick 1] temperature 35.000 -> 35.125 (+0.125) [biosphere:shading -0.125, climate:greenhouse +0.250]")


func test_tick_without_deltas_is_still_logged() -> void:
	_log()
	_apply_tick(2, [])
	assert_str(_text.lines[0]).is_equal("[Tick 2] no changes")
	var record := _json(_jsonl.lines[0])
	assert_str(record["record"]).is_equal("tick")
	assert_array(record["changes"]).is_empty()


func test_saturation_is_marked() -> void:
	_log()
	_apply_tick(3, [Delta.new(&"biomass", -2.0, &"biosphere", &"dieback")])
	assert_str(_text.lines[0]).contains("SATURATED (requested -2.000)")
	assert_bool(_json(_jsonl.lines[0])["changes"][0]["saturated"]).is_true()


func test_jsonl_tick_record_has_exact_values_and_deltas() -> void:
	_log()
	_apply_tick(4, [Delta.new(&"temperature", 0.1, &"climate", &"greenhouse")])
	var change: Dictionary = _json(_jsonl.lines[0])["changes"][0]
	assert_str(change["parameter"]).is_equal("temperature")
	assert_bool(float(change["new"]) == 35.0 + 0.1).is_true()
	assert_str(change["deltas"][0]["cause"]).is_equal("greenhouse")
	assert_str(change["deltas"][0]["source"]).is_equal("climate")


func test_deltas_can_be_left_out() -> void:
	_log(false)
	_apply_tick(5, [Delta.new(&"temperature", 1.0, &"climate", &"greenhouse")])
	assert_str(_text.lines[0]).is_equal("[Tick 5] temperature 35.000 -> 36.000 (+1.000)")
	assert_bool((_json(_jsonl.lines[0])["changes"][0] as Dictionary).has("deltas")).is_false()


func test_rejected_batch_is_logged_as_error() -> void:
	_log()
	_apply_tick(6, [Delta.new(&"temperature", NAN, &"climate", &"greenhouse")])
	assert_str(_text.lines[0]).starts_with("[Tick 6] REJECTED")
	var record := _json(_jsonl.lines[0])
	assert_str(record["record"]).is_equal("rejected")
	assert_int((record["errors"] as Array).size()).is_equal(1)


func test_other_events_are_logged_generically() -> void:
	_log()
	_bus.publish(SimEvent.new(&"drought_started", 7, &"events", {"humidity": 12.5}))
	_bus.flush()
	assert_str(_text.lines[0]).is_equal('[Tick 7] EVENT drought_started from events {"humidity":12.5}')
	var record := _json(_jsonl.lines[0])
	assert_str(record["type"]).is_equal("drought_started")
	assert_float(record["data"]["humidity"]).is_equal(12.5)


func test_events_with_a_summary_print_it_and_keep_full_data_in_json() -> void:
	_log()
	_bus.publish(SimEvent.new(&"world_event_started", 8, &"events",
			{"summary": "Susza started: humidity 12.50 < 20", "id": "drought"}))
	_bus.flush()
	assert_str(_text.lines[0]).is_equal("[Tick 8] EVENT world_event_started from events: Susza started: humidity 12.50 < 20")
	assert_str(_json(_jsonl.lines[0])["data"]["id"]).is_equal("drought")


func test_close_closes_every_sink() -> void:
	_log().close()
	assert_bool(_text.is_closed()).is_true()
	assert_bool(_jsonl.is_closed()).is_true()


func test_negligible_causes_are_folded_in_text_but_kept_in_jsonl() -> void:
	_log()
	_apply_tick(8, [
		Delta.new(&"temperature", 0.25, &"climate", &"greenhouse"),
		Delta.new(&"temperature", 0.0001, &"biosphere", &"moss_growth"),
		Delta.new(&"temperature", -0.0002, &"biosphere", &"tree_dieback")])
	assert_str(_text.lines[0]).is_equal(
			"[Tick 8] temperature 35.000 -> 35.250 (+0.250) [climate:greenhouse +0.250, +2 negligible]")
	assert_int((_json(_jsonl.lines[0])["changes"][0]["deltas"] as Array).size()).is_equal(3)
