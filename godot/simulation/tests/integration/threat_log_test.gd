extends GdUnitTestSuite
## What the window knows about crises: the warnings that just arrived (the
## first of each kind teaches the player), and the crises that loom or rage now.

const SAVE := "user://threat_log_test/decision.json"


func _bus() -> EventBus:
	return EventBus.new()


func _warned(id: String, tick: int = 1) -> SimEvent:
	return SimEvent.new(EventSystem.WARNED_EVENT, tick, &"events", {"id": id, "name": id.capitalize(),
			"story": "%s is coming." % id, "counters": ["perk_cull"]})


func _log() -> Array:
	var bus := _bus()
	var log := ThreatLog.new()
	log.attach(bus)
	return [log, bus]


func test_a_new_warning_is_reported_once_and_flagged_as_the_first() -> void:
	var made := _log()
	var log: ThreatLog = made[0]
	var bus: EventBus = made[1]
	bus.publish(_warned("drought"))
	bus.flush()
	var first := log.take_new_warnings()
	assert_int(first.size()).is_equal(1)
	assert_str(first[0]["id"]).is_equal("drought")
	assert_str(first[0]["text"]).is_equal("drought is coming.")
	assert_array(first[0]["counters"]).is_equal(["perk_cull"])
	assert_bool(first[0]["first_time"]).is_true()
	assert_array(log.take_new_warnings()).is_empty()
	bus.publish(_warned("drought", 400))
	bus.publish(_warned("ice_age", 401))
	bus.flush()
	var next := log.take_new_warnings()
	assert_array(next.map(func(w: Dictionary) -> bool: return w["first_time"])).is_equal([false, true])


func test_which_kinds_were_met_survives_a_save() -> void:
	var made := _log()
	var log: ThreatLog = made[0]
	(made[1] as EventBus).publish(_warned("drought"))
	(made[1] as EventBus).flush()
	var restored := ThreatLog.new()
	restored.load_state(log.save_state())
	var bus := _bus()
	restored.attach(bus)
	bus.publish(_warned("drought", 900))
	bus.flush()
	assert_bool(restored.take_new_warnings()[0]["first_time"]).is_false()


func test_damaged_saved_data_starts_fresh() -> void:
	var log := ThreatLog.new()
	log.load_state({"met": "nonsense"})
	assert_dict(log.save_state()).is_equal({"met": []})


func _session(events_path: String = "") -> SimResult:
	var args := PackedStringArray(["--seed", "1", "--personality", "harmonious", "--save", SAVE])
	var options: Dictionary = PlaySession.parse_args(args).value
	if not events_path.is_empty():
		options["events"] = events_path
	options["file_logs"] = false
	options["live"] = true
	return GameSession.create(options, func(_line: String) -> void: pass)


func test_threats_list_the_looming_crisis_with_its_counters() -> void:
	var created := _session()
	assert_array(Array(created.errors)).is_empty()
	var game: GameSession = created.value
	game.begin_round()
	var found: Array[Dictionary] = []
	var done := 0
	while found.is_empty() and done < 4000:
		game.step(50)
		done += 50
		found = game.threats()
	assert_bool(found.is_empty()).override_failure_message("no threat in 4000 ticks").is_false()
	var threat: Dictionary = found[0]
	assert_bool(threat["state"] in ["warned", "pending", "active"]).is_true()
	assert_str(threat["name"]).is_not_empty()
	assert_array(threat["counters"]).is_not_empty()
	var counter: Dictionary = threat["counters"][0]
	assert_bool(counter["kind"] in ["perk", "action"]).is_true()
	assert_str(counter["name"]).is_not_empty()
	assert_bool(counter["owned"]).is_false()


func test_a_counter_that_is_neither_perk_nor_action_is_a_load_error() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EventCatalog.DEFAULT_PATH))
	data["events"][0]["warning"]["counters"] = ["nope"]
	var path := "user://threat_log_test/events_bad.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://threat_log_test"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var created := _session(ProjectSettings.globalize_path(path))
	assert_bool(created.is_ok()).is_false()
	assert_str("\n".join(created.errors)).contains("nope")
