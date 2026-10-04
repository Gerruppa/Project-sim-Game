extends GdUnitTestSuite
## Verifies the real parameter data shipped with the project.

const EXPECTED_IDS := [&"temperature", &"humidity", &"oxygen", &"biomass", &"cloud_cover", &"precipitation"]


func _schema() -> ParameterSchema:
	return ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH).value


func test_project_parameters_load_without_errors() -> void:
	var result := ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH)
	assert_array(Array(result.errors)).is_empty()


func test_project_parameters_in_storage_order() -> void:
	assert_array(_schema().ids()).is_equal(EXPECTED_IDS)


func test_schema_version_counts_parameter_changes() -> void:
	# v1: four core parameters. v2: cloud_cover and precipitation (ClimateSystem).
	assert_int(_schema().version()).is_equal(2)


func test_every_parameter_uses_full_normalized_scale() -> void:
	var schema := _schema()
	for i in schema.size():
		assert_float(schema.def_at(i).min_value()).is_equal(0.0)
		assert_float(schema.def_at(i).max_value()).is_equal(100.0)


func test_param_constants_match_project_data() -> void:
	var schema := _schema()
	for id: StringName in [Param.TEMPERATURE, Param.HUMIDITY, Param.OXYGEN, Param.BIOMASS,
			Param.CLOUD_COVER, Param.PRECIPITATION]:
		assert_int(schema.index_of(id)).is_not_equal(-1)


func test_young_planet_starts_dry_and_clear() -> void:
	var schema := _schema()
	assert_float(schema.def_of(Param.CLOUD_COVER).initial_value()).is_equal(10.0)
	assert_float(schema.def_of(Param.PRECIPITATION).initial_value()).is_equal(0.0)
