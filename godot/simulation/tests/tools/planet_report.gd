extends SceneTree
## Balance report for the planet as the game runs it (climate + atmosphere + biosphere).
##   godot --headless --path godot -s res://simulation/tests/tools/planet_report.gd -- \
##       [--seeds N] [--ticks N] [--climate path] [--atmosphere path] [--species path] \
##       [--biosphere path] [--personality name] [--climate-only] [--lifeless]
## --personality defaults to "none" so runs compare like with like.
## Prints per-seed statistics after warm-up; use it before and after changing data.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const WARM_UP := 2000
const ICY_BELOW := 16.0
const WARM_ABOVE := 28.0
const ALIVE_ABOVE := 5.0
const FOREST_ABOVE := 10.0
const OXYGENATED_ABOVE := 15.0


class Options:
	var seeds := 8
	var ticks := 15000
	var climate_path := ClimateConfig.DEFAULT_PATH
	var atmosphere_path := AtmosphereConfig.DEFAULT_PATH
	var species_path := SpeciesCatalog.DEFAULT_PATH
	var biosphere_path := BiosphereConfig.DEFAULT_PATH
	var atmosphere := true
	var life := true
	var personality := PersonalityCatalog.NONE


func _init() -> void:
	var options := _parse(OS.get_cmdline_user_args())
	var climate := ClimateConfig.load_json(options.climate_path)
	var atmosphere := AtmosphereConfig.load_json(options.atmosphere_path)
	var catalog := SpeciesCatalog.load_json(options.species_path)
	var biosphere := BiosphereConfig.load_json(options.biosphere_path)
	var errors := climate.errors + atmosphere.errors + catalog.errors + biosphere.errors
	if not errors.is_empty():
		printerr("\n".join(errors))
		quit(2)
		return

	print("seed | T avg | icy % | ice ages longest | CO2 min..max | O2 min..max | oxygenated @ | B max | trees @ | forest % | species avg (min..max) | extinctions")
	var started := Time.get_ticks_msec()
	for seed_value in range(1, options.seeds + 1):
		print(_report(seed_value, options, climate.value, atmosphere.value, catalog.value, biosphere.value))
	print("time: %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit(0)


func _parse(args: PackedStringArray) -> Options:
	var options := Options.new()
	var i := 0
	while i < args.size():
		match args[i]:
			"--seeds": i += 1; options.seeds = args[i].to_int()
			"--ticks": i += 1; options.ticks = args[i].to_int()
			"--climate": i += 1; options.climate_path = args[i]
			"--atmosphere": i += 1; options.atmosphere_path = args[i]
			"--species": i += 1; options.species_path = args[i]
			"--biosphere": i += 1; options.biosphere_path = args[i]
			"--climate-only": options.atmosphere = false; options.life = false
			"--lifeless": options.life = false
			"--personality": i += 1; options.personality = StringName(args[i])
		i += 1
	return options


func _report(seed_value: int, options: Options, climate: ClimateConfig, atmosphere: AtmosphereConfig,
		catalog: SpeciesCatalog, biosphere: BiosphereConfig) -> String:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(climate, seed_value))
	if options.atmosphere:
		manager.register_system(AtmosphereSystem.new(atmosphere))
	var life: BiosphereSystem = null
	if options.life:
		life = BiosphereSystem.new(biosphere, catalog, seed_value)
		manager.register_system(life)
	var specs := {&"climate": ClimateConfig.SPEC, &"atmosphere": AtmosphereConfig.SPEC, &"biosphere": BiosphereConfig.SPEC}
	var personality_catalog: PersonalityCatalog = PersonalityCatalog.load_json(PersonalityCatalog.DEFAULT_PATH, specs).value
	var personality := PersonalitySystem.create(personality_catalog, options.personality, seed_value)
	if not personality.is_ok():
		return "%d | %s" % [seed_value, personality.errors]
	manager.register_system(personality.value)
	var extinctions := [0]
	manager.event_bus().subscribe(&"species_extinct", func(_event: SimEvent) -> void: extinctions[0] += 1)

	var total_t := 0.0
	var icy := 0
	var ice_ages := 0
	var longest := 0
	var ice_start := 0
	var regime := ""
	var co2 := Vector2(100.0, 0.0)
	var o2 := Vector2(100.0, 0.0)
	var biomass_max := 0.0
	var oxygenated_at := -1
	var trees_at := -1
	var forest_ticks := 0
	var alive_total := 0
	var alive := Vector2i(99, 0)
	for tick in options.ticks:
		if not manager.step():
			return "%d | halted: %s" % [seed_value, manager.errors()]
		var snapshot := manager.snapshot()
		if oxygenated_at == -1 and snapshot.get_value(Param.OXYGEN) > OXYGENATED_ABOVE:
			oxygenated_at = tick + 1
		if life != null and trees_at == -1 and life.population(&"tree") > 1.0:
			trees_at = tick + 1
		if tick < WARM_UP:
			continue
		var t := snapshot.get_value(Param.TEMPERATURE)
		total_t += t
		icy += 1 if t < ICY_BELOW else 0
		co2 = Vector2(minf(co2.x, snapshot.get_value(Param.CO2)), maxf(co2.y, snapshot.get_value(Param.CO2)))
		o2 = Vector2(minf(o2.x, snapshot.get_value(Param.OXYGEN)), maxf(o2.y, snapshot.get_value(Param.OXYGEN)))
		biomass_max = maxf(biomass_max, snapshot.get_value(Param.BIOMASS))
		if life != null:
			forest_ticks += 1 if life.population(&"tree") > FOREST_ABOVE else 0
			var count := 0
			for id in catalog.ids():
				count += 1 if life.population(id) > ALIVE_ABOVE else 0
			alive_total += count
			alive = Vector2i(mini(alive.x, count), maxi(alive.y, count))
		var now := "icy" if t < ICY_BELOW else ("warm" if t > WARM_ABOVE else regime)
		if now == "icy" and regime != "icy":
			ice_start = tick
		if regime == "icy" and now == "warm":
			ice_ages += 1
			longest = maxi(longest, tick - ice_start)
		regime = now
	var measured := options.ticks - WARM_UP
	return "%d | %.1f | %.0f%% | %d %d | %.0f..%.0f | %.1f..%.1f | %d | %.1f | %d | %.0f%% | %.1f (%d..%d) | %d" % [
		seed_value, total_t / measured, 100.0 * icy / measured, ice_ages, longest, co2.x, co2.y, o2.x, o2.y,
		oxygenated_at, biomass_max, trees_at, 100.0 * forest_ticks / measured,
		float(alive_total) / measured, alive.x, alive.y, extinctions[0]]
