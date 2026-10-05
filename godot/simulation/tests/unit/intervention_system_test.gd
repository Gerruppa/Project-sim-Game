extends GdUnitTestSuite
## InterventionSystem: validation, cooldowns, modifiers with expiry,
## follow-up commands, notifications and saving.

const I := preload("res://simulation/tests/support/intervention_fixtures.gd")
const C := preload("res://simulation/tests/support/climate_fixtures.gd")

var _registry: ModifierRegistry


func before_test() -> void:
	_registry = I.registry()


func _system(defs: Array = [I.timed("warm"), I.seeding()]) -> InterventionSystem:
	return InterventionSystem.new(I.catalog(defs), I.SPECIES)


func _command(tick: int, action: String, args: Dictionary = {}) -> SimCommand:
	return SimCommand.new(tick, InterventionSystem.ID, StringName(action), args)


## Runs phase 2 for ticks from..to and returns every event emitted on the way.
func _ticks(system: InterventionSystem, from: int, to: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for tick in range(from, to + 1):
		system.provide_modifiers(C.snapshot({}), tick, _registry)
		_registry.expire(tick - 1)
		events.append_array(system.take_events(tick))
	return events


func _types(events: Array[SimEvent]) -> Array:
	return events.map(func(event: SimEvent) -> String: return String(event.type))


func test_validates_action_arguments_and_species() -> void:
	var system := _system()
	assert_bool(system.validate_command(_command(1, "warm")).is_ok()).is_true()
	assert_bool(system.validate_command(_command(1, "seed", {"species": "moss"})).is_ok()).is_true()
	assert_str("\n".join(system.validate_command(_command(1, "comet")).errors)).contains("unknown intervention")
	assert_str("\n".join(system.validate_command(_command(1, "seed", {"species": "lichen"})).errors)).contains("moss, tree")
	assert_str("\n".join(system.validate_command(_command(1, "warm", {"species": "moss"})).errors)).contains("unknown argument")


func test_applied_intervention_reports_its_story_and_arguments() -> void:
	var system := _system()
	system.apply_command(_command(3, "seed", {"species": "moss"}))
	var event := system.take_events(3)[0]
	assert_str(String(event.type)).is_equal("intervention_applied")
	assert_str(event.data["story"]).is_equal("Seeding {species}.")
	assert_str(event.data["species"]).is_equal("moss")


func test_seeding_asks_the_biosphere() -> void:
	var follow_ups := _system().apply_command(_command(3, "seed", {"species": "tree"}))
	assert_int(follow_ups.size()).is_equal(1)
	assert_str(String(follow_ups[0].action)).is_equal("add_population")
	assert_dict(follow_ups[0].args).is_equal({"species": "tree", "amount": 5.0})


func test_timed_modifiers_act_for_their_duration_then_end() -> void:
	var system := _system()
	system.apply_command(_command(5, "warm"))
	system.take_events(5)
	_ticks(system, 5, 5)
	assert_int(_registry.modifiers().size()).is_equal(1)
	assert_int(_registry.modifiers()[0].expires_at).is_equal(14)
	var events := _ticks(system, 6, 14)
	assert_array(events).is_empty()
	assert_int(_registry.modifiers().size()).is_equal(1)
	events = _ticks(system, 15, 15)
	assert_array(_types(events)).is_equal(["intervention_ended"])
	assert_str(events[0].data["story"]).is_equal("warm ends.")
	assert_int(_registry.modifiers().size()).is_equal(0)


func test_cooldown_blocks_reuse_and_is_shared_by_a_group() -> void:
	var system := _system([I.timed("warm", {"cooldown_group": "mirrors"}), I.timed("cool", {"cooldown_group": "mirrors"})])
	system.apply_command(_command(1, "warm"))
	assert_int(system.ready_at(&"cool")).is_equal(21)
	assert_str("\n".join(system.validate_command(_command(20, "cool")).errors)).contains("available from tick 21")
	assert_bool(system.validate_command(_command(21, "cool")).is_ok()).is_true()


func test_queued_command_meeting_a_new_cooldown_is_rejected_in_the_log() -> void:
	var system := _system()
	assert_bool(system.validate_command(_command(2, "warm")).is_ok()).is_true()
	system.apply_command(_command(1, "warm"))
	system.take_events(1)
	assert_array(system.apply_command(_command(2, "warm"))).is_empty()
	var events := system.take_events(2)
	assert_array(_types(events)).is_equal(["intervention_rejected"])
	assert_int(events[0].data["ready_at"]).is_equal(21)


func test_save_mid_intervention_restores_modifiers_and_cooldowns() -> void:
	var first := _system()
	first.apply_command(_command(5, "warm"))
	_ticks(first, 5, 8)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(first.save_state()))
	_registry = I.registry()
	var restored := _system()
	assert_array(Array(restored.load_state(saved).errors)).is_empty()
	restored.restore_modifiers(_registry)
	restored.restore_modifiers(_registry)
	assert_int(_registry.modifiers().size()).is_equal(1)
	assert_int(_registry.modifiers()[0].expires_at).is_equal(14)
	assert_int(restored.ready_at(&"warm")).is_equal(25)
	assert_array(_types(_ticks(restored, 9, 15))).is_equal(["intervention_ended"])


