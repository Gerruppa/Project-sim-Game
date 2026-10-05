class_name ExactCodec
extends RefCounted
## Exact text forms of numbers for save files.
##
## JSON numbers are doubles and Godot's decimal parsing is not documented as
## correctly rounded, so floats are stored as Base64 of their IEEE 754 bytes
## and 64-bit integers (RNG states) as decimal strings.


## Marshalls reports an engine error for empty data, so an empty array is
## stored as an empty string.
static func floats_to_text(values: PackedFloat64Array) -> String:
	return "" if values.is_empty() else Marshalls.raw_to_base64(values.to_byte_array())


## Value: PackedFloat64Array of exactly `count` finite values.
static func floats_from_text(text: Variant, count: int, label: String) -> SimResult:
	if typeof(text) != TYPE_STRING:
		return SimResult.failure("%s must be Base64 text" % label)
	var values := PackedFloat64Array() if (text as String).is_empty() \
			else Marshalls.base64_to_raw(text).to_float64_array()
	if values.size() != count:
		return SimResult.failure("%s holds %d values, expected %d" % [label, values.size(), count])
	for value in values:
		if not is_finite(value):
			return SimResult.failure("%s holds a value that is not finite" % label)
	return SimResult.success(values)


static func int_to_text(value: int) -> String:
	return str(value)


## Value: int. Only an exact decimal integer is accepted.
static func int_from_text(text: Variant, label: String) -> SimResult:
	if typeof(text) != TYPE_STRING or not (text as String).is_valid_int():
		return SimResult.failure("%s must be an integer written as text" % label)
	return SimResult.success((text as String).to_int())
