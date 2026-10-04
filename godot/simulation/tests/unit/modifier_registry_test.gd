extends GdUnitTestSuite


class Coefficients:
	var rate: float
	var limit: float
	var period: int


const SPEC := {"rate": [0.0, 10.0, false], "limit": [0.0, 20.0, false], "period": [2.0, 1000.0, true]}

var _registry: ModifierRegistry
var _base: Coefficients


func before_test() -> void:
	_registry = ModifierRegistry.new()
	_registry.register_target(&"climate", SPEC)
	_base = Coefficients.new()
	_base.rate = 2.0
	_base.limit = 10.0
	_base.period = 360


func _mod(target: String, operation: StringName, value: float, source: String = "test", expires_at: int = -1) -> Modifier:
	return Modifier.new(StringName(target), operation, value, StringName(source), expires_at)


func _resolved() -> Coefficients:
	return _registry.resolve(&"climate", _base)


func test_adds_then_multiplies() -> void:
	_registry.add(_mod("climate.limit", Modifier.MULTIPLY, 1.5))
	_registry.add(_mod("climate.limit", Modifier.ADD, 2.0))
	assert_float(_resolved().limit).is_equal(18.0)


func test_unmodified_fields_are_copied_and_base_stays_intact() -> void:
	_registry.add(_mod("climate.rate", Modifier.MULTIPLY, 2.0))
	var resolved := _resolved()
	assert_float(resolved.rate).is_equal(4.0)
	assert_float(resolved.limit).is_equal(10.0)
	assert_int(resolved.period).is_equal(360)
	assert_float(_base.rate).is_equal(2.0)
	assert_object(resolved).is_not_same(_base)


func test_result_clamps_to_spec_range() -> void:
	_registry.add(_mod("climate.limit", Modifier.MULTIPLY, 5.0))
	assert_float(_resolved().limit).is_equal(20.0)


func test_integer_coefficients_stay_integers() -> void:
	_registry.add(_mod("climate.period", Modifier.MULTIPLY, 1.5))
	assert_int(_resolved().period).is_equal(540)


func test_order_of_registration_does_not_change_bits() -> void:
	# Premise: float multiplication is not associative.
	assert_bool(2.0 * 1.1 * 1.3 * 0.7 * 1.9 == 2.0 * 1.9 * 0.7 * 1.3 * 1.1).is_false()
	var values := [1.1, 1.3, 0.7, 1.9]
	var first := ModifierRegistry.new()
	var second := ModifierRegistry.new()
	first.register_target(&"climate", SPEC)
	second.register_target(&"climate", SPEC)
	for i in values.size():
		first.add(_mod("climate.rate", Modifier.MULTIPLY, values[i], "s%d" % i))
		second.add(_mod("climate.rate", Modifier.MULTIPLY, values[values.size() - 1 - i], "s%d" % (values.size() - 1 - i)))
	var a: Coefficients = first.resolve(&"climate", _base)
	var b: Coefficients = second.resolve(&"climate", _base)
	assert_bool(a.rate == b.rate).is_true()


func test_rejects_unknown_targets_and_bad_values() -> void:
	assert_str("\n".join(_registry.add(_mod("ocean.rate", Modifier.ADD, 1.0)).errors)).contains("ocean")
	assert_str("\n".join(_registry.add(_mod("climate.speed", Modifier.ADD, 1.0)).errors)).contains("speed")
	assert_str("\n".join(_registry.add(_mod("climate", Modifier.ADD, 1.0)).errors)).contains("climate")
	assert_bool(_registry.add(_mod("climate.rate", &"power", 1.0)).is_ok()).is_false()
	assert_bool(_registry.add(_mod("climate.rate", Modifier.ADD, NAN)).is_ok()).is_false()
	assert_int(_registry.modifiers().size()).is_equal(0)


func test_knows_registered_systems() -> void:
	assert_bool(_registry.has_target(&"climate")).is_true()
	assert_bool(_registry.has_target(&"biosphere")).is_false()


func test_version_changes_only_when_modifiers_change() -> void:
	var start := _registry.version()
	_registry.add(_mod("climate.rate", Modifier.ADD, 1.0))
	var after_add := _registry.version()
	assert_int(after_add).is_greater(start)
	_registry.expire(100)
	assert_int(_registry.version()).is_equal(after_add)


func test_temporary_modifiers_expire() -> void:
	_registry.add(_mod("climate.rate", Modifier.ADD, 1.0, "drought", 5))
	_registry.add(_mod("climate.rate", Modifier.ADD, 2.0, "personality"))
	assert_int(_registry.expire(4)).is_equal(0)
	assert_int(_registry.expire(5)).is_equal(1)
	assert_float(_resolved().rate).is_equal(4.0)


func test_modifiers_can_be_removed_by_source() -> void:
	_registry.add(_mod("climate.rate", Modifier.ADD, 1.0, "personality:chaotic"))
	_registry.add(_mod("climate.limit", Modifier.ADD, 1.0, "personality:chaotic"))
	_registry.add(_mod("climate.rate", Modifier.ADD, 1.0, "other"))
	assert_int(_registry.remove_source(&"personality:chaotic")).is_equal(2)
	assert_int(_registry.modifiers().size()).is_equal(1)
