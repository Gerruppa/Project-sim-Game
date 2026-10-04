extends GdUnitTestSuite


func test_result_without_errors_is_ok() -> void:
	var result := SimResult.success(5)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.value).is_equal(5)


func test_result_with_error_is_not_ok() -> void:
	var result := SimResult.new()
	result.add_error("broken")
	assert_bool(result.is_ok()).is_false()
	assert_array(result.errors).contains(["broken"])


func test_warnings_do_not_make_result_fail() -> void:
	var result := SimResult.success(1)
	result.add_warning("odd but fine")
	assert_bool(result.is_ok()).is_true()
	assert_array(result.warnings).contains(["odd but fine"])
