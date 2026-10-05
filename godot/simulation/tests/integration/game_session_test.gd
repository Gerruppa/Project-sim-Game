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
