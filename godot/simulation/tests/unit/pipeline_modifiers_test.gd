extends GdUnitTestSuite
## Tick phase 2: modifier providers run, then effective coefficients are applied
## before any system computes.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

var _state: PlanetState
var _pipeline: TickPipeline
var _system: TestScaledSystem
var _provider: TestModifierProvider


func before_test() -> void:
	_state = PlanetState.create(P.project_schema(), {"temperature": 10.0}).value
	_pipeline = TickPipeline.new(_state, EventBus.new())
	_system = TestScaledSystem.new(1.0)
	_provider = TestModifierProvider.new()
	# Provider registered after the system on purpose: phase 2 still runs first.
	_pipeline.register(_system, 1)
	_pipeline.register(_provider, 1)


func _temperature() -> float:
	return _state.get_value(Param.TEMPERATURE)


func test_without_modifiers_systems_use_base_coefficients() -> void:
	_pipeline.execute(1)
	assert_float(_temperature()).is_equal(11.0)


func test_modifier_applies_from_the_tick_it_is_added() -> void:
	_provider.schedule[2] = [Modifier.new(&"scaled.amount", Modifier.MULTIPLY, 3.0, &"test")]
	_pipeline.execute(1)
	_pipeline.execute(2)
	_pipeline.execute(3)
	assert_float(_temperature()).is_equal(10.0 + 1.0 + 3.0 + 3.0)


func test_temporary_modifier_stops_after_its_last_tick() -> void:
	_provider.schedule[1] = [Modifier.new(&"scaled.amount", Modifier.ADD, 4.0, &"test", 2)]
	for tick in range(1, 5):
		_pipeline.execute(tick)
	assert_float(_temperature()).is_equal(10.0 + 5.0 + 5.0 + 1.0 + 1.0)


func test_base_coefficients_are_never_changed() -> void:
	_provider.schedule[1] = [Modifier.new(&"scaled.amount", Modifier.MULTIPLY, 3.0, &"test")]
	_pipeline.execute(1)
	assert_float(_system.base_config.amount).is_equal(1.0)


func test_registry_knows_registered_coefficients() -> void:
	assert_bool(_pipeline.modifier_registry().add(Modifier.new(&"scaled.amount", Modifier.ADD, 1.0, &"x")).is_ok()).is_true()
	assert_bool(_pipeline.modifier_registry().add(Modifier.new(&"scaled.speed", Modifier.ADD, 1.0, &"x")).is_ok()).is_false()
