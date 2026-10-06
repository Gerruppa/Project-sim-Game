extends GdUnitTestSuite
## LifeZones: the colour of a planet value comes from the species that live
## here or may come next, never from one fixed target.

const S := preload("res://simulation/tests/support/biosphere_fixtures.gd")


func _species(id: String, overrides: Dictionary = {}) -> SpeciesData:
	return S.catalog([S.species(id, overrides)]).all()[0]


func _list(entries: Array) -> Array[SpeciesData]:
	var result: Array[SpeciesData] = []
	for entry: SpeciesData in entries:
		result.append(entry)
	return result


func test_temperature_is_green_in_the_range_amber_in_the_margin_red_outside() -> void:
	# The fixture species lives at 10..50 with a margin of 5.
	var life := _list([_species("moss")])
	assert_str(LifeZones.zone(&"temperature", 30.0, life)).is_equal("good")
	assert_str(LifeZones.zone(&"temperature", 10.0, life)).is_equal("good")
	assert_str(LifeZones.zone(&"temperature", 7.0, life)).is_equal("poor")
	assert_str(LifeZones.zone(&"temperature", 52.0, life)).is_equal("poor")
	assert_str(LifeZones.zone(&"temperature", 4.0, life)).is_equal("bad")
	assert_str(LifeZones.zone(&"temperature", 60.0, life)).is_equal("bad")


func test_the_best_species_decides() -> void:
	var life := _list([_species("a", {"t_min": 10.0, "t_max": 20.0, "t_margin": 2.0}),
			_species("b", {"t_min": 40.0, "t_max": 60.0, "t_margin": 2.0})])
	assert_str(LifeZones.zone(&"temperature", 15.0, life)).is_equal("good")
	assert_str(LifeZones.zone(&"temperature", 50.0, life)).is_equal("good")
	assert_str(LifeZones.zone(&"temperature", 30.0, life)).is_equal("bad")
	assert_str(LifeZones.zone(&"temperature", 61.0, life)).is_equal("poor")


func test_water_has_no_upper_limit_and_uses_the_species_water_source() -> void:
	var wet := _list([_species("moss", {"water": "humidity", "water_min": 20.0, "water_margin": 8.0})])
	assert_str(LifeZones.zone(&"humidity", 90.0, wet)).is_equal("good")
	assert_str(LifeZones.zone(&"humidity", 15.0, wet)).is_equal("poor")
	assert_str(LifeZones.zone(&"humidity", 5.0, wet)).is_equal("bad")
	# Nothing here drinks rain, so rainfall gets no colour.
	assert_str(LifeZones.zone(&"precipitation", 0.0, wet)).is_equal("none")


func test_a_parameter_no_species_limits_has_no_colour() -> void:
	var life := _list([_species("moss")])
	assert_str(LifeZones.zone(&"co2", 0.0, life)).is_equal("none")
	assert_str(LifeZones.zone(&"oxygen", 99.0, life)).is_equal("none")
	assert_str(LifeZones.zone(&"cloud_cover", 50.0, life)).is_equal("none")
	assert_str(LifeZones.zone(&"temperature", 20.0, _list([]))).is_equal("none")


func test_oxygen_is_needed_by_some_and_poison_to_anaerobes() -> void:
	var plant := _list([_species("moss", {"o2_need": 10.0})])
	assert_str(LifeZones.zone(&"oxygen", 12.0, plant)).is_equal("good")
	assert_str(LifeZones.zone(&"oxygen", 7.0, plant)).is_equal("poor")
	assert_str(LifeZones.zone(&"oxygen", 3.0, plant)).is_equal("bad")
	var anaerobe := _list([_species("bacteria", {"o2_max": 12.0})])
	assert_str(LifeZones.zone(&"oxygen", 5.0, anaerobe)).is_equal("good")
	assert_str(LifeZones.zone(&"oxygen", 20.0, anaerobe)).is_equal("poor")
	assert_str(LifeZones.zone(&"oxygen", 30.0, anaerobe)).is_equal("bad")


func test_co2_and_soil_are_floors() -> void:
	var life := _list([_species("moss", {"co2_need": 8.0, "biomass_need": 12.0})])
	assert_str(LifeZones.zone(&"co2", 40.0, life)).is_equal("good")
	assert_str(LifeZones.zone(&"co2", 5.0, life)).is_equal("poor")
	assert_str(LifeZones.zone(&"co2", 0.0, life)).is_equal("bad")
	assert_str(LifeZones.zone(&"biomass", 12.0, life)).is_equal("good")
	assert_str(LifeZones.zone(&"biomass", 7.0, life)).is_equal("poor")
	assert_str(LifeZones.zone(&"biomass", 2.0, life)).is_equal("bad")


func test_the_zone_follows_the_succession() -> void:
	var catalog := S.catalog([S.species("first", {"t_min": 5.0, "t_max": 70.0}),
			S.species("second", {"t_min": 20.0, "t_max": 45.0, "emerges_from": "first"}),
			S.species("third", {"t_min": 30.0, "t_max": 40.0, "emerges_from": "second"})])
	var biosphere := BiosphereSystem.new(S.calm(), catalog, 1)
	# Nothing lives yet: only the species that needs no precursor counts.
	assert_array(LifeZones.relevant(biosphere).map(func(s: SpeciesData) -> String: return String(s.id))).is_equal(["first"])
	biosphere.set_population(&"first", 20.0)
	assert_array(LifeZones.relevant(biosphere).map(func(s: SpeciesData) -> String: return String(s.id))).is_equal(["first", "second"])
	biosphere.set_population(&"second", 20.0)
	assert_array(LifeZones.relevant(biosphere).map(func(s: SpeciesData) -> String: return String(s.id))).is_equal(["first", "second", "third"])
	# A species that dies out is no longer alive but can come back (it needs no
	# precursor); the third one stays a candidate while the second lives.
	biosphere.set_population(&"first", 0.0)
	biosphere.set_population(&"second", 0.0)
	assert_array(LifeZones.relevant(biosphere).map(func(s: SpeciesData) -> String: return String(s.id))).is_equal(["first"])
