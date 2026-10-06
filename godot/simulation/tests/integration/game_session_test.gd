extends GdUnitTestSuite
## GameSession: the game as data, shared by the console and the window.

const SAVE := "user://game_session_test/decision.json"


func _session() -> GameSession:
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--seed", "13", "--save", SAVE])).value
	options["file_logs"] = false
	var created := GameSession.create(options, func(_line: String) -> void: pass)
	assert_array(Array(created.errors)).is_empty()
	return created.value


func test_steps_stop_at_the_decision_point() -> void:
	var game := _session()
	game.begin_round()
	var ran := game.step(100)
	assert_int(ran).is_equal(100)
	assert_bool(game.round_over()).is_false()
	game.step(10000)
	assert_bool(game.round_over()).is_true()
	assert_int(game.tick()).is_equal(130)
	assert_str(String(game.decision_point().type)).is_equal("species_emerged")
	assert_array(Array(game.decision_sentences())).is_equal(["Pojawiają się bakterie."])
	assert_int(game.step(100)).is_equal(0)


func test_trends_count_from_the_last_remembered_decision() -> void:
	var game := _session()
	game.begin_round()
	game.step(10000)
	assert_str(game.planet_rows()[0]["change"]).is_empty()
	game.remember()
	game.begin_round()
	game.step(10000)
	assert_bool((game.planet_rows()[0]["change"] as String).is_empty()).is_false()
	assert_int(game.last_tick()).is_equal(130)


func test_actions_report_readiness_and_submit_queues() -> void:
	var game := _session()
	game.begin_round()
	game.step(10000)
	var before: Dictionary = game.actions()[2]
	assert_str(before["id"]).is_equal("mirrors_warm")
	assert_bool(before["ready"]).is_true()
	assert_array(before["levels"]).has_size(3)
	assert_str(game.submit("mirrors_warm", {"level": "weak"}).value).is_equal("Lustra orbitalne (lekko)")
	var after: Dictionary = game.actions()[2]
	# Not applied yet: the cooldown starts when the command runs next tick,
	# but the same cooldown group cannot be queued twice meanwhile.
	assert_bool(after["ready"]).is_true()
	assert_str("\n".join(game.submit("mirrors_cool", {}).errors)).contains("już zaplanowane")
	assert_bool(game.submit("aquifer_release", {}).is_ok()).is_true()
	game.begin_round()
	game.step(1)
	assert_bool(game.actions()[2]["ready"]).is_false()
	assert_str("\n".join(game.submit("mirrors_cool", {}).errors)).contains("odnawia")


func test_species_choices_say_what_each_species_lacks() -> void:
	var game := _session()
	var choices := game.species_choices()
	assert_int(choices.size()).is_equal(5)
	assert_str(choices[2]["name"]).is_equal("mchy")
	assert_str(choices[2]["needs"]).starts_with("brakuje:")


# --- the player's units, zones and action timers ------------------------------

func _at_first_decision() -> GameSession:
	var game := _session()
	game.begin_round()
	game.step(10000)
	return game


func test_planet_rows_speak_the_players_units() -> void:
	var game := _at_first_decision()
	var temperature: Dictionary = game.planet_rows()[0]
	assert_str(temperature["id"]).is_equal("temperature")
	# The normalized value stays for the bars; the player reads degrees.
	assert_str(temperature["shown"]).is_equal(game.display.shown("temperature", temperature["value"]))
	assert_str(temperature["shown"]).ends_with(" °C")
	game.remember()
	game.begin_round()
	game.step(10000)
	var later: Dictionary = game.planet_rows()[0]
	# The change is the difference of the two shown temperatures, not of the 0-100 values.
	assert_str(later["change"]).is_equal(GameSession.trend(
			game.display.change("temperature", temperature["value"], later["value"]), 1))
	assert_str(later["name"]).is_equal("Średnia temperatura")


func test_rows_carry_the_life_zone() -> void:
	var game := _at_first_decision()
	var zones := {}
	for row in game.planet_rows():
		zones[row["id"]] = row["zone"]
	# Bacteria live at 5-70 degrees (the normalized 5-70) and need no CO2.
	assert_str(zones["temperature"]).is_not_empty()
	assert_str(zones["cloud_cover"]).is_equal("none")
	assert_str(zones["crust_oxidation"]).is_equal("none")


func test_actions_say_how_many_ticks_until_ready() -> void:
	var game := _at_first_decision()
	assert_int(game.actions()[2]["ready_in"]).is_equal(0)
	game.submit("mirrors_warm", {"level": "weak"})
	game.begin_round()
	game.step(1)
	var warm: Dictionary = game.actions()[2]
	assert_bool(warm["ready"]).is_false()
	# Used in tick 131, ready again 1500 ticks later (tick 1631), one tick of slack.
	assert_int(warm["ready_at"]).is_equal(1631)
	assert_int(warm["ready_in"]).is_equal(1631 - game.tick() - 1)
	game.manager.run_ticks(100)
	assert_int(game.actions()[2]["ready_in"]).is_equal(1631 - game.tick() - 1)


