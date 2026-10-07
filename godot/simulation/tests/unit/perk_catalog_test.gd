extends GdUnitTestSuite
## PerkCatalog: loading the project perks and rejecting bad data.

const P := preload("res://simulation/tests/support/perk_fixtures.gd")
const I := preload("res://simulation/tests/support/intervention_fixtures.gd")
const Q := preload("res://simulation/tests/support/personality_fixtures.gd")
const E := preload("res://simulation/tests/support/event_fixtures.gd")


func _errors(perks: Array, extra: Dictionary = {}) -> String:
	return "\n".join(P.parse(perks, extra).errors)


func test_project_data_is_valid() -> void:
	var catalog := P.project_catalog()
	assert_int(catalog.ids().size()).is_equal(47)
	assert_array(catalog.branches().map(func(b: Dictionary) -> String: return b["id"])).is_equal(
			["environment", "resistance", "sowing", "production", "shield", "fauna"])
	assert_float(catalog.refund_ratio).is_equal(0.7)
	assert_array(catalog.free_interventions).contains_exactly([&"seed_species"])
	assert_float(catalog.income_per_biomass_tick).is_equal(0.00001)
	var hardy := catalog.get_def(&"res_hardy_1")
	assert_int(hardy.cost).is_equal(4)
	assert_str(String(hardy.source())).is_equal("perk:res_hardy_1")
	assert_array(catalog.get_def(&"perk_volcanic").requires).contains_exactly([&"perk_mirrors_warm"])
	assert_array(catalog.get_def(&"perk_cull").unlocks).contains_exactly([&"cull_species"])


func test_every_intervention_is_free_or_unlocked() -> void:
	var data: Dictionary = CoefficientLoader.read_json(PerkCatalog.DEFAULT_PATH, "perks").value
	var all: Array = data["perks"]
	var ids := I.project_catalog().ids()
	assert_int(ids.size()).is_equal(7)
	assert_bool(PerkCatalog.from_data(data, Q.specs(), ids).is_ok()).is_true()
	var without_cull: Array = all.filter(func(p: Dictionary) -> bool: return p["id"] != "perk_cull")
	var broken := data.duplicate()
	broken["perks"] = without_cull
	var result := PerkCatalog.from_data(broken, Q.specs(), ids)
	assert_bool(result.is_ok()).is_false()
	assert_str("\n".join(result.errors)).contains("cull_species")


func test_rejects_unknown_intervention_references() -> void:
	assert_str(_errors([P.perk("a", {"unlocks": ["teleport"]})])).contains("teleport")
	assert_str(_errors([P.perk("a")], {"free_interventions": ["teleport"]})).contains("teleport")


func test_rejects_unknown_requirement() -> void:
	var errors := _errors([P.perk("a", {"requires": ["ghost"]})])
	assert_str(errors).contains("ghost")
	assert_str(errors).contains("a")


func test_rejects_requirement_cycle() -> void:
	var errors := _errors([P.perk("a", {"requires": ["b"]}), P.perk("b", {"requires": ["a"]})])
	assert_str(errors).contains("cycle")
	assert_str(errors).contains("a")
	assert_str(errors).contains("b")
	assert_str(_errors([P.perk("self", {"requires": ["self"]})])).contains("cycle")


func test_accepts_a_requirement_chain() -> void:
	assert_bool(P.parse([P.perk("a"), P.perk("b", {"requires": ["a"]}), P.perk("c", {"requires": ["a", "b"]})]).is_ok()).is_true()


func test_rejects_bad_modifier_target() -> void:
	var bad := {"modifiers": [{"target": "biosphere.nope", "operation": "multiply", "value": 0.9}]}
	assert_str(_errors([P.perk("a", bad)])).contains("has no coefficient 'nope'")


func test_rejects_duplicate_id() -> void:
	assert_str(_errors([P.perk("a"), P.perk("a")])).contains("duplicate id 'a'")


func test_rejects_unknown_tree() -> void:
	assert_str(_errors([P.perk("a", {"tree": "magic"})])).contains("tree")


