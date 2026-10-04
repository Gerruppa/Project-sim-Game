extends GdUnitTestSuite
## AtmosphereSystem with ClimateSystem in the real SimulationManager:
## the carbon thermostat ends ice ages, fresh crust delays oxygen.

const A := preload("res://simulation/tests/support/atmosphere_fixtures.gd")
const C := preload("res://simulation/tests/support/climate_fixtures.gd")
const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const FROZEN := {"temperature": 5.0, "humidity": 5.0, "cloud_cover": 5.0, "precipitation": 0.0}


func _manager(start: Dictionary, with_atmosphere: bool = true, climate: ClimateConfig = null) -> SimulationManager:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema(), start).value
	manager.register_system(ClimateSystem.new(climate if climate != null else C.calm(), 42))
	if with_atmosphere:
		manager.register_system(AtmosphereSystem.new(A.config()))
	return manager


## Ticks until temperature rises above `threshold`, or -1.
func _ticks_until_warm(manager: SimulationManager, limit: int, threshold: float) -> int:
	for tick in limit:
		manager.step()
		if manager.snapshot().get_value(Param.TEMPERATURE) > threshold:
			return tick + 1
	return -1


func test_without_atmosphere_a_frozen_planet_stays_frozen() -> void:
	var manager := _manager(FROZEN, false)
	assert_int(_ticks_until_warm(manager, 5000, C.calm().ice_free)).is_equal(-1)


func test_volcanic_co2_ends_an_ice_age() -> void:
	# No drift, no seasons: only the carbon cycle can thaw the planet.
	var manager := _manager(FROZEN)
	var thawed_after := _ticks_until_warm(manager, 5000, C.calm().ice_free)
	assert_int(thawed_after).is_between(1, 5000)
	assert_float(manager.snapshot().get_value(Param.CO2)).is_greater(A.config().co2_ref + 20.0)


func test_warm_wet_planet_draws_co2_down() -> void:
	var manager := _manager({"temperature": 45.0, "humidity": 35.0, "cloud_cover": 50.0, "precipitation": 30.0, "co2": 60.0})
	manager.run_ticks(2000)
	assert_float(manager.snapshot().get_value(Param.CO2)).is_less(60.0)


func test_fresh_crust_holds_oxygen_back() -> void:
	# Same oxygen producer, two planets: fresh crust vs already oxidized crust.
	var fresh := _manager({"temperature": 35.0})
	var oxidized := _manager({"temperature": 35.0, "crust_oxidation": 100.0})
	for manager: SimulationManager in [fresh, oxidized]:
		manager.register_system(TestStubSystem.new(&"producer", Param.OXYGEN, 0.05))
		manager.run_ticks(2000)
	var fresh_oxygen := fresh.snapshot().get_value(Param.OXYGEN)
	var oxidized_oxygen := oxidized.snapshot().get_value(Param.OXYGEN)
	assert_float(oxidized_oxygen).is_greater(fresh_oxygen * 2.0)
	assert_float(fresh.snapshot().get_value(Param.CRUST_OXIDATION)).is_greater(0.0)


func test_lifeless_planet_loses_its_oxygen() -> void:
	var manager := _manager({"temperature": 35.0, "oxygen": 2.0})
	manager.run_ticks(3000)
	assert_float(manager.snapshot().get_value(Param.OXYGEN)).is_less(1.0)