func test_seconds_text_rounds_up_and_shows_minutes() -> void:
	assert_str(GameSession.seconds_text(300, 100.0)).is_equal("3 s")
	assert_str(GameSession.seconds_text(301, 100.0)).is_equal("4 s")
	assert_str(GameSession.seconds_text(1, 1000.0)).is_equal("1 s")
	assert_str(GameSession.seconds_text(0, 10.0)).is_equal("0 s")
	assert_str(GameSession.seconds_text(2000, 1.0)).is_equal("33 min 20 s")
	assert_str(GameSession.seconds_text(60, 1.0)).is_equal("1 min 00 s")
	assert_str(GameSession.seconds_text(10, 0.0)).is_equal("–")


func test_a_timed_action_is_watched_while_it_runs_and_while_its_effect_shows() -> void:
	var game := _at_first_decision()
	assert_array(game.active_actions()).is_empty()
	game.submit("mirrors_cool", {"level": "weak"})
	var queued: Dictionary = game.active_actions()[0]
	assert_str(queued["phase"]).is_equal("queued")
	assert_str(queued["name"]).is_equal("Pył orbitalny")
	assert_str(queued["level_name"]).is_equal("lekko")
	game.begin_round()
	game.step(1)
	var started := game.tick()
	var running: Dictionary = game.active_actions()[0]
	assert_str(running["phase"]).is_equal("running")
	# Dust acts for 500 ticks, its effect usually shows for 1270-2600 ticks after the start.
	assert_int(running["remaining"]).is_equal(500)
	assert_int(running["fade_min"]).is_equal(1270)
	assert_int(running["fade_max"]).is_equal(2600)
	game.manager.run_ticks(200)
	var midway: Dictionary = game.active_actions()[0]
	assert_int(midway["remaining"]).is_equal(500 - (game.tick() - started))
	assert_int(midway["fade_max"]).is_equal(2600 - (game.tick() - started))
	assert_float(midway["progress"]).is_greater(0.0).is_less(0.2)
	game.manager.run_ticks(400)
	var after: Dictionary = game.active_actions()[0]
	assert_str(after["phase"]).is_equal("observe")
	assert_int(after["remaining"]).is_equal(0)
	assert_int(after["fade_max"]).is_greater(0)
	game.manager.run_ticks(2600)
	assert_array(game.active_actions()).is_empty()


func test_an_instant_action_without_a_measured_effect_is_not_watched() -> void:
	var game := _at_first_decision()
	game.submit("seed_species", {"species": "bacteria"})
	game.begin_round()
	game.step(1)
	assert_array(game.active_actions()).is_empty()


func test_a_game_loaded_in_the_middle_of_an_action_still_watches_it() -> void:
	var game := _at_first_decision()
	game.submit("mirrors_warm", {})
	game.begin_round()
	game.step(300)
	assert_bool(game.save().is_ok()).is_true()
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--load", SAVE])).value
	options["file_logs"] = false
	var loaded: GameSession = GameSession.create(options, func(_line: String) -> void: pass).value
	var rows := loaded.active_actions()
	assert_int(rows.size()).is_equal(1)
	assert_str(rows[0]["id"]).is_equal("mirrors_warm")
	assert_str(rows[0]["phase"]).is_equal("running")
	assert_int(rows[0]["remaining"]).is_equal(500 - (loaded.tick() - 131))



## Played to the n-th decision point; returns the planet values (0-100) of the
## decision before it, the start of the trends shown at the n-th.
func _play_to(game: GameSession, decisions: int) -> Dictionary:
	var before := {}
	for i in decisions:
		before.clear()
		for row in game.planet_rows():
			before[row["id"]] = row["value"]
		game.remember()
		game.begin_round()
		game.step(20000)
	return before


func test_species_effects_name_who_made_the_oxygen() -> void:
	var game := _session()
	_play_to(game, 6)
	var algae: Dictionary = game.life_rows().filter(func(row: Dictionary) -> bool: return row["id"] == "algae")[0]
	var oxygen: Array = (algae["effects"] as Array).filter(func(e: Dictionary) -> bool: return e["id"] == "oxygen")
	assert_array(oxygen).has_size(1)
	assert_float(oxygen[0]["change"]).is_greater(0.0)
	assert_str(oxygen[0]["shown"]).starts_with("+").ends_with(" % atmosfery")


## The shares of life, the player and the planet add up to the change the
## planet table shows (nothing saturated on this path).
func test_shares_add_up_to_the_change_since_the_last_decision() -> void:
	var game := _session()
	var before := _play_to(game, 6)
	var groups: Array = game.life_rows().map(func(row: Dictionary) -> Array: return row["effects"])
	groups.append_array(game.other_effects().map(func(row: Dictionary) -> Array: return row["effects"]))
	for param: String in ["oxygen", "co2"]:
		var total := 0.0
		for effects: Array in groups:
			for effect: Dictionary in effects:
				if effect["id"] == param:
					total += effect["change"]
		var now: float = game.planet_rows().filter(func(row: Dictionary) -> bool: return row["id"] == param)[0]["value"]
		var shown := game.display.change(param, before[param], now)
		assert_float(total).override_failure_message("%s: shares %f, change %f" % [param, total, shown]) \
				.is_equal_approx(shown, maxf(0.2, absf(shown) * 0.01))


func test_a_species_not_yet_here_shows_no_effect() -> void:
	var game := _session()
	_play_to(game, 1)
	var trees: Dictionary = game.life_rows().filter(func(row: Dictionary) -> bool: return row["id"] == "tree")[0]
	assert_array(trees["effects"]).is_empty()