func test_rejects_zero_cost() -> void:
	assert_str(_errors([P.perk("a", {"cost": 0})])).contains("cost")
	assert_str(_errors([P.perk("a", {"cost": 2.5})])).contains("cost")


func test_rejects_empty_side_effect() -> void:
	assert_str(_errors([P.perk("a", {"side_effect": ""})])).contains("side_effect")


func test_rejects_perk_without_effect() -> void:
	assert_str(_errors([P.perk("a", {"modifiers": [], "unlocks": []})])).contains("needs at least one modifier or unlock")


func test_rejects_incomplete_story_and_unknown_keys() -> void:
	assert_str(_errors([P.perk("a", {"story": {"bought": "x"}})])).contains("refunded")
	assert_str(_errors([P.perk("a", {"story": {"bought": "x", "refunded": "y", "sold": "z"}})])).contains("sold")
	assert_str(_errors([P.perk("a", {"price": 3})])).contains("price")


func test_rejects_refund_ratio_outside_0_1() -> void:
	assert_str(_errors([P.perk("a")], {"refund_ratio": 1.5})).contains("refund_ratio")
	assert_str(_errors([P.perk("a")], {"refund_ratio": -0.1})).contains("refund_ratio")
	assert_bool(P.parse([P.perk("a")], {"refund_ratio": 1.0}).is_ok()).is_true()


func test_rejects_negative_income() -> void:
	assert_str(_errors([P.perk("a")], {"income_per_biomass_tick": -1.0})).contains("income_per_biomass_tick")


func test_reports_all_errors_at_once() -> void:
	var result := P.parse([P.perk("a", {"tree": "magic"}), P.perk("b", {"cost": 0})])
	assert_int(result.errors.size()).is_greater_equal(2)


func _line(id: String, tier: int, cost: int, extra: Dictionary = {}) -> Dictionary:
	var data := {"line": id.rstrip("_123"), "tier": tier, "cost": cost}
	if tier > 1:
		data["requires"] = ["%s_%d" % [id.rstrip("_123"), tier - 1]]
	data.merge(extra, true)
	return P.perk(id, data)


func test_branches_come_from_the_data_in_order() -> void:
	var catalog := P.catalog([P.perk("a")])
	assert_array(catalog.branches().map(func(b: Dictionary) -> String: return b["id"])).is_equal(["life", "environment"])
	assert_str(catalog.branches()[0]["name"]).is_not_empty()


func test_rejects_an_unknown_branch() -> void:
	assert_str(_errors([P.perk("a", {"tree": "magic"})])).contains("branch").contains("magic")


func test_rejects_bad_branches() -> void:
	assert_str(_errors([P.perk("a")], {"branches": []})).contains("branches")
	assert_str(_errors([P.perk("a")], {"branches": [{"id": "life", "name": "Life", "help": "x"}, {"id": "life", "name": "Again", "help": "y"}]})).contains("duplicate")


func test_a_tier_chain_is_accepted_and_ordered() -> void:
	var catalog := P.catalog([_line("cold_3", 3, 15), _line("cold_1", 1, 5), _line("cold_2", 2, 9)])
	assert_array(catalog.line_of(&"cold").map(func(d: PerkDef) -> int: return d.tier)).is_equal([1, 2, 3])
	assert_array(catalog.get_def(&"cold_2").requires).is_equal([&"cold_1"])


func test_tier_two_must_require_tier_one_of_the_same_line() -> void:
	var loose := _line("cold_2", 2, 9, {"requires": []})
	assert_str(_errors([_line("cold_1", 1, 5), loose])).contains("cold_2").contains("tier 1")


func test_a_tier_needs_the_tier_below_to_exist() -> void:
	assert_str(_errors([_line("cold_2", 2, 9, {"requires": []})])).contains("tier")


func test_tier_costs_must_grow_within_a_line() -> void:
	assert_str(_errors([_line("cold_1", 1, 9), _line("cold_2", 2, 9)])).contains("cost")


func test_rejects_tier_above_three_or_below_one() -> void:
	assert_str(_errors([_line("cold_1", 1, 5), _line("cold_2", 2, 6), _line("cold_3", 3, 7), _line("cold_4", 4, 8)])).contains("tier")
	assert_str(_errors([P.perk("a", {"tier": 0})])).contains("tier")


