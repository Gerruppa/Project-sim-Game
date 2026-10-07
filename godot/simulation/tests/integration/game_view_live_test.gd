extends GdUnitTestSuite
## The window in live mode (the default): the planet never stops at decision
## points, Spark bubbles lie on the globe, the perk shop sits on the right and
## actions work while the planet runs. Ticks are driven through
## GameView.advance, not real time.

const SAVE := "user://game_view_live_test/decision.json"

var _view: GameView


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
	# Species emerging stop nothing; only a first-time crisis warning pauses, with a card.
	assert_bool(view.session.decision_point() == null).is_true()
	if view.card().is_open():
		assert_str(view.card().title_text()).contains("Warning")
		view.card().press("ok")
	assert_bool(view.at_decision()).is_false()
	assert_str(view.decision_text()).contains("The planet lives")
	assert_int(view.session.tick()).is_equal(2000)


func test_collecting_a_bubble_raises_the_sparks_label() -> void:
	var view := _open()
	view.start()
	assert_str(view.sparks_text()).is_equal("Sparks: 3")
	_to_bubble(view)
	var bubbles := view.session.bubbles.bubbles()
	assert_array(bubbles).is_not_empty()
	var collected := view.collect_bubble(bubbles[0]["id"])
	assert_bool(collected.is_ok()).is_true()
	view.advance(2)
	assert_str(view.sparks_text()).is_equal("Sparks: %d" % (3 + int(collected.value)))
	assert_int(view.session.sparks()).is_greater_equal(1)


func test_pressing_a_bubble_on_the_globe_reaches_the_sparks() -> void:
	var view := _open()
	view.start()
	_to_bubble(view)
	var id: int = view.session.bubbles.bubbles()[0]["id"]
	view.bubble_layer().press(id)
	view.advance(2)
	assert_int(view.session.sparks()).is_greater_equal(1)
	assert_str(view.sparks_text()).is_not_equal("Sparks: 3")
	assert_array(view.session.bubbles.bubbles().filter(func(b: Dictionary) -> bool: return b["id"] == id)).is_empty()


func test_first_perk_is_affordable_before_tick_600_for_a_perfect_player() -> void:
	var view := _open()
	view.start()
	_earn(view, 4)
	assert_int(view.session.sparks()).is_greater_equal(4)
	var bought := view.buy_perk("res_hardy_1")
	assert_array(Array(bought.errors)).is_empty()
	view.advance(2)
	assert_int(view.session.tick()).is_less_equal(600)
	var owned := view.session.perk_rows().filter(func(row: Dictionary) -> bool: return row["id"] == "res_hardy_1")
	assert_bool(owned[0]["owned"]).is_true()
	assert_str(view.chronicle_text()).contains("Done: Hardiness I.")


func test_locked_action_button_names_the_perk() -> void:
	var view := _open()
	view.start()
	view.advance(2)
	assert_str(view.action_text("mirrors_warm")).contains("needs")
	assert_str(view.action_text("mirrors_warm")).contains("Orbital mirrors")
	assert_bool(view.action_button("mirrors_warm").disabled).is_true()
	assert_str(view.action_button("mirrors_warm").tooltip_text).contains("Orbital mirrors")
	_fund(view, 8)
	assert_bool(view.buy_perk("perk_mirrors_warm").is_ok()).is_true()
	view.advance(2)
	assert_str(view.action_text("mirrors_warm")).not_contains("needs")
	assert_bool(view.action_button("mirrors_warm").disabled).is_false()


func test_actions_are_allowed_while_the_planet_runs_in_live_mode() -> void:
	var view := _open()
	view.start()
	view.advance(20)
	var done := view.plant("bacteria")
	assert_array(Array(done.errors)).is_empty()
	assert_str(view.chronicle_text()).contains("Done: Seed a species")


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
	assert_str(view.decision_text()).contains("Apprentice")
	assert_str(view.decision_text()).contains("Goals")


## A live game has no decision points, so its trends count from the start.
func test_live_trend_headers_count_from_the_start_of_the_game() -> void:
	var view := _open()
	assert_array(view.trend_titles()).is_equal(["Planet", "Life (population 0-100)"])


func test_running_text_does_not_promise_a_stop() -> void:
	var view := _open()
	view.start()
	assert_str(view.decision_text()).not_contains("stops by itself")


