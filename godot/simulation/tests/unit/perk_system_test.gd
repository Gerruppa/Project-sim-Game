extends GdUnitTestSuite
## PerkSystem: Sparks balance, buying and refunding, permanent modifiers,
## income from biomass, unlocks and saving.

const P := preload("res://simulation/tests/support/perk_fixtures.gd")
const I := preload("res://simulation/tests/support/intervention_fixtures.gd")
const C := preload("res://simulation/tests/support/climate_fixtures.gd")

var _registry: ModifierRegistry


func before_test() -> void:
	_registry = I.registry()


func _hardy() -> Dictionary:
	return P.perk("perk_hardy", {"cost": 4, "modifiers": [
			{"target": "biosphere.stress_scale", "operation": "multiply", "value": 0.8}]})


## hardy (4) <- fast (10, requires hardy), plain (10).
func _system(extra: Array = []) -> PerkSystem:
	var perks: Array = [_hardy(), P.perk("perk_fast", {"cost": 10, "requires": ["perk_hardy"]}), P.perk("perk_plain", {"cost": 10})]
	perks.append_array(extra)
	return PerkSystem.new(P.catalog(perks))


func _command(action: StringName, args: Dictionary = {}, tick: int = 1) -> SimCommand:
	return SimCommand.new(tick, PerkSystem.ID, action, args)


func _grant(system: PerkSystem, amount: float) -> void:
	system.apply_command(_command(PerkSystem.ACTION_GRANT, {"amount": amount}))
	system.take_events(1)


func _buy(system: PerkSystem, perk: String) -> void:
	system.apply_command(_command(PerkSystem.ACTION_BUY, {"perk": perk}))


func _refund(system: PerkSystem, perk: String) -> void:
	system.apply_command(_command(PerkSystem.ACTION_REFUND, {"perk": perk}))


## Phase 2 of one tick.
func _tick(system: PerkSystem, biomass: float = 0.0, tick: int = 1) -> void:
	system.provide_modifiers(C.snapshot({Param.BIOMASS: biomass}), tick, _registry)
	_registry.expire(tick - 1)


func _types(events: Array[SimEvent]) -> Array:
	return events.map(func(event: SimEvent) -> String: return String(event.type))


func _errors(result: SimResult) -> String:
	return "\n".join(result.errors)


func test_grant_adds_sparks_and_emits_event() -> void:
	var system := _system()
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_GRANT, {"amount": 2.5, "source": "bubble"})).is_ok()).is_true()
	system.apply_command(_command(PerkSystem.ACTION_GRANT, {"amount": 2.5, "source": "bubble"}))
	system.apply_command(_command(PerkSystem.ACTION_GRANT, {"amount": 3}))
	assert_float(system.sparks()).is_equal(5.5)
	var events := system.take_events(1)
	assert_array(_types(events)).is_equal(["sparks_granted", "sparks_granted"])
	assert_float(events[0].data["amount"]).is_equal(2.5)
	assert_str(events[0].data["source"]).is_equal("bubble")
	assert_bool(events[0].data.has("story")).is_false()


func test_grant_rejects_zero_negative_nan_and_over_100() -> void:
	var system := _system()
	for bad: Variant in [0.0, -1.0, NAN, INF, 100.5, "5", null]:
		assert_bool(system.validate_command(_command(PerkSystem.ACTION_GRANT, {"amount": bad})).is_ok()).is_false()
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_GRANT, {})).is_ok()).is_false()
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_GRANT, {"amount": 1.0, "extra": 1})).is_ok()).is_false()
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_GRANT, {"amount": 100.0})).is_ok()).is_true()
	# A command that slipped past validation changes nothing and says so.
	system.apply_command(_command(PerkSystem.ACTION_GRANT, {"amount": NAN}))
	assert_float(system.sparks()).is_equal(0.0)
	assert_array(_types(system.take_events(1))).is_equal(["perk_rejected"])


func test_unknown_action_and_perk_are_refused() -> void:
	var system := _system()
	assert_str(_errors(system.validate_command(_command(&"sell")))).contains("unknown perk action")
	assert_str(_errors(system.validate_command(_command(PerkSystem.ACTION_BUY, {"perk": "perk_x"})))).contains("perk_hardy")
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_BUY, {})).is_ok()).is_false()


func test_buy_needs_enough_sparks() -> void:
	var system := _system()
	_grant(system, 2.5)
	var result := system.validate_command(_command(PerkSystem.ACTION_BUY, {"perk": "perk_hardy"}))
	assert_bool(result.is_ok()).is_false()
	assert_str(_errors(result)).contains("brakuje 2 Iskier")
	_buy(system, "perk_hardy")
	assert_bool(system.owns(&"perk_hardy")).is_false()
	assert_float(system.sparks()).is_equal(2.5)


