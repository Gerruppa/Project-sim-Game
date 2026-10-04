extends GdUnitTestSuite

const A := preload("res://simulation/tests/support/atmosphere_fixtures.gd")
const C := preload("res://simulation/tests/support/climate_fixtures.gd")

## Warm, rainy planet with CO2 at the reference level and some oxygen.
const BASE := {"temperature": 35.0, "humidity": 30.0, "precipitation": 20.0, "co2": 40.0,
		"oxygen": 10.0, "crust_oxidation": 0.0}


func _causes(values: Dictionary, config: AtmosphereConfig = null) -> Dictionary:
	var merged := BASE.duplicate()
	merged.merge(values, true)
	var system := AtmosphereSystem.new(config if config != null else A.config())
	return C.by_cause(system.compute(C.snapshot(merged)))


func test_system_id_is_atmosphere() -> void:
	assert_str(AtmosphereSystem.new(A.config()).system_id()).is_equal("atmosphere")


func test_volcanoes_always_add_co2() -> void:
	assert_float(_causes({})["co2:volcanic_outgassing"]).is_equal(A.config().volcanic_co2)
	assert_float(_causes({"temperature": 2.0})["co2:volcanic_outgassing"]).is_equal(A.config().volcanic_co2)


func test_weathering_removes_co2_when_warm() -> void:
	assert_float(_causes({})["co2:silicate_weathering"]).is_less(0.0)


func test_rain_speeds_up_weathering() -> void:
	var dry: float = _causes({"precipitation": 0.0})["co2:silicate_weathering"]
	var wet: float = _causes({"precipitation": 60.0})["co2:silicate_weathering"]
	assert_float(wet).is_less(dry)


func test_frozen_planet_stops_weathering() -> void:
	# Under ice CO2 can only accumulate: this is how ice ages end.
	assert_bool(_causes({"temperature": 5.0}).has("co2:silicate_weathering")).is_false()


func test_co2_above_reference_warms_the_planet() -> void:
	assert_float(_causes({"co2": 70.0})["temperature:co2_greenhouse"]).is_greater(0.0)
	assert_float(_causes({"co2": 10.0})["temperature:co2_greenhouse"]).is_less(0.0)
	assert_bool(_causes({"co2": 40.0}).has("temperature:co2_greenhouse")).is_false()


func test_photolysis_makes_oxygen_from_water_vapor() -> void:
	assert_float(_causes({})["oxygen:photolysis"]).is_greater(0.0)
	assert_bool(_causes({"humidity": 0.0}).has("oxygen:photolysis")).is_false()


func test_fresh_crust_absorbs_oxygen_and_oxidizes() -> void:
	var causes := _causes({})
	var absorbed: float = causes["oxygen:crust_oxidation"]
	assert_float(absorbed).is_less(0.0)
	assert_float(causes["crust_oxidation:crust_oxidation"]).is_equal_approx(-absorbed * A.config().crust_capacity, 1e-15)


func test_oxidized_crust_absorbs_nothing() -> void:
	var causes := _causes({"crust_oxidation": 100.0})
	assert_bool(causes.has("oxygen:crust_oxidation")).is_false()
	assert_bool(causes.has("crust_oxidation:crust_oxidation")).is_false()


func test_volcanic_gases_consume_oxygen() -> void:
	assert_float(_causes({})["oxygen:volcanic_gases"]).is_less(0.0)
	assert_bool(_causes({"oxygen": 0.0}).has("oxygen:volcanic_gases")).is_false()


func test_never_touches_water_or_life() -> void:
	for delta in AtmosphereSystem.new(A.config()).compute(C.snapshot(BASE)):
		assert_bool(delta.parameter in [Param.HUMIDITY, Param.CLOUD_COVER, Param.PRECIPITATION, Param.BIOMASS]).is_false()
		assert_str(delta.source).is_equal("atmosphere")


func test_is_a_pure_function_of_the_snapshot() -> void:
	var system := AtmosphereSystem.new(A.config())
	var first := C.by_cause(system.compute(C.snapshot(BASE)))
	var second := C.by_cause(system.compute(C.snapshot(BASE)))
	assert_dict(first).is_equal(second)
