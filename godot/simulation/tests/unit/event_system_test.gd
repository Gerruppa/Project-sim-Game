extends GdUnitTestSuite
## EventSystem: lifecycles become modifiers and notifications, never deltas.

const E := preload("res://simulation/tests/support/event_fixtures.gd")

var _registry: ModifierRegistry


func before_test() -> void:
	_registry = E.registry()


## Feeds humidity values as ticks 1, 2, ...; returns the emitted events.
func _feed(system: EventSystem, values: Array, first_tick: int = 1) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i in values.size():
		var tick := first_tick + i
		system.detect(E.snapshot({"humidity": values[i]}, tick), tick, _registry)
		events.append_array(system.take_events(tick))
	return events


func _sources() -> Array[StringName]:
	var sources: Array[StringName] = []
	for modifier in _registry.modifiers():
		sources.append(modifier.source)
	return sources


func test_active_event_registers_its_modifiers_until_it_ends() -> void:
	var system := EventSystem.new(E.catalog([E.def("dry")]))
	_feed(system, [15.0])
	assert_array(_sources()).is_equal([&"event:dry"])
	assert_str(_registry.modifiers()[0].target).is_equal("climate.water_availability")
	_feed(system, [35.0], 2)
	assert_array(_sources()).is_empty()


func test_publishes_start_and_end_with_their_causes() -> void:
	var system := EventSystem.new(E.catalog([E.def("dry")]))
	var events := _feed(system, [25.0, 15.0, 22.0, 35.0])
	assert_int(events.size()).is_equal(2)
	assert_str(events[0].type).is_equal(EventSystem.STARTED_EVENT)
	assert_int(events[0].tick).is_equal(2)
	assert_str(events[0].data["id"]).is_equal("dry")
	assert_float(events[0].data["causes"][0]["measured"]).is_equal(15.0)
	assert_array(events[0].data["modifiers"]).is_equal(["climate.water_availability multiply 0.5"])
	assert_str(events[0].data["summary"]).contains("Test dry started").contains("humidity 15.00 < 20")
	assert_str(events[1].type).is_equal(EventSystem.ENDED_EVENT)
	assert_int(events[1].tick).is_equal(4)
	assert_str(events[1].data["reason"]).is_equal("conditions")
	assert_int(events[1].data["duration"]).is_equal(2)
	assert_str(events[1].data["summary"]).contains("ended after 2 ticks (end conditions)")


func test_tells_the_story_matching_how_the_event_ended() -> void:
	var by_conditions := _feed(EventSystem.new(E.catalog([E.def("dry")])), [15.0, 35.0])
	assert_str(by_conditions[0].data["story"]).is_equal("dry begins.")
	assert_str(by_conditions[1].data["story"]).is_equal("dry is over.")
	var by_time := _feed(EventSystem.new(E.catalog([E.def("dry", {"max_duration": 2})])), [15.0, 15.0, 15.0])
	assert_str(by_time[1].data["story"]).is_equal("dry fades out.")


func test_time_limit_is_named_in_the_summary() -> void:
	var system := EventSystem.new(E.catalog([E.def("dry", {"max_duration": 2})]))
	var events := _feed(system, [15.0, 15.0, 15.0])
	assert_str(events[1].data["reason"]).is_equal("max_duration")
	assert_str(events[1].data["summary"]).contains("(time limit)").contains("humidity 15.00 not > 30")


func test_waits_until_the_history_fills_its_windows() -> void:
	var def := E.def("dry", {"trigger": {"condition": {"measure": "mean", "param": "humidity", "window": 3, "op": "<", "value": 20}, "for_ticks": 1}})
	var system := EventSystem.new(E.catalog([def]))
	_feed(system, [10.0, 10.0])
	assert_str(system.phase_of(&"dry")).is_equal(EventLifecycle.INACTIVE)
	_feed(system, [10.0], 3)
	assert_array(system.active_ids()).is_equal([&"dry"])


