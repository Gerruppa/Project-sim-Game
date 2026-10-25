extends GdUnitTestSuite
## EventConfig: how severe crises are and how long they rest. Perks turn these
## two numbers; the defaults leave every crisis as written in data.

const E := preload("res://simulation/tests/support/event_fixtures.gd")

var _registry: ModifierRegistry


func before_test() -> void:
	_registry = E.registry()


func _config(severity: float = 1.0, cooldown_scale: float = 1.0) -> EventConfig:
	var result := EventConfig.from_data({"config_version": 1, "severity": severity, "cooldown_scale": cooldown_scale})
	assert_array(Array(result.errors)).is_empty()
	return result.value


func _system(defs: Array, config: EventConfig = null) -> EventSystem:
	return EventSystem.new(E.catalog(defs), &"", config)


func _start_dry(system: EventSystem) -> void:
	system.detect(E.snapshot({"humidity": 15.0}, 1), 1, _registry)
	system.take_events(1)


func test_the_project_config_is_neutral() -> void:
	var loaded := EventConfig.load_json(EventConfig.DEFAULT_PATH)
	assert_array(Array(loaded.errors)).is_empty()
	assert_float((loaded.value as EventConfig).severity).is_equal(1.0)
	assert_float((loaded.value as EventConfig).cooldown_scale).is_equal(1.0)
	assert_float(EventConfig.neutral().severity).is_equal(1.0)


func test_out_of_range_values_are_rejected() -> void:
	assert_str("\n".join(EventConfig.from_data({"config_version": 1, "severity": 1.5, "cooldown_scale": 1.0}).errors)).contains("severity")
	assert_str("\n".join(EventConfig.from_data({"config_version": 1, "severity": 1.0, "cooldown_scale": 0.0}).errors)).contains("cooldown_scale")


func test_severity_pulls_a_multiplier_toward_one() -> void:
	var system := _system([E.def("dry")], _config(0.5))
	_start_dry(system)
	assert_float(_registry.modifiers()[0].value).is_equal_approx(0.75, 1e-9)


func test_severity_scales_an_added_amount() -> void:
	var def := E.def("dry", {"modifiers": [{"target": "climate.base_temperature", "operation": "add", "value": 10.0}]})
	var system := _system([def], _config(0.5))
	_start_dry(system)
	assert_float(_registry.modifiers()[0].value).is_equal_approx(5.0, 1e-9)


func test_full_severity_leaves_the_event_as_written() -> void:
	var system := _system([E.def("dry")], _config(1.0))
	_start_dry(system)
	assert_float(_registry.modifiers()[0].value).is_equal(0.5)


func test_severity_counts_at_the_start_of_the_crisis_only() -> void:
	var system := _system([E.def("dry")], _config(0.5))
	_start_dry(system)
	system.apply_coefficients(_config(1.0))
	assert_float(_registry.modifiers()[0].value).is_equal_approx(0.75, 1e-9)


func test_cooldown_scale_stretches_the_rest_after_a_crisis() -> void:
	var system := _system([E.def("dry", {"cooldown": 100})], _config(1.0, 2.0))
	_start_dry(system)
	system.detect(E.snapshot({"humidity": 35.0}, 2), 2, _registry)
	assert_int(system.save_state()["events"]["dry"]["cooldown_left"]).is_equal(200)


func test_an_event_system_without_config_behaves_as_before() -> void:
	var system := _system([E.def("dry", {"cooldown": 100})])
	_start_dry(system)
	assert_float(_registry.modifiers()[0].value).is_equal(0.5)
	system.detect(E.snapshot({"humidity": 35.0}, 2), 2, _registry)
	assert_int(system.save_state()["events"]["dry"]["cooldown_left"]).is_equal(100)
	assert_object(system.coefficients()).is_null()


func test_a_perk_can_turn_the_severity() -> void:
	var registry := ModifierRegistry.new()
	registry.register_target(&"events", EventConfig.SPEC)
	registry.add(Modifier.new(&"events.severity", &"multiply", 0.5, &"perk:test", Modifier.PERMANENT))
	var effective := registry.resolve(&"events", EventConfig.neutral()) as EventConfig
	assert_float(effective.severity).is_equal(0.5)
