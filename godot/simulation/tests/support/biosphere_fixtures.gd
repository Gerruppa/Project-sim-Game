extends RefCounted
## Biosphere test data: species and biosphere settings with overrides.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")


## A species that thrives on a temperate, wet planet and needs nothing else.
static func species(id: String, overrides: Dictionary = {}) -> Dictionary:
	var data := {
		"id": id, "layer": 1, "weight": 0.2, "growth": 0.05, "capacity": 80.0,
		"t_min": 10.0, "t_max": 50.0, "t_margin": 5.0,
		"water": "humidity", "water_min": 10.0, "water_margin": 5.0,
		"co2_need": 0.0, "o2_need": 0.0, "o2_max": 0.0, "o2_refuge": 0.0, "biomass_need": 0.0,
		"shade": 0.0, "flammable": 0.0, "base_mortality": 0.001, "stress_mortality": 0.05,
		"emerges_from": "", "seed": 0.01,
		"oxygen": 0.0, "co2_uptake": 0.0, "respiration": 0.0, "transpiration": 0.0,
	}
	data.merge(overrides, true)
	return data


static func catalog_data(species_list: Array) -> Dictionary:
	return {"catalog_version": 1, "species": species_list}


static func catalog(species_list: Array) -> SpeciesCatalog:
	var result := SpeciesCatalog.from_data(catalog_data(species_list))
	assert(result.is_ok(), "fixture catalog must be valid: %s" % [result.errors])
	return result.value


static func config_data(overrides: Dictionary = {}) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BiosphereConfig.DEFAULT_PATH))
	parsed.merge(overrides, true)
	return parsed


static func config(overrides: Dictionary = {}) -> BiosphereConfig:
	var result := BiosphereConfig.from_data(config_data(overrides))
	assert(result.is_ok(), "fixture biosphere config must be valid: %s" % [result.errors])
	return result.value


## Biosphere without randomness or fires: only growth, death and competition act.
static func calm(overrides: Dictionary = {}) -> BiosphereConfig:
	var calm_overrides := {"growth_noise": 0.0, "fire_rate": 0.0}
	calm_overrides.merge(overrides, true)
	return config(calm_overrides)


## Temperate, wet, oxygen-free planet.
static func snapshot(values: Dictionary = {}) -> PlanetSnapshot:
	var merged := {"temperature": 30.0, "humidity": 40.0, "precipitation": 20.0, "oxygen": 0.0,
			"co2": 40.0, "biomass": 0.0}
	merged.merge(values, true)
	var state: PlanetState = PlanetState.create(P.project_schema(), merged).value
	return state.snapshot(0)
