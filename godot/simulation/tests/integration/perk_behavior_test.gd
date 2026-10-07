extends GdUnitTestSuite
## Perks on the real planet: each modifier perk changes how life fares, an
## unlocking perk changes nothing but the purse, the chronicle tells what was
## bought, and a save with a perk continues bit for bit.

const TEST_DIR := "user://perk_behavior_test"
const TICKS := 3000
const SPECIES: Array[String] = ["bacteria", "algae", "moss"]

## Run key -> {"fingerprint", "sparks", "biomass"}, shared by the tests.
var _runs := {}


func _config() -> SimConfig:
	return SimConfig.from_data({
		"config_version": 1, "seed": 42, "base_ticks_per_second": 1, "speed_multipliers": [1, 10, 100],
		"max_catch_up_ticks": 1000, "personality": "guardian",
		"log": {"text": false, "jsonl": false, "deltas": false, "chronicle": false, "directory": TEST_DIR},
	}).value


func _planet() -> Dictionary:
	var built := SimulationRunner.build_planet(_config(), SimulationRunner.parse_args(PackedStringArray()).value)
	assert_array(Array(built.errors)).is_empty()
	return built.value


func _run_info(planet: Dictionary) -> Dictionary:
	return {"personality": planet["personality"], "data_fingerprints": planet["fingerprints"], "lineage": []}


## Perks needed first, then the perk itself.
func _chain(perk: StringName, catalog: PerkCatalog) -> Array[StringName]:
	var chain: Array[StringName] = []
	for required in catalog.get_def(perk).requires:
		chain.append_array(_chain(required, catalog))
	chain.append(perk)
	return chain


## A planet seeded with life that was granted 100 Sparks and bought `perks` one per tick.
func _bought(perks: Array[StringName]) -> SimulationManager:
	var manager: SimulationManager = _planet()["manager"]
	for species in SPECIES:
		assert_bool(manager.submit(BiosphereSystem.ID, &"add_population", {"species": species, "amount": 5.0}).is_ok()).is_true()
	assert_bool(manager.submit(PerkSystem.ID, PerkSystem.ACTION_GRANT, {"amount": 100.0}).is_ok()).is_true()
	manager.run_ticks(1)
	for perk in perks:
		var submitted := manager.submit(PerkSystem.ID, PerkSystem.ACTION_BUY, {"perk": String(perk)})
		assert_array(Array(submitted.errors)).is_empty()
		manager.run_ticks(1)
	return manager


func _perks(manager: SimulationManager) -> PerkSystem:
	return manager.system(PerkSystem.ID) as PerkSystem


## Everything the planet is: state hash and every population.
func _fingerprint(manager: SimulationManager) -> String:
	var biosphere := manager.system(BiosphereSystem.ID) as BiosphereSystem
	var parts := PackedStringArray([manager.state_hash()])
	for id in biosphere.species_ids():
		parts.append("%s=%s" % [id, ExactCodec.floats_to_text(PackedFloat64Array([biosphere.population(id)]))])
	return "|".join(parts)


func _measure(perks: Array[StringName], ticks: int = TICKS) -> Dictionary:
	var key := "%s@%d" % [perks, ticks]
	if not _runs.has(key):
		var manager := _bought(perks)
		manager.run_ticks(ticks - manager.tick())
		_runs[key] = {"fingerprint": _fingerprint(manager), "sparks": _perks(manager).sparks(),
				"biomass": manager.snapshot().get_value(Param.BIOMASS)}
	return _runs[key]


func _catalog() -> PerkCatalog:
	return _perks(_planet()["manager"]).catalog()


func test_each_modifier_perk_changes_the_planet() -> void:
	var catalog := _catalog()
	for perk: StringName in [&"res_hardy_1", &"res_hardy_2", &"res_fire_1", &"sow_regrowth_1"]:
		var with_perk := _chain(perk, catalog)
		var without: Array[StringName] = []
		without.append_array(with_perk.slice(0, with_perk.size() - 1))
		var different: bool = _measure(with_perk)["fingerprint"] != _measure(without)["fingerprint"]
		if not different:
			different = _measure(with_perk, 2 * TICKS)["fingerprint"] != _measure(without, 2 * TICKS)["fingerprint"]
		assert_bool(different).override_failure_message("%s left the planet exactly as it was" % perk).is_true()


