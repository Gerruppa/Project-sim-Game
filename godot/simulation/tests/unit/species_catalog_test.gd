extends GdUnitTestSuite

const S := preload("res://simulation/tests/support/biosphere_fixtures.gd")


func _errors(species_list: Array) -> String:
	return "\n".join(SpeciesCatalog.from_data(S.catalog_data(species_list)).errors)


func test_project_catalog_climbs_from_bacteria_to_large_mammals() -> void:
	var result := SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH)
	assert_array(Array(result.errors)).is_empty()
	var catalog: SpeciesCatalog = result.value
	assert_array(catalog.ids()).is_equal([&"bacteria", &"algae", &"moss", &"shrub", &"tree", &"insects", &"small_animals", &"large_mammals"])
	assert_str(catalog.get_species(&"insects").food).is_equal("moss")
	assert_str(catalog.get_species(&"small_animals").food).is_equal("shrub")
	assert_str(catalog.get_species(&"large_mammals").food).is_equal("tree")
	assert_str(catalog.get_species(&"large_mammals").emerges_from).is_equal("small_animals")
	assert_bool(catalog.get_species(&"insects").pollinator > 0.0).is_true()
	for id: StringName in [&"insects", &"small_animals", &"large_mammals"]:
		assert_float(catalog.get_species(id).weight).is_equal(0.0)
	assert_str(catalog.get_species(&"tree").emerges_from).is_equal("shrub")
	assert_str(catalog.get_species(&"bacteria").emerges_from).is_equal("")


func test_project_weights_keep_biomass_on_scale() -> void:
	var catalog: SpeciesCatalog = SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value
	var total := 0.0
	for species in catalog.all():
		total += species.weight
	assert_float(total).is_less_equal(1.0)


func test_rejects_duplicate_id() -> void:
	assert_str(_errors([S.species("moss"), S.species("moss")])).contains("duplicate")


func test_rejects_unknown_water_source() -> void:
	assert_str(_errors([S.species("moss", {"water": "rivers"})])).contains("water")


func test_rejects_unknown_precursor() -> void:
	assert_str(_errors([S.species("moss", {"emerges_from": "lichen"})])).contains("lichen")


func test_rejects_succession_cycle() -> void:
	var errors := _errors([S.species("a", {"emerges_from": "b"}), S.species("b", {"emerges_from": "a"})])
	assert_str(errors).contains("cycle")


func test_rejects_inverted_temperature_window() -> void:
	assert_str(_errors([S.species("moss", {"t_min": 40.0, "t_max": 20.0})])).contains("t_min")


func test_rejects_weights_above_one_in_total() -> void:
	assert_str(_errors([S.species("a", {"weight": 0.7}), S.species("b", {"weight": 0.6})])).contains("weight")


func test_rejects_unknown_and_missing_fields() -> void:
	assert_str(_errors([S.species("moss", {"colour": 1.0})])).contains("colour")
	var broken := S.species("moss")
	broken.erase("growth")
	assert_str(_errors([broken])).contains("growth")


func test_rejects_empty_catalog() -> void:
	assert_bool(SpeciesCatalog.from_data(S.catalog_data([])).is_ok()).is_false()


func test_suitability_follows_temperature_window() -> void:
	var moss: SpeciesData = S.catalog([S.species("moss")]).get_species(&"moss")
	assert_float(moss.suitability(S.snapshot({"temperature": 30.0}))).is_equal(1.0)
	assert_float(moss.suitability(S.snapshot({"temperature": 2.0}))).is_equal(0.0)
	assert_float(moss.suitability(S.snapshot({"temperature": 60.0}))).is_equal(0.0)


func test_suitability_uses_the_species_water_source() -> void:
	var shrub: SpeciesData = S.catalog([S.species("shrub", {"water": "precipitation", "water_min": 10.0})]).get_species(&"shrub")
	assert_float(shrub.suitability(S.snapshot({"humidity": 80.0, "precipitation": 0.0}))).is_equal(0.0)
	assert_float(shrub.suitability(S.snapshot({"humidity": 5.0, "precipitation": 30.0}))).is_equal(1.0)


func test_suitability_requires_oxygen_co2_and_soil_when_asked() -> void:
	var tree: SpeciesData = S.catalog([S.species("tree", {"o2_need": 18.0, "co2_need": 8.0, "biomass_need": 20.0})]).get_species(&"tree")
	assert_float(tree.suitability(S.snapshot({"oxygen": 0.0, "biomass": 30.0}))).is_equal(0.0)
	assert_float(tree.suitability(S.snapshot({"oxygen": 30.0, "biomass": 0.0}))).is_equal(0.0)
	assert_float(tree.suitability(S.snapshot({"oxygen": 30.0, "biomass": 30.0, "co2": 0.0}))).is_equal(0.0)
	assert_float(tree.suitability(S.snapshot({"oxygen": 30.0, "biomass": 30.0}))).is_equal(1.0)


func test_oxygen_shrinks_anaerobes_to_their_refuge() -> void:
	var bacteria: SpeciesData = S.catalog([S.species("bacteria", {"o2_max": 12.0, "o2_refuge": 0.15})]).get_species(&"bacteria")
	assert_float(bacteria.oxygen_capacity_factor(0.0)).is_equal(1.0)
	assert_float(bacteria.oxygen_capacity_factor(30.0)).is_equal(0.15)
	assert_float(S.catalog([S.species("moss")]).get_species(&"moss").oxygen_capacity_factor(90.0)).is_equal(1.0)


func test_limiting_factor_is_the_weakest_requirement() -> void:
	var catalog := SpeciesCatalog.from_data({"catalog_version": 1, "species": [
			preload("res://simulation/tests/support/biosphere_fixtures.gd").species("moss", {"co2_need": 20.0})]}).value as SpeciesCatalog
	var moss := catalog.get_species(&"moss")
	var S := preload("res://simulation/tests/support/biosphere_fixtures.gd")
	assert_str(moss.limiting_factor(S.snapshot({"temperature": 60.0}))).is_equal("heat")
	assert_str(moss.limiting_factor(S.snapshot({"temperature": 3.0}))).is_equal("cold")
	assert_str(moss.limiting_factor(S.snapshot({"humidity": 6.0}))).is_equal("drought")
	assert_str(moss.limiting_factor(S.snapshot({"co2": 2.0}))).is_equal("co2_starvation")
