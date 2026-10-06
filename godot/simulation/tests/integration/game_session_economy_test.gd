extends GdUnitTestSuite
## GameSession's economy: Sparks from bubbles, perks bought with them, actions
## locked until their perk is owned, and the live mode that never stops at a
## decision point.

const SAVE := "user://game_session_economy_test/decision.json"
const NOBODY_HOME := "user://game_session_economy_test/live_autosave.json"


func _session(live: bool = true, save: String = SAVE, load_save: bool = false) -> GameSession:
	var args := PackedStringArray(["--load", save, "--save", save]) if load_save else PackedStringArray(["--seed", "13", "--save", save])
	var options: Dictionary = PlaySession.parse_args(args).value
	options["file_logs"] = false
	options["live"] = live
	var created := GameSession.create(options, func(_line: String) -> void: pass)
	assert_array(Array(created.errors)).is_empty()
	return created.value


func _discovery(game: GameSession) -> int:
	game.bubbles.on_event(SimEvent.new(&"species_emerged", game.tick(), &"biosphere", {"species": "moss", "population": 1.0}))
	var found := game.bubbles.bubbles()
	assert_int(found.size()).is_equal(1)
	assert_str(found[0]["kind"]).is_equal("discovery")
	return found[0]["id"]


## Grants Sparks and waits for them to land (a buy is checked against the balance at submit time).
func _fund(game: GameSession, amount: int) -> void:
	assert_bool(game.manager.submit(PerkSystem.ID, PerkSystem.ACTION_GRANT, {"amount": amount, "source": "test"}).is_ok()).is_true()
	game.step(2)


func _row(game: GameSession, id: String) -> Dictionary:
	for row: Dictionary in game.perk_rows():
		if row["id"] == id:
			return row
	return {}


func test_perk_rows_describe_cost_requirements_and_refund() -> void:
	var game := _session()
	game.begin_round()
	var fast := _row(game, "perk_fast_growth")
	assert_bool(fast["available"]).is_false()
	assert_array(fast["missing"]).is_equal(["Wytrzymałość"])
	assert_bool(fast["owned"]).is_false()
	assert_bool(fast["affordable"]).is_false()
	assert_int(fast["cost"]).is_equal(12)
	assert_str(fast["tree"]).is_not_empty()
	assert_str(fast["side_effect"]).is_not_empty()
	_fund(game, 4)
	var hardy := _row(game, "perk_hardy")
	assert_bool(hardy["affordable"]).is_true()
	assert_bool(hardy["available"]).is_true()
	assert_array(hardy["missing"]).is_empty()
	assert_str(game.buy_perk("perk_hardy").value).is_equal("Wytrzymałość")
	game.step(2)
	hardy = _row(game, "perk_hardy")
	assert_bool(hardy["owned"]).is_true()
	assert_int(hardy["cost"]).is_equal(4)
	assert_int(hardy["refund"]).is_equal(2)
	assert_bool(_row(game, "perk_fast_growth")["available"]).is_true()


func test_collect_bubble_grants_sparks_next_tick() -> void:
	var game := _session()
	game.begin_round()
	var id := _discovery(game)
	var collected := game.collect_bubble(id)
	assert_bool(collected.is_ok()).is_true()
	assert_int(collected.value).is_equal(4)
	game.step(2)
	assert_int(game.sparks()).is_equal(4)
	var again := game.collect_bubble(id)
	assert_bool(again.is_ok()).is_false()
	assert_str("\n".join(again.errors)).is_equal("Bąbelek już zniknął.")
	game.step(2)
	assert_int(game.sparks()).is_equal(4)


func test_locked_action_is_refused_in_live_mode_only() -> void:
	var game := _session()
	game.begin_round()
	var refused := game.submit("mirrors_warm", {})
	assert_bool(refused.is_ok()).is_false()
	assert_str("\n".join(refused.errors)).is_equal("Lustra orbitalne wymaga perka „Lustra orbitalne”.")
	var locked: Dictionary = game.actions()[2]
	assert_bool(locked["unlocked"]).is_false()
	assert_str(locked["unlock_perk"]).is_equal("Lustra orbitalne")
	var free := game.submit("seed_species", {"species": "moss"})
	assert_bool("\n".join(free.errors).contains("wymaga perka")).is_false()
	for action: Dictionary in game.actions():
		if action["id"] == "seed_species":
			assert_bool(action["unlocked"]).is_true()
			assert_str(action["unlock_perk"]).is_empty()
	var classic := _session(false)
	classic.begin_round()
	assert_bool(classic.submit("mirrors_warm", {}).is_ok()).is_true()


func test_buying_the_perk_unlocks_the_action() -> void:
	var game := _session()
	game.begin_round()
	_fund(game, 8)
	assert_bool(game.buy_perk("perk_mirrors_warm").is_ok()).is_true()
	game.step(3)
	assert_bool(game.actions()[2]["unlocked"]).is_true()
	assert_bool(game.submit("mirrors_warm", {}).is_ok()).is_true()


func test_buy_without_sparks_fails_at_submit_with_the_missing_amount() -> void:
	var game := _session()
	game.begin_round()
	_fund(game, 2)
	var failed := game.buy_perk("perk_hardy")
	assert_bool(failed.is_ok()).is_false()
	assert_str("\n".join(failed.errors)).contains("brakuje 2 Iskier")
	assert_bool(game.refund_perk("perk_hardy").is_ok()).is_false()


