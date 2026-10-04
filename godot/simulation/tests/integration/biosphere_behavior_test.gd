extends GdUnitTestSuite
## The whole planet with life (climate + atmosphere + biosphere), one long run
## shared by all tests: succession, oxygenation, anaerobe refuge, fire limits.

const C := preload("res://simulation/tests/support/climate_fixtures.gd")
const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const TICKS := 16000
const AFTER_OXYGENATION := 3000

var _first_seen := {}
var _oxygenated_at := -1
var _crust_at_oxygenation := 0.0
var _oxygen_high := 0.0
var _bacteria_after := -1.0
var _events: Array[String] = []
var _manager: SimulationManager
var _life: BiosphereSystem


func before() -> void:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	_manager = SimulationManager.create(config, P.project_schema(), {"temperature": 35.0}).value
	# Calm, warm climate: life is not interrupted by ice ages.
	_manager.register_system(ClimateSystem.new(C.calm(), 42))
	_manager.register_system(AtmosphereSystem.new(AtmosphereConfig.load_json(AtmosphereConfig.DEFAULT_PATH).value))
	_life = BiosphereSystem.new(BiosphereConfig.load_json(BiosphereConfig.DEFAULT_PATH).value,
			SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value, 42)
	_manager.register_system(_life)
	_manager.event_bus().subscribe(&"species_emerged", _on_emerged)
	for tick in TICKS:
		_manager.step()
		var snapshot := _manager.snapshot()
		var oxygen := snapshot.get_value(Param.OXYGEN)
		_oxygen_high = maxf(_oxygen_high, oxygen)
		for id: StringName in [&"bacteria", &"algae", &"moss", &"shrub", &"tree"]:
			if not _first_seen.has(id) and _life.population(id) > 1.0:
				_first_seen[id] = tick
		if _oxygenated_at == -1 and oxygen > 15.0:
			_oxygenated_at = tick
			_crust_at_oxygenation = snapshot.get_value(Param.CRUST_OXIDATION)
		if _oxygenated_at != -1 and tick == _oxygenated_at + AFTER_OXYGENATION:
			_bacteria_after = _life.population(&"bacteria")


func _on_emerged(event: SimEvent) -> void:
	_events.append(event.data["species"])


func test_run_never_halts() -> void:
	assert_bool(_manager.is_halted()).is_false()


func test_life_follows_succession_order() -> void:
	for id: StringName in [&"bacteria", &"algae", &"moss", &"shrub", &"tree"]:
		assert_bool(_first_seen.has(id)).override_failure_message("%s never appeared" % id).is_true()
	assert_int(_first_seen[&"bacteria"]).is_less(_first_seen[&"algae"])
	assert_int(_first_seen[&"algae"]).is_less(_first_seen[&"moss"])
	assert_int(_first_seen[&"moss"]).is_less(_first_seen[&"shrub"])
	assert_int(_first_seen[&"shrub"]).is_less(_first_seen[&"tree"])


func test_emergence_is_reported_in_order() -> void:
	assert_array(_events.slice(0, 3)).is_equal(["bacteria", "algae", "moss"])


func test_oxygen_waits_for_the_crust() -> void:
	# Algae produce oxygen long before it accumulates: fresh crust absorbs it first.
	assert_int(_oxygenated_at).is_greater(_first_seen[&"algae"] + 1000)
	# In this calm, warm run algae never pause, so oxygen builds up early;
	# the crust has still absorbed the oxygen equivalent of ~90 units by then.
	assert_float(_crust_at_oxygenation).is_greater(5.0)


func test_trees_need_the_oxygenated_world() -> void:
	assert_int(_first_seen[&"tree"]).is_greater(_oxygenated_at)


func test_anaerobes_survive_in_a_refuge() -> void:
	assert_float(_bacteria_after).is_between(1.0, 15.0)


func test_fires_and_photorespiration_cap_oxygen() -> void:
	assert_float(_oxygen_high).is_less(50.0)


func test_life_changes_the_planet() -> void:
	var snapshot := _manager.snapshot()
	assert_float(snapshot.get_value(Param.BIOMASS)).is_greater(5.0)
	assert_float(snapshot.get_value(Param.BIOMASS)).is_equal_approx(_life.biomass_total(), 1e-4)
