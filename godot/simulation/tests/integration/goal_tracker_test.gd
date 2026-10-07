extends GdUnitTestSuite
## GoalTracker on a real planet, driven by hand-made events: victory, stars,
## ambitions and saving. Populations are set directly, ticks are published
## on the bus, so each rule is tested on its own.

const ALL := ["bacteria", "algae", "moss", "shrub", "tree", "insects", "small_animals", "large_mammals"]

## Ticks every stage of life must stay alive to win (goals.json).
const HOLD := 1800

var _manager: SimulationManager
var _tracker: GoalTracker
var _goals: Dictionary


func _config(archetype: String) -> SimConfig:
	return SimConfig.from_data({
		"config_version": 1, "seed": 42, "base_ticks_per_second": 1, "speed_multipliers": [1, 10, 100],
		"max_catch_up_ticks": 1000, "personality": archetype,
		"log": {"text": false, "jsonl": false, "deltas": false, "chronicle": false, "directory": "user://goal_tracker_test"},
	}).value


func _start(archetype: String = "guardian", goals: Dictionary = {}) -> void:
	_goals = goals if not goals.is_empty() else GoalTracker.load_json().value
	_manager = SimulationRunner.build_planet(_config(archetype), SimulationRunner.parse_args(PackedStringArray()).value).value["manager"]
	_tracker = GoalTracker.new(_goals, _manager, archetype)
	_manager.attach_log(_tracker)


func _populate(species: Array, value: float = 5.0) -> void:
	var biosphere := _manager.system(BiosphereSystem.ID) as BiosphereSystem
	for id: String in species:
		biosphere.set_population(StringName(id), value)


func _publish(type: StringName, tick: int, data: Dictionary = {}) -> void:
	_manager.event_bus().publish(SimEvent.new(type, tick, &"test", data))
	_manager.event_bus().flush()


func _ticks(from: int, to: int) -> void:
	for tick in range(from, to + 1):
		_publish(SimEvent.TICK_APPLIED, tick)


func test_project_goals_are_valid() -> void:
	assert_array(Array(GoalTracker.load_json().errors)).is_empty()


func test_rejects_goals_without_the_three_stars() -> void:
	var data: Dictionary = GoalTracker.load_json().value.duplicate(true)
	data["stars"] = []
	data["ambitions"] = [{"id": "x", "name": "X", "kind": "fly"}]
	var errors := "\n".join(GoalTracker.validate(data).errors)
	assert_str(errors).contains("no_losses")
	assert_str(errors).contains("fly")


func test_victory_needs_every_stage_alive_for_the_whole_stretch() -> void:
	_start()
	_populate(ALL.slice(0, 7))
	_ticks(1, 800)
	assert_bool(_tracker.won()).is_false()
	assert_array(_tracker.missing_stages()).is_equal(["large_mammals"])
	_populate(ALL)
	_ticks(801, 801 + HOLD - 2)
	assert_bool(_tracker.won()).is_false()
	_ticks(801 + HOLD - 1, 801 + HOLD - 1)
	assert_bool(_tracker.won()).is_true()
	assert_int(_tracker.victory_tick()).is_equal(801 + HOLD - 1)


func test_a_quiet_quick_light_victory_earns_three_stars() -> void:
	_start()
	_populate(ALL)
	_publish(&"intervention_applied", 5, {"id": "mirrors_warm", "level": "weak"})
	_ticks(1, HOLD)
	assert_array(_tracker.stars()).contains_exactly(["no_losses", "fast", "light_hand"])
	assert_str(_tracker.stars_text()).starts_with("★★★")
	assert_str("".join(_tracker.take_news())).contains("VICTORY: Mature planet in year 6.")


func test_stars_are_lost_by_extinction_slowness_and_a_heavy_hand() -> void:
	_start()
	_populate(ALL)
	_publish(&"species_extinct", 1, {"species": "moss", "cause": "cold"})
	_publish(&"intervention_applied", 2, {"id": "mirrors_cool", "level": "strong"})
	_ticks(10800, 10800 + 719)
	assert_array(_tracker.stars()).is_empty()
	assert_str(_tracker.stars_text()).is_equal("☆☆☆")


func test_more_than_five_actions_is_not_a_light_hand() -> void:
	_start()
	_populate(ALL)
	for i in 6:
		_publish(&"intervention_applied", 1, {"id": "aquifer_release"})
	_ticks(1, HOLD)
	assert_bool(_tracker.stars().has("light_hand")).is_false()


