extends SceneTree
## How early are crises announced, and how often is the warning a false alarm?
## Runs every archetype and seed with no player and prints, per crisis, the
## ticks of each warning, start and withdrawal.
##   godot --headless --path godot -s res://simulation/tests/tools/warning_report.gd -- [--seeds N] [--ticks N] [--events PATH]

const ARCHETYPES := ["harmonious", "chaotic", "guardian"]

var events_path := ""


func _init() -> void:
	var seeds := 6
	var ticks := 30000
	events_path = EventCatalog.DEFAULT_PATH
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--seeds":
				seeds = int(args[i + 1])
			"--ticks":
				ticks = int(args[i + 1])
			"--events":
				events_path = args[i + 1]
	var leads := {}
	var false_alarms := {}
	var warned_total := {}
	var started_total := {}
	var unwarned := {}
	for archetype: String in ARCHETYPES:
		for seed_value in range(1, seeds + 1):
			var line := _run(seed_value, archetype, ticks, leads, false_alarms, warned_total, started_total, unwarned)
			print(line)
	print("--- summary over %d runs of %d ticks" % [seeds * ARCHETYPES.size(), ticks])
	for id: String in started_total:
		var lead: Array = leads.get(id, [])
		lead.sort()
		print("%-14s starts %3d, warned ahead %3d, unwarned %3d, lead min %s median %s, false alarms %d of %d warnings" % [
				id, started_total[id], lead.size(), unwarned.get(id, 0),
				str(lead[0]) if not lead.is_empty() else "-", str(lead[lead.size() / 2]) if not lead.is_empty() else "-",
				false_alarms.get(id, 0), warned_total.get(id, 0)])
	quit()


func _run(seed_value: int, archetype: String, ticks: int, leads: Dictionary, false_alarms: Dictionary,
		warned_total: Dictionary, started_total: Dictionary, unwarned: Dictionary) -> String:
	var options: Dictionary = SimulationRunner.parse_args(PackedStringArray(["--seed", str(seed_value), "--personality", archetype, "--events", events_path])).value
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value).with_personality(StringName(archetype))
	var manager: SimulationManager = SimulationRunner.build_planet(config, options).value["manager"]
	var warned_at := {}
	var text := PackedStringArray()
	manager.event_bus().subscribe(EventSystem.WARNED_EVENT, func(event: SimEvent) -> void:
		warned_at[event.data["id"]] = event.tick
		warned_total[event.data["id"]] = warned_total.get(event.data["id"], 0) + 1
		text.append("%s warned@%d" % [event.data["id"], event.tick]))
	manager.event_bus().subscribe(EventSystem.WARNING_CLEARED_EVENT, func(event: SimEvent) -> void:
		warned_at.erase(event.data["id"])
		false_alarms[event.data["id"]] = false_alarms.get(event.data["id"], 0) + 1
		text.append("%s cleared@%d" % [event.data["id"], event.tick]))
	manager.event_bus().subscribe(EventSystem.STARTED_EVENT, func(event: SimEvent) -> void:
		var id: String = event.data["id"]
		started_total[id] = started_total.get(id, 0) + 1
		if warned_at.has(id):
			var lead: int = event.tick - int(warned_at[id])
			var list: Array = leads.get(id, [])
			list.append(lead)
			leads[id] = list
			text.append("%s started@%d (lead %d)" % [id, event.tick, lead])
			warned_at.erase(id)
		else:
			unwarned[id] = unwarned.get(id, 0) + 1
			text.append("%s started@%d (NO WARNING)" % [id, event.tick]))
	manager.run_ticks(ticks)
	return "seed %d %-10s %s" % [seed_value, archetype, "; ".join(text)]
