extends RefCounted
## PerkCatalog test data: perk definitions, parsing and the project catalog.

const Q := preload("res://simulation/tests/support/personality_fixtures.gd")
const I := preload("res://simulation/tests/support/intervention_fixtures.gd")


## A valid life perk with one modifier. Overrides replace whole keys.
static func perk(id: String, overrides: Dictionary = {}) -> Dictionary:
	var data := {
		"id": id, "name": "Test " + id, "help": "Test perk.", "tree": "life", "cost": 5,
		"requires": [],
		"modifiers": [{"target": "biosphere.stress_scale", "operation": "multiply", "value": 0.9}],
		"unlocks": [],
		"side_effect": "Test side effect.",
		"story": {"bought": id + " bought.", "refunded": id + " refunded."},
	}
	data.merge(overrides, true)
	return data


## Every intervention is free unless `extra` says otherwise.
static func parse(perks: Array, extra: Dictionary = {}) -> SimResult:
	var ids := I.project_catalog().ids()
	var data := {"perks_version": 1, "refund_ratio": 0.7, "income_per_biomass_tick": 0.00001,
			"free_interventions": ids.map(func(id: StringName) -> String: return String(id)), "perks": perks}
	data.merge(extra, true)
	return PerkCatalog.from_data(data, Q.specs(), ids)


static func catalog(perks: Array, extra: Dictionary = {}) -> PerkCatalog:
	var result := parse(perks, extra)
	assert(result.is_ok(), "fixture perks must be valid: %s" % [result.errors])
	return result.value


static func project_catalog() -> PerkCatalog:
	var result := PerkCatalog.load_json(PerkCatalog.DEFAULT_PATH, Q.specs(), I.project_catalog().ids())
	assert(result.is_ok(), "project perks must be valid: %s" % [result.errors])
	return result.value
