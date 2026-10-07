extends GdUnitTestSuite
## How a game ends: the victory card, the "time is up" card, and that each
## shows once, also across a save and a load.

const SAVE := "user://game_ending_test/decision.json"

var _view: GameView


func _open(live_options: Dictionary = {}) -> GameView:
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--seed", "13", "--save", SAVE])).value
	options["file_logs"] = false
	options.merge(live_options, true)
	_view = GameView.new()
	_view.options = options
	add_child(_view)
	return _view


func after_test() -> void:
	if _view != null:
		_view.queue_free()
		_view = null


## A game that has won, as if the goal had been reached at `tick`.
func _win(view: GameView, tick: int = 500) -> void:
	view.session.goals.load_state({"victory": {"tick": tick, "stars": ["no_losses", "fast"]}})


func _session(game_years: int = GameSession.GAME_YEARS) -> GameSession:
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--seed", "13", "--save", SAVE])).value
	options["file_logs"] = false
	options["live"] = true
	var created := GameSession.create(options, func(_line: String) -> void: pass)
	assert_array(Array(created.errors)).is_empty()
	var game: GameSession = created.value
	game.game_years = game_years
	return game


func test_the_game_is_open_until_it_is_won_or_the_years_run_out() -> void:
	var game := _session()
	assert_str(game.outcome()).is_empty()


func test_outcome_is_won_when_the_goal_is_reached() -> void:
	var game := _session()
	game.goals.load_state({"victory": {"tick": 500, "stars": []}})
	assert_str(game.outcome()).is_equal("won")


func test_outcome_is_timeup_when_the_years_run_out() -> void:
	var game := _session(1)
	game.begin_round()
	game.step(GameCalendar.TICKS_PER_YEAR - 1)
	assert_str(game.outcome()).is_empty()
	game.step(1)
	assert_str(game.outcome()).is_equal("timeup")


func test_a_win_beats_the_end_of_time_in_the_same_tick() -> void:
	var game := _session(1)
	game.begin_round()
	game.step(GameCalendar.TICKS_PER_YEAR)
	game.goals.load_state({"victory": {"tick": 360, "stars": []}})
	assert_str(game.outcome()).is_equal("won")


func test_summary_counts_what_the_player_did() -> void:
	var game := _session()
	var summary := game.summary()
	assert_int(summary["total"]).is_equal(8)
	assert_int(summary["alive"]).is_equal(0)
	assert_int(summary["perks"]).is_equal(0)
	assert_int(summary["bubbles"]).is_equal(0)
	assert_str(summary["date"]).is_equal("Year 1, January")


func test_ending_seen_survives_save_and_load() -> void:
	var game := _session()
	game.ending_seen = true
	assert_bool(game.save().is_ok()).is_true()
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--load", SAVE, "--save", SAVE])).value
	options["file_logs"] = false
	options["live"] = true
	var loaded: GameSession = GameSession.create(options, func(_line: String) -> void: pass).value
	assert_bool(loaded.ending_seen).is_true()


func test_a_loaded_game_without_the_flag_has_not_seen_its_ending() -> void:
	var game := _session()
	assert_bool(game.ending_seen).is_false()


func test_window_shows_the_congratulations_card_on_victory() -> void:
	var view := _open()
	view.card().press("start")
	_win(view)
	view.advance(10)
	assert_bool(view.card().is_open()).is_true()
	assert_str(view.card().title_text()).contains("Congratulations")
	assert_str(view.card().body_text()).contains("Mature planet").contains("Year 1")
	assert_array(view.card().button_labels()).is_equal(["Keep playing", "New planet"])
	assert_bool(view.at_decision()).is_true()


func test_the_card_shows_once_and_keep_playing_resumes() -> void:
	var view := _open()
	view.card().press("start")
	_win(view)
	view.advance(10)
	var tick := view.session.tick()
	# Real time no longer moves the planet while the card waits.
	view._process(5.0)
	assert_int(view.session.tick()).is_equal(tick)
	view.card().press("continue")
	assert_bool(view.card().is_open()).is_false()
	assert_bool(view.at_decision()).is_false()
	view.advance(10)
	assert_int(view.session.tick()).is_greater(tick)
	assert_bool(view.card().is_open()).is_false()
	assert_bool(view.session.ending_seen).is_true()


func test_time_up_card_text() -> void:
	var view := _open()
	view.card().press("start")
	view.session.game_years = 1
	view.advance(GameCalendar.TICKS_PER_YEAR + 10)
	assert_bool(view.card().is_open()).is_true()
	assert_str(view.card().title_text()).contains("Time")
	assert_str(view.card().body_text()).contains("years are over")


func test_the_new_planet_button_opens_the_new_game_screen() -> void:
	var view := _open()
	view.card().press("start")
	_win(view)
	view.advance(10)
	view.card().press("new")
	assert_str(view.card().title_text()).contains("new planet")
	assert_bool(view.session.ending_seen).is_true()
