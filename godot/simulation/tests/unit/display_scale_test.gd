extends GdUnitTestSuite
## DisplayScale: the planet's 0-100 values as the player reads them, through
## anchor points that put each game threshold where it happens on Earth.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")
const I := preload("res://simulation/tests/support/intervention_fixtures.gd")

const IDS: Array[StringName] = [&"temperature", &"oxygen", &"humidity"]
const ACTIONS: Array[StringName] = [&"mirrors_warm", &"seed_species"]


func _data(overrides: Dictionary = {}) -> Dictionary:
	var data := {
		"parameters": {
			"temperature": {"label": "Średnia temperatura", "unit": "°C", "decimals": 1,
				"points": [[0, -30], [16, 0], [30, 10], [40, 24], [100, 100]]},
			"oxygen": {"unit": "% atmosfery", "decimals": 1, "points": [[0, 0], [22, 16], [40, 30], [100, 60]]},
		},
		"actions": {"mirrors_warm": {"effect_ticks": [1490, 2400]}},
	}
	data.merge(overrides, true)
	return data


func _scale(overrides: Dictionary = {}) -> DisplayScale:
	var result := DisplayScale.from_data(_data(overrides), IDS, ACTIONS)
	assert_array(Array(result.errors)).is_empty()
	return result.value


func _errors(data: Dictionary) -> String:
	return "\n".join(DisplayScale.from_data(data, IDS, ACTIONS).errors)


func _points_error(points: Variant) -> String:
	return _errors({"parameters": {"oxygen": {"unit": "%", "decimals": 0, "points": points}}})


func _project_ids() -> Array[StringName]:
	var schema := P.project_schema()
	var ids: Array[StringName] = []
	for i in schema.size():
		ids.append(schema.def_at(i).id())
	return ids


func _project() -> DisplayScale:
	var result := DisplayScale.load_json(DisplayScale.DEFAULT_PATH, _project_ids(), I.project_catalog().ids())
	assert_array(Array(result.errors)).is_empty()
	return result.value


func test_anchor_points_map_exactly() -> void:
	var scale := _scale()
	assert_float(scale.to_display("temperature", 0.0)).is_equal(-30.0)
	assert_float(scale.to_display("temperature", 16.0)).is_equal(0.0)
	assert_float(scale.to_display("temperature", 30.0)).is_equal(10.0)
	assert_float(scale.to_display("temperature", 40.0)).is_equal(24.0)
	assert_float(scale.to_display("temperature", 100.0)).is_equal(100.0)


func test_values_between_anchors_are_linear_within_their_segment() -> void:
	var scale := _scale()
	assert_float(scale.to_display("temperature", 8.0)).is_equal_approx(-15.0, 0.0001)
	assert_float(scale.to_display("temperature", 23.0)).is_equal_approx(5.0, 0.0001)
	assert_float(scale.to_display("temperature", 35.0)).is_equal_approx(17.0, 0.0001)
	assert_float(scale.to_display("oxygen", 15.0)).is_equal_approx(10.909, 0.001)


func test_values_outside_the_scale_continue_the_end_segments() -> void:
	var scale := _scale()
	assert_float(scale.to_display("temperature", -10.0)).is_equal_approx(-48.75, 0.0001)
	assert_float(scale.to_display("temperature", 110.0)).is_equal_approx(112.667, 0.001)


func test_a_change_is_the_difference_of_two_shown_values() -> void:
	var scale := _scale()
	# The same 8 points warm more above the start than they cool below it.
	assert_float(scale.change("temperature", 30.0, 38.0)).is_equal_approx(11.2, 0.0001)
	assert_float(scale.change("temperature", 30.0, 22.0)).is_equal_approx(-5.714, 0.001)


func test_a_difference_converts_around_the_current_value() -> void:
	var scale := _scale()
	# 8 points centred on 30: from 26 (7.14 °C) to 34 (15.6 °C).
	assert_float(scale.difference("temperature", 8.0, 30.0)).is_equal_approx(8.457, 0.001)
	assert_float(scale.difference("temperature", -8.0, 30.0)).is_equal_approx(-8.457, 0.001)
	# Inside one segment the place does not matter.
	assert_float(scale.difference("oxygen", 4.0, 10.0)).is_equal_approx(scale.difference("oxygen", 4.0, 15.0), 0.0001)


func test_a_parameter_without_a_mapping_stays_on_the_normalized_scale() -> void:
	var scale := _scale()
	assert_float(scale.to_display("humidity", 37.5)).is_equal(37.5)
	assert_float(scale.change("humidity", 30.0, 34.0)).is_equal(4.0)
	assert_str(scale.shown("humidity", 37.5)).is_equal("37.5")
	assert_str(scale.label("humidity", "Wilgotność")).is_equal("Wilgotność")
	assert_bool(scale.has_parameter("humidity")).is_false()