func test_buy_needs_requirements() -> void:
	var system := _system()
	_grant(system, 50.0)
	var result := system.validate_command(_command(PerkSystem.ACTION_BUY, {"perk": "perk_fast"}))
	assert_bool(result.is_ok()).is_false()
	assert_str(_errors(result)).contains("Test perk_hardy")
	assert_array(system.missing_requirements(&"perk_fast")).is_equal([&"perk_hardy"])
	_buy(system, "perk_hardy")
	assert_array(system.missing_requirements(&"perk_fast")).is_empty()
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_BUY, {"perk": "perk_fast"})).is_ok()).is_true()


func test_cannot_buy_owned_perk() -> void:
	var system := _system()
	_grant(system, 50.0)
	_buy(system, "perk_hardy")
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_BUY, {"perk": "perk_hardy"})).is_ok()).is_false()
	_buy(system, "perk_hardy")
	assert_float(system.sparks()).is_equal(46.0)
	assert_array(system.owned()).is_equal([&"perk_hardy"])


func test_buy_spends_sparks_and_registers_permanent_modifiers() -> void:
	var system := _system()
	_grant(system, 6.0)
	_buy(system, "perk_hardy")
	assert_float(system.sparks()).is_equal(2.0)
	assert_bool(system.owns(&"perk_hardy")).is_true()
	var event := system.take_events(1)[0]
	assert_str(String(event.type)).is_equal("perk_bought")
	assert_str(event.data["story"]).is_equal("perk_hardy bought.")
	assert_int(_registry.modifiers().size()).is_equal(0)
	_tick(system)
	assert_int(_registry.modifiers().size()).is_equal(1)
	var modifier := _registry.modifiers()[0]
	assert_str(String(modifier.target)).is_equal("biosphere.stress_scale")
	assert_str(String(modifier.operation)).is_equal("multiply")
	assert_float(modifier.value).is_equal(0.8)
	assert_str(String(modifier.source)).is_equal("perk:perk_hardy")
	assert_int(modifier.expires_at).is_equal(Modifier.PERMANENT)
	_tick(system, 0.0, 2)
	_tick(system, 0.0, 500)
	assert_int(_registry.modifiers().size()).is_equal(1)


func test_two_buys_in_one_tick_cannot_overspend() -> void:
	var system := _system()
	_grant(system, 4.0)
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_BUY, {"perk": "perk_hardy"})).is_ok()).is_true()
	_buy(system, "perk_hardy")
	system.take_events(1)
	system.apply_command(_command(PerkSystem.ACTION_BUY, {"perk": "perk_hardy"}))
	assert_array(_types(system.take_events(1))).is_equal(["perk_rejected"])
	assert_float(system.sparks()).is_equal(0.0)
	# Two different perks for the same money: the second is rejected with a story.
	var other := _system()
	_grant(other, 10.0)
	_buy(other, "perk_plain")
	_buy(other, "perk_hardy")
	var events := other.take_events(1)
	assert_array(_types(events)).is_equal(["perk_bought", "perk_rejected"])
	assert_str(events[1].data["story"]).contains("Test perk_hardy").contains("brakuje 4 Iskier")
	assert_float(other.sparks()).is_equal(0.0)


func test_queued_buy_meets_requirements_checked_again() -> void:
	var system := _system()
	_grant(system, 50.0)
	_buy(system, "perk_fast")
	assert_array(_types(system.take_events(1))).is_equal(["perk_rejected"])
	assert_float(system.sparks()).is_equal(50.0)
	assert_array(system.owned()).is_empty()


func test_refund_returns_floor_of_ratio_and_removes_modifiers() -> void:
	var system := _system()
	_grant(system, 10.0)
	_buy(system, "perk_plain")
	system.take_events(1)
	_tick(system)
	_refund(system, "perk_plain")
	assert_float(system.sparks()).is_equal(7.0)
	assert_bool(system.owns(&"perk_plain")).is_false()
	var event := system.take_events(1)[0]
	assert_str(String(event.type)).is_equal("perk_refunded")
	assert_str(event.data["story"]).is_equal("perk_plain refunded.")
	assert_int(_registry.modifiers().size()).is_equal(1)
	_tick(system, 0.0, 2)
	assert_int(_registry.modifiers().size()).is_equal(0)
	# 4 * 0.7 = 2.8 -> 2.
	_buy(system, "perk_hardy")
	_refund(system, "perk_hardy")
	assert_float(system.sparks()).is_equal(5.0)


func test_refund_in_the_tick_of_the_buy_registers_nothing() -> void:
	var system := _system()
	_grant(system, 10.0)
	_buy(system, "perk_hardy")
	_refund(system, "perk_hardy")
	_tick(system)
	assert_int(_registry.modifiers().size()).is_equal(0)


func test_refund_refused_while_another_owned_perk_requires_it() -> void:
	var system := _system()
	_grant(system, 50.0)
	_buy(system, "perk_hardy")
	_buy(system, "perk_fast")
	var result := system.validate_command(_command(PerkSystem.ACTION_REFUND, {"perk": "perk_hardy"}))
	assert_bool(result.is_ok()).is_false()
	assert_str(_errors(result)).contains("Test perk_fast")
	system.take_events(1)
	_refund(system, "perk_hardy")
	assert_array(_types(system.take_events(1))).is_equal(["perk_rejected"])
	assert_bool(system.owns(&"perk_hardy")).is_true()
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_REFUND, {"perk": "perk_plain"})).is_ok()).is_false()
	_refund(system, "perk_fast")
	assert_bool(system.validate_command(_command(PerkSystem.ACTION_REFUND, {"perk": "perk_hardy"})).is_ok()).is_true()


