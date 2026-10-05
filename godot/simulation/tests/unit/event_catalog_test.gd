extends GdUnitTestSuite
## EventCatalog: loading and validating world event definitions.

const E := preload("res://simulation/tests/support/event_fixtures.gd")


func _errors(overrides: Dictionary) -> PackedStringArray:
	return E.parse([E.def("x", overrides)]).errors


func test_project_catalog_is_valid() -> void:
	var result := EventCatalog.load_json(EventCatalog.DEFAULT_PATH, E.P.project_schema(), E.Q.specs(), E.ARCHETYPES)
	assert_array(Array(result.errors)).is_empty()
	assert_array((result.value as EventCatalog).ids()).contains([&"drought", &"guardian_healing"])


func test_project_reactions_belong_to_their_archetype() -> void:
	var healing := E.project_catalog().get_def(&"guardian_healing")
	assert_bool(healing.applies_to(&"guardian")).is_true()
	assert_bool(healing.applies_to(&"chaotic")).is_false()
	assert_bool(E.project_catalog().get_def(&"drought").applies_to(&"none")).is_true()


func test_reads_a_definition() -> void:
	var def := E.catalog([E.def("x", {"personality": ["guardian"], "min_duration": 5, "cooldown": 7,
			"trigger": {"condition": {"measure": "mean", "param": "humidity", "window": 40, "op": "<", "value": 20}, "for_ticks": 3}})]).get_def(&"x")
	assert_str(def.name).is_equal("Test x")
	assert_array(def.personality).is_equal([&"guardian"])
	assert_int(def.trigger_ticks).is_equal(3)
	assert_int(def.min_duration).is_equal(5)
	assert_int(def.cooldown).is_equal(7)
	assert_int(def.required_samples()).is_equal(40)
	assert_float(def.modifiers[0]["value"]).is_equal(0.5)


func test_rejects_missing_or_bad_fields() -> void:
	assert_bool(_errors({"id": ""}).is_empty()).is_false()
	assert_bool(_errors({"name": 3}).is_empty()).is_false()
	assert_bool(_errors({"max_duration": 0}).is_empty()).is_false()
	assert_bool(_errors({"min_duration": 10, "max_duration": 10}).is_empty()).is_false()
	assert_bool(_errors({"cooldown": -1}).is_empty()).is_false()
	assert_bool(_errors({"cooldown": 1.5}).is_empty()).is_false()
	assert_bool(_errors({"trigger": {"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 1}, "for_ticks": 0}}).is_empty()).is_false()
	assert_bool(_errors({"end": "humidity > 30"}).is_empty()).is_false()
	assert_bool(_errors({"severity": 2}).is_empty()).is_false()


func test_every_event_tells_its_story() -> void:
	var def := E.catalog([E.def("x")]).get_def(&"x")
	assert_str(def.story["start"]).is_equal("x begins.")
	assert_str(def.story["end_time_limit"]).is_equal("x fades out.")
	assert_bool(_errors({"story": "It rains."}).is_empty()).is_false()
	assert_bool(_errors({"story": {"start": "a", "end": "b"}}).is_empty()).is_false()
	assert_bool(_errors({"story": {"start": "a", "end": "", "end_time_limit": "c"}}).is_empty()).is_false()
	assert_bool(_errors({"story": {"start": "a", "end": "b", "end_time_limit": "c", "middle": "d"}}).is_empty()).is_false()
	var data := E.def("x")
	data.erase("story")
	assert_bool(E.parse([data]).is_ok()).is_false()


func test_event_must_act_through_known_modifiers() -> void:
	assert_bool(_errors({"modifiers": []}).is_empty()).is_false()
	assert_bool(_errors({"modifiers": [{"target": "climate.rain", "operation": "multiply", "value": 1}]}).is_empty()).is_false()
	assert_bool(_errors({"modifiers": [{"target": "climate.water_availability", "operation": "set", "value": 1}]}).is_empty()).is_false()


func test_rejects_unknown_archetypes() -> void:
	assert_bool(_errors({"personality": ["guardain"]}).is_empty()).is_false()
	assert_bool(_errors({"personality": "guardian"}).is_empty()).is_false()


func test_rejects_duplicate_ids() -> void:
	assert_bool(E.parse([E.def("x"), E.def("x")]).is_ok()).is_false()


func test_reports_all_errors_at_once() -> void:
	var result := E.parse([E.def("a", {"name": ""}), E.def("b", {"cooldown": -1, "modifiers": []})])
	assert_int(result.errors.size()).is_greater_equal(3)


func test_empty_catalog_is_allowed() -> void:
	assert_bool(E.parse([]).is_ok()).is_true()
	assert_bool(EventCatalog.from_data({}, E.P.project_schema(), E.Q.specs(), E.ARCHETYPES).is_ok()).is_false()
