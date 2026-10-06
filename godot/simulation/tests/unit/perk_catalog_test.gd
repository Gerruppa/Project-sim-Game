extends GdUnitTestSuite
## PerkCatalog: loading the project perks and rejecting bad data.

const P := preload("res://simulation/tests/support/perk_fixtures.gd")
const I := preload("res://simulation/tests/support/intervention_fixtures.gd")
const Q := preload("res://simulation/tests/support/personality_fixtures.gd")


func _errors(perks: Array, extra: Dictionary = {}) -> String:
	return "\n".join(P.parse(perks, extra).errors)


func test_project_data_is_valid() -> void:
	var catalog := P.project_catalog()
	assert_int(catalog.ids().size()).is_equal(10)
	assert_float(catalog.refund_ratio).is_equal(0.7)
	assert_array(catalog.free_interventions).contains_exactly([&"seed_species"])
	assert_float(catalog.income_per_biomass_tick).is_equal(0.00001)
	var hardy := catalog.get_def(&"perk_hardy")
	assert_int(hardy.cost).is_equal(4)
	assert_str(String(hardy.source())).is_equal("perk:perk_hardy")
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