func test_unlocks_follow_ownership() -> void:
	var ids := I.project_catalog().ids()
	var paid: Array[StringName] = ids.filter(func(id: StringName) -> bool: return id != &"cull_species")
	var perks: Array = [P.perk("perk_cull", {"cost": 6, "modifiers": [], "unlocks": ["cull_species"]})]
	var system := PerkSystem.new(P.catalog(perks, {"free_interventions": paid.map(func(id: StringName) -> String: return String(id))}))
	assert_bool(system.unlocks(&"seed_species")).is_true()
	assert_bool(system.unlocks(&"cull_species")).is_false()
	assert_object(system.unlocking_perk(&"seed_species")).is_null()
	assert_str(String(system.unlocking_perk(&"cull_species").id)).is_equal("perk_cull")
	_grant(system, 6.0)
	_buy(system, "perk_cull")
	assert_bool(system.unlocks(&"cull_species")).is_true()
	_refund(system, "perk_cull")
	assert_bool(system.unlocks(&"cull_species")).is_false()


func test_owned_returns_a_copy_in_purchase_order() -> void:
	var system := _system()
	_grant(system, 50.0)
	_buy(system, "perk_plain")
	_buy(system, "perk_hardy")
	var list := system.owned()
	assert_array(list).is_equal([&"perk_plain", &"perk_hardy"])
	list.clear()
	assert_array(system.owned()).has_size(2)


func test_income_accrues_from_biomass() -> void:
	var system := _system()
	for tick in range(1, 1001):
		_tick(system, 50.0, tick)
	assert_float(system.sparks()).is_equal_approx(50.0 * 1000.0 * system.catalog().income_per_biomass_tick, 1e-9)
	assert_float(system.sparks()).is_greater(0.0)
	var barren := _system()
	_tick(barren, 0.0)
	assert_float(barren.sparks()).is_equal(0.0)
	assert_array(_types(system.take_events(1))).is_empty()


func test_save_and_load_roundtrip_is_exact() -> void:
	var system := _system()
	_grant(system, 30.0)
	_buy(system, "perk_hardy")
	_buy(system, "perk_plain")
	for tick in range(1, 8):
		_tick(system, 33.3, tick)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(system.save_state()))
	var restored := _system()
	assert_bool(restored.load_state(saved).is_ok()).is_true()
	assert_bool(restored.sparks() == system.sparks()).is_true()
	assert_array(restored.owned()).is_equal([&"perk_hardy", &"perk_plain"])
	assert_bool(restored.sparks() != floorf(restored.sparks())).is_true()
	var fresh := I.registry()
	restored.restore_modifiers(fresh)
	assert_int(fresh.modifiers().size()).is_equal(2)
	assert_str(String(fresh.modifiers()[0].source)).is_equal("perk:perk_hardy")
	restored.restore_modifiers(fresh)
	assert_int(fresh.modifiers().size()).is_equal(2)


func test_load_rejects_unknown_perk_and_bad_format() -> void:
	var system := _system()
	_grant(system, 5.0)
	var good := system.save_state()
	var sparks_text: String = good["sparks"]
	var bad_states: Array[Dictionary] = [
		{"format": "other", "sparks": sparks_text, "owned": []},
		{"format": PerkSystem.FORMAT, "sparks": sparks_text, "owned": ["perk_missing"]},
		{"format": PerkSystem.FORMAT, "sparks": sparks_text, "owned": ["perk_hardy", "perk_hardy"]},
		{"format": PerkSystem.FORMAT, "sparks": sparks_text, "owned": ["perk_fast"]},
		{"format": PerkSystem.FORMAT, "sparks": sparks_text, "owned": [3]},
		{"format": PerkSystem.FORMAT, "sparks": sparks_text, "owned": "perk_hardy"},
		{"format": PerkSystem.FORMAT, "sparks": 5.0, "owned": []},
		{"format": PerkSystem.FORMAT, "sparks": ExactCodec.floats_to_text(PackedFloat64Array([NAN])), "owned": []},
		{"format": PerkSystem.FORMAT, "sparks": ExactCodec.floats_to_text(PackedFloat64Array([-1.0])), "owned": []},
		{"format": PerkSystem.FORMAT, "sparks": ExactCodec.floats_to_text(PackedFloat64Array([1.0, 2.0])), "owned": []},
		{"format": PerkSystem.FORMAT, "owned": []},
	]
	for state in bad_states:
		var target := _system()
		assert_bool(target.load_state(state).is_ok()).is_false()
		assert_float(target.sparks()).is_equal(0.0)
		assert_array(target.owned()).is_empty()
	assert_str(_errors(_system().load_state(bad_states[1]))).contains("perk_missing")
