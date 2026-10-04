extends SceneTree
## Balance report for the planet as the game runs it (climate + atmosphere).
##   godot --headless --path godot -s res://simulation/tests/tools/planet_report.gd -- \
##       [--seeds N] [--ticks N] [--climate path] [--atmosphere path] [--climate-only]
## Prints per-seed statistics after warm-up; use it before and after changing data.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const WARM_UP := 2000
const ICY_BELOW := 16.0
const WARM_ABOVE := 28.0


func _init() -> void:
	var seeds := 8
	var ticks := 15000
	var climate_path := ClimateConfig.DEFAULT_PATH
	var atmosphere_path := AtmosphereConfig.DEFAULT_PATH
	var with_atmosphere := true
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--seeds": i += 1; seeds = args[i].to_int()
			"--ticks": i += 1; ticks = args[i].to_int()
			"--climate": i += 1; climate_path = args[i]
			"--atmosphere": i += 1; atmosphere_path = args[i]
			"--climate-only": with_atmosphere = false
		i += 1
	var climate := ClimateConfig.load_json(climate_path)
	var atmosphere := AtmosphereConfig.load_json(atmosphere_path)
	if not climate.is_ok() or not atmosphere.is_ok():
		printerr("\n".join(climate.errors + atmosphere.errors))
		quit(2)
		return

	print("seed | T min..max avg | H | C | P | CO2 min..max | O2 max | crust max | icy % | at 0 | ice ages | longest")
	for seed_value in range(1, seeds + 1):
		print(_report(seed_value, ticks, climate.value, atmosphere.value if with_atmosphere else null))
	quit(0)


func _report(seed_value: int, ticks: int, climate: ClimateConfig, atmosphere: AtmosphereConfig) -> String:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(climate, seed_value))
	if atmosphere != null:
		manager.register_system(AtmosphereSystem.new(atmosphere))
	var ids := [Param.TEMPERATURE, Param.HUMIDITY, Param.CLOUD_COVER, Param.PRECIPITATION,
			Param.CO2, Param.OXYGEN, Param.CRUST_OXIDATION]
	var lows: Array[float] = []
	var highs: Array[float] = []
	for _id: StringName in ids:
		lows.append(100.0)
		highs.append(0.0)
	var total_t := 0.0
	var icy := 0
	var at_zero := 0
	var ice_ages := 0
	var longest := 0
	var ice_start := 0
	var regime := ""
	for tick in ticks:
		if not manager.step():
			return "%d | halted: %s" % [seed_value, manager.errors()]
		if tick < WARM_UP:
			continue
		var snapshot := manager.snapshot()
		for j in ids.size():
			var value := snapshot.get_value(ids[j])
			lows[j] = minf(lows[j], value)
			highs[j] = maxf(highs[j], value)
		var t := snapshot.get_value(Param.TEMPERATURE)
		total_t += t
		icy += 1 if t < ICY_BELOW else 0
		at_zero += 1 if t <= 0.5 else 0
		var now := "icy" if t < ICY_BELOW else ("warm" if t > WARM_ABOVE else regime)
		if now == "icy" and regime != "icy":
			ice_start = tick
		if regime == "icy" and now == "warm":
			ice_ages += 1
			longest = maxi(longest, tick - ice_start)
		regime = now
	var measured := ticks - WARM_UP
	return "%d | %.1f..%.1f avg %.1f | %.0f..%.0f | %.0f..%.0f | %.0f..%.0f | %.1f..%.1f | %.2f | %.2f | %.0f%% | %d | %d | %d" % [
		seed_value, lows[0], highs[0], total_t / measured, lows[1], highs[1], lows[2], highs[2],
		lows[3], highs[3], lows[4], highs[4], highs[5], highs[6], 100.0 * icy / measured, at_zero, ice_ages, longest]