func test_shown_has_the_unit_the_decimals_and_the_label() -> void:
	var scale := _scale()
	assert_str(scale.shown("temperature", 30.0)).is_equal("10.0 °C")
	assert_str(scale.shown("temperature", 8.0)).is_equal("-15.0 °C")
	assert_str(scale.shown("oxygen", 2.0)).is_equal("1.5 % atmosfery")
	assert_str(scale.label("temperature", "Temperatura")).is_equal("Średnia temperatura")
	assert_str(scale.label("oxygen", "Tlen")).is_equal("Tlen")


func test_the_chronicle_converts_levels_and_differences() -> void:
	var scale := _scale()
	assert_str(scale.chronicle_number("temperature", "min", 30.0, 0.0)).is_equal("10,0 °C")
	assert_str(scale.chronicle_number("temperature", "change", -8.0, 30.0)).is_equal("-8,5 °C")
	assert_str(scale.chronicle_number("humidity", "mean", 14.25, 50.0)).is_equal("14,3")


func test_effect_ticks_are_known_only_for_measured_actions() -> void:
	var scale := _scale()
	assert_array(scale.effect_ticks("mirrors_warm")).is_equal([1490, 2400])
	assert_array(scale.effect_ticks("seed_species")).is_empty()


func test_errors_are_reported_together() -> void:
	var text := _errors({
		"parameters": {
			"tempreature": {"unit": "°C", "decimals": 0, "points": [[0, 0], [100, 1]]},
			"oxygen": {"unit": "", "decimals": 7, "label": 3, "points": [[0, 0], [100, 1]]},
		},
		"actions": {"nope": {"effect_ticks": [1, 2]}, "mirrors_warm": {"effect_ticks": [9, 3]}},
	})
	assert_str(text).contains("'tempreature': not a parameter of the planet")
	assert_str(text).contains("'unit' must be a non-empty string")
	assert_str(text).contains("'label' must be a string")
	assert_str(text).contains("'decimals' must be a whole number 0..3")
	assert_str(text).contains("'nope': not an intervention")
	assert_str(text).contains("first <= last")


func test_anchor_points_must_increase_and_span_the_scale() -> void:
	assert_str(_points_error([[0, 0]])).contains("'points' must be")
	assert_str(_points_error([[0, 0], [50, 10], [40, 20], [100, 30]])).contains("'points' must be")
	assert_str(_points_error([[0, 30], [50, 10], [100, 40]])).contains("'points' must be")
	assert_str(_points_error([[10, 0], [100, 10]])).contains("'points' must be")
	assert_str(_points_error([[0, 0], [90, 10]])).contains("'points' must be")
	assert_str(_points_error([[0, 0], ["x", 10]])).contains("'points' must be")
	assert_str(_points_error([[0, 0], [100, 10]])).is_empty()


func test_the_file_needs_a_parameters_object() -> void:
	assert_str(_errors({"parameters": []})).contains("'parameters' must be an object")


func test_every_planet_parameter_and_timed_action_is_configured_in_the_project_file() -> void:
	var scale := _project()
	var catalog := I.project_catalog()
	for id in _project_ids():
		assert_bool(scale.has_parameter(String(id))).override_failure_message(
				"parameter '%s' has no player unit in display.json" % id).is_true()
	for id in catalog.ids():
		if catalog.get_def(id).duration > 0:
			assert_array(scale.effect_ticks(String(id))).override_failure_message(
					"timed action '%s' has no effect_ticks in display.json" % id).has_size(2)


func test_the_project_puts_the_start_at_ten_degrees_and_an_ice_age_at_freezing() -> void:
	var scale := _project()
	assert_str(scale.shown("temperature", 30.0)).is_equal("10.0 °C")
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/events/events.json"))
	var found := false
	for event: Dictionary in events["events"]:
		if event["id"] == "ice_age":
			found = true
			# The ice age starts when the mean falls below 0 °C as the player reads it.
			assert_float(scale.to_display("temperature", float(event["trigger"]["condition"]["value"]))).is_equal(0.0)
	assert_bool(found).is_true()


func test_goal_texts_name_parameter_values_in_the_players_units() -> void:
	var scale := _project()
	var goals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/goals/goals.json"))
	var checked := 0
	for ambition: Dictionary in goals["ambitions"]:
		if ambition["kind"] == "parameter":
			checked += 1
			assert_str(ambition["text"]).override_failure_message(
					"ambition '%s' should name its threshold in the player's units" % ambition["id"]).contains(
					scale.chronicle_number(ambition["param"], "value", float(ambition["value"]), 0.0))
	assert_int(checked).is_greater(0)
