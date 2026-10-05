extends RefCounted
## InterventionSystem test data: definitions, catalogs and specs.

const Q := preload("res://simulation/tests/support/personality_fixtures.gd")

const SPECIES: Array[StringName] = [&"moss", &"tree"]


static func command_specs() -> Dictionary:
	return {&"biosphere": BiosphereSystem.COMMANDS}


## A timed intervention: +4 base temperature for 10 ticks, cooldown 20.
static func timed(id: String, overrides: Dictionary = {}) -> Dictionary:
	var data := {
		"id": id, "name": "Test " + id, "cooldown": 20, "duration": 10,
		"story": {"applied": id + " starts.", "ended": id + " ends."},
		"modifiers": [{"target": "climate.base_temperature", "operation": "add", "value": 4.0}],
	}
	data.merge(overrides, true)
	return data


## An instant intervention with a species argument that asks the biosphere.
static func seeding(id: String = "seed", overrides: Dictionary = {}) -> Dictionary:
	var data := {
		"id": id, "name": "Test " + id, "args": ["species"], "cooldown": 5,
		"story": {"applied": "Seeding {species}."},
		"commands": [{"target": "biosphere", "action": "add_population", "args": {"species": "$species", "amount": 5.0}}],
	}
	data.merge(overrides, true)
	return data


static func parse(defs: Array) -> SimResult:
	return InterventionCatalog.from_data({"interventions_version": 1, "interventions": defs,
			"decision_points": {"events": ["species_extinct"], "grace_ticks": 10}}, Q.specs(), command_specs())


static func catalog(defs: Array) -> InterventionCatalog:
	var result := parse(defs)
	assert(result.is_ok(), "fixture interventions must be valid: %s" % [result.errors])
	return result.value


static func project_catalog() -> InterventionCatalog:
	var result := InterventionCatalog.load_json(InterventionCatalog.DEFAULT_PATH, Q.specs(), command_specs())
	assert(result.is_ok(), "project interventions must be valid: %s" % [result.errors])
	return result.value


static func registry() -> ModifierRegistry:
	var registry := ModifierRegistry.new()
	for id: StringName in Q.specs():
		registry.register_target(id, Q.specs()[id])
	return registry
