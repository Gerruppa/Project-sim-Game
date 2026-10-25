extends SceneTree
## When does each stage of life appear on a planet left alone, and how does it
## fare? Runs every archetype and seed with no player and prints, per run, the
## year each species first established itself, how often it died out and its
## population at the end; then the medians.
##   godot --headless --path godot -s res://simulation/tests/tools/life_timeline.gd -- [--seeds N] [--ticks N] [--personality NAME]

const ARCHETYPES := ["harmonious", "chaotic", "guardian"]


func _init() -> void:
	var seeds := 6
	var ticks := 40000
	var only := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--seeds":
				seeds = int(args[i + 1])
			"--ticks":
				ticks = int(args[i + 1])
			"--personality":
				only = args[i + 1]
	var first: Dictionary = {}
	var runs := 0
	for archetype: String in ARCHETYPES:
		if not only.is_empty() and only != archetype:
			continue
		for seed_value in range(1, seeds + 1):
			runs += 1
			print(_run(seed_value, archetype, ticks, first))
	print("--- median first year over %d runs of %d ticks (never = not reached)" % [runs, ticks])
	for id: String in first:
		var years: Array = first[id]
		years.sort()
		print("%-14s reached in %2d of %d runs, median year %s, earliest %s, latest %s" % [id, years.size(), runs,
				str(years[years.size() / 2]) if not years.is_empty() else "never",
				str(years[0]) if not years.is_empty() else "-", str(years[-1]) if not years.is_empty() else "-"])
	quit()


func _run(seed_value: int, archetype: String, ticks: int, first: Dictionary) -> String:
	var options: Dictionary = SimulationRunner.parse_args(PackedStringArray(["--seed", str(seed_value), "--personality", archetype])).value
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value).with_personality(StringName(archetype))
	var manager: SimulationManager = SimulationRunner.build_planet(config, options).value["manager"]
	var seen := {}
	var died := {}
	manager.event_bus().subscribe(&"species_emerged", func(event: SimEvent) -> void:
		var id: String = event.data["species"]
		if not seen.has(id):
			seen[id] = event.tick)
	manager.event_bus().subscribe(&"species_extinct", func(event: SimEvent) -> void:
		var id: String = event.data["species"]
		died[id] = int(died.get(id, 0)) + 1)
	manager.run_ticks(ticks)
	var biosphere := manager.system(BiosphereSystem.ID) as BiosphereSystem
	var parts := PackedStringArray()
	for id in biosphere.species_ids():
		var key := String(id)
		if not first.has(key):
			first[key] = []
		var tick: int = seen.get(key, -1)
		if tick >= 0:
			(first[key] as Array).append(GameCalendar.year(tick))
		parts.append("%s %s/%d/%.0f" % [key, "-" if tick < 0 else str(GameCalendar.year(tick)), int(died.get(key, 0)), biosphere.population(id)])
	return "seed %d %-10s (first year/extinctions/final pop) %s" % [seed_value, archetype, "  ".join(parts)]
