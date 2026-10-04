extends GdUnitTestSuite


class Target:
	var rate: float
	var period: int


const SPEC := {"rate": [0.0, 1.0, false], "period": [2.0, 100.0, true]}


func test_fills_target_fields() -> void:
	var result := CoefficientLoader.fill(Target.new(), {"rate": 0.5, "period": 10}, SPEC, [], "test")
	assert_bool(result.is_ok()).is_true()
	var target: Target = result.value
	assert_float(target.rate).is_equal(0.5)
	assert_int(target.period).is_equal(10)


func test_spec_entry_without_field_is_an_internal_error() -> void:
	# Guards against a spec and a class drifting apart.
	var spec := {"rate": [0.0, 1.0, false], "missing": [0.0, 1.0, false]}
	var result := CoefficientLoader.fill(Target.new(), {"rate": 0.5, "missing": 0.1}, spec, [], "test")
	assert_str("\n".join(result.errors)).contains("internal")


func test_ordered_pairs_are_checked() -> void:
	var spec := {"rate": [0.0, 100.0, false], "period": [0.0, 100.0, true]}
	var result := CoefficientLoader.fill(Target.new(), {"rate": 50.0, "period": 10}, spec, [["rate", "period"]], "test")
	assert_str("\n".join(result.errors)).contains("'rate' must be lower than 'period'")


func test_read_json_reports_missing_file() -> void:
	assert_str("\n".join(CoefficientLoader.read_json("res://nope.json", "test").errors)).contains("not found")
