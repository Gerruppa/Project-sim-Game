extends SceneTree
## Are the goals reachable by playing well? A simple bot plays every
## archetype and seed from decision point to decision point, following the
## game's own hints: answer each crisis with the action measured to help,
## seed the next species of the succession as soon as its conditions are
## good (or a lost one when they are good again), otherwise wait.
##   godot --headless --path godot -s res://simulation/tests/tools/goal_bot.gd -- [--seeds N] [--ticks N]

const ARCHETYPES := ["harmonious", "chaotic", "guardian"]
## Crisis -> the action the hints recommend.
const ANSWERS := {"drought": "aquifer_release", "ice_age": "mirrors_warm:weak", "overheating": "mirrors_cool:weak"}


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
	var advisor: HintAdvisor = HintAdvisor.load_json().value
	var texts: ChronicleTexts = ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH).value
	var wins := 0
	var runs := 0
	var counts := {}
	var star_counts := {}
	for archetype: String in ARCHETYPES:
		for seed_value in range(1, seeds + 1):
			runs += 1
			var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value) \
					.with_personality(StringName(archetype))
			var manager: SimulationManager = SimulationRunner.build_planet(config,
					SimulationRunner.parse_args(PackedStringArray()).value).value["manager"]
			var tracker := GoalTracker.new(goals, manager, archetype)
			manager.attach_log(tracker)
			var actions := 0
			while manager.tick() < ticks and not tracker.won():
				var catalog := (manager.system(InterventionSystem.ID) as InterventionSystem).catalog()
				var watcher := DecisionWatcher.new(catalog.decision_events, catalog.decision_grace, manager.tick(), texts,
						manager.snapshot().schema())
				manager.attach_log(watcher)
				while manager.tick() < ticks and not watcher.reached() and not tracker.won():
					manager.step()
				if watcher.reached():
					for act in _choose(manager, watcher.point(), advisor):
						if SimulationRunner.submit_acts(manager, [act]).is_ok():
							actions += 1
			var won := "year %d %s" % [GoalTracker.year(tracker.victory_tick()), tracker.stars_text()] if tracker.won() else "no"
			wins += 1 if tracker.won() else 0
			for id: String in tracker.achieved():
				counts[id] = counts.get(id, 0) + 1
			for star: String in tracker.stars():
				star_counts[star] = star_counts.get(star, 0) + 1
			print("%-10s seed %d | actions %2d | victory: %-44s | ambitions: %s" % [archetype, seed_value, actions, won,
					", ".join(PackedStringArray(tracker.achieved().keys()))])
	print("\nbot victory: %d of %d runs within %d ticks" % [wins, runs, ticks])
	print("stars: %s" % star_counts)
	for id: String in counts:
		print("  %-16s %d of %d" % [id, counts[id], runs])
	quit(0)


## The bot's answer to a decision point: a crisis action, then seeding.
func _choose(manager: SimulationManager, point: SimEvent, advisor: HintAdvisor) -> Array[String]:
	var acts: Array[String] = []
	if point.type == &"world_event_started" and ANSWERS.has(str(point.data.get("id"))):
		acts.append(ANSWERS[str(point.data["id"])])
	var biosphere := manager.system(BiosphereSystem.ID) as BiosphereSystem
	var present := biosphere.established_population()
	for species in biosphere.species_list():
		if biosphere.population(species.id) >= present:
			continue
		if not species.emerges_from.is_empty() and biosphere.population(species.emerges_from) < present:
			continue
		if advisor.missing_needs(species, manager.snapshot()).is_empty():
			acts.append("seed_species:%s" % species.id)
		break
	return acts
