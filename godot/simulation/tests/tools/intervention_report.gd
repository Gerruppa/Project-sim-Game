extends SceneTree
## Fun check for interventions (docs/gameplay.md): does every action change
## the planet's story, does it have a price, and is any action always best?
##   godot --headless --path godot -s res://simulation/tests/tools/intervention_report.gd -- [--seeds N]
## For every archetype and seed: run to ACT_TICK, save, then continue once
## without intervention and once per action, and compare what followed.

const ACT_TICK := 2500
const TOTAL := 6500
const ARCHETYPES := ["harmonious", "chaotic", "guardian"]
const ACTIONS := ["seed_species:shrub", "seed_species:tree", "cull_species:moss", "mirrors_warm", "mirrors_cool",
		"cloud_seeding", "volcanic_awakening"]
## Population above which a species counts as alive at the end.
const ALIVE_ABOVE := 1.0
## Relative biomass change that counts as a gain or a loss.
const BIOMASS_MARGIN := 0.05


class Recorder extends RunObserver:
	var lines := PackedStringArray()
	var extinctions := 0

	func attach(bus: EventBus) -> void:
		bus.subscribe_all(_on_event)

	func _on_event(event: SimEvent) -> void:
		if event.type == SimEvent.TICK_APPLIED or String(event.type).begins_with("intervention_"):
			return
		lines.append("%d %s %s" % [event.tick, event.type, event.data.get("species", event.data.get("id", ""))])
		if event.type == &"species_extinct":
			extinctions += 1


class Outcome:
	var lines := PackedStringArray()
	var extinctions := 0
	var biomass := 0.0
	var mean_temperature := 0.0
	var alive := 0


func _init() -> void:
	var seeds := 3
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--seeds":
		seeds = args[1].to_int()
	var started := Time.get_ticks_msec()
	# action -> [changed, priced, gained, Δbiomass sum, ΔT sum]
	var totals := {}
	for action: String in ACTIONS:
		totals[action] = [0, 0, 0, 0.0, 0.0]
	var runs := 0
	for archetype: String in ARCHETYPES:
		for seed_value in range(1, seeds + 1):
			runs += 1
			var save := _save_at_act_tick(archetype, seed_value)
			var base := _continue(archetype, seed_value, save, "")
			for action: String in ACTIONS:
				var outcome := _continue(archetype, seed_value, save, action)
				var row: Array = totals[action]
				var changed := outcome.lines != base.lines
				var priced := outcome.extinctions > base.extinctions or outcome.alive < base.alive \
						or outcome.biomass < base.biomass * (1.0 - BIOMASS_MARGIN)
				var gained := outcome.alive > base.alive or outcome.extinctions < base.extinctions \
						or outcome.biomass > base.biomass * (1.0 + BIOMASS_MARGIN)
				row[0] += 1 if changed else 0
				row[1] += 1 if priced else 0
				row[2] += 1 if gained else 0
				row[3] += outcome.biomass - base.biomass
				row[4] += outcome.mean_temperature - base.mean_temperature
				print("%-10s seed %d %-20s changed %-5s price %-5s gain %-5s | biomass %6.2f vs %6.2f | T %5.2f vs %5.2f | alive %d vs %d | extinctions %d vs %d"
						% [archetype, seed_value, action, changed, priced, gained, outcome.biomass, base.biomass,
						outcome.mean_temperature, base.mean_temperature, outcome.alive, base.alive,
						outcome.extinctions, base.extinctions])
	print("")
	print("action               | changed | has a price | gains | avg Δbiomass | avg ΔT   (of %d runs, act at tick %d, to tick %d)" % [runs, ACT_TICK, TOTAL])
	for action: String in ACTIONS:
		var row: Array = totals[action]
		var verdict := "ALWAYS BEST" if row[2] == runs and row[1] == 0 else ("no effect" if row[0] < 2 else "")
		print("%-20s | %3d     | %3d         | %3d   | %+8.2f     | %+6.2f %s" % [action, row[0], row[1], row[2],
				row[3] / runs, row[4] / runs, verdict])
	print("time: %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit(0)


func _planet(archetype: String, seed_value: int) -> Dictionary:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value) \
			.with_personality(StringName(archetype))
	return SimulationRunner.build_planet(config, SimulationRunner.parse_args(PackedStringArray()).value).value


func _run_info(planet: Dictionary) -> Dictionary:
	return {"personality": planet["personality"], "data_fingerprints": planet["fingerprints"], "lineage": []}


func _save_at_act_tick(archetype: String, seed_value: int) -> Dictionary:
	var planet := _planet(archetype, seed_value)
	(planet["manager"] as SimulationManager).run_ticks(ACT_TICK - 1)
	return SaveSystem.capture(planet["manager"], _run_info(planet))


func _continue(archetype: String, seed_value: int, save: Dictionary, action: String) -> Outcome:
	var planet := _planet(archetype, seed_value)
	var manager: SimulationManager = planet["manager"]
	SaveSystem.restore(manager, save, _run_info(planet))
	var recorder := Recorder.new()
	manager.attach_log(recorder)
	if not action.is_empty():
		var submitted := SimulationRunner.submit_acts(manager, [action])
		if not submitted.is_ok():
			printerr(submitted.errors)
	var temperature_sum := 0.0
	for tick in range(ACT_TICK, TOTAL + 1):
		manager.step()
		temperature_sum += manager.snapshot().get_value(Param.TEMPERATURE)
	var outcome := Outcome.new()
	outcome.lines = recorder.lines
	outcome.extinctions = recorder.extinctions
	outcome.biomass = manager.snapshot().get_value(Param.BIOMASS)
	outcome.mean_temperature = temperature_sum / float(TOTAL - ACT_TICK + 1)
	var biosphere := manager.system(BiosphereSystem.ID) as BiosphereSystem
	for id: String in ["bacteria", "algae", "moss", "shrub", "tree"]:
		if biosphere.population(StringName(id)) > ALIVE_ABOVE:
			outcome.alive += 1
	return outcome
