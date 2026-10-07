extends GdUnitTestSuite
## The window (ui/GameView) runs headless: it builds, plays to a decision
## point, shows it, lets the player act with a button, pauses and resumes.
## Ticks are driven through GameView.advance, not real time.

const SAVE := "user://game_view_test/decision.json"

var _view: GameView


func _open(args: Array = ["--seed", "13"]) -> GameView:
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(args + ["--save", SAVE])).value
	options["file_logs"] = false
	# These tests cover the decision-point flow; the live mode has its own suite.
	options["live"] = false
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
	assert_str(view.decision_text()).contains("Welcome to Genesis Error")


func test_plays_to_the_first_decision_point_and_saves() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	assert_bool(view.at_decision()).is_true()
	assert_str(view.decision_text()).contains("DECISION POINT · Year 1, May")
	assert_str(view.decision_text()).contains("Life takes hold: bacteria.")
	assert_str(view.chronicle_text()).contains("Year 1, May: Life takes hold: bacteria.")
	assert_bool(FileAccess.file_exists(ProjectSettings.globalize_path(SAVE))).is_true()


func test_an_action_button_queues_the_intervention() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	var done := view.act("aquifer_release")
	assert_array(Array(done.errors)).is_empty()
	assert_str(view.chronicle_text()).contains("Done: Aquifers.")
	assert_int(view.session.manager.command_queue().pending().size()).is_equal(1)
	assert_bool(view.act("aquifer_release").is_ok()).is_false()


func test_pause_lets_the_player_act_between_decisions() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	view.start()
	view.advance(20)
	view.toggle_pause()
	assert_str(view.decision_text()).contains("PAUSED · Year 1")
	assert_bool(view.act("mirrors_cool").is_ok()).is_true()
	view.toggle_pause()
	assert_str(view.decision_text()).contains("The planet lives")


func test_speeds_follow_the_buttons() -> void:
	var view := _open()
	assert_int(view.session.manager.scheduler().speed()).is_equal(GameView.DEFAULT_SPEED)
	for speed: int in GameView.SPEEDS:
		view.set_speed(speed)
		assert_int(view.session.manager.scheduler().speed()).is_equal(speed)
	view.set_speed(7)
	assert_int(view.session.manager.scheduler().speed()).is_equal(GameView.SPEEDS[-1])


## Players used x1000 to skip the game; the window offers 5-100 and starts at 25.
func test_window_offers_watching_speeds_only() -> void:
	assert_array(GameView.SPEEDS).is_equal([5, 10, 25, 50, 100])
	assert_int(GameView.DEFAULT_SPEED).is_equal(25)
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	for speed: int in GameView.SPEEDS:
		assert_bool(config.speed_multipliers().has(speed)).override_failure_message("x%d not in sim_config" % speed).is_true()


## Without live mode the trends still count from the last decision.
func test_legacy_trend_headers_count_from_the_last_decision() -> void:
	var view := _open()
	for title in view.trend_titles():
		assert_str(title).contains("since the last decision")


func test_loaded_game_skips_the_intro() -> void:
	var first := _open()
	first.start()
	_to_decision(first)
	first.queue_free()
	_view = null
	var view := _open(["--load", SAVE])
	assert_bool(view.at_decision()).is_false()
	assert_str(view.decision_text()).contains("The planet lives")


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
	assert_str(view.decision_text()).contains("new planet")
	assert_str(view.error_text()).is_empty()


func test_new_game_screen_starts_the_chosen_planet() -> void:
	var view := _open_without_options()
	view.choose_planet("13", 2)
	view.new_game()
	assert_int(view.session.manager.config().seed()).is_equal(13)
	assert_str(String(view.session.manager.config().personality())).is_equal("chaotic")
	assert_str(view.decision_text()).contains("Welcome to Genesis Error")


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
	assert_str(view.parameter_text("oxygen")).ends_with(" % of atmosphere")
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
	assert_str(view.action_text("aquifer_release")).is_equal("Aquifers (9 s)")
	view.set_speed(10)
	assert_str(view.action_text("aquifer_release")).is_equal("Aquifers (1 min 30 s)")
	view.advance(100)
	assert_str(view.action_text("aquifer_release")).ends_with("s)")
	assert_str(view.action_text("mirrors_warm")).is_equal("Orbital mirrors")


func test_a_running_action_shows_how_long_it_acts_and_when_its_effect_fades() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	view.set_speed(100)
	view.act("aquifer_release")
	var queued := view.watch_lines()[0]
	assert_str(queued).starts_with("Aquifers: starts next tick")
	view.start()
	view.advance(1)
	var line := view.watch_lines()[0]
	assert_str(line).starts_with("Aquifers: acts for 3 s more")
	assert_str(line).contains("the effect usually shows for another")


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
		extinct_seen = extinct_seen or view.session.life_rows().any(func(row: Dictionary) -> bool: return row["change"] == "lost")
		view.act("aquifer_release")
		view.act("mirrors_cool")
	assert_bool(extinct_seen).override_failure_message("no extinction shown: the widest text was not tried").is_true()
	assert_float(worst.x).is_less_equal(GameView.BASE_SIZE.x)
	assert_float(worst.y).is_less_equal(GameView.BASE_SIZE.y)


