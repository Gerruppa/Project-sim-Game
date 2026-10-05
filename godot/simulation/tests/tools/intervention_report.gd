extends SceneTree
## Fun check for interventions (docs/gameplay.md): does every action change
## the planet's story, does it have a price, and is any action always best?
##   godot --headless --path godot -s res://simulation/tests/tools/intervention_report.gd -- [--seeds N] [--at decision|extinction|event:<id>] [--actions a,b]
## For every archetype and seed: run to the act tick, save, then continue
## once without intervention and once per action, and compare what followed.
## The act tick is ACT_TICK, or with --at decision the first crisis after
## WARM_UP (a drought starts or a species dies out): the player's real moment.
## Outcomes are averaged over the watched window, not read at its end: the
## planet recovers within 1000-2500 ticks (intervention_trace.gd), so the
## end state hides what the player saw happen.
## --at extinction acts at the first species dying out after WARM_UP;
## "$extinct" in an action is replaced by that species (seed_species:$extinct
## asks whether bringing a lost species back pays off). Runs without an
## extinction are skipped. --at event:<id> acts when that world event first
## starts (e.g. event:fire_season).

const ACT_TICK := 2500
## How long consequences are watched after the act.
const WATCH := 2000
const WARM_UP := 1500
const CRISES: Array[StringName] = [&"world_event_started", &"species_extinct"]
const ARCHETYPES := ["harmonious", "chaotic", "guardian"]
const ACTIONS := ["seed_species:shrub", "seed_species:tree", "cull_species:moss", "cull_species:shrub", "mirrors_warm",
		"mirrors_cool", "cloud_seeding", "aquifer_release", "volcanic_awakening"]
## Population above which a species counts as alive.
const ALIVE_ABOVE := 1.0
## Difference in mean living species that counts as a gain or a loss.
const ALIVE_MARGIN := 0.25
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


class CrisisWatch extends RunObserver:
	var tick := -1
	var what := ""
	var species := ""
	var types: Array[StringName]
	## Only this world event counts, when set.
	var event_id := ""

	func _init(types_value: Array[StringName]) -> void:
		types = types_value

	func attach(bus: EventBus) -> void:
		bus.subscribe_all(_on_event)

	func _on_event(event: SimEvent) -> void:
		if tick == -1 and event.tick > WARM_UP and types.has(event.type) \
				and (event_id.is_empty() or event.data.get("id") == event_id):
			tick = event.tick
			species = str(event.data.get("species", ""))
			what = "%s %s" % [event.type, event.data.get("id", species)]


## Species that died out at the act tick of the current run (--at extinction).
var _extinct := ""


class Outcome:
	var lines := PackedStringArray()
	var extinctions := 0
	var biomass := 0.0
	var mean_temperature := 0.0
	var alive := 0.0


