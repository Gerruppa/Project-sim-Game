extends GdUnitTestSuite
## Fauna in the biosphere: animals live on plants. They appear only after their
## food has been plentiful for long enough, starve without it, eat it and
## pollinate other plants. A tiny planet: moss, a shrub, and bugs that eat moss.

const B := preload("res://simulation/tests/support/biosphere_fixtures.gd")

const GOOD := {"temperature": 28.0, "humidity": 40.0, "precipitation": 20.0, "oxygen": 20.0, "co2": 40.0, "biomass": 20.0}


func _list() -> Array:
	return [
		B.species("moss", {"layer": 1, "weight": 0.5, "growth": 0.03, "capacity": 80.0}),
		B.species("shrub", {"layer": 2, "weight": 0.5, "growth": 0.01, "capacity": 80.0, "seed": 0.0}),
		B.species("bug", {"layer": 0, "weight": 0.0, "growth": 0.03, "capacity": 70.0, "seed": 0.01, "emerges_from": "moss",
				"food": "moss", "food_need": 20.0, "food_ticks": 100, "graze": 0.004, "pollinator": 1.0, "stress_mortality": 0.05}),
	]


func _system(config: Dictionary = {}, seed_value: int = 1) -> BiosphereSystem:
	return BiosphereSystem.new(B.calm(config), B.catalog(_list()), seed_value)


## One compute with `moss` held at the given population (the other species run free).
func _tick(system: BiosphereSystem, moss: float) -> void:
	system.set_population(&"moss", moss)
	system.compute(B.snapshot(GOOD))


func test_fauna_does_not_emerge_while_food_is_scarce() -> void:
	var system := _system()
	for i in 1000:
		_tick(system, 10.0)
	assert_float(system.population(&"bug")).is_equal(0.0)
	assert_float(system.food_progress(&"bug")).is_equal(0.0)


func test_fauna_emerges_only_after_the_food_streak() -> void:
	var system := _system()
	var first := -1
	for i in 3000:
		_tick(system, 40.0)
		if first == -1 and system.population(&"bug") >= 1.0:
			first = i
	assert_int(first).override_failure_message("bugs never appeared").is_greater(-1)
	assert_int(first).is_greater_equal(100)


func test_the_food_streak_grows_and_decays() -> void:
	var system := _system()
	for i in 60:
		_tick(system, 40.0)
	assert_float(system.food_progress(&"bug")).is_equal_approx(0.6, 1e-9)
	for i in 30:
		_tick(system, 10.0)
	assert_float(system.food_progress(&"bug")).is_equal_approx(0.3, 1e-9)
	for i in 100:
		_tick(system, 10.0)
	assert_float(system.food_progress(&"bug")).is_equal(0.0)


func test_plants_need_no_food_streak() -> void:
	assert_float(_system().food_progress(&"moss")).is_equal(1.0)
	assert_float(_system().food_progress(&"nope")).is_equal(1.0)


func test_fauna_starves_without_food_and_the_cause_is_hunger() -> void:
	var system := _system()
	system.set_population(&"bug", 30.0)
	system.compute(B.snapshot(GOOD))
	for i in 600:
		_tick(system, 0.0)
	assert_float(system.population(&"bug")).is_equal(0.0)
	assert_bool(system.is_lost(&"bug")).is_true()
	assert_str(String(system.extinction_cause(&"bug"))).is_equal("hunger")


func test_grazing_lowers_the_food_population() -> void:
	var with_bugs := _system()
	var without := _system()
	with_bugs.set_population(&"moss", 40.0)
	without.set_population(&"moss", 40.0)
	with_bugs.set_population(&"bug", 50.0)
	for i in 300:
		with_bugs.compute(B.snapshot(GOOD))
		without.compute(B.snapshot(GOOD))
	assert_float(with_bugs.population(&"moss")).is_less(without.population(&"moss") - 1.0)
	assert_float(with_bugs.population(&"moss")).is_greater_equal(0.0)


func test_graze_scale_turns_up_the_appetite() -> void:
	var normal := _system()
	var hungry := _system({"graze_scale": 5.0})
	for system: BiosphereSystem in [normal, hungry]:
		system.set_population(&"moss", 40.0)
		system.set_population(&"bug", 50.0)
	for i in 200:
		normal.compute(B.snapshot(GOOD))
		hungry.compute(B.snapshot(GOOD))
	assert_float(hungry.population(&"moss")).is_less(normal.population(&"moss"))


func test_pollinators_make_other_plants_grow_faster() -> void:
	var alone := _system({"pollination": 0.5})
	var visited := _system({"pollination": 0.5})
	alone.set_population(&"shrub", 5.0)
	visited.set_population(&"shrub", 5.0)
	for i in 200:
		alone.set_population(&"moss", 40.0)
		visited.set_population(&"moss", 40.0)
		alone.set_population(&"bug", 0.0)
		visited.set_population(&"bug", 50.0)
		alone.compute(B.snapshot(GOOD))
		visited.compute(B.snapshot(GOOD))
	assert_float(visited.population(&"shrub")).is_greater(alone.population(&"shrub"))


