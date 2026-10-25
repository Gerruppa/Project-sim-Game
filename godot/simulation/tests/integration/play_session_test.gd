extends GdUnitTestSuite
## The console game played from a script: intro, decision screens, menus,
## actions, hints and saving.

const SAVE := "user://play_session_test/decision.json"

var _output := PackedStringArray()
var _input: Array = []


func _create(args: PackedStringArray, answers: Array, extra: Dictionary = {}) -> PlaySession:
	_input = answers.duplicate()
	_output = PackedStringArray()
	var options: Dictionary = PlaySession.parse_args(args).value
	options["file_logs"] = false
	options.merge(extra, true)
	var read := func() -> Variant: return null if _input.is_empty() else _input.pop_front()
	var write := func(text: String) -> void: _output.append(text)
	var created := PlaySession.create(options, read, write)
	assert_array(Array(created.errors)).is_empty()
	return created.value


func _session(answers: Array, extra: Dictionary = {}) -> PlaySession:
	return _create(PackedStringArray(["--seed", "13", "--save", SAVE]), answers, extra)


func _text() -> String:
	return "".join(_output)


func test_new_game_shows_the_intro_and_the_first_decision_with_a_menu() -> void:
	var session := _session(["", "q"])
	assert_int(session.play()).is_equal(0)
	var text := _text()
	assert_str(text).contains("Welcome to Genesis Error.")
	assert_str(text).contains("=== Decision point: tick 130 (year 1) ===")
	assert_str(text).contains("What happened:  Life takes hold: bacteria.")
	assert_str(text).contains("Planet:\n  Average temperature ")
	assert_str(text).contains("Life:\n  bacteria ")
	assert_str(text).contains("Hint:")
	assert_str(text).contains(" 1) Seed a species")
	assert_str(text).contains("Back to the game: ./godot/play.sh --load decision.json")
	assert_bool(FileAccess.file_exists(ProjectSettings.globalize_path(SAVE))).is_true()


func test_seeding_through_the_menu_queues_the_command() -> void:
	_session(["", "0", "1", "3"]).play()
	var text := _text()
	assert_str(text).contains("Which species?")
	assert_str(text).contains("missing: oxygen")
	assert_str(text).contains("Done: Seed a species (moss).")


func test_levels_have_a_default_on_enter() -> void:
	_session(["", "4", ""]).play()
	assert_str(_text()).contains("How strong?")
	assert_str(_text()).contains("Done: Orbital dust (full power).")


func test_menu_answers_unknown_input_help_and_hint_toggle() -> void:
	_session(["", "x", "?", "h", "q"]).play()
	var text := _text()
	assert_str(text).contains("I do not understand \"x\"")
	assert_str(text).contains("Aquifers: For 300 ticks the land evaporates")
	assert_str(text).contains("Hints hidden.")


func test_cooling_down_action_is_refused_with_its_ready_tick() -> void:
	_session(["", "3", "1", "", "3", "q"]).play()
	assert_str(_text()).contains("Orbital mirrors is still recharging: available from tick 1631.")


func test_waiting_runs_the_planet_to_the_next_decision() -> void:
	_session(["", "0", "q"]).play()
	assert_str(_text()).contains("=== Decision point: tick 294 (year 1) ===")


func test_loaded_game_skips_the_intro() -> void:
	_session(["", "q"]).play()
	_create(PackedStringArray(["--load", SAVE, "--save", SAVE]), ["q"]).play()
	assert_str(_text()).not_contains("Welcome to Genesis Error.")
	assert_str(_text()).contains("=== Decision point: tick 294")


func test_hints_can_start_hidden() -> void:
	_session(["", "q"], {"hints": false}).play()
	assert_str(_text()).not_contains("Hint:")


func test_parses_play_options() -> void:
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--seed", "7", "--no-hints"])).value
	assert_int(options["seed"]).is_equal(7)
	assert_bool(options["hints"]).is_false()
	assert_bool(options["full_logs"]).is_false()
	assert_bool(PlaySession.parse_args(PackedStringArray(["--full-logs"])).value["full_logs"]).is_true()
	assert_bool(PlaySession.parse_args(PackedStringArray(["--load", "a.json", "--seed", "2"])).is_ok()).is_false()
	assert_bool(PlaySession.parse_args(PackedStringArray(["--fast"])).is_ok()).is_false()


func test_second_screen_shows_what_changed_since_the_first() -> void:
	_session(["", "0", "q"]).play()
	var text := _text()
	assert_str(text).contains("Planet (change since the previous decision, 164 ticks ago):")
	# The mean temperature in degrees, and its change since the first screen.
	assert_str(text).contains("%-20s %16s   %s" % ["Average temperature", "17.0 °C", "↓ 7.7"])
	assert_str(text).contains("bacteria        15   ↑ 14")


func test_species_that_died_since_the_last_decision_is_marked() -> void:
	_session(["", "0", "1", "3", "", "q"]).play()
	assert_str(_text()).contains("moss          LOST   lost")


func test_trend_shows_direction_and_hides_noise() -> void:
	assert_str(PlaySession.trend(9.46, 1)).is_equal("↑ 9.5")
	assert_str(PlaySession.trend(-0.6, 1)).is_equal("↓ 0.6")
	assert_str(PlaySession.trend(0.04, 1)).is_equal("=")
	assert_str(PlaySession.trend(-0.4, 0)).is_equal("=")
	assert_str(PlaySession.trend(23.2, 0)).is_equal("↑ 23")


func test_world_event_causes_use_the_players_parameter_names() -> void:
	# Seed 3: an ice age starts at tick 531, the third decision point.
	_create(PackedStringArray(["--seed", "3", "--save", SAVE]), ["", "0", "0", "q"]).play()
	var text := _text()
	assert_str(text).contains("What happened:  Ice age:")
	assert_str(text).contains("(Temperature averages")
	assert_str(text).not_contains("(temperature averages")


func test_screen_shows_the_goal_and_ambitions() -> void:
	_session(["", "c", "q"]).play()
	var text := _text()
	assert_str(text).contains("Goal:          Mature planet: stages of life 1/8, missing: algae, moss, shrubs, trees, insects, small animals, large mammals")
	assert_str(text).contains("Ambitions:     0/9")
	assert_str(text).contains("Main goal: Mature planet.")
	assert_str(text).contains("☆ Fast: win before year 40")
	assert_str(text).contains("[ ] Gardener: bring back a species that died out by seeding it")


func test_goal_progress_is_saved_with_the_game() -> void:
	_session(["", "3", "1", "", "q"]).play()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(SAVE)))
	assert_int(int(saved["extras"]["goals"]["interventions"])).is_equal(1)


func test_screen_shows_what_each_species_and_the_planet_did() -> void:
	_session(["", "0", "q"]).play()
	var text := _text()
	assert_str(text).contains("bacteria        15   ↑ 14     impact: ")
	assert_str(text).contains("The rest of the planet (rocks, oceans, weather, events): ")
