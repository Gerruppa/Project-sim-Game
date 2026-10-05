extends GdUnitTestSuite
## Interventions on the real planet: commands reach the systems at their
## tick, the planet answers, the chronicle tells it in the right order and
## a save taken mid-intervention continues bit for bit.

const TEST_DIR := "user://intervention_behavior_test"


class EventRecorder extends RunObserver:
	var lines := PackedStringArray()

	func attach(bus: EventBus) -> void:
		bus.subscribe_all(_on_event)

	func _on_event(event: SimEvent) -> void:
		if event.type != SimEvent.TICK_APPLIED:
			lines.append("%d %s %s" % [event.tick, event.type, event.data.get("summary", event.data)])


func _config() -> SimConfig:
	return SimConfig.from_data({
		"config_version": 1, "seed": 42, "base_ticks_per_second": 1, "speed_multipliers": [1, 10, 100],
		"max_catch_up_ticks": 1000, "personality": "guardian",
		"log": {"text": false, "jsonl": false, "deltas": false, "chronicle": false, "directory": TEST_DIR},
	}).value


func _planet() -> Dictionary:
	var built := SimulationRunner.build_planet(_config(), SimulationRunner.parse_args(PackedStringArray()).value)
	assert_array(Array(built.errors)).is_empty()
	return built.value


func _run_info(planet: Dictionary) -> Dictionary:
	return {"personality": planet["personality"], "data_fingerprints": planet["fingerprints"], "lineage": []}


func test_submit_rejects_past_ticks_and_unknown_targets() -> void:
	var manager: SimulationManager = _planet()["manager"]
	manager.run_ticks(3)
	assert_str("\n".join(manager.submit(InterventionSystem.ID, &"mirrors_cool", {}, 3).errors)).contains("already run")
	assert_str("\n".join(manager.submit(&"geology", &"quake").errors)).contains("no system 'geology'")
	assert_str("\n".join(manager.submit(&"climate", &"warm").errors)).contains("accepts no commands")


func test_seeding_comes_before_the_planets_answer() -> void:
	var manager: SimulationManager = _planet()["manager"]
	var recorder := EventRecorder.new()
	manager.attach_log(recorder)
	assert_bool(manager.submit(InterventionSystem.ID, &"seed_species", {"species": "moss"}).is_ok()).is_true()
	manager.run_ticks(1)
	assert_str(recorder.lines[0]).starts_with("1 intervention_applied")
	assert_str(recorder.lines[1]).starts_with("1 species_emerged")
	assert_float((manager.system(BiosphereSystem.ID) as BiosphereSystem).population(&"moss")).is_greater(4.0)


func test_cooling_mirrors_cool_the_planet_until_they_fold() -> void:
	var plain: SimulationManager = _planet()["manager"]
	var cooled: SimulationManager = _planet()["manager"]
	var recorder := EventRecorder.new()
	cooled.attach_log(recorder)
	cooled.submit(InterventionSystem.ID, &"mirrors_cool")
	plain.run_ticks(300)
	cooled.run_ticks(300)
	assert_float(cooled.snapshot().get_value(Param.TEMPERATURE)).is_less(plain.snapshot().get_value(Param.TEMPERATURE) - 1.0)
	cooled.run_ticks(201)
	assert_array(Array(recorder.lines).filter(func(line: String) -> bool: return line.begins_with("501 intervention_ended"))).has_size(1)


func test_save_mid_intervention_with_queued_commands_continues_identically() -> void:
	var continuous: SimulationManager = _planet()["manager"]
	continuous.submit(InterventionSystem.ID, &"volcanic_awakening")
	continuous.submit(InterventionSystem.ID, &"seed_species", {"species": "algae"}, 150)
	continuous.run_ticks(600)

	var first := _planet()
	var manager: SimulationManager = first["manager"]
	manager.submit(InterventionSystem.ID, &"volcanic_awakening")
	manager.submit(InterventionSystem.ID, &"seed_species", {"species": "algae"}, 150)
	manager.run_ticks(100)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveSystem.capture(manager, _run_info(first))))

	var second := _planet()
	var restored := SaveSystem.restore(second["manager"], saved, _run_info(second))
	assert_array(Array(restored.errors)).is_empty()
	(second["manager"] as SimulationManager).run_ticks(500)
	assert_str((second["manager"] as SimulationManager).state_hash()).is_equal(continuous.state_hash())


func test_chronicle_names_the_seeded_species() -> void:
	var manager: SimulationManager = _planet()["manager"]
	var sink := MemoryLogSink.new()
	var chronicle := PlanetChronicle.new([sink], ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH).value)
	manager.attach_log(chronicle)
	manager.submit(InterventionSystem.ID, &"seed_species", {"species": "moss"})
	manager.submit(InterventionSystem.ID, &"mirrors_warm")
	manager.submit(InterventionSystem.ID, &"mirrors_cool", {}, 2)
	manager.run_ticks(2)
	assert_array(Array(sink.lines)).contains(["[Tick 1] Gracz zasiewa mchy.",
			"[Tick 1] Gracz rozkłada lustra orbitalne: planeta dostaje więcej światła.",
			"[Tick 2] Pył orbitalny: jeszcze niegotowe, dostępne od ticku 1501."])