func test_without_the_pollination_coefficient_bugs_do_not_pollinate() -> void:
	var alone := _system()
	var visited := _system()
	alone.set_population(&"shrub", 5.0)
	visited.set_population(&"shrub", 5.0)
	for i in 200:
		for system: BiosphereSystem in [alone, visited]:
			system.set_population(&"moss", 40.0)
		alone.set_population(&"bug", 0.0)
		visited.set_population(&"bug", 50.0)
		alone.compute(B.snapshot(GOOD))
		visited.compute(B.snapshot(GOOD))
	assert_float(visited.population(&"shrub")).is_equal_approx(alone.population(&"shrub"), 1e-9)


func test_fauna_coefficients_scale_seeding_and_food_need() -> void:
	var slow := _system()
	var quick := _system({"fauna_seed_scale": 5.0})
	var slow_at := -1
	var quick_at := -1
	for i in 3000:
		_tick(slow, 40.0)
		_tick(quick, 40.0)
		if slow_at == -1 and slow.population(&"bug") >= 1.0:
			slow_at = i
		if quick_at == -1 and quick.population(&"bug") >= 1.0:
			quick_at = i
	assert_int(quick_at).is_greater(-1)
	assert_bool(slow_at == -1 or quick_at < slow_at).is_true()
	var picky := _system({"food_need_scale": 2.0})
	for i in 150:
		_tick(picky, 30.0)
	assert_float(picky.food_progress(&"bug")).is_equal(0.0)
	var easy := _system({"food_need_scale": 0.5})
	for i in 50:
		_tick(easy, 15.0)
	assert_float(easy.food_progress(&"bug")).is_equal_approx(0.5, 1e-9)


func test_fauna_growth_scale_speeds_up_fauna_only() -> void:
	var normal := _system()
	var lively := _system({"fauna_growth_scale": 3.0})
	for system: BiosphereSystem in [normal, lively]:
		system.set_population(&"bug", 5.0)
	for i in 60:
		_tick(normal, 40.0)
		_tick(lively, 40.0)
	assert_float(lively.population(&"bug")).is_greater(normal.population(&"bug"))


func test_populations_stay_within_bounds_and_finite() -> void:
	var system := _system({"growth_noise": 0.1})
	system.set_population(&"bug", 80.0)
	for i in 4000:
		system.compute(B.snapshot(GOOD))
		for id in system.species_ids():
			var p := system.population(id)
			assert_bool(is_finite(p) and p >= 0.0 and p <= 100.0).override_failure_message("%s = %s at %d" % [id, p, i]).is_true()


func test_a_fauna_run_is_deterministic() -> void:
	var first := _system({"growth_noise": 0.1}, 7)
	var second := _system({"growth_noise": 0.1}, 7)
	first.set_population(&"bug", 10.0)
	second.set_population(&"bug", 10.0)
	for i in 800:
		first.compute(B.snapshot(GOOD))
		second.compute(B.snapshot(GOOD))
	assert_dict(first.save_state()).is_equal(second.save_state())


func test_save_and_load_keep_the_food_streaks() -> void:
	var system := _system()
	for i in 60:
		_tick(system, 40.0)
	var restored := _system()
	assert_bool(restored.load_state(system.save_state()).is_ok()).is_true()
	assert_float(restored.food_progress(&"bug")).is_equal_approx(0.6, 1e-9)


func test_an_old_state_without_food_streaks_loads_as_zero() -> void:
	var system := _system()
	for i in 60:
		_tick(system, 40.0)
	var saved := system.save_state()
	saved.erase("food_streaks")
	var restored := _system()
	assert_bool(restored.load_state(saved).is_ok()).is_true()
	assert_float(restored.food_progress(&"bug")).is_equal(0.0)


func test_catalog_rejects_unknown_food_and_a_missing_need() -> void:
	var broken := _list()
	broken[2] = B.species("bug", {"food": "ghost", "food_need": 20.0})
	assert_str("\n".join(SpeciesCatalog.from_data(B.catalog_data(broken)).errors)).contains("ghost")
	broken[2] = B.species("bug", {"food": "moss", "food_need": 0.0})
	assert_str("\n".join(SpeciesCatalog.from_data(B.catalog_data(broken)).errors)).contains("food_need")
	broken[2] = B.species("bug", {"food": "bug", "food_need": 10.0})
	assert_str("\n".join(SpeciesCatalog.from_data(B.catalog_data(broken)).errors)).contains("itself")


func test_species_without_fauna_fields_still_load() -> void:
	var catalog := B.catalog([B.species("moss")])
	var moss := catalog.get_species(&"moss")
	assert_bool(moss.is_fauna()).is_false()
	assert_float(moss.food_need).is_equal(0.0)
	assert_bool(B.catalog(_list()).get_species(&"bug").is_fauna()).is_true()