func test_new_warnings_reach_the_chronicle_once() -> void:
	var view := _open()
	view.start()
	view.session.warnings.append("Autosave failed: test")
	view.advance(1)
	view.advance(1)
	var text := view.chronicle_text()
	assert_str(text).contains("WARNING: Autosave failed: test")
	assert_int(text.split("Autosave failed: test").size()).is_equal(2)


## A live game never reaches a decision point, so the tracker's news (the
## ambition below is real: a tree population above 10) must reach the chronicle
## from advance().
func test_live_goal_news_reaches_the_chronicle() -> void:
	var view := _open()
	view.start()
	view.advance(5)
	assert_str(view.chronicle_text()).not_contains("Ambition reached")
	var biosphere := view.session.manager.system(BiosphereSystem.ID) as BiosphereSystem
	biosphere.set_population(&"tree", 50.0)
	view.advance(5)
	assert_str(view.chronicle_text()).contains("Ambition reached: First forest")
	assert_bool(view.at_decision()).is_false()
	# Said once: the news were taken from the tracker.
	view.advance(5)
	assert_int(view.chronicle_text().split("Ambition reached: First forest").size()).is_equal(2)


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
	assert_str(view.sparks_text()).is_equal("Sparks: 3 (+%d)" % sparks)
	view.advance(2)
	assert_int(view.session.pending_sparks()).is_equal(0)
	assert_str(view.sparks_text()).is_equal("Sparks: %d" % (3 + sparks))


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


func test_live_game_hides_the_bottom_console() -> void:
	var view := _open()
	view.start()
	assert_bool(view.console_visible()).is_false()


func test_intro_uses_the_card_over_the_globe() -> void:
	var view := _open()
	assert_bool(view.card().is_open()).is_true()
	assert_str(view.card().title_text()).contains("Welcome")
	assert_array(view.card().button_labels()).is_equal(["Start ▶"])
	view.card().press("start")
	assert_bool(view.card().is_open()).is_false()
	assert_str(view.decision_text()).contains("The planet lives")


func test_chronicle_floats_over_the_globe() -> void:
	var view := _open()
	view.start()
	view.advance(200)
	assert_bool(view.chronicle_overlay().get_parent() == view.planet()).is_true()
	assert_str(view.chronicle_text()).contains("Year 1")


func test_the_card_fits_the_minimum_window() -> void:
	var view := _open()
	await await_idle_frame()
	var needed := view.card().get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(GameView.MIN_WINDOW.x)
	assert_float(needed.y).is_less_equal(GameView.MIN_WINDOW.y)


func test_species_panel_lists_every_species_with_a_verdict() -> void:
	var view := _open()
	view.start()
	view.advance(50)
	var panel := view.species_panel()
	for id: String in ["bacteria", "algae", "moss", "shrub", "tree"]:
		assert_str(panel.row_text(id)).is_not_empty()
	assert_str(panel.row_text("shrub")).contains("Waiting")
	assert_str(panel.row_tooltip("shrub")).contains("Waiting for moss")
	assert_str(panel.row_tooltip("bacteria")).contains("Temperature")


func test_plant_button_seeds_the_species() -> void:
	var view := _open()
	view.start()
	view.advance(400)
	var done := view.plant("bacteria")
	assert_bool(done.is_ok()).is_true()
	assert_str(view.chronicle_text()).contains("Done: Seed a species (bacteria)")
	assert_bool(view.species_panel().plant_button("bacteria").disabled).is_true()


func test_plant_button_asks_through_a_signal() -> void:
	var panel := SpeciesPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.refresh([{"id": "moss", "name": "moss", "verdict": &"ideal", "label": "Ideal conditions", "short": "Ideal",
			"needs": [], "verb": "Plant", "ready": true, "alive": false, "why": "", "fit": 1.0}])
	monitor_signals(panel)
	panel.press("moss")
	await assert_signal(panel).is_emitted("plant_requested", ["moss"])


func _warn(view: GameView, id: String, name: String) -> void:
	view.session.manager.event_bus().publish(SimEvent.new(EventSystem.WARNED_EVENT, view.session.tick(), &"events",
			{"id": id, "name": name, "story": "%s is coming." % name, "counters": ["perk_mirrors_warm"]}))
	view.session.manager.event_bus().flush()