func test_rejects_two_perks_with_the_same_line_and_tier() -> void:
	assert_str(_errors([_line("cold_1", 1, 5), P.perk("other", {"line": "cold", "tier": 1})])).contains("cold")


func test_income_scale_must_be_a_sensible_fraction() -> void:
	assert_str(_errors([P.perk("a", {"income_scale": 0.0})])).contains("income_scale")
	assert_str(_errors([P.perk("a", {"income_scale": 1.5})])).contains("income_scale")
	assert_bool(P.parse([P.perk("a", {"income_scale": 0.9})]).is_ok()).is_true()


func test_check_species_rejects_an_unknown_species() -> void:
	var catalog := P.catalog([P.perk("a", {"requires_species": ["insects"]})])
	var ok := SimResult.new()
	catalog.check_species([&"insects", &"moss"], ok)
	assert_bool(ok.is_ok()).is_true()
	var bad := SimResult.new()
	catalog.check_species([&"moss"], bad)
	assert_str("\n".join(bad.errors)).contains("insects")


func test_the_project_has_six_branches_each_with_perks() -> void:
	var catalog := P.project_catalog()
	for branch in catalog.branches():
		var in_branch := catalog.defs().filter(func(d: PerkDef) -> bool: return d.tree == StringName(branch["id"]))
		assert_bool(in_branch.size() >= 5).override_failure_message("branch %s has %d perks" % [branch["id"], in_branch.size()]).is_true()


func test_the_resistance_lines_have_three_tiers_where_planned() -> void:
	var catalog := P.project_catalog()
	assert_array(catalog.line_of(&"res_cold").map(func(d: PerkDef) -> StringName: return d.id)).is_equal(
			[&"res_cold_1", &"res_cold_2", &"res_cold_3"])
	assert_array(catalog.get_def(&"res_cold_2").requires).is_equal([&"res_cold_1"])
	assert_array(catalog.get_def(&"res_cold_3").requires).is_equal([&"res_cold_2"])
	assert_array(catalog.line_of(&"res_fire").map(func(d: PerkDef) -> StringName: return d.id)).is_equal(
			[&"res_fire_1", &"res_fire_2"])


func test_shield_perks_slow_the_income() -> void:
	var catalog := P.project_catalog()
	for id: StringName in [&"shield_1", &"shield_2", &"shield_3", &"shield_calm_1", &"shield_calm_2"]:
		assert_float(catalog.get_def(id).income_scale).is_less(1.0)
	assert_float(catalog.get_def(&"res_cold_1").income_scale).is_equal(1.0)


func test_every_perk_carries_a_price_in_the_world() -> void:
	for def in P.project_catalog().defs():
		assert_str(def.side_effect).override_failure_message("%s has no side effect" % def.id).is_not_empty()
		assert_str(def.help).is_not_empty()


func test_event_counters_name_known_perks_or_actions() -> void:
	var perks := P.project_catalog()
	var actions := I.project_catalog()
	var events := E.project_catalog()
	var checked := 0
	for def in events.all():
		for counter in def.warning_counters:
			checked += 1
			assert_bool(perks.get_def(counter) != null or actions.get_def(counter) != null).override_failure_message(
					"%s names unknown counter %s" % [def.id, counter]).is_true()
	assert_int(checked).is_greater(5)


func test_fauna_perks_wait_for_insects_and_the_species_exist() -> void:
	var catalog := P.project_catalog()
	var fauna := catalog.defs().filter(func(d: PerkDef) -> bool: return d.tree == &"fauna")
	assert_int(fauna.size()).is_equal(9)
	for def: PerkDef in fauna:
		assert_array(def.requires_species).is_equal([&"insects"])
	var species := SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value as SpeciesCatalog
	var check := SimResult.new()
	catalog.check_species(species.ids(), check)
	assert_array(Array(check.errors)).is_empty()
	assert_array(catalog.line_of(&"fauna_swarm").map(func(d: PerkDef) -> int: return d.tier)).is_equal([1, 2, 3])
