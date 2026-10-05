extends GdUnitTestSuite

const P := preload("res://simulation/tests/support/schema_fixtures.gd")


func _project_state(overrides: Dictionary = {}) -> PlanetState:
	return PlanetState.create(P.project_schema(), overrides).value


## Awkward values whose shortest decimal form does not round-trip trivially.
func _awkward_state() -> PlanetState:
	return _project_state({
		"temperature": 100.0 / 3.0,
		"humidity": 0.1 + 0.2,
		"oxygen": 99.99999999999999,
		"biomass": 5e-324,
	})


func _exact_base64(values: Array) -> String:
	return Marshalls.raw_to_base64(PackedFloat64Array(values).to_byte_array())


## One value per project parameter: `first` for the first one, 1.0 for the rest.
func _project_values(first: float) -> Array:
	var values := [first]
	for i in P.project_schema().size() - 1:
		values.append(1.0)
	return values


func _assert_bitwise_equal(actual: PlanetState, expected: PlanetState) -> void:
	assert_str(Marshalls.raw_to_base64(actual.values_copy().to_byte_array())) \
			.is_equal(Marshalls.raw_to_base64(expected.values_copy().to_byte_array()))


func test_platform_is_little_endian() -> void:
	assert_bool(PlanetStateCodec.is_little_endian()).is_true()


func test_json_round_trip_is_bitwise_exact() -> void:
	var original := _awkward_state()
	var result := PlanetStateCodec.from_json(P.project_schema(), PlanetStateCodec.to_json(original))
	assert_array(Array(result.errors)).is_empty()
	assert_array(Array(result.warnings)).is_empty()
	_assert_bitwise_equal(result.value, original)


func test_encoded_data_contains_readable_values_and_order() -> void:
	var data := PlanetStateCodec.encode(_project_state())
	assert_float(data["values"]["temperature"]).is_equal(30.0)
	var expected_order := Array(P.project_schema().ids()).map(func(id: StringName) -> String: return String(id))
	assert_array(data["parameter_order"]).is_equal(expected_order)
	assert_int(data["schema_version"]).is_equal(P.project_schema().version())


func test_hash_is_sha256_hex() -> void:
	assert_int(PlanetStateCodec.state_hash(_project_state()).length()).is_equal(64)


func test_equal_states_have_equal_hash() -> void:
	assert_str(PlanetStateCodec.state_hash(_awkward_state())) \
			.is_equal(PlanetStateCodec.state_hash(_awkward_state()))


func test_hash_detects_one_ulp_difference() -> void:
	# 0.3 and 0.1 + 0.2 are adjacent doubles.
	var a := PlanetStateCodec.state_hash(_project_state({"humidity": 0.3}))
	var b := PlanetStateCodec.state_hash(_project_state({"humidity": 0.1 + 0.2}))
	assert_str(a).is_not_equal(b)


func test_missing_parameter_gets_initial_value_with_warning() -> void:
	var old_schema := P.schema([P.parameter("temperature", 35.0)])
	var old_state: PlanetState = PlanetState.create(old_schema, {"temperature": 61.0}).value
	var new_schema := P.schema([P.parameter("temperature", 35.0), P.parameter("oxygen", 4.0)])

	var result := PlanetStateCodec.decode(new_schema, PlanetStateCodec.encode(old_state))
	assert_bool(result.is_ok()).is_true()
	var state: PlanetState = result.value
	assert_float(state.get_value(&"temperature")).is_equal(61.0)
	assert_float(state.get_value(&"oxygen")).is_equal(4.0)
	assert_str("\n".join(result.warnings)).contains("oxygen")


func test_unknown_parameter_is_an_error() -> void:
	var big_schema := P.schema([P.parameter("temperature", 35.0), P.parameter("oxygen", 4.0)])
	var small_schema := P.schema([P.parameter("temperature", 35.0)])
	var data := PlanetStateCodec.encode(PlanetState.create(big_schema).value)
	var result := PlanetStateCodec.decode(small_schema, data)
	assert_str("\n".join(result.errors)).contains("oxygen")


func test_exact_values_win_over_readable_values() -> void:
	var data := PlanetStateCodec.encode(_project_state({"temperature": 40.0}))
	data["values"]["temperature"] = 41.0
	var result := PlanetStateCodec.decode(P.project_schema(), data)
	assert_float((result.value as PlanetState).get_value(&"temperature")).is_equal(40.0)
	assert_str("\n".join(result.warnings)).contains("temperature")


func test_parsing_noise_in_readable_values_is_not_reported() -> void:
	var data := PlanetStateCodec.encode(_project_state({"temperature": 40.0}))
	data["values"]["temperature"] = 40.000000000000007
	assert_array(Array(PlanetStateCodec.decode(P.project_schema(), data).warnings)).is_empty()


func test_readable_values_are_used_when_exact_missing() -> void:
	var data := PlanetStateCodec.encode(_project_state())
	data.erase("values_exact")
	data["values"]["oxygen"] = 12.0
	var result := PlanetStateCodec.decode(P.project_schema(), data)
	assert_bool(result.is_ok()).is_true()
	assert_float((result.value as PlanetState).get_value(&"oxygen")).is_equal(12.0)
	assert_str("\n".join(result.warnings)).contains("values_exact")


func test_exact_length_mismatch_is_an_error() -> void:
	var data := PlanetStateCodec.encode(_project_state())
	data["values_exact"] = _exact_base64([1.0, 2.0])
	assert_str("\n".join(PlanetStateCodec.decode(P.project_schema(), data).errors)).contains("values_exact")


func test_non_finite_stored_value_is_an_error() -> void:
	var data := PlanetStateCodec.encode(_project_state())
	data["values_exact"] = _exact_base64(_project_values(NAN))
	assert_bool(PlanetStateCodec.decode(P.project_schema(), data).is_ok()).is_false()


func test_stored_value_outside_limits_is_an_error() -> void:
	var data := PlanetStateCodec.encode(_project_state())
	data["values_exact"] = _exact_base64(_project_values(150.0))
	assert_str("\n".join(PlanetStateCodec.decode(P.project_schema(), data).errors)).contains("temperature")


func test_schema_version_mismatch_is_a_warning() -> void:
	var data := PlanetStateCodec.encode(_project_state())
	data["schema_version"] = 99
	var result := PlanetStateCodec.decode(P.project_schema(), data)
	assert_bool(result.is_ok()).is_true()
	assert_str("\n".join(result.warnings)).contains("schema_version")


func test_missing_parameter_order_is_an_error() -> void:
	var data := PlanetStateCodec.encode(_project_state())
	data.erase("parameter_order")
	assert_bool(PlanetStateCodec.decode(P.project_schema(), data).is_ok()).is_false()


func test_invalid_json_is_an_error() -> void:
	assert_bool(PlanetStateCodec.from_json(P.project_schema(), "{ not json").is_ok()).is_false()
