class_name SimResult
extends RefCounted
## Outcome of an operation that can fail with data errors.
##
## GDScript has no exceptions and assert() is stripped from release
## builds, so validation returns errors as data that tests can inspect.

var value: Variant = null
var errors := PackedStringArray()
var warnings := PackedStringArray()


static func success(result_value: Variant) -> SimResult:
	var result := SimResult.new()
	result.value = result_value
	return result


static func failure(message: String) -> SimResult:
	var result := SimResult.new()
	result.add_error(message)
	return result


func is_ok() -> bool:
	return errors.is_empty()


func add_error(message: String) -> void:
	errors.append(message)


func add_warning(message: String) -> void:
	warnings.append(message)
