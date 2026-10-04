extends GdUnitTestSuite
## EventCondition: parsing the condition language and evaluating it.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")
const E := preload("res://simulation/tests/support/event_fixtures.gd")


func _parse(raw: Variant) -> SimResult:
	var result := SimResult.new()
	result.value = EventCondition.parse(raw, P.project_schema(), "c", result)
	return result


func _leaf(measure: String, op: String, value: float, window: int = 0) -> Dictionary:
	var data := {"measure": measure, "param": "humidity", "op": op, "value": value}
	if window > 0:
		data["window"] = window
	return data


func _met(raw: Dictionary, values: Array) -> bool:
	var result := _parse(raw)
	assert_array(Array(result.errors)).is_empty()
	return (result.value as EventCondition).is_met(E.history_of(&"humidity", values))


func test_operators_compare_the_measure_with_the_threshold() -> void:
	assert_bool(_met(_leaf("value", "<", 20.0), [19.0])).is_true()
	assert_bool(_met(_leaf("value", "<", 20.0), [20.0])).is_false()
	assert_bool(_met(_leaf("value", "<=", 20.0), [20.0])).is_true()
	assert_bool(_met(_leaf("value", ">", 20.0), [20.0])).is_false()
	assert_bool(_met(_leaf("value", ">=", 20.0), [20.0])).is_true()


func test_trend_measures_drive_conditions() -> void:
	# humidity fell from 40 to 25: change -15, anomaly vs mean 32.5 = -7.5
	assert_bool(_met(_leaf("change", "<", -10.0, 1), [40.0, 25.0])).is_true()
	assert_bool(_met(_leaf("anomaly", "<", -7.0, 2), [40.0, 25.0])).is_true()
	assert_bool(_met(_leaf("anomaly", "<", -8.0, 2), [40.0, 25.0])).is_false()


func test_combinators() -> void:
	var low := _leaf("value", "<", 20.0)
	var high := _leaf("value", ">", 30.0)
	assert_bool(_met({"all": [low, _leaf("value", ">", 10.0)]}, [15.0])).is_true()
	assert_bool(_met({"all": [low, high]}, [15.0])).is_false()
	assert_bool(_met({"any": [low, high]}, [35.0])).is_true()
	assert_bool(_met({"any": [low, high]}, [25.0])).is_false()
	assert_bool(_met({"not": low}, [25.0])).is_true()
	assert_bool(_met({"all": [{"not": low}, {"any": [high, _leaf("value", "<", 26.0)]}]}, [25.0])).is_true()


func test_collects_history_needs_per_parameter() -> void:
	var result := _parse({"all": [_leaf("mean", "<", 1.0, 50), _leaf("change", "<", 1.0, 80),
			{"measure": "value", "param": "oxygen", "op": ">", "value": 1}]})
	var needs := {}
	(result.value as EventCondition).collect_needs(needs)
	assert_dict(needs).is_equal({&"humidity": 81, &"oxygen": 1})


func test_describe_lists_every_leaf_with_its_measured_value() -> void:
	var condition: EventCondition = _parse({"all": [_leaf("value", "<", 20.0), _leaf("mean", ">", 50.0, 2)]}).value
	var facts := condition.describe(E.history_of(&"humidity", [30.0, 10.0]))
	assert_int(facts.size()).is_equal(2)
	assert_dict(facts[0]).contains_key_value("measured", 10.0).contains_key_value("met", true)
	assert_dict(facts[1]).contains_key_value("measured", 20.0).contains_key_value("met", false) \
			.contains_key_value("window", 2)


func test_rejects_bad_leaves() -> void:
	assert_bool(_parse({"measure": "median", "param": "humidity", "op": "<", "value": 1}).is_ok()).is_false()
	assert_bool(_parse({"measure": "value", "param": "humdity", "op": "<", "value": 1}).is_ok()).is_false()
	assert_bool(_parse({"measure": "value", "param": "humidity", "op": "==", "value": 1}).is_ok()).is_false()
	assert_bool(_parse({"measure": "value", "param": "humidity", "op": "<", "value": "1"}).is_ok()).is_false()
	assert_bool(_parse({"measure": "value", "param": "humidity", "op": "<", "value": 1, "window": 5}).is_ok()).is_false()
	assert_bool(_parse({"measure": "mean", "param": "humidity", "op": "<", "value": 1}).is_ok()).is_false()
	assert_bool(_parse({"measure": "mean", "param": "humidity", "op": "<", "value": 1, "window": 2.5}).is_ok()).is_false()
	assert_bool(_parse(_leaf("mean", "<", 1.0, 1).merged({"window": 0}, true)).is_ok()).is_false()
	assert_bool(_parse(_leaf("mean", "<", 1.0, EventCondition.MAX_WINDOW + 1)).is_ok()).is_false()
	assert_bool(_parse(_leaf("value", "<", 1.0).merged({"extra": 1})).is_ok()).is_false()


func test_rejects_bad_combinators() -> void:
	assert_bool(_parse({"all": []}).is_ok()).is_false()
	assert_bool(_parse({"any": _leaf("value", "<", 1.0)}).is_ok()).is_false()
	assert_bool(_parse({"all": [_leaf("value", "<", 1.0)], "any": []}).is_ok()).is_false()
	assert_bool(_parse({"not": _leaf("value", "<", 1.0), "x": 1}).is_ok()).is_false()
	assert_bool(_parse("humidity < 20").is_ok()).is_false()


func test_reports_every_error_in_a_tree() -> void:
	var result := _parse({"all": [{"measure": "x", "param": "y", "op": "?", "value": 1},
			{"not": {"measure": "value", "param": "humidity", "op": "<"}}]})
	assert_int(result.errors.size()).is_greater_equal(4)
