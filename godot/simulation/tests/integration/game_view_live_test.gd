extends GdUnitTestSuite
## The window in live mode (the default): the planet never stops at decision
## points, Spark bubbles lie on the globe, the perk shop sits on the right and
## actions work while the planet runs. Ticks are driven through
## GameView.advance, not real time.

const SAVE := "user://game_view_live_test/decision.json"

var _view: GameView
var _panel: PerkPanel


## Seed 42: bacteria emerge at tick 130, a discovery bubble worth 4 Sparks.
func _open(args: Array = ["--seed", "42"]) -> GameView:
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
	if _panel != null:
		_panel.queue_free()
		_panel = null


## Plays until at least one bubble lies on the globe (or the limit).
func _to_bubble(view: GameView, limit: int = 20000) -> void:
	var done := 0
	while view.session.bubbles.bubbles().is_empty() and done < limit:
		view.advance(10)
		done += 10


## Collects every bubble seen while playing until the Sparks reach `goal`.
func _earn(view: GameView, goal: int, limit: int = 20000) -> void:
	var done := 0
	while view.session.sparks() < goal and done < limit:
		view.advance(10)
		done += 10
		for bubble: Dictionary in view.session.bubbles.bubbles():
			view.collect_bubble(bubble["id"])


func _fund(view: GameView, amount: int) -> void:
	assert_bool(view.session.manager.submit(PerkSystem.ID, PerkSystem.ACTION_GRANT, {"amount": amount, "source": "test"}).is_ok()).is_true()
	view.advance(2)


func test_live_game_does_not_stop_at_decision_points() -> void:
	var view := _open()
	view.start()
	view.advance(2000)
	assert_bool(view.at_decision()).is_false()
	assert_str(view.decision_text()).contains("Planeta żyje")
	assert_int(view.session.tick()).is_equal(2000)


func test_collecting_a_bubble_raises_the_sparks_label() -> void:
	var view := _open()
	view.start()
	assert_str(view.sparks_text()).is_equal("Iskry: 0")
	_to_bubble(view)
	var bubbles := view.session.bubbles.bubbles()
	assert_array(bubbles).is_not_empty()
	var collected := view.collect_bubble(bubbles[0]["id"])
	assert_bool(collected.is_ok()).is_true()
	view.advance(2)
	assert_str(view.sparks_text()).is_equal("Iskry: %d" % int(collected.value))
	assert_int(view.session.sparks()).is_greater_equal(1)


func test_pressing_a_bubble_on_the_globe_reaches_the_sparks() -> void:
	var view := _open()
	view.start()
	_to_bubble(view)
	var id: int = view.session.bubbles.bubbles()[0]["id"]
	view.bubble_layer().press(id)
	view.advance(2)
	assert_int(view.session.sparks()).is_greater_equal(1)
	assert_str(view.sparks_text()).is_not_equal("Iskry: 0")
	assert_array(view.session.bubbles.bubbles().filter(func(b: Dictionary) -> bool: return b["id"] == id)).is_empty()


func test_first_perk_is_affordable_before_tick_600_for_a_perfect_player() -> void:
	var view := _open()
	view.start()
	_earn(view, 4)
	assert_int(view.session.sparks()).is_greater_equal(4)
	var bought := view.buy_perk("perk_hardy")
	assert_array(Array(bought.errors)).is_empty()
	view.advance(2)
	assert_int(view.session.tick()).is_less_equal(600)
	var owned := view.session.perk_rows().filter(func(row: Dictionary) -> bool: return row["id"] == "perk_hardy")
	assert_bool(owned[0]["owned"]).is_true()
	assert_str(view.chronicle_text()).contains("Zrobione: Wytrzymałość.")


func test_perk_panel_buy_button_follows_the_sparks() -> void:
	var view := _open()
	view.start()
	view.advance(2)
	assert_bool(view.perk_panel().buy_button("perk_hardy").disabled).is_true()
	_fund(view, 4)
	assert_bool(view.perk_panel().buy_button("perk_hardy").disabled).is_false()
	# The tree is respected: a perk behind another stays shut however rich the player is.
	_fund(view, 20)
	assert_bool(view.perk_panel().buy_button("perk_fast_growth").disabled).is_true()
	assert_str(view.perk_panel().row_text("perk_fast_growth")).contains("wymaga: Wytrzymałość")


