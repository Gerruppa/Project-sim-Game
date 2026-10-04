extends GdUnitTestSuite

const S := preload("res://simulation/tests/support/biosphere_fixtures.gd")


func _errors(overrides: Dictionary) -> String:
	return "\n".join(BiosphereConfig.from_data(S.config_data(overrides)).errors)


func test_project_biosphere_loads() -> void:
	var result := BiosphereConfig.load_json(BiosphereConfig.DEFAULT_PATH)
	assert_array(Array(result.errors)).is_empty()
	assert_float((result.value as BiosphereConfig).fire_o2_low).is_equal(22.0)


func test_rejects_unknown_and_missing_keys() -> void:
	assert_str(_errors({"fire_ratio": 1.0})).contains("fire_ratio")
	var data := S.config_data()
	data.erase("fire_rate")
	assert_str("\n".join(BiosphereConfig.from_data(data).errors)).contains("fire_rate")


func test_rejects_inverted_thresholds() -> void:
	assert_str(_errors({"fire_o2_low": 50.0, "fire_o2_high": 40.0})).contains("fire_o2_low")
	assert_str(_errors({"photorespiration_low": 70.0})).contains("photorespiration_low")
