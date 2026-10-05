extends GdUnitTestSuite

const C := preload("res://simulation/tests/support/climate_fixtures.gd")

## Neutral planet: temperature at base, humidity and clouds at reference values.
const NEUTRAL := {"temperature": 37.0, "humidity": 40.0, "cloud_cover": 40.0, "precipitation": 0.0, "biomass": 0.0}


func _causes(values: Dictionary, config: ClimateConfig = null, tick: int = 0) -> Dictionary:
	var merged := NEUTRAL.duplicate()
	merged.merge(values, true)
	var system := ClimateSystem.new(config if config != null else C.calm(), 42)
	return C.by_cause(system.compute(C.snapshot(merged, tick)))


func test_system_id_is_climate() -> void:
	assert_str(ClimateSystem.new(C.calm(), 1).system_id()).is_equal("climate")


func test_season_wave_is_a_triangle_between_minus_one_and_one() -> void:
	assert_float(ClimateSystem.season_wave(0, 360)).is_equal(-1.0)
	assert_float(ClimateSystem.season_wave(90, 360)).is_equal(0.0)
	assert_float(ClimateSystem.season_wave(180, 360)).is_equal(1.0)
	assert_float(ClimateSystem.season_wave(270, 360)).is_equal(0.0)
	assert_float(ClimateSystem.season_wave(360, 360)).is_equal(-1.0)


func test_cold_planet_relaxes_toward_base_temperature() -> void:
	assert_float(_causes({"temperature": 32.0})["temperature:radiative_balance"]).is_greater(0.0)


func test_hot_planet_relaxes_toward_base_temperature() -> void:
	assert_float(_causes({"temperature": 60.0})["temperature:radiative_balance"]).is_less(0.0)


func test_ice_cools_only_a_cold_planet() -> void:
	assert_float(_causes({"temperature": 5.0})["temperature:ice_albedo"]).is_less(0.0)
	assert_bool(_causes({"temperature": 50.0}).has("temperature:ice_albedo")).is_false()


func test_cooling_fades_near_absolute_cold() -> void:
	# Soft floor: the temperature scale's lower limit is approached, not hit.
	var near_zero: float = _causes({"temperature": 1.0})["temperature:ice_albedo"]
	var deep_ice: float = _causes({"temperature": 10.0})["temperature:ice_albedo"]
	assert_float(near_zero).is_less(0.0)
	assert_float(absf(near_zero)).is_less(absf(deep_ice) * 0.5)


func test_soft_floor_does_not_reduce_warming() -> void:
	var cold: float = _causes({"temperature": 1.0})["temperature:radiative_balance"]
	var config := C.calm()
	assert_float(cold).is_equal_approx(config.thermal_response * (config.base_temperature - 1.0), 1e-12)


func test_clouds_above_reference_cool_the_planet() -> void:
	assert_float(_causes({"cloud_cover": 80.0})["temperature:cloud_albedo"]).is_less(0.0)
	assert_float(_causes({"cloud_cover": 10.0})["temperature:cloud_albedo"]).is_greater(0.0)


func test_vegetation_warms_only_when_biomass_exists() -> void:
	assert_bool(_causes({}).has("temperature:vegetation_albedo")).is_false()
	assert_float(_causes({"biomass": 50.0})["temperature:vegetation_albedo"]).is_greater(0.0)


func test_water_vapor_acts_as_greenhouse() -> void:
	assert_float(_causes({"humidity": 70.0})["temperature:greenhouse"]).is_greater(0.0)
	assert_float(_causes({"humidity": 10.0})["temperature:greenhouse"]).is_less(0.0)


func test_season_warms_in_summer_and_cools_in_winter() -> void:
	var seasonal := C.config({"drift_noise": 0.0})
	assert_float(_causes({}, seasonal, 180)["temperature:season"]).is_greater(0.0)
	assert_float(_causes({}, seasonal, 0)["temperature:season"]).is_less(0.0)


func test_warm_dry_air_evaporates_water() -> void:
	assert_float(_causes({"temperature": 50.0, "humidity": 10.0})["humidity:evaporation"]).is_greater(0.0)


func test_frozen_planet_does_not_evaporate() -> void:
	assert_bool(_causes({"temperature": 0.0, "humidity": 10.0}).has("humidity:evaporation")).is_false()


func test_rain_removes_humidity() -> void:
	assert_float(_causes({"temperature": 40.0, "precipitation": 30.0})["humidity:rainfall"]).is_less(0.0)


func test_cold_precipitation_is_snow() -> void:
	var causes := _causes({"temperature": 10.0, "precipitation": 30.0})
	assert_float(causes["humidity:snowfall"]).is_less(0.0)
	assert_bool(causes.has("humidity:rainfall")).is_false()