func test_reactions_run_only_on_their_archetype() -> void:
	var catalog := E.catalog([E.def("any"), E.def("healing", {"personality": ["guardian"]})])
	assert_array(EventSystem.new(catalog, &"guardian").event_ids()).is_equal([&"any", &"healing"])
	assert_array(EventSystem.new(catalog, &"chaotic").event_ids()).is_equal([&"any"])
	assert_array(EventSystem.new(catalog, &"none").event_ids()).is_equal([&"any"])
	assert_array(EventSystem.new(catalog).event_ids()).is_equal([&"any"])


func test_skips_modifiers_of_systems_the_planet_does_not_run() -> void:
	_registry = ModifierRegistry.new()
	_registry.register_target(&"climate", ClimateConfig.SPEC)
	var def := E.def("x", {"modifiers": [{"target": "biosphere.growth_scale", "operation": "multiply", "value": 2},
			{"target": "climate.water_availability", "operation": "multiply", "value": 0.5}]})
	var system := EventSystem.new(E.catalog([def]))
	var events := _feed(system, [15.0])
	assert_int(_registry.modifiers().size()).is_equal(1)
	assert_array(events[0].data["modifiers"]).is_equal(["climate.water_availability multiply 0.5"])


func test_events_are_independent() -> void:
	var system := EventSystem.new(E.catalog([E.def("dry"), E.def("very_dry",
			{"trigger": {"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 10}, "for_ticks": 1}})]))
	_feed(system, [15.0, 5.0])
	assert_array(system.active_ids()).is_equal([&"dry", &"very_dry"])
	assert_array(_sources()).contains_exactly_in_any_order([&"event:dry", &"event:very_dry"])


func test_save_and_load_continue_identically() -> void:
	var def := E.def("dry", {"min_duration": 2, "cooldown": 3,
			"trigger": {"condition": {"measure": "anomaly", "param": "humidity", "window": 4, "op": "<", "value": -3}, "for_ticks": 2}})
	var values := [30.0, 30.0, 30.0, 25.0, 22.0, 20.0, 19.0, 24.0, 30.0, 31.0, 30.0, 20.0, 18.0, 17.0, 16.0, 30.0]
	var continuous := EventSystem.new(E.catalog([def]))
	var expected := _summaries(_feed(continuous, values))
	var expected_modifiers := _sources()

	for split in range(1, values.size()):
		_registry = E.registry()
		var first := EventSystem.new(E.catalog([def]))
		var before := _summaries(_feed(first, values.slice(0, split)))
		var saved: Dictionary = JSON.parse_string(JSON.stringify(first.save_state()))
		_registry = E.registry()
		var restored := EventSystem.new(E.catalog([def]))
		assert_bool(restored.load_state(saved).is_ok()).is_true()
		restored.restore_modifiers(_registry)
		var after := _summaries(_feed(restored, values.slice(split), split + 1))
		assert_array(before + after).override_failure_message("split at %d" % split).is_equal(expected)
		assert_array(_sources()).is_equal(expected_modifiers)


func test_load_restores_modifiers_of_active_events() -> void:
	var first := EventSystem.new(E.catalog([E.def("dry")]))
	_feed(first, [15.0])
	_registry = E.registry()
	var restored := EventSystem.new(E.catalog([E.def("dry")]))
	restored.load_state(first.save_state())
	restored.restore_modifiers(_registry)
	restored.restore_modifiers(_registry)
	assert_array(_sources()).is_equal([&"event:dry"])


func test_load_rejects_state_of_another_planet() -> void:
	var catalog := E.catalog([E.def("dry"), E.def("healing", {"personality": ["guardian"]})])
	var guardian := EventSystem.new(catalog, &"guardian").save_state()
	assert_bool(EventSystem.new(catalog, &"chaotic").load_state(guardian).is_ok()).is_false()
	assert_bool(EventSystem.new(catalog).load_state({"format": "x"}).is_ok()).is_false()


func test_never_returns_deltas() -> void:
	var system := EventSystem.new(E.project_catalog(), &"guardian")
	assert_array(system.compute(E.snapshot({}))).is_empty()


func _summaries(events: Array[SimEvent]) -> Array[String]:
	var result: Array[String] = []
	for event in events:
		result.append("%d %s" % [event.tick, event.data["summary"]])
	return result
