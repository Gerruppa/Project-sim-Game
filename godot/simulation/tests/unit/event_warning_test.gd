extends GdUnitTestSuite
## Early warnings: a looser condition than the trigger tells the player a crisis
## is coming, once per episode, long before it starts.

const E := preload("res://simulation/tests/support/event_fixtures.gd")

var _registry: ModifierRegistry


func before_test() -> void:
	_registry = E.registry()


## "dry" starts below humidity 20 and ends above 30; it is warned about below 30.
func _def(overrides: Dictionary = {}, warning: Dictionary = {}) -> Dictionary:
	var block := {
		"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 30},
		"for_ticks": 3, "clear_ticks": 5,
		"text": "Dry air is coming.", "counters": ["aquifer_release"],
	}
	block.merge(warning, true)
	var data := {"warning": block}
	data.merge(overrides, true)
	return E.def("dry", data)


func _system(overrides: Dictionary = {}, warning: Dictionary = {}) -> EventSystem:
	return EventSystem.new(E.catalog([_def(overrides, warning)]))


## Feeds humidity as ticks 1, 2, ...; returns the events as "tick:type".
func _feed(system: EventSystem, values: Array, first_tick: int = 1) -> Array[String]:
	var seen: Array[String] = []
	for i in values.size():
		var tick := first_tick + i
		system.detect(E.snapshot({"humidity": values[i]}, tick), tick, _registry)
		for event in system.take_events(tick):
			seen.append("%d:%s" % [tick, event.type])
	return seen


func test_the_warning_comes_before_the_crisis() -> void:
	var seen := _feed(_system(), [40.0, 28.0, 27.0, 26.0, 25.0, 15.0])
	assert_array(seen).is_equal(["4:world_event_warned", "6:world_event_started"])


func test_the_warning_needs_its_condition_for_ticks_in_a_row() -> void:
	var system := _system()
	assert_array(_feed(system, [28.0, 28.0, 40.0, 28.0, 28.0])).is_empty()
	assert_array(system.warned_ids()).is_empty()
	assert_array(_feed(system, [28.0], 6)).is_equal(["6:world_event_warned"])
	assert_array(system.warned_ids()).is_equal([&"dry"])


func test_the_warning_says_what_to_expect_and_what_helps() -> void:
	var system := _system()
	var events: Array[SimEvent] = []
	for i in 4:
		system.detect(E.snapshot({"humidity": 28.0}, i + 1), i + 1, _registry)
		events.append_array(system.take_events(i + 1))
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].data["story"]).is_equal("Dry air is coming.")
	assert_array(events[0].data["counters"]).is_equal(["aquifer_release"])
	assert_str(events[0].data["id"]).is_equal("dry")
	assert_dict(system.info_of(&"dry")).contains_key_value("warning_text", "Dry air is coming.")


func test_a_condition_hovering_at_the_threshold_warns_once() -> void:
	var system := _system()
	var wobble: Array = []
	for i in 12:
		wobble.append_array([28.0, 28.0, 28.0, 28.0, 33.0, 33.0, 33.0])
	var seen := _feed(system, wobble)
	assert_array(seen.filter(func(e: String) -> bool: return e.ends_with("world_event_warned"))).has_size(1)
	assert_array(seen.filter(func(e: String) -> bool: return e.ends_with("world_event_warning_cleared"))).is_empty()


func test_the_warning_clears_after_enough_calm() -> void:
	var system := _system()
	var seen := _feed(system, [28.0, 28.0, 28.0, 40.0, 40.0, 40.0, 40.0, 40.0])
	assert_array(seen).is_equal(["3:world_event_warned", "8:world_event_warning_cleared"])
	assert_array(system.warned_ids()).is_empty()


func test_the_start_of_the_crisis_ends_the_warning_silently() -> void:
	var system := _system()
	var seen := _feed(system, [28.0, 28.0, 28.0, 15.0])
	assert_array(seen).is_equal(["3:world_event_warned", "4:world_event_started"])
	assert_array(system.warned_ids()).is_empty()


func test_no_warning_during_the_crisis_or_its_cooldown() -> void:
	var system := _system({"cooldown": 50})
	var seen := _feed(system, [15.0, 15.0, 15.0, 15.0, 35.0, 28.0, 28.0, 28.0, 28.0])
	assert_array(seen.filter(func(e: String) -> bool: return e.ends_with("world_event_warned"))).is_empty()


func test_an_event_without_a_warning_never_warns() -> void:
	var system := EventSystem.new(E.catalog([E.def("dry")]))
	assert_array(_feed(system, [28.0, 28.0, 28.0, 28.0, 28.0])).is_empty()
	assert_dict(system.info_of(&"dry")).contains_key_value("warning_text", "")


func test_warning_state_survives_save_and_load() -> void:
	var first := _system()
	_feed(first, [28.0, 28.0, 28.0])
	var restored := _system()
	assert_bool(restored.load_state(first.save_state()).is_ok()).is_true()
	assert_array(restored.warned_ids()).is_equal([&"dry"])
	# Restored, it does not warn a second time.
	assert_array(_feed(restored, [28.0, 28.0], 4)).is_empty()


func test_an_old_save_without_warning_keys_loads() -> void:
	var first := _system()
	_feed(first, [28.0])
	var saved := first.save_state()
	for key: String in ["warned", "warn_streak", "calm_streak"]:
		(saved["events"]["dry"] as Dictionary).erase(key)
	var restored := _system()
	assert_bool(restored.load_state(saved).is_ok()).is_true()
	assert_array(restored.warned_ids()).is_empty()


func test_the_warning_reads_history_the_trigger_does_not() -> void:
	var catalog := E.catalog([_def({}, {"condition": {"measure": "mean", "param": "humidity", "window": 50, "op": "<", "value": 30}})])
	assert_int(catalog.get_def(&"dry").warning_required_samples()).is_equal(50)
	# The warning never delays the crisis itself.
	assert_int(catalog.get_def(&"dry").required_samples()).is_equal(1)


func test_catalog_rejects_a_bad_warning() -> void:
	var errors := func(warning: Variant) -> String:
		return "\n".join(E.parse([E.def("dry", {"warning": warning})]).errors)
	assert_str(errors.call({"text": "x", "counters": []})).contains("condition")
	assert_str(errors.call({"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 30},
			"text": "", "counters": []})).contains("text")
	assert_str(errors.call({"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 30},
			"text": "x", "counters": "aquifer"})).contains("counters")
	assert_str(errors.call({"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 30},
			"text": "x", "counters": [], "for_ticks": 0})).contains("for_ticks")
	assert_str(errors.call({"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 30},
			"text": "x", "counters": [], "surprise": 1})).contains("surprise")
	assert_str(errors.call("soon")).contains("warning")
