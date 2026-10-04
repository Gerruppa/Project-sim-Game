class_name CoefficientLoader
extends RefCounted
## Shared loading and validation of system coefficient files
## (climate.json, atmosphere.json, ...).
##
## A spec maps each coefficient name to [min, max, integer]. Every key is
## required, unknown keys are errors (a typo would otherwise leave the
## intended coefficient at 0), and all errors are reported at once.


static func read_json(path: String, label: String) -> SimResult:
	if not FileAccess.file_exists(path):
		return SimResult.failure("%s file not found: %s" % [label, path])
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return SimResult.failure("%s JSON error in %s at line %d: %s"
				% [label, path, json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return SimResult.failure("%s root must be an object: %s" % [label, path])
	return SimResult.success(json.data)


## Validates `data` against `spec` and writes the values into `target`'s
## properties of the same names. `ordered_pairs` lists [lower, upper] names
## where lower must be strictly below upper.
static func fill(target: Object, data: Dictionary, spec: Dictionary, ordered_pairs: Array, label: String) -> SimResult:
	var result := SimResult.new()
	for key: Variant in data:
		if key != "config_version" and not spec.has(key):
			result.add_error("unknown %s coefficient '%s'" % [label, key])

	for name: String in spec:
		var rule: Array = spec[name]
		var value: Variant = data.get(name)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			result.add_error("'%s' must be a number" % name)
			continue
		var number := float(value)
		if not is_finite(number) or number < rule[0] or number > rule[1]:
			result.add_error("'%s' must lie within %s..%s" % [name, rule[0], rule[1]])
			continue
		if rule[2] and number != floorf(number):
			result.add_error("'%s' must be an integer" % name)
			continue
		if not name in target:
			result.add_error("internal: %s has no field '%s'" % [label, name])
			continue
		target.set(name, int(number) if rule[2] else number)

	if result.is_ok():
		for pair: Array in ordered_pairs:
			if float(target.get(pair[0])) >= float(target.get(pair[1])):
				result.add_error("'%s' must be lower than '%s'" % [pair[0], pair[1]])
	if result.is_ok():
		result.value = target
	return result
