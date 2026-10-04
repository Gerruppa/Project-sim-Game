extends GdUnitTestSuite


func test_lerp_returns_endpoints_and_midpoint() -> void:
	assert_float(SimMath.lerp(10.0, 20.0, 0.0)).is_equal(10.0)
	assert_float(SimMath.lerp(10.0, 20.0, 1.0)).is_equal(20.0)
	assert_float(SimMath.lerp(10.0, 20.0, 0.5)).is_equal(15.0)


func test_lerp_does_not_clamp_weight() -> void:
	assert_float(SimMath.lerp(0.0, 10.0, 2.0)).is_equal(20.0)


func test_smoothstep_clamps_outside_edges() -> void:
	assert_float(SimMath.smoothstep(20.0, 40.0, 0.0)).is_equal(0.0)
	assert_float(SimMath.smoothstep(20.0, 40.0, 99.0)).is_equal(1.0)


func test_smoothstep_midpoint_is_half() -> void:
	assert_float(SimMath.smoothstep(20.0, 40.0, 30.0)).is_equal(0.5)


func test_smoothstep_with_equal_edges_is_a_step() -> void:
	assert_float(SimMath.smoothstep(30.0, 30.0, 29.0)).is_equal(0.0)
	assert_float(SimMath.smoothstep(30.0, 30.0, 30.0)).is_equal(1.0)


func test_int_pow_positive_exponent() -> void:
	assert_float(SimMath.int_pow(2.0, 10)).is_equal(1024.0)
	assert_float(SimMath.int_pow(0.5, 3)).is_equal(0.125)


func test_int_pow_zero_exponent_is_one() -> void:
	assert_float(SimMath.int_pow(7.0, 0)).is_equal(1.0)


func test_int_pow_negative_exponent_is_reciprocal() -> void:
	assert_float(SimMath.int_pow(2.0, -2)).is_equal(0.25)


func test_u32_to_unit_float_maps_range_to_zero_one() -> void:
	assert_float(SimMath.u32_to_unit_float(0)).is_equal(0.0)
	assert_float(SimMath.u32_to_unit_float(2147483648)).is_equal(0.5)
	assert_float(SimMath.u32_to_unit_float(4294967295)).is_less(1.0)
