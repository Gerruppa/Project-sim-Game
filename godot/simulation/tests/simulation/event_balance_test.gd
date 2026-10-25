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


## Every world event ends properly, and the crises of a warmer and a colder
## planet both happen on the guardian runs (fire seasons need forests, so
## they are measured with event_impact.gd instead).
func test_every_event_ends_and_climate_crises_happen() -> void:
	var catalog := E.project_catalog()
	var seen := {}
	for seed_value in range(1, SEEDS + 1):
		var stats := _run(seed_value, &"guardian")
		for id: String in stats:
			var entry: Array = stats[id]
			seen[id] = seen.get(id, 0) + entry[0]
			assert_int(entry[0] - entry[1]).override_failure_message("seed %d: %s did not end" % [seed_value, id]).is_between(0, 1)
			assert_int(entry[2]).is_less_equal(catalog.get_def(StringName(id)).max_duration)
	for id: String in ["ice_age", "overheating"]:
		assert_int(seen.get(id, 0)).override_failure_message("no %s in %d runs" % [id, SEEDS]).is_greater(0)


## Crises are announced: for each crisis most starts were warned about, the
## warning leads by a useful time, and not every warning is a false alarm.
## Run: three seeds on the three archetypes, 9000 ticks (docs/events.md).
func test_crises_are_warned_about_ahead_of_time() -> void:
	var leads := {}
	var started := {}
	var warned := {}
	var withdrawn := {}
	for archetype: StringName in [&"harmonious", &"chaotic", &"guardian"]:
		for seed_value in range(1, SEEDS + 1):
			_measure_warnings(seed_value, archetype, leads, started, warned, withdrawn)
	for id: String in ["overheating", "drought", "ice_age"]:
		var lead: Array = leads.get(id, [])
		lead.sort()
		var label := "%s: %d starts, %d warned ahead, lead %s" % [id, started.get(id, 0), lead.size(), lead]
		assert_int(started.get(id, 0)).override_failure_message(label).is_greater(5)
		assert_float(float(lead.size()) / started[id]).override_failure_message(label).is_greater_equal(0.7)
		assert_int(lead[lead.size() / 2]).override_failure_message(label).is_greater_equal(100)
		assert_float(float(withdrawn.get(id, 0)) / maxi(1, warned.get(id, 0))).override_failure_message(
				"%s: too many false alarms (%d of %d)" % [id, withdrawn.get(id, 0), warned.get(id, 0)]).is_less_equal(0.6)


func _measure_warnings(seed_value: int, archetype: StringName, leads: Dictionary, started: Dictionary,
		warned: Dictionary, withdrawn: Dictionary) -> void:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH).value, seed_value))
	manager.register_system(AtmosphereSystem.new(AtmosphereConfig.load_json(AtmosphereConfig.DEFAULT_PATH).value))
	manager.register_system(BiosphereSystem.new(BiosphereConfig.load_json(BiosphereConfig.DEFAULT_PATH).value,
			SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value, seed_value))
	manager.register_system(PersonalitySystem.create(Q.project_catalog(), archetype, seed_value).value)
	manager.register_system(EventSystem.new(E.project_catalog(), archetype))
	var warned_at := {}
	manager.event_bus().subscribe(EventSystem.WARNED_EVENT, func(event: SimEvent) -> void:
		warned_at[event.data["id"]] = event.tick
		warned[event.data["id"]] = warned.get(event.data["id"], 0) + 1)
	manager.event_bus().subscribe(EventSystem.WARNING_CLEARED_EVENT, func(event: SimEvent) -> void:
		warned_at.erase(event.data["id"])
		withdrawn[event.data["id"]] = withdrawn.get(event.data["id"], 0) + 1)
	manager.event_bus().subscribe(EventSystem.STARTED_EVENT, func(event: SimEvent) -> void:
		var id: String = event.data["id"]
		started[id] = started.get(id, 0) + 1
		if warned_at.has(id):
			var list: Array = leads.get(id, [])
			list.append(event.tick - int(warned_at[id]))
			leads[id] = list
			warned_at.erase(id))
	assert_int(manager.run_ticks(9000)).is_equal(9000)
