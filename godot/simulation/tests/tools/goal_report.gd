extends SceneTree
## How hard are the goals without a player? Runs every archetype and seed
## untouched and reports when the planet matured (victory), its stars and
## which ambitions came by themselves.
##   godot --headless --path godot -s res://simulation/tests/tools/goal_report.gd -- [--seeds N] [--ticks N]

const ARCHETYPES := ["harmonious", "chaotic", "guardian"]


func _init() -> void:
	var seeds := 4
	var ticks := 30000
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 < args.size() and args[i] == "--seeds":
			seeds = args[i + 1].to_int()
		elif i + 1 < args.size() and args[i] == "--ticks":
			ticks = args[i + 1].to_int()
	var goals: Dictionary = GoalTracker.load_json().value
	var wins := 0
	var runs := 0
	var counts := {}
	for archetype: String in ARCHETYPES:
		for seed_value in range(1, seeds + 1):
			runs += 1
			var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value) \
					.with_personality(StringName(archetype))
			var manager: SimulationManager = SimulationRunner.build_planet(config,
					SimulationRunner.parse_args(PackedStringArray()).value).value["manager"]
			var tracker := GoalTracker.new(goals, manager, archetype)
			manager.attach_log(tracker)
			var longest := 0
			for tick in ticks:
				manager.step()
				longest = maxi(longest, tracker.streak())
			var won := "year %d %s" % [GoalTracker.year(tracker.victory_tick()), tracker.stars_text()] if tracker.won() else "no (longest streak %d)" % longest
			wins += 1 if tracker.won() else 0
			for id: String in tracker.achieved():
				counts[id] = counts.get(id, 0) + 1
			print("%-10s seed %d | victory: %-40s | ambitions: %s" % [archetype, seed_value, won, ", ".join(PackedStringArray(tracker.achieved().keys()))])
	print("\nvictory untouched: %d of %d runs within %d ticks (%d years)" % [wins, runs, ticks, ticks / 360])
	for id: String in counts:
		print("  %-16s %d of %d" % [id, counts[id], runs])
	quit(0)