func test_refunding_a_perk_through_the_panel_returns_sparks() -> void:
	var view := _open()
	view.start()
	_fund(view, 4)
	view.buy_perk("perk_hardy")
	view.advance(2)
	var before := view.session.sparks()
	assert_str(view.perk_panel().buy_button("perk_hardy").text).starts_with("Cofnij (+")
	view.perk_panel().press("perk_hardy")
	view.advance(2)
	assert_int(view.session.sparks()).is_greater(before)
	assert_str(view.chronicle_text()).contains("Zrobione: Wytrzymałość.")
	assert_str(view.perk_panel().buy_button("perk_hardy").text).is_equal("Kup")


func test_locked_action_button_names_the_perk() -> void:
	var view := _open()
	view.start()
	view.advance(2)
	assert_str(view.action_text("mirrors_warm")).contains("wymaga")
	assert_str(view.action_text("mirrors_warm")).contains("Lustra orbitalne")
	assert_bool(view.action_button("mirrors_warm").disabled).is_true()
	assert_str(view.action_button("mirrors_warm").tooltip_text).contains("Lustra orbitalne")
	_fund(view, 8)
	assert_bool(view.buy_perk("perk_mirrors_warm").is_ok()).is_true()
	view.advance(2)
	assert_str(view.action_text("mirrors_warm")).not_contains("wymaga")
	assert_bool(view.action_button("mirrors_warm").disabled).is_false()


func test_actions_are_allowed_while_the_planet_runs_in_live_mode() -> void:
	var view := _open()
	view.start()
	view.advance(20)
	var done := view.act("seed_species")
	assert_array(Array(done.errors)).is_empty()
	assert_str(view.chronicle_text()).contains("Zrobione: Zasiew gatunku")


func test_pausing_does_not_age_bubbles() -> void:
	var view := _open()
	view.start()
	_to_bubble(view)
	view.toggle_pause()
	view._process(20.0)
	assert_array(view.session.bubbles.bubbles()).is_not_empty()


func test_a_running_planet_ages_bubbles_in_real_seconds() -> void:
	var view := _open()
	view.start()
	_to_bubble(view)
	var old: int = view.session.bubbles.bubbles()[0]["id"]
	view._process(20.0)
	var still := view.session.bubbles.bubbles().filter(func(b: Dictionary) -> bool: return b["id"] == old)
	assert_array(still).is_empty()


func test_default_speed_is_x25_and_x50_is_offered() -> void:
	assert_int(GameView.DEFAULT_SPEED).is_equal(25)
	assert_array(GameView.SPEEDS).is_equal([5, 10, 25, 50, 100])
	var view := _open()
	assert_int(view.session.manager.scheduler().speed()).is_equal(25)


func test_live_intro_names_the_creator() -> void:
	var view := _open()
	assert_bool(view.at_decision()).is_true()
	assert_str(view.decision_text()).contains("Creator")
	assert_str(view.decision_text()).contains("Praktykant")
	assert_str(view.decision_text()).contains("„Cele”")


## A live game has no decision points, so its trends count from the start.
func test_live_trend_headers_count_from_the_start_of_the_game() -> void:
	var view := _open()
	for title in view.trend_titles():
		assert_str(title).contains("od początku gry").not_contains("decyzji")


func test_running_text_does_not_promise_a_stop() -> void:
	var view := _open()
	view.start()
	assert_str(view.decision_text()).not_contains("sama się zatrzyma")


func test_new_warnings_reach_the_chronicle_once() -> void:
	var view := _open()
	view.start()
	view.session.warnings.append("Autozapis się nie udał: test")
	view.advance(1)
	view.advance(1)
	var text := view.chronicle_text()
	assert_str(text).contains("UWAGA: Autozapis się nie udał: test")
	assert_int(text.split("Autozapis się nie udał: test").size()).is_equal(2)


func test_perk_panel_shows_both_trees_with_cost_and_state() -> void:
	_panel = PerkPanel.new()
	add_child(_panel)
	var rows: Array[Dictionary] = [
		{"id": "a", "name": "Alfa", "help": "Pomaga.", "tree": "environment", "cost": 5, "owned": false, "affordable": true,
				"available": true, "missing": [], "side_effect": "Boli.", "refund": 3},
		{"id": "b", "name": "Beta", "help": "Też.", "tree": "life", "cost": 9, "owned": false, "affordable": false,
				"available": true, "missing": [], "side_effect": "", "refund": 6},
		{"id": "c", "name": "Gamma", "help": "Trzeci.", "tree": "life", "cost": 2, "owned": true, "affordable": true,
				"available": true, "missing": [], "side_effect": "", "refund": 1},
		{"id": "d", "name": "Delta", "help": "Czwarty.", "tree": "life", "cost": 1, "owned": false, "affordable": true,
				"available": false, "missing": ["Beta"], "side_effect": "", "refund": 0},
	]
	_panel.refresh(rows, 6)
	assert_str(_panel.row_text("a")).contains("Alfa").contains("5")
	assert_bool(_panel.buy_button("a").disabled).is_false()
	assert_bool(_panel.buy_button("b").disabled).is_true()
	assert_str(_panel.buy_button("c").text).is_equal("Cofnij (+1)")
	assert_bool(_panel.buy_button("c").disabled).is_false()
	assert_bool(_panel.buy_button("d").disabled).is_true()
	assert_str(_panel.row_text("d")).contains("wymaga: Beta")
	assert_str(_panel.buy_button("a").tooltip_text).contains("Pomaga.").contains("Boli.")
	assert_array(_panel.headers()).is_equal(["Środowisko", "Życie"])
	# The balance changes the buttons, not the rows.
	var rich: Array[Dictionary] = []
	for row in rows:
		rich.append(row.merged({"affordable": true}, true))
	_panel.refresh(rich, 20)
	assert_bool(_panel.buy_button("b").disabled).is_false()