func test_the_planet_has_life_to_measure() -> void:
	assert_float(_measure([])["biomass"]).override_failure_message("test planet must keep biomass, or the perk comparison proves nothing").is_greater(0.0)


func test_unlocking_perk_does_not_change_the_simulation() -> void:
	var plain := _measure([])
	var unlocked := _measure([&"perk_cull"])
	assert_str(unlocked["fingerprint"]).is_equal(plain["fingerprint"])
	var cost := _catalog().get_def(&"perk_cull").cost
	assert_float(unlocked["sparks"]).is_equal_approx(plain["sparks"] - cost, 1e-9)


func test_income_follows_the_planets_life() -> void:
	var catalog := _catalog()
	var sparks := float(_measure([])["sparks"])
	assert_float(sparks).is_greater(100.0)
	# Biomass cannot exceed 100 here, so the income is bounded by the coefficient.
	assert_float(sparks).is_less(100.0 + catalog.start_sparks + 100.0 * TICKS * catalog.income_per_biomass_tick + 1e-6)


func test_save_load_continuity_with_a_perk() -> void:
	var info_source := _planet()
	var continuous := _bought([&"res_hardy_1"])
	continuous.run_ticks(600)

	var manager := _bought([&"res_hardy_1"])
	manager.run_ticks(100)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveSystem.capture(manager, _run_info(info_source))))

	var second := _planet()
	var restored := SaveSystem.restore(second["manager"], saved, _run_info(second))
	assert_array(Array(restored.errors)).is_empty()
	var resumed: SimulationManager = second["manager"]
	assert_bool(_perks(resumed).owns(&"res_hardy_1")).is_true()
	assert_bool(_perks(resumed).sparks() == _perks(manager).sparks()).is_true()
	resumed.run_ticks(500)
	manager.run_ticks(500)
	assert_int(resumed.tick()).is_equal(continuous.tick())
	assert_str(_fingerprint(resumed)).is_equal(_fingerprint(continuous))
	assert_str(_fingerprint(manager)).is_equal(_fingerprint(continuous))
	assert_bool(_perks(resumed).sparks() == _perks(continuous).sparks()).is_true()
	var now := resumed.snapshot()
	var then := continuous.snapshot()
	for i in now.size():
		assert_bool(now.get_value_at(i) == then.get_value_at(i)).is_true()


func test_chronicle_tells_purchases_and_refusals_but_not_every_grant() -> void:
	var manager: SimulationManager = _planet()["manager"]
	var sink := MemoryLogSink.new()
	var chronicle := PlanetChronicle.new([sink], ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH).value)
	manager.attach_log(chronicle)
	manager.submit(PerkSystem.ID, PerkSystem.ACTION_GRANT, {"amount": 4.0})
	manager.submit(PerkSystem.ID, PerkSystem.ACTION_GRANT, {"amount": 4.0}, 2)
	manager.run_ticks(1)
	manager.submit(PerkSystem.ID, PerkSystem.ACTION_BUY, {"perk": "res_hardy_1"})
	manager.submit(PerkSystem.ID, PerkSystem.ACTION_BUY, {"perk": "res_hardy_1"}, 2)
	manager.submit(PerkSystem.ID, PerkSystem.ACTION_GRANT, {"amount": 20.0}, 3)
	manager.run_ticks(1)
	manager.submit(PerkSystem.ID, PerkSystem.ACTION_REFUND, {"perk": "res_hardy_1"})
	manager.run_ticks(2)
	var lines := Array(sink.lines)
	var hardy := _catalog().get_def(&"res_hardy_1")
	assert_array(lines).contains(["[Tick 2] " + hardy.story["bought"]])
	assert_array(lines).contains(["[Tick 3] " + hardy.story["refunded"]])
	assert_array(lines.filter(func(line: String) -> bool: return line.contains("The Apprentice cannot"))).has_size(1)
	assert_array(lines.filter(func(line: String) -> bool: return line.contains("Iskr"))).is_empty()


