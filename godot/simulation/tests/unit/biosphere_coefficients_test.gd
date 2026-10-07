extends GdUnitTestSuite
## The coefficients perks turn: tolerance of cold, heat and drought, the amount
## a seeding adds, natural seeding, capacity and photosynthesis. Their defaults
## change nothing.

const B := preload("res://simulation/tests/support/biosphere_fixtures.gd")


## Lives at 20-35 (margin 8), water 22+ (margin 8); grows fast, seeds itself.
func _moss() -> Dictionary:
	return B.species("moss", {"t_min": 20.0, "t_max": 35.0, "t_margin": 8.0, "water_min": 22.0, "water_margin": 8.0,
			"growth": 0.05, "seed": 0.01, "oxygen": 0.1, "capacity": 80.0})


func _system(config_overrides: Dictionary = {}) -> BiosphereSystem:
	return BiosphereSystem.new(B.calm(config_overrides), B.catalog([_moss()]), 1)


func _moss_data() -> SpeciesData:
	return B.catalog([_moss()]).get_species(&"moss")


func test_zero_tolerances_change_nothing() -> void:
	var moss := _moss_data()
	var snapshot := B.snapshot({"temperature": 17.0, "humidity": 18.0})
	assert_float(moss.suitability(snapshot, 0.0, 0.0, 0.0)).is_equal(moss.suitability(snapshot))
	assert_str(String(moss.limiting_factor(snapshot, 0.0, 0.0, 0.0))).is_equal(String(moss.limiting_factor(snapshot)))


func test_cold_tolerance_moves_the_cold_edge() -> void:
	var moss := _moss_data()
	var snapshot := B.snapshot({"temperature": 17.0, "humidity": 40.0})
	assert_float(moss.suitability(snapshot)).is_less(0.8)
	assert_float(moss.suitability(snapshot, 3.0)).is_equal_approx(1.0, 1e-9)


func test_heat_tolerance_moves_the_hot_edge() -> void:
	var moss := _moss_data()
	var snapshot := B.snapshot({"temperature": 38.0, "humidity": 40.0})
	assert_float(moss.suitability(snapshot)).is_less(0.8)
	assert_float(moss.suitability(snapshot, 0.0, 3.0)).is_equal_approx(1.0, 1e-9)


func test_drought_tolerance_lowers_the_water_need() -> void:
	var moss := _moss_data()
	var snapshot := B.snapshot({"temperature": 28.0, "humidity": 18.0})
	assert_float(moss.suitability(snapshot)).is_less(0.8)
	assert_float(moss.suitability(snapshot, 0.0, 0.0, 4.0)).is_equal_approx(1.0, 1e-9)


func test_the_system_reads_tolerances_from_its_coefficients() -> void:
	var snapshot := B.snapshot({"temperature": 17.0, "humidity": 40.0})
	assert_float(_system().fit_of(&"moss", snapshot)).is_less(0.8)
	assert_float(_system({"cold_tolerance": 3.0}).fit_of(&"moss", snapshot)).is_equal_approx(1.0, 1e-9)
	var tolerant := _system({"cold_tolerance": 3.0, "heat_tolerance": 2.0, "drought_tolerance": 1.0})
	assert_vector(tolerant.tolerance()).is_equal(Vector3(3.0, 2.0, 1.0))


func _seed(system: BiosphereSystem, amount: float) -> void:
	system.apply_command(SimCommand.new(1, BiosphereSystem.ID, &"add_population", {"species": "moss", "amount": amount}))


func test_seeding_adds_amount_times_seed_scale() -> void:
	var plain := _system()
	_seed(plain, 5.0)
	assert_float(plain.population(&"moss")).is_equal(5.0)
	var scaled := _system({"seed_scale": 1.4})
	_seed(scaled, 5.0)
	assert_float(scaled.population(&"moss")).is_equal_approx(7.0, 1e-9)


func test_seeding_never_passes_the_top_of_the_scale() -> void:
	var scaled := _system({"seed_scale": 2.0})
	_seed(scaled, 80.0)
	assert_float(scaled.population(&"moss")).is_equal(100.0)


## Population after `ticks` computes on a fixed, perfect planet.
func _grow(system: BiosphereSystem, ticks: int) -> float:
	var snapshot := B.snapshot({"temperature": 28.0, "humidity": 40.0})
	for i in ticks:
		system.compute(snapshot)
	return system.population(&"moss")


func test_capacity_scale_sets_how_much_life_fits() -> void:
	var full := _system()
	full.set_population(&"moss", 20.0)
	var half := _system({"capacity_scale": 0.5})
	half.set_population(&"moss", 20.0)
	assert_float(_grow(half, 2500)).is_less(_grow(full, 2500) * 0.7)


func test_natural_seed_scale_speeds_up_emergence() -> void:
	var slow := _system()
	var fast := _system({"natural_seed_scale": 5.0})
	var snapshot := B.snapshot({"temperature": 28.0, "humidity": 40.0})
	var slow_at := -1
	var fast_at := -1
	for tick in 3000:
		slow.compute(snapshot)
		fast.compute(snapshot)
		if slow_at == -1 and slow.population(&"moss") >= 1.0:
			slow_at = tick
		if fast_at == -1 and fast.population(&"moss") >= 1.0:
			fast_at = tick
	assert_int(fast_at).is_greater(-1)
	assert_bool(slow_at == -1 or fast_at < slow_at).is_true()


func _oxygen_from_photosynthesis(system: BiosphereSystem) -> float:
	var total := 0.0
	for delta in system.compute(B.snapshot({"temperature": 28.0, "humidity": 40.0})):
		if delta.parameter == Param.OXYGEN and String(delta.cause).ends_with("_photosynthesis"):
			total += delta.amount
	return total


func test_photosynthesis_scale_multiplies_the_oxygen_made() -> void:
	var plain := _system()
	plain.set_population(&"moss", 50.0)
	var boosted := _system({"photosynthesis_scale": 1.5})
	boosted.set_population(&"moss", 50.0)
	assert_float(_oxygen_from_photosynthesis(boosted)).is_equal_approx(_oxygen_from_photosynthesis(plain) * 1.5, 1e-9)


func test_the_new_coefficients_are_validated() -> void:
	for name: String in ["cold_tolerance", "heat_tolerance", "drought_tolerance"]:
		assert_str("\n".join(BiosphereConfig.from_data(B.config_data({name: 41.0})).errors)).contains(name)
	for name: String in ["seed_scale", "natural_seed_scale", "photosynthesis_scale"]:
		assert_str("\n".join(BiosphereConfig.from_data(B.config_data({name: -1.0})).errors)).contains(name)
	assert_str("\n".join(BiosphereConfig.from_data(B.config_data({"capacity_scale": 0.0})).errors)).contains("capacity_scale")