func test_load_rejects_damaged_state() -> void:
	var system := _system()
	assert_bool(system.load_state({}).is_ok()).is_false()
	assert_bool(system.load_state({"format": "interventions_state", "ready_at": {"warm": -3}, "active": []}).is_ok()).is_false()
	assert_bool(system.load_state({"format": "interventions_state", "ready_at": {},
			"active": [{"id": "comet", "started": 1, "ends": 4, "args": {}}]}).is_ok()).is_false()


func test_never_returns_deltas() -> void:
	var system := _system()
	system.apply_command(_command(1, "warm"))
	assert_array(system.compute(C.snapshot({}))).is_empty()


func _leveled() -> InterventionSystem:
	return _system([I.timed("warm", {"levels": {"default": "strong", "options": {
			"weak": {"scale": 0.25, "name": "lekko"}, "strong": {"scale": 1.0, "name": "mocno"}}}})])


func test_level_scales_the_modifier_and_names_itself() -> void:
	var system := _leveled()
	system.apply_command(_command(1, "warm", {"level": "weak"}))
	var event := system.take_events(1)[0]
	assert_str(event.data["level"]).is_equal("weak")
	assert_str(event.data["level_name"]).is_equal("lekko")
	_ticks(system, 1, 1)
	assert_float(_registry.modifiers()[0].value).is_equal(1.0)


func test_without_a_level_the_default_applies() -> void:
	var system := _leveled()
	system.apply_command(_command(1, "warm"))
	assert_str(system.take_events(1)[0].data["level_name"]).is_equal("mocno")
	_ticks(system, 1, 1)
	assert_float(_registry.modifiers()[0].value).is_equal(4.0)


func test_validates_levels() -> void:
	var system := _leveled()
	assert_bool(system.validate_command(_command(1, "warm", {"level": "weak"})).is_ok()).is_true()
	assert_str("\n".join(system.validate_command(_command(1, "warm", {"level": "hot"})).errors)).contains("unknown level")
	assert_str("\n".join(_system().validate_command(_command(1, "warm", {"level": "weak"})).errors)).contains("unknown argument")


func test_level_survives_a_save() -> void:
	var first := _leveled()
	first.apply_command(_command(5, "warm", {"level": "weak"}))
	_ticks(first, 5, 6)
	_registry = I.registry()
	var restored := _leveled()
	restored.load_state(JSON.parse_string(JSON.stringify(first.save_state())))
	restored.restore_modifiers(_registry)
	assert_float(_registry.modifiers()[0].value).is_equal(1.0)
