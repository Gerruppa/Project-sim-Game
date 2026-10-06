extends GdUnitTestSuite
## The window (ui/GameView) runs headless: it builds, plays to a decision
## point, shows it, lets the player act with a button, pauses and resumes.
## Ticks are driven through GameView.advance, not real time.

const SAVE := "user://game_view_test/decision.json"

var _view: GameView


func _open(args: Array = ["--seed", "13"]) -> GameView:
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(args + ["--save", SAVE])).value
	options["file_logs"] = false
	_view = GameView.new()
	_view.options = options
	add_child(_view)
	return _view


func after_test() -> void:
	if _view != null:
		_view.queue_free()
		_view = null


## Advances until a decision point (or the limit).
func _to_decision(view: GameView, limit: int = 20000) -> void:
	var done := 0
	while not view.at_decision() and done < limit:
		view.advance(500)
		done += 500


func test_new_game_starts_with_the_intro() -> void:
	var view := _open()
	assert_bool(view.at_decision()).is_true()
	assert_str(view.decision_text()).contains("Witaj w Genesis Error")


func test_plays_to_the_first_decision_point_and_saves() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	assert_bool(view.at_decision()).is_true()
	assert_str(view.decision_text()).contains("PUNKT DECYZJI · tick 130")
	assert_str(view.decision_text()).contains("Pojawiają się bakterie.")
	assert_str(view.chronicle_text()).contains("[Tick 130] Pojawiają się bakterie.")
	assert_bool(FileAccess.file_exists(ProjectSettings.globalize_path(SAVE))).is_true()


func test_an_action_button_queues_the_intervention() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	var done := view.act("aquifer_release")
	assert_array(Array(done.errors)).is_empty()
	assert_str(view.chronicle_text()).contains("Zrobione: Wody podziemne.")
	assert_int(view.session.manager.command_queue().pending().size()).is_equal(1)
	assert_bool(view.act("aquifer_release").is_ok()).is_false()


func test_pause_lets_the_player_act_between_decisions() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	view.start()
	view.advance(20)
	view.toggle_pause()
	assert_str(view.decision_text()).contains("PAUZA")
	assert_bool(view.act("mirrors_cool").is_ok()).is_true()
	view.toggle_pause()
	assert_str(view.decision_text()).contains("Planeta żyje")


func test_speeds_follow_the_buttons() -> void:
	var view := _open()
	assert_int(view.session.manager.scheduler().speed()).is_equal(GameView.DEFAULT_SPEED)
	for speed: int in GameView.SPEEDS:
		view.set_speed(speed)
		assert_int(view.session.manager.scheduler().speed()).is_equal(speed)
	view.set_speed(7)
	assert_int(view.session.manager.scheduler().speed()).is_equal(GameView.SPEEDS[-1])


## Players used x1000 to skip the game; the window offers 5-100 and starts at 10.
func test_window_offers_watching_speeds_only() -> void:
	assert_array(GameView.SPEEDS).is_equal([5, 10, 25, 100])
	assert_int(GameView.DEFAULT_SPEED).is_equal(10)
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	for speed: int in GameView.SPEEDS:
		assert_bool(config.speed_multipliers().has(speed)).override_failure_message("x%d not in sim_config" % speed).is_true()


func test_loaded_game_skips_the_intro() -> void:
	var first := _open()
	first.start()
	_to_decision(first)
	first.queue_free()
	_view = null
	var view := _open(["--load", SAVE])
	assert_bool(view.at_decision()).is_false()
	assert_str(view.decision_text()).contains("Planeta żyje")


func test_bad_options_show_an_error_instead_of_crashing() -> void:
	var view := GameView.new()
	view.options = PlaySession.parse_args(PackedStringArray(["--seed", "1", "--save", SAVE])).value
	view.options["climate"] = "res://missing.json"
	view.options["file_logs"] = false
	_view = view
	add_child(view)
	assert_object(view.session).is_null()
	assert_str(view.error_text()).contains("missing.json")


func test_decision_shows_what_changed_since_the_planet_last_ran_on() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	var changes := view.session.planet_rows().map(func(row: Dictionary) -> String: return row["change"])
	assert_bool(changes.any(func(change: String) -> bool: return change.begins_with("↑") or change.begins_with("↓"))) \
			.override_failure_message("every trend is '=' at the decision: %s" % [changes]).is_true()
	view.act("aquifer_release")
	changes = view.session.planet_rows().map(func(row: Dictionary) -> String: return row["change"])
	assert_bool(changes.any(func(change: String) -> bool: return change != "=")).is_true()


func _open_without_options() -> GameView:
	_view = GameView.new()
	_view.command_line = PackedStringArray()
	add_child(_view)
	return _view


func test_double_clicked_game_asks_which_planet_first() -> void:
	var view := _open_without_options()
	assert_object(view.session).is_null()
	assert_str(view.decision_text()).contains("nowa planeta")
	assert_str(view.error_text()).is_empty()