func test_perk_panel_presses_ask_to_buy_or_refund() -> void:
	_panel = PerkPanel.new()
	add_child(_panel)
	var rows: Array[Dictionary] = [
		{"id": "a", "name": "Alfa", "help": "", "tree": "life", "cost": 5, "owned": false, "affordable": true,
				"available": true, "missing": [], "side_effect": "", "refund": 3},
		{"id": "c", "name": "Gamma", "help": "", "tree": "life", "cost": 2, "owned": true, "affordable": true,
				"available": true, "missing": [], "side_effect": "", "refund": 1},
	]
	_panel.refresh(rows, 6)
	monitor_signals(_panel)
	_panel.press("a")
	await assert_signal(_panel).is_emitted("buy_requested", ["a"])
	_panel.press("c")
	await assert_signal(_panel).is_emitted("refund_requested", ["c"])


## A live game never reaches a decision point, so the tracker's news (the
## ambition below is real: a tree population above 10) must reach the chronicle
## from advance().
func test_live_goal_news_reaches_the_chronicle() -> void:
	var view := _open()
	view.start()
	view.advance(5)
	assert_str(view.chronicle_text()).not_contains("Ambicja zdobyta")
	var biosphere := view.session.manager.system(BiosphereSystem.ID) as BiosphereSystem
	biosphere.set_population(&"tree", 50.0)
	view.advance(5)
	assert_str(view.chronicle_text()).contains("Ambicja zdobyta: Pierwszy las")
	assert_bool(view.at_decision()).is_false()
	# Said once: the news were taken from the tracker.
	view.advance(5)
	assert_int(view.chronicle_text().split("Ambicja zdobyta: Pierwszy las").size()).is_equal(2)


## The bubbles of the window spawn where the globe faces the player.
func test_live_bubbles_spawn_in_view_of_the_player() -> void:
	var view := _open()
	view.start()
	# Six bubbles (they only age while the window runs in real time): by chance
	# all six would be on the near side of a globe less than once in a thousand.
	var done := 0
	while view.session.bubbles.bubbles().size() < 6 and done < 20000:
		view.advance(10)
		done += 10
	var shown := view.session.bubbles.bubbles()
	assert_int(shown.size()).is_greater_equal(6)
	for bubble: Dictionary in shown:
		assert_object(view.planet().screen_point(bubble["lat"], bubble["lon"])).is_not_null()


## A bubble collected in a pause waits for the next tick; the label says so.
func test_pending_sparks_show_in_the_label_during_a_pause() -> void:
	var view := _open()
	view.start()
	_to_bubble(view)
	view.toggle_pause()
	var id: int = view.session.bubbles.bubbles()[0]["id"]
	var collected := view.collect_bubble(id)
	assert_bool(collected.is_ok()).is_true()
	var sparks := int(collected.value)
	assert_int(view.session.pending_sparks()).is_equal(sparks)
	assert_str(view.sparks_text()).is_equal("Iskry: 0 (+%d)" % sparks)
	view.advance(2)
	assert_int(view.session.pending_sparks()).is_equal(0)
	assert_str(view.sparks_text()).is_equal("Iskry: %d" % sparks)


## Closing the window saves a live game that has begun, so no bubble is a reason not to quit.
func test_closing_the_window_saves_a_live_game() -> void:
	var view := _open()
	view.start()
	view.advance(30)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	view._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_bool(FileAccess.file_exists(SAVE)).is_true()


## A new game that never ran must not overwrite the player's last save.
func test_closing_the_window_before_the_first_tick_saves_nothing() -> void:
	var view := _open()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	view._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_bool(FileAccess.file_exists(SAVE)).is_false()