func test_parameter_ambition_counts_only_before_its_year() -> void:
	_start()
	var biosphere := _manager.system(BiosphereSystem.ID)
	assert_object(biosphere).is_not_null()
	# Oxygen is 2 at the start: "Oddech planety" is not reached by ticks alone.
	_ticks(1, 5)
	assert_bool(_tracker.achieved().has("oxygenated")).is_false()


func test_species_ambition_with_an_archetype() -> void:
	_start("chaotic")
	_populate(["tree"], 2.0)
	_ticks(1, 1)
	assert_bool(_tracker.achieved().has("tame_chaos")).is_true()
	_start("guardian")
	_populate(["tree"], 2.0)
	_ticks(1, 1)
	assert_bool(_tracker.achieved().has("tame_chaos")).is_false()


func test_surviving_a_winter_needs_no_extinction_and_a_developed_planet() -> void:
	_start()
	_populate(ALL.slice(0, 4))
	_publish(&"world_event_started", 10, {"id": "ice_age"})
	_publish(&"world_event_ended", 400, {"id": "ice_age"})
	assert_bool(_tracker.achieved().has("survive_winter")).is_true()
	_start()
	_populate(ALL.slice(0, 2))
	_publish(&"world_event_started", 10, {"id": "ice_age"})
	_publish(&"world_event_ended", 400, {"id": "ice_age"})
	assert_bool(_tracker.achieved().has("survive_winter")).is_false()
	_start()
	_populate(ALL.slice(0, 4))
	_publish(&"world_event_started", 10, {"id": "ice_age"})
	_publish(&"species_extinct", 50, {"species": "tree", "cause": "cold"})
	_publish(&"world_event_ended", 400, {"id": "ice_age"})
	assert_bool(_tracker.achieved().has("survive_winter")).is_false()


func test_gardener_needs_the_players_seed() -> void:
	_start()
	_publish(&"species_returned", 10, {"species": "moss"})
	assert_bool(_tracker.achieved().has("gardener")).is_false()
	_publish(&"intervention_applied", 20, {"id": "seed_species", "species": "moss"})
	_publish(&"species_returned", 21, {"species": "moss"})
	assert_bool(_tracker.achieved().has("gardener")).is_true()


func test_untouched_victory_is_its_own_ambition_but_not_a_light_hand() -> void:
	_start()
	_populate(ALL)
	_ticks(1, HOLD)
	assert_bool(_tracker.achieved().has("hands_off")).is_true()
	assert_array(_tracker.stars()).contains_exactly(["no_losses", "fast"])


func test_progress_survives_a_save() -> void:
	_start()
	_populate(ALL)
	_publish(&"intervention_applied", 5, {"id": "mirrors_warm", "level": "medium"})
	_ticks(1, 300)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_tracker.save_state()))
	_start()
	_populate(ALL)
	_tracker.load_state(saved)
	assert_int(_tracker.streak()).is_equal(300)
	_ticks(301, HOLD)
	assert_bool(_tracker.won()).is_true()
	assert_bool(_tracker.stars().has("light_hand")).is_false()


func test_damaged_progress_starts_fresh() -> void:
	_start()
	_tracker.load_state({"achieved": "x", "victory": 3, "running": []})
	assert_bool(_tracker.won()).is_false()
	assert_int(_tracker.achieved().size()).is_equal(0)


func test_the_goal_line_counts_the_remaining_time_in_months() -> void:
	_start()
	_populate(ALL)
	_ticks(1, 300)
	var line := "\n".join(_tracker.status_lines({}))
	assert_str(line).contains("4 y. 2 mo. to go").not_contains("ticks")


func test_ending_texts_are_part_of_the_goal_data() -> void:
	var data: Dictionary = GoalTracker.load_json().value
	for kind: String in ["won", "timeup"]:
		assert_str(data["ending"][kind]["title"]).is_not_empty()
		assert_str(data["ending"][kind]["body"]).is_not_empty()
	var broken := data.duplicate(true)
	(broken["ending"] as Dictionary).erase("timeup")
	assert_bool(GoalTracker.validate(broken).is_ok()).is_false()
	assert_str("\n".join(GoalTracker.validate(broken).errors)).contains("ending")
