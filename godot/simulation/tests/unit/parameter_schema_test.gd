extends GdUnitTestSuite

const P := preload("res://simulation/tests/support/schema_fixtures.gd")


func _errors_for(parameters: Array) -> String:
	return "\n".join(ParameterSchema.from_data(P.data(parameters)).errors)


func test_valid_data_builds_schema_in_declared_order() -> void:
	var result := ParameterSchema.from_data(P.data())
	assert_bool(result.is_ok()).is_true()
	var schema: ParameterSchema = result.value
	assert_int(schema.version()).is_equal(1)
	assert_int(schema.size()).is_equal(2)
	assert_array(schema.ids()).is_equal([&"temperature", &"biomass"])
	assert_int(schema.index_of(&"biomass")).is_equal(1)


func test_definition_exposes_data() -> void:
	var definition := P.schema().def_of(&"temperature")
	assert_str(definition.id()).is_equal("temperature")
	assert_float(definition.min_value()).is_equal(0.0)
	assert_float(definition.max_value()).is_equal(100.0)
	assert_float(definition.initial_value()).is_equal(35.0)
	assert_str(definition.unit()).is_equal("normalized")
	assert_str(definition.anchor(50)).is_equal("middle")


func test_unknown_id_has_no_index() -> void:
	assert_int(P.schema().index_of(&"unknown")).is_equal(-1)
	assert_object(P.schema().def_of(&"unknown")).is_null()


func test_initial_values_follow_schema_order() -> void:
	var values := P.schema().initial_values()
	assert_array(Array(values)).is_equal([35.0, 0.0])


func test_ids_returns_a_copy() -> void:
	var schema := P.schema()
	var ids := schema.ids()
	ids.clear()
	assert_int(schema.ids().size()).is_equal(2)


func test_rejects_duplicate_id() -> void:
	var errors := _errors_for([P.parameter("oxygen", 5.0), P.parameter("oxygen", 6.0)])
	assert_str(errors).contains("duplicate")


func test_rejects_min_not_below_max() -> void:
	assert_str(_errors_for([P.parameter("oxygen", 5.0, 50.0, 50.0)])).contains("min")


func test_rejects_limits_outside_normalized_scale() -> void:
	assert_str(_errors_for([P.parameter("oxygen", 5.0, -1.0, 100.0)])).contains("0..100")
	assert_str(_errors_for([P.parameter("oxygen", 5.0, 0.0, 101.0)])).contains("0..100")


func test_rejects_initial_outside_limits() -> void:
	assert_str(_errors_for([P.parameter("oxygen", 120.0)])).contains("initial")


func test_rejects_non_finite_numbers() -> void:
	assert_str(_errors_for([P.parameter("oxygen", NAN)])).contains("finite")


func test_rejects_missing_field() -> void:
	var broken := P.parameter("oxygen", 5.0)
	broken.erase("unit")
	assert_str(_errors_for([broken])).contains("unit")


func test_rejects_wrong_field_type() -> void:
	var broken := P.parameter("oxygen", 5.0)
	broken["min"] = "zero"
	assert_str(_errors_for([broken])).contains("min")


func test_rejects_missing_anchor() -> void:
	var broken := P.parameter("oxygen", 5.0)
	broken["anchors"] = {"0": "none", "100": "full"}
	assert_str(_errors_for([broken])).contains("anchor")


func test_rejects_empty_parameter_list() -> void:
	var result := ParameterSchema.from_data({"schema_version": 1, "parameters": []})
	assert_bool(result.is_ok()).is_false()


func test_rejects_missing_schema_version() -> void:
	var result := ParameterSchema.from_data({"parameters": [P.parameter("oxygen", 5.0)]})
	assert_str("\n".join(result.errors)).contains("schema_version")


func test_reports_all_errors_at_once() -> void:
	var result := ParameterSchema.from_data(P.data([P.parameter("a", 500.0), P.parameter("b", 5.0, 9.0, 1.0)]))
	assert_int(result.errors.size()).is_greater_equal(2)


func test_load_json_reports_parse_error_with_line() -> void:
	var path := "user://broken_schema.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\n\"schema_version\": 1,\n\"parameters\": [\n}")
	file.close()
	var result := ParameterSchema.load_json(path)
	assert_bool(result.is_ok()).is_false()
	assert_str("\n".join(result.errors)).contains("line")


func test_load_json_reports_missing_file() -> void:
	var result := ParameterSchema.load_json("res://does/not/exist.json")
	assert_bool(result.is_ok()).is_false()
