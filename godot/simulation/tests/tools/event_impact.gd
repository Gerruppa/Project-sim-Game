extends SceneTree
## How much does a world event hurt the planet? Runs every archetype and seed
## twice: with every event, and with every event except the measured one
## (events have no randomness, so the runs differ only by what that event
## does), and compares them while it is active and in the ticks after it.
##   godot --headless --path godot -s res://simulation/tests/tools/event_impact.gd -- [--seeds N] [--ticks N] [--event id]

const ARCHETYPES := ["harmonious", "chaotic", "guardian"]
const PARAMS: Array[StringName] = [&"humidity", &"precipitation", &"temperature", &"biomass"]
const SPECIES: Array[StringName] = [&"algae", &"moss", &"shrub", &"tree"]
## Ticks after an event ends that still count as its aftermath.
const AFTERMATH := 300
## The project's events without the measured one (written at start).
const WITHOUT_PATH := "user://event_impact_without.json"


class EventSpan extends RunObserver:
	var event_id: String
	var active := false
	var ended_at := -1
	var count := 0
	var lengths := 0

	func _init(id: String) -> void:
		event_id = id

	func attach(bus: EventBus) -> void:
		bus.subscribe_all(_on_event)

	func _on_event(event: SimEvent) -> void:
		if event.data.get("id") != event_id:
			return
		if event.type == EventSystem.STARTED_EVENT:
			active = true
			count += 1
		elif event.type == EventSystem.ENDED_EVENT:
			active = false
			ended_at = event.tick
			lengths += int(event.data["duration"])


func _init() -> void:
	var seeds := 3
	var ticks := 8000
	var event_id := "drought"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--seeds": seeds = args[i + 1].to_int()
			"--ticks": ticks = args[i + 1].to_int()
			"--event": event_id = args[i + 1]
	_write_catalog_without(event_id)
	var names: Array[StringName] = PARAMS.duplicate()
	for species in SPECIES:
		names.append(StringName("pop_" + species))
	# phase -> name -> [sum with, sum without]; phase: "during", "after"
	var sums := {"during": {}, "after": {}}
	var phase_ticks := {"during": 0, "after": 0}
	var events := 0
	var event_ticks := 0
	var extinctions := [0, 0]
	for archetype: String in ARCHETYPES:
		for seed_value in range(1, seeds + 1):
			var with_events := _planet(archetype, seed_value, true)
			var without := _planet(archetype, seed_value, false)
			var span := EventSpan.new(event_id)
			(with_events["manager"] as SimulationManager).attach_log(span)
			var lost := [0, 0]
			(with_events["manager"] as SimulationManager).event_bus().subscribe(&"species_extinct", func(_e: SimEvent) -> void: lost[0] += 1)
			(without["manager"] as SimulationManager).event_bus().subscribe(&"species_extinct", func(_e: SimEvent) -> void: lost[1] += 1)
			for tick in ticks:
				(with_events["manager"] as SimulationManager).step()
				(without["manager"] as SimulationManager).step()
				var phase := ""
				if span.active:
					phase = "during"
				elif span.ended_at != -1 and tick + 1 - span.ended_at <= AFTERMATH:
					phase = "after"
				if phase.is_empty():
					continue
				phase_ticks[phase] += 1
				for name in names:
					var row: Array = sums[phase].get(name, [0.0, 0.0])
					row[0] += _value(with_events, name)
					row[1] += _value(without, name)
					sums[phase][name] = row
			events += span.count
			event_ticks += span.lengths
			extinctions[0] += lost[0]
			extinctions[1] += lost[1]
	print("%s: %d events in %d runs x %d ticks, mean length %.0f ticks" % [event_id, events, seeds * ARCHETYPES.size(),
			ticks, float(event_ticks) / maxi(events, 1)])
	print("extinctions in all runs: %d with %s, %d without it" % [extinctions[0], event_id, extinctions[1]])
	for phase: String in ["during", "after"]:
		print("\n%s (%d ticks): mean with %s vs without it (difference)" % [phase, phase_ticks[phase], event_id])
		for name in names:
			if not sums[phase].has(name):
				continue
			var row: Array = sums[phase][name]
			var a: float = row[0] / phase_ticks[phase]
			var b: float = row[1] / phase_ticks[phase]
			print("  %-14s %7.2f vs %7.2f  (%+.2f)" % [name, a, b, a - b])
	quit(0)


func _planet(archetype: String, seed_value: int, with_events: bool) -> Dictionary:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value) \
			.with_personality(StringName(archetype))
	var options: Dictionary = SimulationRunner.parse_args(PackedStringArray()).value
	if not with_events:
		options["events"] = WITHOUT_PATH
	return SimulationRunner.build_planet(config, options).value


func _write_catalog_without(event_id: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EventCatalog.DEFAULT_PATH))
	data["events"] = (data["events"] as Array).filter(func(e: Dictionary) -> bool: return e["id"] != event_id)
	var file := FileAccess.open(WITHOUT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _value(planet: Dictionary, name: StringName) -> float:
	var manager: SimulationManager = planet["manager"]
	if String(name).begins_with("pop_"):
		return (manager.system(BiosphereSystem.ID) as BiosphereSystem).population(StringName(String(name).substr(4)))
	return manager.snapshot().get_value(name)
