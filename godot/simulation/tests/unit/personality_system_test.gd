extends GdUnitTestSuite

const Q := preload("res://simulation/tests/support/personality_fixtures.gd")
const C := preload("res://simulation/tests/support/climate_fixtures.gd")

var _registry: ModifierRegistry


func before_test() -> void:
	_registry = ModifierRegistry.new()
	for id: StringName in Q.specs():
		_registry.register_target(id, Q.specs()[id])


func _create(choice: StringName, seed_value: int = 42, catalog: PersonalityCatalog = null) -> PersonalitySystem:
	var result := PersonalitySystem.create(catalog if catalog != null else Q.project_catalog(), choice, seed_value)
	assert_array(Array(result.errors)).is_empty()
	return result.value


func _provide(system: PersonalitySystem, tick: int = 1) -> void:
	system.provide_modifiers(C.snapshot({}), tick, _registry)


func test_none_adds_nothing_and_says_nothing() -> void:
	var system := _create(PersonalityCatalog.NONE)
	_provide(system)
	assert_str(system.archetype_id()).is_equal("none")
	assert_int(_registry.modifiers().size()).is_equal(0)
	assert_array(system.take_events(1)).is_empty()


func test_forced_archetype_registers_its_modifiers_once() -> void:
	var system := _create(&"chaotic")
	_provide(system, 1)
	_provide(system, 2)
	assert_str(system.archetype_id()).is_equal("chaotic")
	var expected := Q.project_catalog().get_archetype(&"chaotic").modifiers.size()
	assert_int(_registry.modifiers().size()).is_equal(expected)
	for modifier in _registry.modifiers():
		assert_str(modifier.source).is_equal("personality:chaotic")
		assert_int(modifier.expires_at).is_equal(Modifier.PERMANENT)


func test_personality_is_announced_once() -> void:
	var system := _create(&"guardian")
	_provide(system, 1)
	var events := system.take_events(1)
	_provide(system, 2)
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].type).is_equal("planet_personality")
	assert_str(events[0].data["archetype"]).is_equal("guardian")
	assert_array(system.take_events(2)).is_empty()


func test_random_choice_is_deterministic_per_seed() -> void:
	assert_str(_create(PersonalityCatalog.RANDOM, 9).archetype_id()).is_equal(_create(PersonalityCatalog.RANDOM, 9).archetype_id())


func test_random_choice_draws_every_archetype_across_seeds() -> void:
	var seen := {}
	for seed_value in range(1, 40):
		seen[_create(PersonalityCatalog.RANDOM, seed_value).archetype_id()] = true
	assert_int(seen.size()).is_equal(3)
	assert_bool(seen.has(&"none")).is_false()


func test_weights_steer_the_random_choice() -> void:
	var catalog := Q.catalog([Q.archetype("common", [], {"weight": 1000}), Q.archetype("rare", [], {"weight": 1})])
	var rare := 0
	for seed_value in range(1, 60):
		rare += 1 if _create(PersonalityCatalog.RANDOM, seed_value, catalog).archetype_id() == &"rare" else 0
	assert_int(rare).is_less_equal(2)


func test_unknown_archetype_is_an_error() -> void:
	assert_bool(PersonalitySystem.create(Q.project_catalog(), &"grumpy", 1).is_ok()).is_false()


func test_modifiers_for_absent_systems_are_skipped() -> void:
	# A climate-only planet has no biosphere: its modifiers have nothing to change.
	var climate_only := ModifierRegistry.new()
	climate_only.register_target(&"climate", ClimateConfig.SPEC)
	var system := _create(&"harmonious")
	system.provide_modifiers(C.snapshot({}), 1, climate_only)
	for modifier in climate_only.modifiers():
		assert_str(modifier.system_id()).is_equal("climate")
	assert_int(climate_only.modifiers().size()).is_equal(2)


func test_returns_no_deltas() -> void:
	assert_array(_create(&"chaotic").compute(C.snapshot({}))).is_empty()
