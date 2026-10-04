extends GdUnitTestSuite
## World events over long runs on several seeds: they happen, they end,
## and the planet keeps running. A guardian planet heals after collapses.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")
const Q := preload("res://simulation/tests/support/personality_fixtures.gd")
const E := preload("res://simulation/tests/support/event_fixtures.gd")

const SEEDS := 3
const TICKS := 12000


## id -> [started, ended, longest]
func _run(seed_value: int, archetype: StringName) -> Dictionary:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH).value, seed_value))
	manager.register_system(AtmosphereSystem.new(AtmosphereConfig.load_json(AtmosphereConfig.DEFAULT_PATH).value))
	manager.register_system(BiosphereSystem.new(BiosphereConfig.load_json(BiosphereConfig.DEFAULT_PATH).value,
			SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value, seed_value))
	manager.register_system(PersonalitySystem.create(Q.project_catalog(), archetype, seed_value).value)
	manager.register_system(EventSystem.new(E.project_catalog(), archetype))
	var stats := {}
	manager.event_bus().subscribe(EventSystem.STARTED_EVENT, func(event: SimEvent) -> void:
		var entry: Array = stats.get(event.data["id"], [0, 0, 0])
		entry[0] += 1
		stats[event.data["id"]] = entry)
	manager.event_bus().subscribe(EventSystem.ENDED_EVENT, func(event: SimEvent) -> void:
		var entry: Array = stats[event.data["id"]]
		entry[1] += 1
		entry[2] = maxi(entry[2], event.data["duration"]))
	var executed := manager.run_ticks(TICKS)
	assert_int(executed).override_failure_message("seed %d halted: %s" % [seed_value, manager.errors()]).is_equal(TICKS)
	return stats


func test_droughts_happen_and_end_on_every_seed() -> void:
	var catalog := E.project_catalog()
	for seed_value in range(1, SEEDS + 1):
		var stats := _run(seed_value, &"guardian")
		assert_bool(stats.has("drought")).override_failure_message("seed %d: no drought" % seed_value).is_true()
		var drought: Array = stats["drought"]
		# At most the last one may still be running when the run stops.
		assert_int(drought[0] - drought[1]).is_between(0, 1)
		assert_int(drought[2]).is_less_equal(catalog.get_def(&"drought").max_duration)
		var healing: Array = stats.get("guardian_healing", [0, 0, 0])
		assert_int(healing[0]).override_failure_message("seed %d: the guardian never healed" % seed_value).is_greater(0)
		assert_int(healing[0] - healing[1]).is_between(0, 1)