func _init() -> void:
	var seeds := 3
	var at_mode := ""
	var actions: Array = ACTIONS
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			seeds = args[i + 1].to_int()
		elif args[i] == "--at" and i + 1 < args.size():
			at_mode = args[i + 1]
		elif args[i] == "--actions" and i + 1 < args.size():
			actions = Array(args[i + 1].split(","))
	var started := Time.get_ticks_msec()
	# action -> [changed, priced, gained, Δbiomass sum, ΔT sum]
	var totals := {}
	for action: String in actions:
		totals[action] = [0, 0, 0, 0.0, 0.0]
	var runs := 0
	for archetype: String in ARCHETYPES:
		for seed_value in range(1, seeds + 1):
			runs += 1
			var save := _save_before_act(archetype, seed_value, at_mode)
			if save.is_empty():
				runs -= 1
				continue
			var act_tick := int(save["tick"]) + 1
			var base := _continue(archetype, seed_value, save, "", act_tick)
			for raw_action: String in actions:
				var action := raw_action.replace("$extinct", _extinct)
				var outcome := _continue(archetype, seed_value, save, action, act_tick)
				var row: Array = totals[raw_action]
				var changed := outcome.lines != base.lines
				var priced := outcome.extinctions > base.extinctions or outcome.alive < base.alive - ALIVE_MARGIN \
						or outcome.biomass < base.biomass * (1.0 - BIOMASS_MARGIN)
				var gained := outcome.alive > base.alive + ALIVE_MARGIN or outcome.extinctions < base.extinctions \
						or outcome.biomass > base.biomass * (1.0 + BIOMASS_MARGIN)
				row[0] += 1 if changed else 0
				row[1] += 1 if priced else 0
				row[2] += 1 if gained else 0
				row[3] += outcome.biomass - base.biomass
				row[4] += outcome.mean_temperature - base.mean_temperature
				print("%-10s seed %d @%-5d %-20s changed %-5s price %-5s gain %-5s | mean biomass %6.2f vs %6.2f | T %5.2f vs %5.2f | alive %.2f vs %.2f | extinctions %d vs %d"
						% [archetype, seed_value, act_tick, action, changed, priced, gained, outcome.biomass, base.biomass,
						outcome.mean_temperature, base.mean_temperature, outcome.alive, base.alive,
						outcome.extinctions, base.extinctions])
	print("")
	print("action               | changed | has a price | gains | avg Δbiomass | avg ΔT   (of %d runs, act %s, watched %d ticks)"
			% [runs, "at tick %d" % ACT_TICK if at_mode.is_empty() else "at the first %s after tick %d" % [at_mode, WARM_UP], WATCH])
	for action: String in actions:
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


## The save the actions branch from: the tick before ACT_TICK, or the end of
## the first crisis tick (the player decides after seeing it).
func _save_before_act(archetype: String, seed_value: int, at_mode: String) -> Dictionary:
	var planet := _planet(archetype, seed_value)
	var manager: SimulationManager = planet["manager"]
	if at_mode.is_empty():
		manager.run_ticks(ACT_TICK - 1)
		return SaveSystem.capture(manager, _run_info(planet))
	var types: Array[StringName] = CRISES
	if at_mode == "extinction":
		types = [&"species_extinct"]
	elif at_mode.begins_with("event:"):
		types = [&"world_event_started"]
	var watch := CrisisWatch.new(types)
	if at_mode.begins_with("event:"):
		watch.event_id = at_mode.substr(6)
	manager.attach_log(watch)
	while watch.tick == -1 and manager.tick() < 30000:
		manager.step()
	if watch.tick == -1:
		print("%-10s seed %d: no %s, skipped" % [archetype, seed_value, at_mode])
		return {}
	_extinct = watch.species
	print("%-10s seed %d crisis at tick %d: %s" % [archetype, seed_value, manager.tick(), watch.what])
	return SaveSystem.capture(manager, _run_info(planet))


func _continue(archetype: String, seed_value: int, save: Dictionary, action: String, act_tick: int) -> Outcome:
	var planet := _planet(archetype, seed_value)
	var manager: SimulationManager = planet["manager"]
	SaveSystem.restore(manager, save, _run_info(planet))
	var recorder := Recorder.new()
	manager.attach_log(recorder)
	if not action.is_empty():
		var submitted := SimulationRunner.submit_acts(manager, [action])
		if not submitted.is_ok():
			printerr(submitted.errors)
	var biosphere := manager.system(BiosphereSystem.ID) as BiosphereSystem
	var outcome := Outcome.new()
	for tick in WATCH:
		manager.step()
		var snapshot := manager.snapshot()
		outcome.mean_temperature += snapshot.get_value(Param.TEMPERATURE) / WATCH
		outcome.biomass += snapshot.get_value(Param.BIOMASS) / WATCH
		for id: StringName in biosphere.species_ids():
			outcome.alive += (1.0 if biosphere.population(id) > ALIVE_ABOVE else 0.0) / WATCH
	outcome.lines = recorder.lines
	outcome.extinctions = recorder.extinctions
	return outcome
