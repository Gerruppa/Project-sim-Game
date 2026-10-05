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
	assert_str(text).contains("Witaj w Genesis Error.")
	assert_str(text).contains("=== Punkt decyzji: tick 130 (rok 1) ===")
	assert_str(text).contains("Co się stało:  Pojawiają się bakterie.")
	assert_str(text).contains("Planeta:\n  Temperatura ")
	assert_str(text).contains("Życie:\n  bakterie ")
	assert_str(text).contains("Podpowiedź:")
	assert_str(text).contains(" 1) Zasiew gatunku")
	assert_str(text).contains("Wróć do gry: ./godot/play.sh --load decision.json")
	assert_bool(FileAccess.file_exists(ProjectSettings.globalize_path(SAVE))).is_true()


func test_seeding_through_the_menu_queues_the_command() -> void:
	_session(["", "0", "1", "3"]).play()
	var text := _text()
	assert_str(text).contains("Który gatunek?")
	assert_str(text).contains("brakuje: tlenu")
	assert_str(text).contains("Zrobione: Zasiew gatunku (mchy).")


func test_levels_have_a_default_on_enter() -> void:
	_session(["", "4", ""]).play()
	assert_str(_text()).contains("Jak mocno?")
	assert_str(_text()).contains("Zrobione: Pył orbitalny (z pełną mocą).")


func test_menu_answers_unknown_input_help_and_hint_toggle() -> void:
	_session(["", "x", "?", "h", "q"]).play()
	var text := _text()
	assert_str(text).contains("Nie rozumiem „x”")
	assert_str(text).contains("Wody podziemne: Na 300 ticków ląd paruje")
	assert_str(text).contains("Podpowiedzi ukryte.")


func test_cooling_down_action_is_refused_with_its_ready_tick() -> void:
	_session(["", "3", "1", "", "3", "q"]).play()
	assert_str(_text()).contains("Lustra orbitalne jeszcze się odnawia: dostępne od ticku 1631.")


func test_waiting_runs_the_planet_to_the_next_decision() -> void:
	_session(["", "0", "q"]).play()
	assert_str(_text()).contains("=== Punkt decyzji: tick 333 (rok 1) ===")


func test_loaded_game_skips_the_intro() -> void:
	_session(["", "q"]).play()
	_create(PackedStringArray(["--load", SAVE, "--save", SAVE]), ["q"]).play()
	assert_str(_text()).not_contains("Witaj w Genesis Error.")
	assert_str(_text()).contains("=== Punkt decyzji: tick 333")


func test_hints_can_start_hidden() -> void:
	_session(["", "q"], {"hints": false}).play()
	assert_str(_text()).not_contains("Podpowiedź:")


func test_parses_play_options() -> void:
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--seed", "7", "--no-hints"])).value
	assert_int(options["seed"]).is_equal(7)
	assert_bool(options["hints"]).is_false()
	assert_bool(PlaySession.parse_args(PackedStringArray(["--load", "a.json", "--seed", "2"])).is_ok()).is_false()
	assert_bool(PlaySession.parse_args(PackedStringArray(["--fast"])).is_ok()).is_false()


func test_second_screen_shows_what_changed_since_the_first() -> void:
	_session(["", "0", "q"]).play()
	var text := _text()
	assert_str(text).contains("Planeta (zmiana od poprzedniej decyzji, 203 ticki temu):")
	assert_str(text).contains("↓ 9.5")
	assert_str(text).contains("glony            1   nowe")


func test_species_that_died_since_the_last_decision_is_marked() -> void:
	_session(["", "0", "1", "3", "", "q"]).play()
	assert_str(_text()).contains("mchy       WYMARŁE   wymarły od ostatniej decyzji")


func test_trend_shows_direction_and_hides_noise() -> void:
	assert_str(PlaySession.trend(9.46, 1)).is_equal("↑ 9.5")
	assert_str(PlaySession.trend(-0.6, 1)).is_equal("↓ 0.6")
	assert_str(PlaySession.trend(0.04, 1)).is_equal("=")
	assert_str(PlaySession.trend(-0.4, 0)).is_equal("=")
	assert_str(PlaySession.trend(23.2, 0)).is_equal("↑ 23")
