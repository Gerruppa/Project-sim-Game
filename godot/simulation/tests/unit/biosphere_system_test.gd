extends GdUnitTestSuite

const S := preload("res://simulation/tests/support/biosphere_fixtures.gd")
const C := preload("res://simulation/tests/support/climate_fixtures.gd")


func _system(species_list: Array, config: BiosphereConfig = null, seed_value: int = 42) -> BiosphereSystem:
	return BiosphereSystem.new(config if config != null else S.calm(), S.catalog(species_list), seed_value)


## Snapshot whose biomass matches the system's populations.
func _snapshot(system: BiosphereSystem, values: Dictionary = {}) -> PlanetSnapshot:
	var merged := {"biomass": system.biomass_total()}
	merged.merge(values, true)
	return S.snapshot(merged)


func _step(system: BiosphereSystem, values: Dictionary = {}) -> Dictionary:
	return C.by_cause(system.compute(_snapshot(system, values)))


func test_system_id_is_biosphere() -> void:
	assert_str(_system([S.species("moss")]).system_id()).is_equal("biosphere")


func test_life_arises_spontaneously_where_suitable() -> void:
	var system := _system([S.species("bacteria")])
	_step(system)
	assert_float(system.population(&"bacteria")).is_greater(0.0)


func test_nothing_arises_where_unsuitable() -> void:
	var system := _system([S.species("bacteria")])
	_step(system, {"temperature": 0.0})
	assert_float(system.population(&"bacteria")).is_equal(0.0)


func test_species_needs_its_precursor_to_appear() -> void:
	# Algae cannot live at 30 degrees here, so moss has no precursor yet.
	var system := _system([S.species("algae", {"t_min": 60.0, "t_max": 90.0}),
			S.species("moss", {"emerges_from": "algae"})])
	_step(system)
	assert_float(system.population(&"moss")).is_equal(0.0)
	system.set_population(&"algae", 50.0)
	_step(system)
	assert_float(system.population(&"moss")).is_greater(0.0)


func test_population_grows_logistically_toward_capacity() -> void:
	var system := _system([S.species("moss", {"seed": 0.0, "base_mortality": 0.0})])
	system.set_population(&"moss", 10.0)
	_step(system)
	assert_float(system.population(&"moss")).is_greater(10.0)
	system.set_population(&"moss", 95.0)
	_step(system)
	assert_float(system.population(&"moss")).is_less(95.0)


func test_bad_environment_kills() -> void:
	var system := _system([S.species("moss", {"seed": 0.0})])
	system.set_population(&"moss", 50.0)
	_step(system, {"temperature": 2.0})
	assert_float(system.population(&"moss")).is_less(50.0)


func test_taller_species_shade_lower_layers() -> void:
	var shaded := _system([S.species("moss", {"layer": 1, "shade": 0.5, "seed": 0.0}),
			S.species("tree", {"layer": 3, "seed": 0.0, "weight": 0.2})])
	var open := _system([S.species("moss", {"layer": 1, "shade": 0.5, "seed": 0.0})])
	for system: BiosphereSystem in [shaded, open]:
		system.set_population(&"moss", 60.0)
	shaded.set_population(&"tree", 100.0)
	_step(shaded)
	_step(open)
	# Capacity 80 halves to 40 under full canopy: moss shrinks there, grows in the open.
	assert_float(shaded.population(&"moss")).is_less(60.0)
	assert_float(open.population(&"moss")).is_greater(60.0)


func test_soil_and_water_layer_is_not_shaded() -> void:
	var system := _system([S.species("algae", {"layer": 0, "shade": 1.0, "seed": 0.0}),
			S.species("tree", {"layer": 3, "seed": 0.0})])
	system.set_population(&"algae", 40.0)
	system.set_population(&"tree", 100.0)
	_step(system)
	assert_float(system.population(&"algae")).is_greater(40.0)


func test_biomass_follows_weighted_populations() -> void:
	var system := _system([S.species("moss", {"weight": 0.2, "seed": 0.0})])
	system.set_population(&"moss", 20.0)
	var before := system.biomass_total()
	var causes := _step(system)
	var biomass_change := 0.0
	for key: String in causes:
		if key.begins_with("biomass:"):
			biomass_change += causes[key]
	assert_float(biomass_change).is_equal_approx(system.biomass_total() - before, 1e-12)
	assert_bool(causes.has("biomass:moss_growth")).is_true()


func test_census_corrects_biomass_that_drifted() -> void:
	var system := _system([S.species("moss", {"seed": 0.0})])
	system.set_population(&"moss", 20.0)
	var causes := C.by_cause(system.compute(S.snapshot({"biomass": 50.0})))
	assert_float(causes["biomass:census"]).is_equal_approx(system.biomass_total() - 50.0 - causes.get("biomass:moss_growth", 0.0), 1e-9)


