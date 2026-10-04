extends RefCounted
## Atmosphere test data: the project's atmosphere.json with optional overrides.


static func data(overrides: Dictionary = {}) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AtmosphereConfig.DEFAULT_PATH))
	parsed.merge(overrides, true)
	return parsed


static func config(overrides: Dictionary = {}) -> AtmosphereConfig:
	var result := AtmosphereConfig.from_data(data(overrides))
	assert(result.is_ok(), "fixture atmosphere config must be valid: %s" % [result.errors])
	return result.value