func test_refund_returns_sparks_and_the_perk() -> void:
	var game := _session()
	game.begin_round()
	_fund(game, 10)
	game.buy_perk("perk_hardy")
	game.step(2)
	assert_int(game.sparks()).is_equal(6)
	assert_str(game.refund_perk("perk_hardy").value).is_equal("Wytrzymałość")
	game.step(2)
	assert_int(game.sparks()).is_equal(8)
	assert_bool(_row(game, "perk_hardy")["owned"]).is_false()


func test_live_round_never_ends_at_a_decision_point() -> void:
	var game := _session()
	game.begin_round()
	assert_int(game.step(5000)).is_equal(5000)
	assert_bool(game.round_over()).is_false()
	assert_object(game.decision_point()).is_null()
	assert_int(game.tick()).is_equal(5000)


func test_default_mode_still_stops_at_the_decision_point() -> void:
	var game := _session(false)
	game.begin_round()
	game.step(10000)
	assert_bool(game.round_over()).is_true()
	assert_int(game.tick()).is_equal(130)


func test_live_autosaves_every_1000_ticks() -> void:
	DirAccess.make_dir_recursive_absolute(NOBODY_HOME.get_base_dir())
	if FileAccess.file_exists(NOBODY_HOME):
		DirAccess.remove_absolute(NOBODY_HOME)
	var game := _session(true, NOBODY_HOME)
	game.begin_round()
	game.step(900)
	assert_bool(FileAccess.file_exists(NOBODY_HOME)).is_false()
	game.step(200)
	assert_int(game.tick()).is_equal(1100)
	assert_bool(FileAccess.file_exists(NOBODY_HOME)).is_true()


func test_load_keeps_sparks_perks_and_bloom_milestones() -> void:
	var game := _session()
	game.begin_round()
	var guard := 0
	while game.bubbles.save_state()["bloom"].is_empty() and guard < 40:
		game.step(250)
		guard += 1
	var bloom: Dictionary = game.bubbles.save_state()["bloom"]
	assert_bool(bloom.is_empty()).override_failure_message("no species reached a bloom threshold in 10000 ticks").is_false()
	_fund(game, 4)
	game.buy_perk("perk_hardy")
	game.step(2)
	var sparks_before := game.sparks()
	assert_bool(game.save().is_ok()).is_true()
	var loaded := _session(true, SAVE, true)
	assert_int(loaded.sparks()).is_equal(sparks_before)
	assert_bool(_row(loaded, "perk_hardy")["owned"]).is_true()
	assert_dict(loaded.bubbles.save_state()["bloom"]).is_equal(bloom)
	loaded.begin_round()
	loaded.step(1)
	for bubble: Dictionary in loaded.bubbles.bubbles():
		assert_str(bubble["kind"]).is_not_equal("bloom")


func test_pending_sparks_count_the_queued_grants_until_they_land() -> void:
	var game := _session()
	game.begin_round()
	game.step(2)
	assert_int(game.pending_sparks()).is_equal(0)
	var id := _discovery(game)
	assert_bool(game.collect_bubble(id).is_ok()).is_true()
	assert_int(game.pending_sparks()).is_equal(4)
	assert_int(game.sparks()).is_equal(0)
	# Another queued command is not Sparks.
	assert_bool(game.manager.submit(PerkSystem.ID, PerkSystem.ACTION_GRANT, {"amount": 3, "source": "test"}).is_ok()).is_true()
	assert_int(game.pending_sparks()).is_equal(7)
	game.step(2)
	assert_int(game.pending_sparks()).is_equal(0)
	assert_int(game.sparks()).is_equal(7)


func test_buying_a_perk_is_not_counted_as_pending_sparks() -> void:
	var game := _session()
	game.begin_round()
	_fund(game, 4)
	assert_bool(game.buy_perk("perk_hardy").is_ok()).is_true()
	assert_int(game.pending_sparks()).is_equal(0)


const BLOCKER := "user://game_session_economy_test/blocker"


## A path no platform can write: its "directory" is a file.
func _unwritable_save() -> String:
	DirAccess.make_dir_recursive_absolute(BLOCKER.get_base_dir())
	var file := FileAccess.open(BLOCKER, FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	return BLOCKER.path_join("save.json")


func _autosave_warnings(game: GameSession) -> int:
	return game.warnings.size()


## A save that keeps failing is reported once; the next failure after a good save is news again.
func test_a_failing_autosave_warns_once_until_a_save_succeeds() -> void:
	var good := "user://game_session_economy_test/autosave_recovers.json"
	DirAccess.make_dir_recursive_absolute(good.get_base_dir())
	var game := _session(true, good)
	var broken := _unwritable_save()
	game.begin_round()
	game.save_path = broken
	game.step(1100)
	assert_int(_autosave_warnings(game)).is_equal(1)
	assert_str(game.warnings[0]).contains("Autozapis się nie udał")
	game.step(1000)
	assert_int(game.tick()).is_equal(2100)
	assert_int(_autosave_warnings(game)).is_equal(1)
	game.save_path = good
	game.step(1000)
	assert_int(_autosave_warnings(game)).is_equal(1)
	assert_bool(FileAccess.file_exists(good)).is_true()
	game.save_path = broken
	game.step(1000)
	assert_int(game.tick()).is_equal(4100)
	assert_int(_autosave_warnings(game)).is_equal(2)