func test_new_game_screen_starts_the_chosen_planet() -> void:
	var view := _open_without_options()
	view.choose_planet("13", 2)
	view.new_game()
	assert_int(view.session.manager.config().seed()).is_equal(13)
	assert_str(String(view.session.manager.config().personality())).is_equal("chaotic")
	assert_str(view.decision_text()).contains("Witaj w Genesis Error")


func test_new_game_screen_draws_a_planet_when_no_number_is_given() -> void:
	var view := _open_without_options()
	view.choose_planet("  ")
	view.new_game()
	assert_object(view.session).is_not_null()
	assert_int(view.session.manager.config().seed()).is_between(1, 99999)


func test_parameters_show_the_players_units_and_life_zone_colours() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	# The starting planet is 30 on the 0-100 scale, which is freezing point in degrees.
	assert_str(view.parameter_text("temperature")).ends_with(" °C")
	assert_str(view.parameter_text("oxygen")).ends_with(" % atmosfery")
	# Bacteria live at 5-70, so the temperature is in their range (green); cloud cover limits nobody.
	assert_bool(view.parameter_color("temperature") == GameView.ZONE_COLORS["good"]).is_true()
	assert_bool(view.parameter_color("cloud_cover") == Color.TRANSPARENT).is_true()


func test_cooldown_counts_in_seconds_of_the_chosen_speed() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	view.set_speed(100)
	assert_bool(view.act("aquifer_release").is_ok()).is_true()
	view.start()
	view.advance(1)
	# 900 ticks of cooldown at 100 ticks per second: 9 seconds.
	assert_str(view.action_text("aquifer_release")).is_equal("Wody podziemne (9 s)")
	view.set_speed(10)
	assert_str(view.action_text("aquifer_release")).is_equal("Wody podziemne (1 min 30 s)")
	view.advance(100)
	assert_str(view.action_text("aquifer_release")).ends_with("s)")
	assert_str(view.action_text("mirrors_warm")).is_equal("Lustra orbitalne")


func test_a_running_action_shows_how_long_it_acts_and_when_its_effect_fades() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	view.set_speed(100)
	view.act("aquifer_release")
	var queued := view.watch_lines()[0]
	assert_str(queued).starts_with("Wody podziemne: ruszy w następnym ticku")
	view.start()
	view.advance(1)
	var line := view.watch_lines()[0]
	assert_str(line).starts_with("Wody podziemne: działa jeszcze 3 s")
	assert_str(line).contains("skutek zwykle widać jeszcze")


## The layout never asks for more than the window it is built for: long
## texts are cut or wrapped, so "Dalej" stays on screen (player feedback).
func test_layout_fits_the_base_window_through_a_game() -> void:
	var view := _open(["--seed", "13", "--personality", "harmonious"])
	var worst := Vector2.ZERO
	var extinct_seen := false
	for round: int in 8:
		view.start()
		_to_decision(view)
		await await_idle_frame()
		worst = worst.max((view.get_child(1) as Control).get_combined_minimum_size())
		extinct_seen = extinct_seen or view.session.life_rows().any(func(row: Dictionary) -> bool: return row["change"] == "wymarły")
		view.act("aquifer_release")
		view.act("mirrors_cool")
	assert_bool(extinct_seen).override_failure_message("no extinction shown: the widest text was not tried").is_true()
	assert_float(worst.x).is_less_equal(GameView.BASE_SIZE.x)
	assert_float(worst.y).is_less_equal(GameView.BASE_SIZE.y)


func test_goals_window_lists_everything_to_win() -> void:
	var view := _open()
	assert_str(view.decision_text()).contains("„Cele”")
	assert_str(view.goals_window_text()).is_empty()
	view.show_goals()
	var text := view.goals_window_text()
	assert_str(text).contains("Dojrzała planeta")
	for ambition: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(GoalTracker.DEFAULT_PATH))["ambitions"]:
		assert_str(text).contains(ambition["name"])


func test_goals_button_waits_for_a_planet() -> void:
	var view := _open_without_options()
	view.show_goals()
	assert_str(view.goals_window_text()).is_empty()


func test_life_shows_what_each_species_did_and_the_rest_of_the_planet() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	view.start()
	_to_decision(view)
	assert_str(view.life_effects_text("bacteria")).contains("Dwutlenek węgla +")
	assert_str(view.life_effects_text("tree")).is_empty()
	assert_str(view.others_text()).starts_with("Reszta planety")


func test_the_globe_follows_the_planet_and_charts_wait_behind_a_button() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	var look := view.planet_look()
	assert_float(look["bacteria"]).is_greater(0.0)
	assert_bool(view.charts_visible()).is_false()
	view.show_charts()
	assert_bool(view.charts_visible()).is_true()
