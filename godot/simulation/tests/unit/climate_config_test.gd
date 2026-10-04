extends GdUnitTestSuite

const C := preload("res://simulation/tests/support/climate_fixtures.gd")


func _errors(overrides: Dictionary) -> String:
	return "\n".join(ClimateConfig.from_data(C.data(overrides)).errors)


func test_project_climate_loads() -> void:
	var result := ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH)
	assert_array(Array(result.errors)).is_empty()
	var config: ClimateConfig = result.value
	assert_int(config.season_period_ticks).is_equal(360)
	assert_float(config.base_temperature).is_equal(37.0)
	assert_float(config.ice_strength).is_equal(22.0)


func test_project_climate_has_soft_cold_floor() -> void:
	assert_float(C.config().cold_floor).is_equal(8.0)
	assert_str(_errors({"cold_floor": -1.0})).contains("cold_floor")


func test_year_length_is_editable() -> void:
	assert_int(C.config({"season_period_ticks": 720}).season_period_ticks).is_equal(720)


func test_rejects_missing_coefficient() -> void:
	var data := C.data()
	data.erase("greenhouse")
	assert_str("\n".join(ClimateConfig.from_data(data).errors)).contains("greenhouse")


func test_rejects_unknown_coefficient() -> void:
	# A typo would otherwise silently leave the intended key at its default.
	assert_str(_errors({"greenhuose": 1.0})).contains("greenhuose")


func test_rejects_values_out_of_range() -> void:
	assert_str(_errors({"thermal_response": 1.5})).contains("thermal_response")
	assert_str(_errors({"cloud_response": 0.0})).contains("cloud_response")
	assert_str(_errors({"water_availability": -0.1})).contains("water_availability")


func test_rejects_non_numeric_and_non_finite_values() -> void:
	assert_str(_errors({"greenhouse": "a lot"})).contains("greenhouse")
	assert_str(_errors({"greenhouse": NAN})).contains("greenhouse")


func test_rejects_fractional_year_length() -> void:
	assert_str(_errors({"season_period_ticks": 360.5})).contains("season_period_ticks")
	assert_str(_errors({"season_period_ticks": 1})).contains("season_period_ticks")


func test_rejects_inverted_thresholds() -> void:
	assert_str(_errors({"ice_full": 40.0, "ice_free": 30.0})).contains("ice_full")
	assert_str(_errors({"cloud_rh_low": 0.9, "cloud_rh_high": 0.5})).contains("cloud_rh_low")
	assert_str(_errors({"rain_cloud_low": 90.0, "rain_cloud_high": 80.0})).contains("rain_cloud_low")
	assert_str(_errors({"capacity_cold": 100.0, "capacity_warm": 50.0})).contains("capacity_cold")
	assert_str(_errors({"evap_cold": 70.0, "evap_warm": 60.0})).contains("evap_cold")


func test_reports_all_errors_at_once() -> void:
	assert_int(ClimateConfig.from_data(C.data({"thermal_response": 5.0, "greenhouse": "x"})).errors.size()).is_greater_equal(2)
