extends GdUnitTestSuite

const A := preload("res://simulation/tests/support/atmosphere_fixtures.gd")


func _errors(overrides: Dictionary) -> String:
	return "\n".join(AtmosphereConfig.from_data(A.data(overrides)).errors)


func test_project_atmosphere_loads() -> void:
	var result := AtmosphereConfig.load_json(AtmosphereConfig.DEFAULT_PATH)
	assert_array(Array(result.errors)).is_empty()
	var config: AtmosphereConfig = result.value
	assert_float(config.co2_ref).is_equal(40.0)
	assert_float(config.volcanic_co2).is_equal(0.03)


func test_rejects_missing_coefficient() -> void:
	var data := A.data()
	data.erase("volcanic_co2")
	assert_str("\n".join(AtmosphereConfig.from_data(data).errors)).contains("volcanic_co2")


func test_rejects_unknown_coefficient() -> void:
	assert_str(_errors({"volcanic_c02": 0.1})).contains("volcanic_c02")


func test_rejects_values_out_of_range() -> void:
	assert_str(_errors({"weathering_rate": -0.1})).contains("weathering_rate")
	assert_str(_errors({"crust_capacity": 2.0})).contains("crust_capacity")
	assert_str(_errors({"co2_ref": 120.0})).contains("co2_ref")


func test_rejects_non_numeric_value() -> void:
	assert_str(_errors({"photolysis_rate": "some"})).contains("photolysis_rate")


func test_rejects_inverted_weathering_temperatures() -> void:
	assert_str(_errors({"weathering_cold": 60.0, "weathering_warm": 50.0})).contains("weathering_cold")


func test_reports_all_errors_at_once() -> void:
	assert_int(AtmosphereConfig.from_data(A.data({"weathering_rate": -1.0, "co2_ref": 500.0})).errors.size()).is_greater_equal(2)
