class_name PlanetStateCodec
extends RefCounted
## Serialization and hashing of PlanetState.
##
## A save holds two representations of the values:
## - "values": readable decimals for humans and diffs,
## - "values_exact": Base64 of the raw IEEE 754 bytes, the source of truth.
## Decimal parsing in Godot (String.to_float) is not documented as
## correctly rounded, so exact round trips must not depend on it.

const FORMAT := "planet_state"
## Bytes of 1.0 as a little-endian IEEE 754 double.
const ONE_LITTLE_ENDIAN: Array[int] = [0, 0, 0, 0, 0, 0, 0xF0, 0x3F]
const BYTES_PER_VALUE := 8


static func is_little_endian() -> bool:
	return PackedFloat64Array([1.0]).to_byte_array() == PackedByteArray(ONE_LITTLE_ENDIAN)


static func encode(state: PlanetState) -> Dictionary:
	var schema := state.schema()
	var order: Array[String] = []
	var readable := {}
	for i in schema.size():
		var id := String(schema.def_at(i).id())
		order.append(id)
		readable[id] = state.get_value_at(i)
	return {
		"format": FORMAT,
		"schema_version": schema.version(),
		"parameter_order": order,
		"values": readable,
		"values_exact": _exact_text(state.values_copy()),
	}


static func to_json(state: PlanetState) -> String:
	return JSON.stringify(encode(state), "\t", true, true)


static func from_json(schema: ParameterSchema, text: String) -> SimResult:
	var json := JSON.new()
	if json.parse(text) != OK:
		return SimResult.failure("state JSON error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return SimResult.failure("state JSON root must be an object")
	return decode(schema, json.data)


## Fingerprint of the exact state. Hashes raw bytes, never decimal text,
## so the hash does not depend on float formatting.
static func state_hash(state: PlanetState) -> String:
	var ids := PackedStringArray()
	for id in state.schema().ids():
		ids.append(String(id))
	return ("%s|%s" % [",".join(ids), _exact_text(state.values_copy())]).sha256_text()


static func decode(schema: ParameterSchema, data: Dictionary) -> SimResult:
	var result := SimResult.new()
	if not is_little_endian():
		return SimResult.failure("unsupported platform: exact values require little-endian doubles")
	var order := _read_order(data, result)
	if not result.is_ok():
		return result
	var stored := _read_stored_values(data, order, result)
	if not result.is_ok():
		return result

	if not data.has("schema_version") or float(data["schema_version"]) != float(schema.version()):
		result.add_warning("schema_version %s differs from current %d; matching parameters by id"
				% [data.get("schema_version", "missing"), schema.version()])

	var values := schema.initial_values()
	for i in order.size():
		var id := StringName(order[i])
		var index := schema.index_of(id)
		if index == -1:
			result.add_error("saved parameter '%s' does not exist in the schema" % id)
			continue
		var error := PlanetState.validate_value(schema.def_at(index), stored[i])
		if not error.is_empty():
			result.add_error("saved " + error)
			continue
		values[index] = stored[i]

	for id in schema.ids():
		if order.find(String(id)) == -1:
			result.add_warning("parameter '%s' missing in save; using initial value" % id)

	if result.is_ok():
		result.value = PlanetState.new(schema, values)
	return result


static func _exact_text(values: PackedFloat64Array) -> String:
	return Marshalls.raw_to_base64(values.to_byte_array())


static func _read_order(data: Dictionary, result: SimResult) -> PackedStringArray:
	var order := PackedStringArray()
	var raw: Variant = data.get("parameter_order")
	if typeof(raw) != TYPE_ARRAY:
		result.add_error("save needs a 'parameter_order' list")
		return order
	for item: Variant in raw:
		if typeof(item) != TYPE_STRING or (item as String).is_empty() or order.has(item):
			result.add_error("'parameter_order' must hold unique, non-empty ids")
			return order
		order.append(item)
	return order


static func _read_stored_values(data: Dictionary, order: PackedStringArray, result: SimResult) -> PackedFloat64Array:
	var readable: Variant = data.get("values")
	if typeof(data.get("values_exact")) == TYPE_STRING:
		var bytes := Marshalls.base64_to_raw(data["values_exact"])
		if bytes.size() != order.size() * BYTES_PER_VALUE:
			result.add_error("'values_exact' holds %d bytes, expected %d"
					% [bytes.size(), order.size() * BYTES_PER_VALUE])
			return PackedFloat64Array()
		var exact := bytes.to_float64_array()
		if typeof(readable) == TYPE_DICTIONARY:
			_warn_on_readable_mismatch(readable, order, exact, result)
		return exact

	if typeof(readable) != TYPE_DICTIONARY:
		result.add_error("save needs 'values_exact' or 'values'")
		return PackedFloat64Array()
	result.add_warning("'values_exact' missing; using readable values, which may not be bit-exact")
	var values := PackedFloat64Array()
	for id in order:
		var value: Variant = (readable as Dictionary).get(id)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			result.add_error("readable value for '%s' must be a number" % id)
			return PackedFloat64Array()
		values.append(float(value))
	return values


static func _warn_on_readable_mismatch(readable: Dictionary, order: PackedStringArray, exact: PackedFloat64Array, result: SimResult) -> void:
	for i in order.size():
		var value: Variant = readable.get(order[i])
		if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and float(value) != exact[i]:
			result.add_warning("readable value of '%s' (%s) differs from exact value (%s); using exact"
					% [order[i], value, exact[i]])
