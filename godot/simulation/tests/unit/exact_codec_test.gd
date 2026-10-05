extends GdUnitTestSuite
## ExactCodec: numbers that survive JSON bit for bit.


func test_floats_survive_json_bit_for_bit() -> void:
	var values := PackedFloat64Array([0.1, 1.0 / 3.0, 9.14385050163826, -0.0, 100.0])
	var text: String = JSON.parse_string(JSON.stringify(ExactCodec.floats_to_text(values)))
	var read := ExactCodec.floats_from_text(text, values.size(), "x")
	assert_array(Array(read.errors)).is_empty()
	assert_str(Marshalls.raw_to_base64((read.value as PackedFloat64Array).to_byte_array())) \
			.is_equal(Marshalls.raw_to_base64(values.to_byte_array()))


func test_empty_floats_are_an_empty_string() -> void:
	assert_str(ExactCodec.floats_to_text(PackedFloat64Array())).is_empty()
	assert_int((ExactCodec.floats_from_text("", 0, "x").value as PackedFloat64Array).size()).is_equal(0)


func test_rejects_wrong_count_non_text_and_non_finite() -> void:
	var two := ExactCodec.floats_to_text(PackedFloat64Array([1.0, 2.0]))
	assert_str("\n".join(ExactCodec.floats_from_text(two, 3, "drift").errors)).contains("drift")
	assert_bool(ExactCodec.floats_from_text(1.5, 1, "x").is_ok()).is_false()
	assert_bool(ExactCodec.floats_from_text(ExactCodec.floats_to_text(PackedFloat64Array([NAN])), 1, "x").is_ok()).is_false()


func test_64_bit_integers_survive_json() -> void:
	# A JSON number is a double and would drop the low bits.
	var state := -6066930334832433271
	var text: String = JSON.parse_string(JSON.stringify(ExactCodec.int_to_text(state)))
	assert_int(ExactCodec.int_from_text(text, "rng").value).is_equal(state)


func test_rejects_integers_that_are_not_exact_text() -> void:
	assert_bool(ExactCodec.int_from_text(12.0, "rng").is_ok()).is_false()
	assert_bool(ExactCodec.int_from_text("12.5", "rng").is_ok()).is_false()
	assert_bool(ExactCodec.int_from_text("", "rng").is_ok()).is_false()