func test_the_first_warning_of_a_kind_pauses_with_a_card() -> void:
	var view := _open()
	view.card().press("start")
	_warn(view, "ice_age", "Ice age")
	view.advance(1)
	assert_bool(view.card().is_open()).is_true()
	assert_str(view.card().title_text()).contains("Warning").contains("Ice age")
	assert_str(view.card().body_text()).contains("Ice age is coming.").contains("Orbital mirrors")
	assert_bool(view.at_decision()).is_true()
	view.card().press("ok")
	assert_bool(view.card().is_open()).is_false()
	assert_bool(view.at_decision()).is_false()


func test_the_second_warning_of_the_same_kind_does_not_stop_the_game() -> void:
	var view := _open()
	view.card().press("start")
	_warn(view, "ice_age", "Ice age")
	view.advance(1)
	view.card().press("ok")
	_warn(view, "ice_age", "Ice age")
	view.advance(1)
	assert_bool(view.card().is_open()).is_false()
	assert_bool(view.at_decision()).is_false()
	assert_str(view.chronicle_text()).contains("Ice age is coming.")


func test_the_threat_strip_follows_the_planet() -> void:
	var view := _open(["--seed", "1", "--personality", "harmonious"])
	view.card().press("start")
	var done := 0
	while view.session.threats().is_empty() and done < 4000:
		view.advance(50)
		if view.card().is_open():
			view.card().press("ok")
		done += 50
	assert_bool(view.session.threats().is_empty()).is_false()
	var threat: Dictionary = view.session.threats()[0]
	assert_str(view.threat_strip().row_text(threat["id"])).contains(threat["name"])


func test_path_bar_shows_the_next_step_and_what_it_needs() -> void:
	var view := _open()
	view.card().press("start")
	view.advance(20)
	assert_str(view.path_bar().chip_state("bacteria")).is_equal("next")
	assert_str(view.path_bar().chip_state("tree")).is_equal("later")
	assert_str(view.path_bar().next_text()).starts_with("Next: bacteria")


func test_a_toast_welcomes_new_life_and_names_the_next_step() -> void:
	var view := _open()
	view.card().press("start")
	var done := 0
	while view.toast().current_text().is_empty() and done < 600:
		view.advance(10)
		done += 10
	assert_str(view.toast().current_text()).contains("bacteria").contains("Next: algae")
	assert_str(view.path_bar().chip_state("bacteria")).is_equal("alive")


func test_the_top_bar_shows_the_cheapest_perk_in_reach() -> void:
	var view := _open()
	view.card().press("start")
	view.advance(2)
	assert_str(view.next_perk_text()).contains("Hardiness I").contains("4")


func test_collecting_a_bubble_shows_the_gain_where_it_was() -> void:
	var view := _open()
	view.start()
	_to_bubble(view)
	var bubble: Dictionary = view.session.bubbles.bubbles()[0]
	view.bubble_layer().refresh()
	var collected := view.collect_bubble(bubble["id"])
	assert_bool(collected.is_ok()).is_true()
	assert_array(Array(view.bubble_layer().floaters())).is_equal(["+%d ✦" % int(collected.value)])


func test_a_new_game_starts_with_the_first_sparks() -> void:
	var view := _open()
	assert_str(view.sparks_text()).is_equal("Sparks: 3")
	assert_str(view.card().body_text()).contains("first perk")


func _fund_and_settle(view: GameView, amount: int) -> void:
	view.session.manager.submit(PerkSystem.ID, PerkSystem.ACTION_GRANT, {"amount": amount, "source": "test"})
	view.advance(2)


func test_the_perks_button_counts_what_can_be_bought() -> void:
	var view := _open()
	view.card().press("start")
	view.advance(2)
	assert_str(view.perks_button_text()).is_equal("Perks ✦")
	_fund_and_settle(view, 20)
	assert_str(view.perks_button_text()).starts_with("Perks ✦ (").contains("to buy")


