extends RefCounted
## Shared test data for schema-dependent tests.
## Loaded with preload() so test helpers stay out of the global class list.


static func parameter(id: String, initial: float, min_value: float = 0.0, max_value: float = 100.0) -> Dictionary:
	return {
		"id": id,
		"display_name": id.capitalize(),
		"unit": "normalized",
		"min": min_value,
		"max": max_value,
		"initial": initial,
		"anchors": {"0": "none", "50": "middle", "100": "full"},
	}


static func data(parameters: Array = []) -> Dictionary:
	if parameters.is_empty():
		parameters = [parameter("temperature", 35.0), parameter("biomass", 0.0)]
	return {"schema_version": 1, "parameters": parameters}


static func schema(parameters: Array = []) -> ParameterSchema:
	var result := ParameterSchema.from_data(data(parameters))
	assert(result.is_ok(), "fixture schema must be valid: %s" % [result.errors])
	return result.value


## Schema with the real project parameters.
static func project_schema() -> ParameterSchema:
	var result := ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH)
	assert(result.is_ok(), "project schema must be valid: %s" % [result.errors])
	return result.value
