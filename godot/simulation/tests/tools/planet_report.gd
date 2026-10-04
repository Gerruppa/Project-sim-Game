extends SceneTree
## Balance report for ClimateSystem: per-seed statistics after warm-up.
##   godot --headless --path godot -s res://simulation/tests/tools/climate_report.gd -- [--seeds N] [--ticks N] [--climate path]
## Prints a table; use it before and after changing climate.json.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const WARM_UP := 2000
const ICY_BELOW := 16.0
const WARM_ABOVE := 28.0


func _init() -> void:
	var seeds := 8
	var ticks := 15000
	var climate_path := ClimateConfig.DEFAULT_PATH
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1, 2):
		match args[i]:
			"--seeds": seeds = args[i + 1].to_int()
			"--ticks": ticks = args[i + 1].to_int()
			"--climate": climate_path = args[i + 1]
	var climate_result := ClimateConfig.load_json(climate_path)
	if not climate_result.is_ok():
		printerr("\n".join(climate_result.errors))
		quit(2)
		return

	print("seed | T min..max avg | H min..max | C min..max | P min..max | icy % | at 0 | regime switches")
	for seed_value in range(1, seeds + 1):
		print(_report(seed_value, ticks, climate_result.value))
	quit(0)


func _report(seed_value: int, ticks: int, climate: ClimateConfig) -> String:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value)
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(climate, seed_value))
	var ids := [Param.TEMPERATURE, Param.HUMIDITY, Param.CLOUD_COVER, Param.PRECIPITATION]
	var lows := [100.0, 100.0, 100.0, 100.0]
	var highs := [0.0, 0.0, 0.0, 0.0]
	var total_t := 0.0
	var icy := 0
	var at_zero := 0
	var switches := 0
	var regime := ""
	for tick in ticks:
		if not manager.step():
			return "%d | halted: %s" % [seed_value, manager.errors()]
		if tick < WARM_UP:
			continue
		var snapshot := manager.snapshot()
		for i in ids.size():
			var value := snapshot.get_value(ids[i])
			lows[i] = minf(lows[i], value)
			highs[i] = maxf(highs[i], value)
		var t := snapshot.get_value(Param.TEMPERATURE)
		total_t += t
		icy += 1 if t < ICY_BELOW else 0
		at_zero += 1 if t <= 0.5 else 0
		var now := "icy" if t < ICY_BELOW else ("warm" if t > WARM_ABOVE else regime)
		if not regime.is_empty() and now != regime:
			switches += 1
		regime = now
	var measured := ticks - WARM_UP
	return "%d | %.1f..%.1f avg %.1f | %.1f..%.1f | %.1f..%.1f | %.1f..%.1f | %.0f%% | %d | %d" % [
		seed_value, lows[0], highs[0], total_t / measured, lows[1], highs[1], lows[2], highs[2],
		lows[3], highs[3], 100.0 * icy / measured, at_zero, switches]
