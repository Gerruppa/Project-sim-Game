extends SceneTree
## How fast does the planet run? Milliseconds per tick of the full planet, so a
## slowdown shows before it hurts the game or the test suite.
##   godot --headless --path godot -s res://simulation/tests/tools/speed_probe.gd -- [--ticks N] [--species PATH] [--events PATH]


func _init() -> void:
	var ticks := 4000
	var extra := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--ticks":
				ticks = int(args[i + 1])
			"--species", "--events":
				extra.append(args[i])
				extra.append(args[i + 1])
	var options: Dictionary = SimulationRunner.parse_args(PackedStringArray(["--seed", "1", "--personality", "harmonious"]) + extra).value
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(1).with_personality(&"harmonious")
	var manager: SimulationManager = SimulationRunner.build_planet(config, options).value["manager"]
	var started := Time.get_ticks_usec()
	manager.run_ticks(ticks)
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	print("PROBE %d ticks in %.0f ms = %.3f ms per tick" % [ticks, elapsed, elapsed / ticks])
	quit()
