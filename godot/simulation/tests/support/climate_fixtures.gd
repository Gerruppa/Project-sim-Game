extends RefCounted
## Climate test data: the project's climate.json with optional overrides.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")


static func data(overrides: Dictionary = {}) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ClimateConfig.DEFAULT_PATH))
	parsed.merge(overrides, true)
	return parsed


static func config(overrides: Dictionary = {}) -> ClimateConfig:
	var result := ClimateConfig.from_data(data(overrides))
	assert(result.is_ok(), "fixture climate config must be valid: %s" % [result.errors])
	return result.value


## Climate without randomness or seasons: only the feedback loops act.
static func calm(overrides: Dictionary = {}) -> ClimateConfig:
	var calm_overrides := {"drift_noise": 0.0, "season_amplitude": 0.0}
	calm_overrides.merge(overrides, true)
	return config(calm_overrides)


static func snapshot(values: Dictionary, tick: int = 0) -> PlanetSnapshot:
	var state: PlanetState = PlanetState.create(P.project_schema(), values).value
	return state.snapshot(tick)


## Sum of deltas per "parameter:cause".
static func by_cause(deltas: Array[Delta]) -> Dictionary:
	var sums := {}
	for delta in deltas:
		var key := "%s:%s" % [delta.parameter, delta.cause]
		sums[key] = sums.get(key, 0.0) + delta.amount
	return sums