func test_opening_the_perk_window_pauses_and_closing_resumes() -> void:
	var view := _open()
	view.card().press("start")
	view.advance(2)
	assert_bool(view.perks_open()).is_false()
	view.open_perks()
	assert_bool(view.perks_open()).is_true()
	assert_bool(view.perk_window().is_open()).is_true()
	var tick := view.session.tick()
	view._process(5.0)
	assert_int(view.session.tick()).is_equal(tick)
	view.close_perks()
	assert_bool(view.perks_open()).is_false()
	view._process(1.0)
	assert_int(view.session.tick()).is_greater(tick)


func test_a_game_paused_by_the_player_stays_paused_after_the_window_closes() -> void:
	var view := _open()
	view.card().press("start")
	view.advance(2)
	view.toggle_pause()
	view.open_perks()
	view.close_perks()
	var tick := view.session.tick()
	view._process(5.0)
	assert_int(view.session.tick()).is_equal(tick)


func test_bubbles_do_not_age_while_the_window_is_open() -> void:
	var view := _open()
	view.card().press("start")
	_to_bubble(view)
	var before: float = view.session.bubbles.bubbles()[0]["age"]
	view.open_perks()
	view._process(5.0)
	assert_float(view.session.bubbles.bubbles()[0]["age"]).is_equal(before)


func test_buying_from_the_window_queues_the_perk_and_shows_it_waiting() -> void:
	var view := _open()
	view.card().press("start")
	_fund_and_settle(view, 20)
	view.open_perks()
	view.perk_window().select("res_hardy_1")
	view.perk_window().press_buy()
	assert_str(view.chronicle_text()).contains("Done: Hardiness I.")
	assert_str(view.perk_window().chip_state("res_hardy_1")).is_equal("queued")
	view.close_perks()
	view.advance(2)
	assert_bool(view.session.perks().owns(&"res_hardy_1")).is_true()


func test_the_p_key_toggles_the_perk_window() -> void:
	var view := _open()
	view.card().press("start")
	view.advance(2)
	var press := InputEventKey.new()
	press.keycode = KEY_P
	press.pressed = true
	view._unhandled_key_input(press)
	assert_bool(view.perks_open()).is_true()
	view._unhandled_key_input(press)
	assert_bool(view.perks_open()).is_false()


func test_the_perk_window_fits_the_minimum_window() -> void:
	var view := _open()
	view.card().press("start")
	view.open_perks()
	await await_idle_frame()
	var needed := view.perk_window().get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(GameView.MIN_WINDOW.x)
	assert_float(needed.y).is_less_equal(GameView.MIN_WINDOW.y)


func test_the_warning_card_can_open_the_perks_that_help() -> void:
	var view := _open()
	view.card().press("start")
	_warn(view, "ice_age", "Ice age")
	view.advance(1)
	assert_array(view.card().button_labels()).is_equal(["Got it", "Open perks"])
	view.card().press("perks")
	assert_bool(view.card().is_open()).is_false()
	assert_bool(view.perks_open()).is_true()
	assert_str(view.perk_window().selected_id()).is_equal("perk_mirrors_warm")


func test_the_path_bar_climbs_to_the_animals() -> void:
	var view := _open()
	view.card().press("start")
	view.advance(2)
	for id: String in ["bacteria", "algae", "moss", "shrub", "tree", "insects", "small_animals", "large_mammals"]:
		assert_str(view.path_bar().chip_state(id)).is_not_empty()
	assert_str(view.path_bar().chip_state("large_mammals")).is_equal("later")


func test_animals_are_released_not_planted() -> void:
	var view := _open()
	view.card().press("start")
	view.advance(2)
	assert_str(view.species_panel().plant_button("insects").text).is_equal("Release")
	assert_str(view.species_panel().plant_button("moss").text).is_equal("Plant")


func test_an_old_save_with_five_species_is_refused_with_a_friendly_message() -> void:
	var first := _open()
	first.card().press("start")
	first.advance(200)
	assert_bool(first.session.save().is_ok()).is_true()
	var path := first.session.save_path
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var biosphere: Dictionary = data["systems"]["biosphere"]
	biosphere["species"] = ["bacteria", "algae", "moss", "shrub", "tree"]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	first.queue_free()
	_view = null
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--load", path, "--save", path])).value
	options["file_logs"] = false
	var view := GameView.new()
	view.options = options
	add_child(view)
	_view = view
	assert_str(view.error_text()).contains("Could not load the save")
