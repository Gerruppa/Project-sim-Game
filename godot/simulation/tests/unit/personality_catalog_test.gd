extends GdUnitTestSuite

const Q := preload("res://simulation/tests/support/personality_fixtures.gd")


func _errors(archetypes: Array) -> String:
	return "\n".join(PersonalityCatalog.from_data(Q.catalog_data(archetypes), Q.specs()).errors)


func test_project_catalog_has_three_archetypes() -> void:
	var result := PersonalityCatalog.load_json(PersonalityCatalog.DEFAULT_PATH, Q.specs())
	assert_array(Array(result.errors)).is_empty()
	assert_array((result.value as PersonalityCatalog).ids()).is_equal([&"harmonious", &"chaotic", &"guardian"])


func test_archetype_keeps_its_modifiers() -> void:
	var chaotic := Q.project_catalog().get_archetype(&"chaotic")
	assert_bool(chaotic.description.is_empty()).is_false()
	var targets := chaotic.modifiers.map(func(m: Dictionary) -> String: return m["target"])
	assert_array(targets).contains(["climate.drift_noise", "atmosphere.volcanic_co2", "biosphere.fire_rate"])


func test_rejects_unknown_target() -> void:
	assert_str(_errors([Q.archetype("odd", [{"target": "climate.drift_nosie", "operation": "multiply", "value": 2.0}])])).contains("drift_nosie")
	assert_str(_errors([Q.archetype("odd", [{"target": "ocean.level", "operation": "add", "value": 1.0}])])).contains("ocean")


func test_rejects_bad_operation_or_value() -> void:
	assert_str(_errors([Q.archetype("odd", [{"target": "climate.drift_noise", "operation": "power", "value": 2.0}])])).contains("operation")
	assert_str(_errors([Q.archetype("odd", [{"target": "climate.drift_noise", "operation": "add", "value": "x"}])])).contains("value")


func test_rejects_duplicate_and_reserved_ids() -> void:
	assert_str(_errors([Q.archetype("calm"), Q.archetype("calm")])).contains("duplicate")
	assert_str(_errors([Q.archetype("none")])).contains("reserved")
	assert_str(_errors([Q.archetype("random")])).contains("reserved")


func test_rejects_non_positive_weight() -> void:
	assert_str(_errors([Q.archetype("calm", [], {"weight": 0})])).contains("weight")


func test_rejects_empty_catalog() -> void:
	assert_bool(PersonalityCatalog.from_data(Q.catalog_data([]), Q.specs()).is_ok()).is_false()
