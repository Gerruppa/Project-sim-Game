extends GdUnitTestSuite
## EventLifecycle: Inactive -> Pending -> Active -> Cooldown -> Inactive.

const E := preload("res://simulation/tests/support/event_fixtures.gd")

var _history: ParamHistory
var _lifecycle: EventLifecycle


func before_test() -> void:
	_history = ParamHistory.new({&"humidity": 1})
	_lifecycle = EventLifecycle.new()


func _def(overrides: Dictionary = {}) -> EventDef:
	return E.catalog([E.def("x", overrides)]).get_def(&"x")


## Feeds humidity values; returns the transitions.
func _run(def: EventDef, values: Array) -> Array[StringName]:
	var transitions: Array[StringName] = []
	for value: float in values:
		_history.record(E.snapshot({"humidity": value}))
		transitions.append(_lifecycle.advance(def, _history))
	return transitions


func test_starts_when_the_trigger_holds() -> void:
	assert_array(_run(_def(), [25.0, 15.0])).is_equal([EventLifecycle.NO_CHANGE, EventLifecycle.STARTED])
	assert_str(_lifecycle.phase).is_equal(EventLifecycle.ACTIVE)


func test_trigger_must_hold_for_ticks_in_a_row() -> void:
	var def := _def({"trigger": {"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 20}, "for_ticks": 3}})
	_run(def, [15.0, 15.0])
	assert_str(_lifecycle.phase).is_equal(EventLifecycle.PENDING)
	_run(def, [25.0])
	assert_str(_lifecycle.phase).is_equal(EventLifecycle.INACTIVE)
	assert_array(_run(def, [15.0, 15.0, 15.0])).is_equal(
			[EventLifecycle.NO_CHANGE, EventLifecycle.NO_CHANGE, EventLifecycle.STARTED])


func test_hysteresis_keeps_the_event_between_thresholds() -> void:
	var transitions := _run(_def(), [15.0, 25.0, 22.0, 28.0, 31.0])
	assert_array(transitions).is_equal([EventLifecycle.STARTED, EventLifecycle.NO_CHANGE,
			EventLifecycle.NO_CHANGE, EventLifecycle.NO_CHANGE, EventLifecycle.ENDED])
	assert_str(_lifecycle.end_reason).is_equal(EventLifecycle.END_CONDITIONS)
	assert_int(_lifecycle.elapsed).is_equal(4)


func test_end_condition_waits_for_min_duration_and_for_ticks() -> void:
	var def := _def({"min_duration": 3,
			"end": {"condition": {"measure": "value", "param": "humidity", "op": ">", "value": 30}, "for_ticks": 2}})
	var transitions := _run(def, [15.0, 35.0, 35.0, 35.0, 35.0])
	# elapsed 1, 2: too early; elapsed 3: first end tick; elapsed 4: ends.
	assert_array(transitions).is_equal([EventLifecycle.STARTED, EventLifecycle.NO_CHANGE,
			EventLifecycle.NO_CHANGE, EventLifecycle.NO_CHANGE, EventLifecycle.ENDED])


func test_end_streak_resets_when_the_condition_breaks() -> void:
	var def := _def({"end": {"condition": {"measure": "value", "param": "humidity", "op": ">", "value": 30}, "for_ticks": 2}})
	var transitions := _run(def, [15.0, 35.0, 25.0, 35.0, 35.0])
	assert_array(transitions).is_equal([EventLifecycle.STARTED, EventLifecycle.NO_CHANGE,
			EventLifecycle.NO_CHANGE, EventLifecycle.NO_CHANGE, EventLifecycle.ENDED])


func test_max_duration_ends_an_event_whose_end_never_comes() -> void:
	var transitions := _run(_def({"max_duration": 3}), [15.0, 10.0, 5.0, 0.0])
	assert_str(transitions[3]).is_equal(EventLifecycle.ENDED)
	assert_str(_lifecycle.end_reason).is_equal(EventLifecycle.END_MAX_DURATION)
	assert_int(_lifecycle.elapsed).is_equal(3)


func test_cooldown_blocks_the_trigger() -> void:
	var def := _def({"max_duration": 1, "cooldown": 2})
	var transitions := _run(def, [15.0, 15.0, 15.0, 15.0, 15.0])
	assert_array(transitions).is_equal([EventLifecycle.STARTED, EventLifecycle.ENDED,
			EventLifecycle.NO_CHANGE, EventLifecycle.NO_CHANGE, EventLifecycle.STARTED])


func test_without_cooldown_the_event_can_start_on_the_next_tick() -> void:
	var transitions := _run(_def({"max_duration": 1}), [15.0, 15.0, 15.0])
	assert_array(transitions).is_equal([EventLifecycle.STARTED, EventLifecycle.ENDED, EventLifecycle.STARTED])


func test_round_trip_and_rejects_bad_data() -> void:
	var def := _def({"trigger": {"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 20}, "for_ticks": 3}})
	_run(def, [15.0, 15.0])
	var copy := EventLifecycle.new()
	assert_bool(copy.load_dict(JSON.parse_string(JSON.stringify(_lifecycle.to_dict()))).is_ok()).is_true()
	assert_dict(copy.to_dict()).is_equal(_lifecycle.to_dict())
	assert_bool(copy.load_dict({"phase": "sleeping", "streak": 0, "elapsed": 0, "cooldown_left": 0}).is_ok()).is_false()
	assert_bool(copy.load_dict({"phase": "active", "streak": -1, "elapsed": 0, "cooldown_left": 0}).is_ok()).is_false()
