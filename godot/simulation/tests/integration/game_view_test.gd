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
	view.set_speed(1000)
	assert_int(view.session.manager.scheduler().speed()).is_equal(1000)
	view.set_speed(7)
	assert_int(view.session.manager.scheduler().speed()).is_equal(1000)


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
