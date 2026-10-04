extends GdUnitTestSuite

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

var _state: PlanetState
var _writer: StateWriter


func before_test() -> void:
	_state = PlanetState.create(P.schema()).value
	_writer = StateWriter.new(_state)


func _delta(parameter: StringName, amount: float, source: StringName = &"test", cause: StringName = &"cause") -> Delta:
	return Delta.new(parameter, amount, source, cause)


func test_applies_single_delta() -> void:
	var report := _writer.apply([_delta(&"temperature", 2.5)])
	assert_bool(report.is_ok()).is_true()
	assert_float(_state.get_value(&"temperature")).is_equal(37.5)


func test_sums_deltas_for_the_same_parameter() -> void:
	_writer.apply([_delta(&"temperature", 2.0, &"a"), _delta(&"temperature", -0.5, &"b")])
	assert_float(_state.get_value(&"temperature")).is_equal(36.5)


func test_empty_delta_list_changes_nothing() -> void:
	var report := _writer.apply([])
	assert_bool(report.is_ok()).is_true()
	assert_array(report.changes).is_empty()
	assert_float(_state.get_value(&"temperature")).is_equal(35.0)


func test_clamps_to_max_and_reports_saturation() -> void:
	var report := _writer.apply([_delta(&"temperature", 500.0)])
	assert_float(_state.get_value(&"temperature")).is_equal(100.0)
	assert_int(report.saturations().size()).is_equal(1)
	assert_float(report.saturations()[0].requested_value).is_equal(535.0)


func test_clamps_to_min_and_reports_saturation() -> void:
	var report := _writer.apply([_delta(&"biomass", -3.0)])
	assert_float(_state.get_value(&"biomass")).is_equal(0.0)
	assert_int(report.saturations().size()).is_equal(1)


func test_clamps_after_summing_not_per_delta() -> void:
	# +80 then -80 must cancel. Clamping each delta would end at 20.
	_writer.apply([_delta(&"temperature", 80.0, &"a"), _delta(&"temperature", -80.0, &"b")])
	assert_float(_state.get_value(&"temperature")).is_equal(35.0)


func test_report_lists_changes_with_old_and_new_value() -> void:
	var report := _writer.apply([_delta(&"temperature", 1.0)])
	assert_int(report.changes.size()).is_equal(1)
	var change: ApplyReport.ParameterChange = report.changes[0]
	assert_str(change.parameter).is_equal("temperature")
	assert_float(change.old_value).is_equal(35.0)
	assert_float(change.new_value).is_equal(36.0)
	assert_bool(change.saturated).is_false()


func test_report_keeps_deltas_with_their_causes() -> void:
	var report := _writer.apply([_delta(&"temperature", 1.0, &"climate", &"greenhouse")])
	assert_str(report.applied_deltas[0].cause).is_equal("greenhouse")
	assert_str(report.applied_deltas[0].source).is_equal("climate")


func test_rejects_nan_and_applies_nothing() -> void:
	var report := _writer.apply([_delta(&"temperature", 1.0), _delta(&"biomass", NAN)])
	assert_bool(report.is_ok()).is_false()
	assert_float(_state.get_value(&"temperature")).is_equal(35.0)


func test_rejects_infinite_delta() -> void:
	assert_bool(_writer.apply([_delta(&"temperature", INF)]).is_ok()).is_false()


func test_rejects_sum_that_overflows_to_infinity() -> void:
	var report := _writer.apply([_delta(&"temperature", 1.0e308, &"a"), _delta(&"temperature", 1.0e308, &"b")])
	assert_bool(report.is_ok()).is_false()
	assert_float(_state.get_value(&"temperature")).is_equal(35.0)


func test_rejects_unknown_parameter() -> void:
	var report := _writer.apply([_delta(&"pressure", 1.0)])
	assert_str("\n".join(report.errors)).contains("pressure")


func test_rejects_delta_without_source_or_cause() -> void:
	assert_bool(_writer.apply([_delta(&"temperature", 1.0, &"", &"cause")]).is_ok()).is_false()
	assert_bool(_writer.apply([_delta(&"temperature", 1.0, &"src", &"")]).is_ok()).is_false()


func test_result_does_not_depend_on_delta_order() -> void:
	# Premise: float addition is not associative.
	assert_bool((0.1 + 0.2) + 0.3 == (0.2 + 0.3) + 0.1).is_false()

	var first: PlanetState = PlanetState.create(P.schema(), {"biomass": 0.0}).value
	var second: PlanetState = PlanetState.create(P.schema(), {"biomass": 0.0}).value
	StateWriter.new(first).apply([
		_delta(&"biomass", 0.1, &"a"), _delta(&"biomass", 0.2, &"b"), _delta(&"biomass", 0.3, &"c")])
	StateWriter.new(second).apply([
		_delta(&"biomass", 0.2, &"b"), _delta(&"biomass", 0.3, &"c"), _delta(&"biomass", 0.1, &"a")])
	assert_bool(first.get_value(&"biomass") == second.get_value(&"biomass")).is_true()


func test_identical_keys_in_any_order_give_same_result() -> void:
	var first: PlanetState = PlanetState.create(P.schema(), {"biomass": 0.0}).value
	var second: PlanetState = PlanetState.create(P.schema(), {"biomass": 0.0}).value
	StateWriter.new(first).apply([_delta(&"biomass", 0.1), _delta(&"biomass", 0.2), _delta(&"biomass", 0.3)])
	StateWriter.new(second).apply([_delta(&"biomass", 0.3), _delta(&"biomass", 0.1), _delta(&"biomass", 0.2)])
	assert_bool(first.get_value(&"biomass") == second.get_value(&"biomass")).is_true()
