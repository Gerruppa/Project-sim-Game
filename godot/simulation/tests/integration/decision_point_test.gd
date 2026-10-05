extends GdUnitTestSuite
## Decision points (--until decision): the run stops at the first event the
## player should react to, after a grace period, and tells them what they
## can do.

const TEST_DIR := "user://decision_point_test"
const I := preload("res://simulation/tests/support/intervention_fixtures.gd")


func _config() -> SimConfig:
	return SimConfig.from_data({
		"config_version": 1, "seed": 42, "base_ticks_per_second": 1, "speed_multipliers": [1, 10, 100],
		"max_catch_up_ticks": 1000, "personality": "harmonious",
		"log": {"text": false, "jsonl": false, "deltas": false, "chronicle": false, "directory": TEST_DIR},
		"save": {"directory": TEST_DIR, "autosave_every": 0},
	}).value


func _manager() -> SimulationManager:
	var built := SimulationRunner.build_planet(_config(), SimulationRunner.parse_args(PackedStringArray()).value)
	assert_array(Array(built.errors)).is_empty()
	return built.value["manager"]


## Steps until the watcher reaches a decision point (or the limit).
func _run_to_decision(manager: SimulationManager, watcher: DecisionWatcher, limit: int = 3000) -> void:
	for i in limit:
		manager.step()
		if watcher.reached():
			return


func _texts() -> ChronicleTexts:
	return ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH).value


func test_project_decision_points_are_world_events_and_species() -> void:
	var catalog := I.project_catalog()
	assert_array(catalog.decision_events).contains_exactly([&"world_event_started", &"species_extinct", &"species_emerged"])
	assert_int(catalog.decision_grace).is_equal(100)


func test_stops_at_the_first_decision_point_after_the_grace_period() -> void:
	var manager := _manager()
	var watcher: DecisionWatcher = SimulationRunner.create_watcher(manager).value
	manager.attach_log(watcher)
	_run_to_decision(manager, watcher)
	assert_bool(watcher.reached()).is_true()
	# Seed 42: bacteria appear at tick 122, the first fact after tick 100.
	assert_int(manager.tick()).is_equal(122)
	assert_str(String(watcher.point().type)).is_equal("species_emerged")
	assert_array(Array(watcher.sentences())).is_equal(["[Tick 122] Pojawiają się bakterie."])


func test_grace_period_hides_the_players_own_consequences() -> void:
	# Seeding moss makes moss "emerge" in the first tick: not a decision point.
	var manager := _manager()
	var watcher := DecisionWatcher.new([&"species_emerged"], 100, manager.tick(), _texts())
	manager.attach_log(watcher)
	manager.submit(InterventionSystem.ID, &"seed_species", {"species": "moss"})
	manager.run_ticks(100)
	assert_bool(watcher.reached()).is_false()


func test_grace_counts_from_the_tick_the_run_continues_from() -> void:
	var manager := _manager()
	manager.run_ticks(200)
	var watcher := DecisionWatcher.new([&"species_emerged", &"species_extinct"], 100, manager.tick(), _texts())
	manager.attach_log(watcher)
	_run_to_decision(manager, watcher)
	assert_int(watcher.point().tick).is_greater_equal(301)


func test_report_shows_the_point_interventions_and_how_to_continue() -> void:
	var manager := _manager()
	var watcher: DecisionWatcher = SimulationRunner.create_watcher(manager).value
	manager.attach_log(watcher)
	manager.submit(InterventionSystem.ID, &"mirrors_cool")
	_run_to_decision(manager, watcher)
	var report := "\n".join(SimulationRunner.decision_report(manager, watcher, "D:/saves/decision.json"))
	assert_str(report).contains("=== Punkt decyzji: tick 122 ===")
	assert_str(report).contains("[Tick 122] Pojawiają się bakterie.")
	assert_str(report).contains("seed_species:<species>")
	assert_str(report).contains("od ticku 1501")
	assert_str(report).contains("bacteria 1.0")
	assert_str(report).contains("--load decision.json --act <interwencja> --until decision")


func test_parses_until_decision() -> void:
	assert_str(SimulationRunner.parse_args(PackedStringArray(["--until", "decision"])).value["until"]).is_equal("decision")
	assert_bool(SimulationRunner.parse_args(PackedStringArray(["--until", "drought"])).is_ok()).is_false()


func test_catalog_requires_decision_points() -> void:
	var data := {"interventions_version": 1, "interventions": [I.timed("warm")]}
	assert_str("\n".join(InterventionCatalog.from_data(data, I.Q.specs(), I.command_specs()).errors)).contains("decision_points")
	data["decision_points"] = {"events": [], "grace_ticks": 10}
	assert_bool(InterventionCatalog.from_data(data, I.Q.specs(), I.command_specs()).is_ok()).is_false()
	data["decision_points"] = {"events": ["species_extinct"], "grace_ticks": -1}
	assert_bool(InterventionCatalog.from_data(data, I.Q.specs(), I.command_specs()).is_ok()).is_false()