func test_goals_window_lists_everything_to_win() -> void:
	var view := _open()
	assert_str(view.decision_text()).contains("Goals")
	assert_str(view.goals_window_text()).is_empty()
	view.show_goals()
	var text := view.goals_window_text()
	assert_str(text).contains("Mature planet")
	for ambition: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(GoalTracker.DEFAULT_PATH))["ambitions"]:
		assert_str(text).contains(ambition["name"])


func test_goals_button_waits_for_a_planet() -> void:
	var view := _open_without_options()
	view.show_goals()
	assert_str(view.goals_window_text()).is_empty()


func test_window_has_no_per_species_effect_lines() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	view.start()
	_to_decision(view)
	assert_str(_all_text(view)).not_contains("The rest of the planet").not_contains("impact:")


## Every label and rich text under the node, joined.
func _all_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text + "
"
	elif node is RichTextLabel:
		text += (node as RichTextLabel).get_parsed_text() + "
"
	for child in node.get_children():
		text += _all_text(child)
	return text


func test_the_globe_follows_the_planet_and_charts_wait_behind_a_button() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	var look := view.planet_look()
	assert_float(look["bacteria"]).is_greater(0.0)
	assert_bool(view.charts_visible()).is_false()
	view.show_charts()
	assert_bool(view.charts_visible()).is_true()


const OLD_SAVE := "user://game_view_test/old_save.json"


## A save as the game wrote it before the Spark shop existed: no state of the perks system.
func _write_old_save() -> void:
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--seed", "13", "--save", OLD_SAVE])).value
	options["file_logs"] = false
	var created := GameSession.create(options, func(_line: String) -> void: pass)
	assert_bool(created.is_ok()).is_true()
	var game: GameSession = created.value
	assert_bool(game.save().is_ok()).is_true()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OLD_SAVE))
	assert_bool((data["systems"] as Dictionary).erase("perks")).is_true()
	var file := FileAccess.open(OLD_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func test_an_old_save_gives_a_friendly_message_and_the_new_game_screen() -> void:
	_write_old_save()
	var view := _open(["--load", OLD_SAVE])
	assert_object(view.session).is_null()
	assert_str(view.error_text()).contains("Could not load the save").contains("Start a new game")
	# The technical reason follows for whoever reports it.
	assert_str(view.error_text()).contains("perks")
	# The player can start over without restarting the application.
	assert_str(view.decision_text()).contains("new planet")
	view.choose_planet("13", 1)
	view.new_game()
	assert_object(view.session).is_not_null()
	assert_str(view.error_text()).is_empty()
	assert_str(view.decision_text()).contains("Welcome to Genesis Error")


func test_an_old_save_chosen_on_the_new_game_screen_keeps_that_screen() -> void:
	_write_old_save()
	var view := _open_without_options()
	view.open_game(PlaySession.parse_args(PackedStringArray(["--load", OLD_SAVE])).value)
	assert_object(view.session).is_null()
	assert_str(view.error_text()).contains("Could not load the save")
	view.choose_planet("42")
	view.new_game()
	assert_int(view.session.manager.config().seed()).is_equal(42)
	assert_str(view.error_text()).is_empty()


func test_a_missing_save_is_reported_the_same_friendly_way() -> void:
	var view := _open_without_options()
	view.open_game(PlaySession.parse_args(PackedStringArray(["--load", "user://game_view_test/none.json"])).value)
	assert_str(view.error_text()).contains("Could not load the save").contains("none.json")
	assert_object(view.session).is_null()


func test_the_top_bar_shows_the_date_not_the_tick() -> void:
	var view := _open()
	view.start()
	view.advance(50)
	assert_str(view.info_text()).contains("Year 1, February")
	assert_str(view.info_text()).not_contains("tick")


func test_the_window_chronicle_shows_dates_not_ticks() -> void:
	var view := _open()
	view.start()
	_to_decision(view)
	assert_str(view.chronicle_text()).not_contains("[Tick")


func test_the_new_game_screen_is_a_card_over_the_globe() -> void:
	var view := _open_without_options()
	assert_bool(view.card().is_open()).is_true()
	assert_str(view.card().title_text()).contains("new planet")
	view.choose_planet("13")
	view.new_game()
	# The new planet starts with its welcome card.
	assert_str(view.card().title_text()).contains("Welcome")
	assert_str(view.card().body_text()).contains("Creator")