func test_humid_air_condenses_into_clouds() -> void:
	assert_float(_causes({"temperature": 20.0, "humidity": 40.0, "cloud_cover": 10.0})["cloud_cover:condensation"]).is_greater(0.0)


func test_dry_air_dissipates_clouds() -> void:
	assert_float(_causes({"temperature": 50.0, "humidity": 5.0, "cloud_cover": 60.0})["cloud_cover:dissipation"]).is_less(0.0)


func test_heavy_clouds_in_humid_air_form_rain() -> void:
	assert_float(_causes({"temperature": 20.0, "humidity": 40.0, "cloud_cover": 90.0})["precipitation:rain_forming"]).is_greater(0.0)


func test_clear_sky_ends_rain() -> void:
	assert_float(_causes({"cloud_cover": 5.0, "precipitation": 40.0})["precipitation:rain_easing"]).is_less(0.0)


func test_never_touches_oxygen_or_biomass() -> void:
	var system := ClimateSystem.new(C.config(), 42)
	for tick in 50:
		for delta in system.compute(C.snapshot({"biomass": 30.0, "precipitation": 20.0}, tick)):
			assert_bool(delta.parameter in [Param.OXYGEN, Param.BIOMASS]).is_false()
			assert_str(delta.source).is_equal("climate")


func test_zero_amounts_are_not_emitted() -> void:
	for delta in ClimateSystem.new(C.calm(), 42).compute(C.snapshot(NEUTRAL)):
		assert_bool(delta.amount != 0.0).is_true()


func test_same_seed_gives_same_deltas() -> void:
	var a := ClimateSystem.new(C.config(), 7)
	var b := ClimateSystem.new(C.config(), 7)
	for tick in 100:
		assert_array(_amounts(a.compute(C.snapshot(NEUTRAL, tick)))).is_equal(_amounts(b.compute(C.snapshot(NEUTRAL, tick))))


func test_different_seeds_drift_differently() -> void:
	var a := ClimateSystem.new(C.config(), 1)
	var b := ClimateSystem.new(C.config(), 2)
	for tick in 20:
		a.compute(C.snapshot(NEUTRAL, tick))
		b.compute(C.snapshot(NEUTRAL, tick))
	assert_float(a.drift()).is_not_equal(b.drift())


func test_drift_stays_within_limit() -> void:
	var config := C.config({"drift_noise": 5.0, "drift_reversion": 0.0})
	var system := ClimateSystem.new(config, 3)
	for tick in 2000:
		system.compute(C.snapshot(NEUTRAL, tick))
		assert_float(absf(system.drift())).is_less_equal(config.drift_limit)


func _amounts(deltas: Array[Delta]) -> Array[float]:
	var amounts: Array[float] = []
	for delta in deltas:
		amounts.append(delta.amount)
	return amounts


func test_exposes_coefficients_for_modifiers() -> void:
	var config := C.calm()
	var system := ClimateSystem.new(config, 1)
	assert_object(system.coefficients()).is_same(config)
	assert_dict(system.coefficient_spec()).is_equal(ClimateConfig.SPEC)


func test_uses_effective_coefficients() -> void:
	var system := ClimateSystem.new(C.config({"drift_noise": 0.0}), 1)
	system.apply_coefficients(C.config({"drift_noise": 0.0, "season_amplitude": 0.0}))
	assert_bool(C.by_cause(system.compute(C.snapshot(NEUTRAL, 0))).has("temperature:season")).is_false()


func test_save_and_load_continue_the_same_drift_and_noise() -> void:
	var first := ClimateSystem.new(C.config(), 42)
	for tick in 5:
		first.compute(C.snapshot(NEUTRAL, tick))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(first.save_state()))
	var restored := ClimateSystem.new(C.config(), 7)
	assert_array(Array(restored.load_state(saved).errors)).is_empty()
	for tick in range(5, 10):
		var expected := C.by_cause(first.compute(C.snapshot(NEUTRAL, tick)))
		assert_dict(C.by_cause(restored.compute(C.snapshot(NEUTRAL, tick)))).is_equal(expected)
	assert_bool(restored.drift() == first.drift()).is_true()


func test_load_rejects_damaged_state() -> void:
	var saved := ClimateSystem.new(C.config(), 42).save_state()
	var system := ClimateSystem.new(C.config(), 42)
	assert_bool(system.load_state({}).is_ok()).is_false()
	var bad_rng := saved.duplicate()
	bad_rng["rng_state"] = 12.5
	assert_bool(system.load_state(bad_rng).is_ok()).is_false()
	var bad_drift := saved.duplicate()
	bad_drift["drift_exact"] = ExactCodec.floats_to_text(PackedFloat64Array([1.0, 2.0]))
	assert_bool(system.load_state(bad_drift).is_ok()).is_false()
