extends GdUnitTestSuite
## Verifies the real parameter data shipped with the project.


func test_project_parameters_load_without_errors() -> void:
	var result := ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH)
	assert_array(Array(result.errors)).is_empty()


func test_project_has_the_four_core_parameters_in_order() -> void:
	var schema: ParameterSchema = ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH).value
	assert_array(schema.ids()).is_equal([&"temperature", &"humidity", &"oxygen", &"biomass"])


func test_every_parameter_uses_full_normalized_scale() -> void:
	var schema: ParameterSchema = ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH).value
	for i in schema.size():
		assert_float(schema.def_at(i).min_value()).is_equal(0.0)
		assert_float(schema.def_at(i).max_value()).is_equal(100.0)


func test_param_constants_match_project_data() -> void:
	var schema: ParameterSchema = ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH).value
	for id: StringName in [Param.TEMPERATURE, Param.HUMIDITY, Param.OXYGEN, Param.BIOMASS]:
		assert_int(schema.index_of(id)).is_not_equal(-1)