func test_photosynthesis_trades_co2_for_oxygen() -> void:
	var system := _system([S.species("algae", {"oxygen": 0.08, "co2_uptake": 0.03, "seed": 0.0})])
	system.set_population(&"algae", 50.0)
	var causes := _step(system)
	assert_float(causes["oxygen:algae_photosynthesis"]).is_greater(0.0)
	assert_float(causes["co2:algae_photosynthesis"]).is_less(0.0)


func test_high_oxygen_slows_photosynthesis() -> void:
	var low := _system([S.species("algae", {"oxygen": 0.08, "seed": 0.0})])
	var high := _system([S.species("algae", {"oxygen": 0.08, "seed": 0.0})])
	low.set_population(&"algae", 50.0)
	high.set_population(&"algae", 50.0)
	var produced_low: float = _step(low, {"oxygen": 10.0})["oxygen:algae_photosynthesis"]
	var produced_high: float = _step(high, {"oxygen": 50.0})["oxygen:algae_photosynthesis"]
	assert_float(produced_high).is_less(produced_low)


func test_respiration_uses_oxygen_and_returns_co2() -> void:
	var system := _system([S.species("moss", {"respiration": 0.02, "seed": 0.0})])
	system.set_population(&"moss", 50.0)
	var causes := _step(system, {"oxygen": 10.0})
	assert_float(causes["oxygen:moss_respiration"]).is_less(0.0)
	assert_float(causes["co2:moss_respiration"]).is_greater(0.0)


func test_plants_transpire_water() -> void:
	var system := _system([S.species("tree", {"transpiration": 0.08, "seed": 0.0})])
	system.set_population(&"tree", 50.0)
	assert_float(_step(system)["humidity:tree_transpiration"]).is_greater(0.0)


func test_high_oxygen_burns_flammable_plants() -> void:
	var fiery := S.config({"growth_noise": 0.0})
	var forest := _system([S.species("tree", {"flammable": 1.0, "seed": 0.0, "o2_need": 0.0})], fiery)
	var calm_forest := _system([S.species("tree", {"flammable": 1.0, "seed": 0.0, "o2_need": 0.0})], fiery)
	forest.set_population(&"tree", 50.0)
	calm_forest.set_population(&"tree", 50.0)
	var causes := _step(forest, {"oxygen": 45.0, "humidity": 15.0})
	var calm_causes := _step(calm_forest, {"oxygen": 10.0, "humidity": 15.0})
	assert_float(causes["oxygen:tree_wildfire"]).is_less(0.0)
	assert_float(causes["co2:tree_wildfire"]).is_greater(0.0)
	assert_bool(calm_causes.has("oxygen:tree_wildfire")).is_false()
	assert_float(forest.population(&"tree")).is_less(calm_forest.population(&"tree"))


func test_anaerobes_retreat_to_refuge_but_survive() -> void:
	var system := _system([S.species("bacteria", {"o2_max": 12.0, "o2_refuge": 0.15, "capacity": 60.0})])
	system.set_population(&"bacteria", 50.0)
	for tick in 3000:
		_step(system, {"oxygen": 30.0})
	var population := system.population(&"bacteria")
	assert_float(population).is_greater(1.0)
	assert_float(population).is_less(60.0 * 0.15 + 0.5)


func test_extinction_and_emergence_are_reported_as_events() -> void:
	var system := _system([S.species("moss", {"seed": 0.0, "stress_mortality": 0.9})])
	system.set_population(&"moss", 5.0)
	for tick in 20:
		_step(system, {"temperature": 0.0})
	assert_float(system.population(&"moss")).is_equal(0.0)
	var types := system.take_events(1).map(func(event: SimEvent) -> String: return String(event.type))
	assert_array(types).contains(["species_extinct"])

	var growing := _system([S.species("bacteria", {"growth": 0.5, "seed": 0.5})])
	for tick in 20:
		_step(growing)
	var emerged := growing.take_events(1)
	assert_str(emerged[0].type).is_equal("species_emerged")
	assert_str(emerged[0].data["species"]).is_equal("bacteria")


func test_populations_stay_on_scale() -> void:
	var system := _system([S.species("weed", {"growth": 1.0, "seed": 1.0, "capacity": 100.0})])
	for tick in 200:
		_step(system)
	assert_float(system.population(&"weed")).is_less_equal(100.0)


func test_never_touches_climate_owned_or_geology_parameters() -> void:
	var system := _system([S.species("tree", {"transpiration": 0.1, "flammable": 1.0})], S.config())
	system.set_population(&"tree", 50.0)
	for delta in system.compute(_snapshot(system, {"oxygen": 45.0})):
		assert_bool(delta.parameter in [Param.TEMPERATURE, Param.CLOUD_COVER, Param.PRECIPITATION, Param.CRUST_OXIDATION]).is_false()
		assert_str(delta.source).is_equal("biosphere")


func test_same_seed_gives_same_populations() -> void:
	var a := _system([S.species("moss")], S.config(), 7)
	var b := _system([S.species("moss")], S.config(), 7)
	for tick in 300:
		_step(a)
		_step(b)
	assert_float(a.population(&"moss")).is_equal(b.population(&"moss"))
