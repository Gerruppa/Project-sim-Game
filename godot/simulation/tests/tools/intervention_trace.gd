extends SceneTree
## How hard does the planet damp the player's hand? For each action taken at
## the first crisis after WARM_UP, compare the run tick by tick with the same
## run without it and report, per parameter and species: the peak difference,
## when it peaks and how long the difference lasts.
##   godot --headless --path godot -s res://simulation/tests/tools/intervention_trace.gd -- [--seeds N] [--actions a,b]

const WARM_UP := 1500
const WATCH := 3000
const ARCHETYPES := ["harmonious", "chaotic", "guardian"]
const ACTIONS := ["mirrors_warm", "mirrors_cool", "cloud_seeding", "aquifer_release", "volcanic_awakening",
		"cull_species:moss", "seed_species:shrub"]
const PARAMS: Array[StringName] = [&"temperature", &"humidity", &"precipitation", &"co2", &"oxygen", &"biomass"]
const SPECIES: Array[StringName] = [&"algae", &"moss", &"shrub", &"tree"]
const CRISES: Array[StringName] = [&"world_event_started", &"species_extinct"]
## A difference "lasts" while it stays above this share of its peak.
const LASTING_SHARE := 0.25


class CrisisWatch extends RunObserver:
	var tick := -1

	func attach(bus: EventBus) -> void:
		bus.subscribe_all(_on_event)

	func _on_event(event: SimEvent) -> void:
		if tick == -1 and event.tick > WARM_UP and CRISES.has(event.type):
			tick = event.tick


func _init() -> void:
	var seeds := 3
	var actions: Array = ACTIONS
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			seeds = args[i + 1].to_int()
		elif args[i] == "--actions" and i + 1 < args.size():
			actions = Array(args[i + 1].split(","))
	var names: Array[StringName] = PARAMS.duplicate()
	for species in SPECIES:
		names.append(StringName("pop_" + species))
	# action -> name -> [peak sum, peak tick sum, lasting sum, runs]
	var totals := {}
	var runs := 0
	for archetype: String in ARCHETYPES:
		for seed_value in range(1, seeds + 1):
			runs += 1
			var save := _save_at_crisis(archetype, seed_value)
			var base := _trace(archetype, seed_value, save, "")
			for action: String in actions:
				var branch := _trace(archetype, seed_value, save, action)
				if not totals.has(action):
					totals[action] = {}
				for name in names:
					var peak := 0.0
					var peak_at := 0
					for k in WATCH:
						var d := absf(branch[name][k] - base[name][k])
						if d > peak:
							peak = d
							peak_at = k
					var lasting := 0
					for k in WATCH:
						if peak > 0.0 and absf(branch[name][k] - base[name][k]) >= LASTING_SHARE * peak:
							lasting = k
					var row: Array = totals[action].get(name, [0.0, 0.0, 0.0, 0])
					row[0] += peak
					row[1] += peak_at
					row[2] += lasting
					row[3] += 1
					totals[action][name] = row
	print("Average over %d runs, action at the first crisis after tick %d, watched %d ticks." % [runs, WARM_UP, WATCH])
	print("Cells: peak |difference| @ ticks to peak, lasting = last tick still >= %d%% of the peak." % roundi(LASTING_SHARE * 100))
	for action: String in totals:
		print("\n%s" % action)
		for name in names:
			var row: Array = totals[action][name]
			print("  %-16s peak %7.3f @ %5d   lasting %5d" % [name, row[0] / row[3], roundi(row[1] / row[3]), roundi(row[2] / row[3])])
	quit(0)


func _planet(archetype: String, seed_value: int) -> Dictionary:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value) \
			.with_personality(StringName(archetype))
	return SimulationRunner.build_planet(config, SimulationRunner.parse_args(PackedStringArray()).value).value


func _run_info(planet: Dictionary) -> Dictionary:
	return {"personality": planet["personality"], "data_fingerprints": planet["fingerprints"], "lineage": []}


func _save_at_crisis(archetype: String, seed_value: int) -> Dictionary:
	var planet := _planet(archetype, seed_value)
	var manager: SimulationManager = planet["manager"]
	var watch := CrisisWatch.new()
	manager.attach_log(watch)
	while watch.tick == -1 and manager.tick() < 20000:
		manager.step()
	return SaveSystem.capture(manager, _run_info(planet))


## name -> Array of WATCH values (plain Arrays: packed arrays stored in a
## Dictionary are copied on write, so appending through it would be lost).
func _trace(archetype: String, seed_value: int, save: Dictionary, action: String) -> Dictionary:
	var planet := _planet(archetype, seed_value)
	var manager: SimulationManager = planet["manager"]
	SaveSystem.restore(manager, save, _run_info(planet))
	if not action.is_empty():
		var submitted := SimulationRunner.submit_acts(manager, [action])
		if not submitted.is_ok():
			printerr(submitted.errors)
	var biosphere := manager.system(BiosphereSystem.ID) as BiosphereSystem
	var series := {}
	for name in PARAMS:
		series[name] = []
	for species in SPECIES:
		series[StringName("pop_" + species)] = []
	for k in WATCH:
		manager.step()
		var snapshot := manager.snapshot()
		for name in PARAMS:
			(series[name] as Array).append(snapshot.get_value(name))
		for species in SPECIES:
			(series[StringName("pop_" + species)] as Array).append(biosphere.population(species))
	return series
