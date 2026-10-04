extends RefCounted
## Personality test data.


## Coefficient specs of the systems the project runs.
static func specs() -> Dictionary:
	return {&"climate": ClimateConfig.SPEC, &"atmosphere": AtmosphereConfig.SPEC, &"biosphere": BiosphereConfig.SPEC}


static func archetype(id: String, modifiers: Array = [], overrides: Dictionary = {}) -> Dictionary:
	if modifiers.is_empty():
		modifiers = [{"target": "climate.drift_noise", "operation": "multiply", "value": 2.0}]
	var data := {"id": id, "weight": 1, "description": "test archetype", "modifiers": modifiers}
	data.merge(overrides, true)
	return data


static func catalog_data(archetypes: Array) -> Dictionary:
	return {"personality_version": 1, "archetypes": archetypes}


static func catalog(archetypes: Array) -> PersonalityCatalog:
	var result := PersonalityCatalog.from_data(catalog_data(archetypes), specs())
	assert(result.is_ok(), "fixture personality catalog must be valid: %s" % [result.errors])
	return result.value


static func project_catalog() -> PersonalityCatalog:
	return PersonalityCatalog.load_json(PersonalityCatalog.DEFAULT_PATH, specs()).value