func _tolerance(manager: SimulationManager) -> Vector3:
	return (manager.system(BiosphereSystem.ID) as BiosphereSystem).tolerance()


func test_cold_resistance_tiers_stack_on_the_real_planet() -> void:
	var manager := _bought([&"res_cold_1", &"res_cold_2", &"res_cold_3"])
	assert_vector(_tolerance(manager)).is_equal(Vector3(10.0, 0.0, 0.0))
	var other := _bought([&"res_heat_1", &"res_drought_1"])
	assert_vector(_tolerance(other)).is_equal(Vector3(0.0, 3.0, 2.0))


func test_refunding_a_resistance_perk_takes_the_tolerance_away() -> void:
	var manager := _bought([&"res_cold_1"])
	assert_float(_tolerance(manager).x).is_equal(3.0)
	manager.submit(PerkSystem.ID, PerkSystem.ACTION_REFUND, {"perk": "res_cold_1"})
	manager.run_ticks(2)
	assert_float(_tolerance(manager).x).is_equal(0.0)


func test_a_tolerant_planet_suits_cold_life_better() -> void:
	var plain := _bought([])
	var hardy := _bought([&"res_cold_1", &"res_cold_2", &"res_cold_3"])
	var cold := plain.snapshot()
	var state: PlanetState = PlanetState.create(cold.schema(), {"temperature": 11.0, "humidity": 40.0, "precipitation": 20.0, "oxygen": 20.0, "biomass": 20.0, "co2": 40.0}).value
	var low := state.snapshot(0)
	var plain_fit := (plain.system(BiosphereSystem.ID) as BiosphereSystem).fit_of(&"shrub", low)
	var hardy_fit := (hardy.system(BiosphereSystem.ID) as BiosphereSystem).fit_of(&"shrub", low)
	assert_float(hardy_fit).is_greater(plain_fit)


func test_shield_perks_soften_crises_and_cost_income() -> void:
	var manager := _bought([&"shield_1", &"shield_2", &"shield_3"])
	var config := (manager.system(EventSystem.ID) as EventSystem).current_config()
	assert_float(config.severity).is_equal_approx(0.85 * 0.85 * 0.85, 1e-9)
	assert_float(_perks(manager).income_scale()).is_equal_approx(0.9 * 0.9 * 0.9, 1e-9)
	var calm := _bought([&"shield_calm_1", &"shield_calm_2"])
	assert_float((calm.system(EventSystem.ID) as EventSystem).current_config().cooldown_scale).is_equal_approx(2.25, 1e-9)


func test_every_branch_perk_changes_something_the_planet_or_the_purse_shows() -> void:
	var catalog := _catalog()
	for def in catalog.defs():
		if def.tree == &"environment":
			continue
		assert_bool(not def.modifiers.is_empty()).override_failure_message("%s does nothing" % def.id).is_true()


func test_fauna_perks_turn_the_animal_coefficients() -> void:
	var manager := _bought([&"fauna_swarm_1", &"fauna_swarm_2", &"fauna_swarm_3", &"fauna_pantry_1", &"fauna_pantry_2",
			&"fauna_pollen_1", &"fauna_pollen_2", &"fauna_migrate_1", &"fauna_migrate_2"])
	var config := (manager.system(BiosphereSystem.ID) as BiosphereSystem).current_config()
	assert_float(config.fauna_growth_scale).is_equal_approx(1.3 * 1.3 * 1.3, 1e-9)
	assert_float(config.food_need_scale).is_equal_approx(0.64, 1e-9)
	assert_float(config.pollination).is_equal_approx(0.5, 1e-9)
	assert_float(config.fauna_seed_scale).is_equal_approx(4.0, 1e-9)
	assert_float(config.graze_scale).is_greater(1.0)
