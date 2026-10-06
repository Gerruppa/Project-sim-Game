class_name SimulationRunner
extends RefCounted
## Console glue around SimulationManager: command-line options, building the
## planet, log files and saves.
##
## Part of the game layer (game/): kept out of simulation/ because it does
## file and process work. The entry points in tools/ (run_simulation.gd,
## play.gd) only call into game/, so everything here is testable.

const DEFAULT_TICKS := 3600
const DEFAULT_SECONDS := 60.0
const USAGE := """Usage: run_simulation.sh [options]
  --seed N        override the seed from sim_config.json
  --ticks N       batch mode: run N ticks as fast as possible (default 3600 = 1 h at x1)
  --realtime      run in real time instead of batch mode
  --speed S       real-time speed multiplier (1, 10, 100)
  --seconds S     real-time duration in seconds (default 60)
  --quiet         do not echo anything to the console
  --story         echo the planet chronicle instead of the full text log
  --climate PATH     climate coefficients file (default res://resources/climate/climate.json)
  --atmosphere PATH  atmosphere coefficients file (default res://resources/atmosphere/atmosphere.json)
  --species PATH     species catalog (default res://resources/biosphere/species.json)
  --biosphere PATH   biosphere coefficients (default res://resources/biosphere/biosphere.json)
  --events PATH      world event definitions (default res://resources/events/events.json)
  --personality NAME harmonious, chaotic, guardian, random or none (default from sim_config.json)
                     other files describe planets of a different character
  --act NAME[:ARG][:LEVEL]  intervene at the first tick of the run (repeatable), e.g.
                     --act seed_species:moss  --act mirrors_cool:weak  --act cloud_seeding
                     mirrors and dust take a level: weak, medium or strong (default)
                     known: seed_species, cull_species, mirrors_warm, mirrors_cool,
                     cloud_seeding, aquifer_release, volcanic_awakening
                     (res://resources/interventions/interventions.json)
  --until decision  stop at the first decision point (a drought starts, a species
                     appears or dies out), save it to <save directory>/decision.json
                     (or --save PATH) and show what the player can do; --ticks is the limit
  --save PATH     save the run when it ends
  --load PATH     continue a saved run (seed and personality come from the save;
                  --ticks counts ticks after the save)
  --autosave N    save every N ticks to <save directory>/<run id>.autosave.json (0 = off,
                  default from sim_config.json)
  A bare file name for --save/--load lives in the save directory from sim_config.json;
  other relative paths are relative to the Godot project (godot/)."""


static func parse_args(args: PackedStringArray) -> SimResult:
	var result := SimResult.new()
	var options := {"realtime": false, "ticks": DEFAULT_TICKS, "speed": 1, "seconds": DEFAULT_SECONDS,
			"quiet": false, "story": false, "climate": ClimateConfig.DEFAULT_PATH, "atmosphere": AtmosphereConfig.DEFAULT_PATH,
			"species": SpeciesCatalog.DEFAULT_PATH, "biosphere": BiosphereConfig.DEFAULT_PATH,
			"events": EventCatalog.DEFAULT_PATH, "act": []}
	var i := 0
	while i < args.size():
		var arg := args[i]
		match arg:
			"--realtime":
				options["realtime"] = true
			"--act":
				if i + 1 >= args.size() or args[i + 1].begins_with("--"):
					result.add_error("--act needs an intervention, e.g. --act seed_species:moss")
					break
				i += 1
				(options["act"] as Array).append(args[i])
			"--quiet":
				options["quiet"] = true
			"--story":
				options["story"] = true
			"--climate", "--atmosphere", "--species", "--biosphere", "--events", "--personality", "--save", "--load", "--until":
				if i + 1 >= args.size() or args[i + 1].begins_with("--"):
					result.add_error("%s needs a value" % arg)
					break
				i += 1
				options[arg.trim_prefix("--")] = args[i]
			"--seed", "--ticks", "--speed", "--seconds", "--autosave":
				if i + 1 >= args.size():
					result.add_error("%s needs a value" % arg)
					break
				i += 1
				_read_number(arg, args[i], options, result)
			_:
				result.add_error("unknown option %s" % arg)
		i += 1
	if options.has("until") and options["until"] != "decision":
		result.add_error("--until takes 'decision'")
	if options.has("load") and (options.has("seed") or options.has("personality")):
		result.add_error("--load takes seed and personality from the save; drop --seed/--personality")
	if result.is_ok():
		result.value = options
	return result


static func _read_number(option: String, text: String, options: Dictionary, result: SimResult) -> void:
	var key := option.trim_prefix("--")
	if key == "seconds":
		if not text.is_valid_float() or text.to_float() <= 0.0:
			result.add_error("--seconds must be a positive number")
			return
		options[key] = text.to_float()
		return
	if not text.is_valid_int():
		result.add_error("%s must be an integer" % option)
		return
	var value := text.to_int()
	if key == "autosave" and value < 0:
		result.add_error("--autosave must be >= 0 (0 = off)")
		return
	if key not in ["seed", "autosave"] and value < 1:
		result.add_error("%s must be >= 1" % option)
		return
	options[key] = value


## Relative paths are resolved against the Godot project directory. In an
## exported game there is no project directory (res:// is read-only inside
## the package), so they go to the game's user folder: "../saves" becomes
## user://saves.
static func resolve_directory(directory: String, exported: bool = OS.has_feature("template")) -> String:
	if directory.begins_with("res://") or directory.begins_with("user://"):
		return ProjectSettings.globalize_path(directory)
	if directory.is_absolute_path():
		return directory
	if exported:
		return ProjectSettings.globalize_path("user://").path_join(directory.trim_prefix("../")).simplify_path()
	return ProjectSettings.globalize_path("res://").path_join(directory).simplify_path()


## Opens a run as the options ask: a new planet, or a saved one continued.
## Value: {"manager", "config", "run" (for SaveSystem.capture; its "extras"
## hold the save's game-layer data), "warnings", "loaded" (bool)}. A save decides seed and personality, so it is read
## before the planet is built.
static func open_run(options: Dictionary) -> SimResult:
	var config_result := SimConfig.load_json(SimConfig.DEFAULT_PATH)
	if not config_result.is_ok():
		return config_result
	var config: SimConfig = config_result.value
	if options.has("seed"):
		config = config.with_seed(options["seed"])
	if options.has("personality"):
		config = config.with_personality(StringName(options["personality"]))

	var save_data := {}
	var lineage := []
	var extras := {}
	if options.has("load"):
		var load_path := resolve_save_path(options["load"], config)
		var read := SaveSystem.read(load_path)
		var header := SaveSystem.read_header(read.value) if read.is_ok() else read
		if not header.is_ok():
			return header
		save_data = read.value
		config = config.with_seed(header.value["seed"]).with_personality(header.value["personality"])
		lineage = (header.value["lineage"] as Array).duplicate()
		lineage.append({"save": load_path.get_file(), "tick": header.value["tick"]})
		extras = header.value["extras"]

	var planet := build_planet(config, options)
	if not planet.is_ok():
		return planet
	var manager: SimulationManager = planet.value["manager"]
	var run := {"personality": planet.value["personality"], "data_fingerprints": planet.value["fingerprints"],
			"lineage": lineage, "extras": extras}
	var warnings := PackedStringArray()
	if options.has("load"):
		var restored := SaveSystem.restore(manager, save_data, run)
		if not restored.is_ok():
			return restored
		warnings = restored.warnings
	return SimResult.success({"manager": manager, "config": config, "run": run, "warnings": warnings,
			"loaded": options.has("load")})


## A bare file name lives in the save directory; other paths go through
## resolve_directory.
static func resolve_save_path(path: String, config: SimConfig) -> String:
	if path.get_file() == path:
		return resolve_directory(config.save_directory()).path_join(path)
	return resolve_directory(path)


## The planet as the console runs it: every system in build order.
## Value: {"manager", "personality" (archetype id), "fingerprints"
## (SHA-256 of every data file the dynamics depend on)}.
static func build_planet(config: SimConfig, options: Dictionary) -> SimResult:
	var schema_result := ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH)
	if not schema_result.is_ok():
		return schema_result
	var manager_result := SimulationManager.create(config, schema_result.value)
	if not manager_result.is_ok():
		return manager_result
	var manager: SimulationManager = manager_result.value

	var climate := ClimateConfig.load_json(options["climate"])
	var atmosphere := AtmosphereConfig.load_json(options["atmosphere"])
	var catalog := SpeciesCatalog.load_json(options["species"])
	var biosphere := BiosphereConfig.load_json(options["biosphere"])
	var specs := {&"climate": ClimateConfig.SPEC, &"atmosphere": AtmosphereConfig.SPEC, &"biosphere": BiosphereConfig.SPEC}
	var personality_catalog := PersonalityCatalog.load_json(PersonalityCatalog.DEFAULT_PATH, specs)
	var failed := SimResult.new()
	for loaded: SimResult in [climate, atmosphere, catalog, biosphere, personality_catalog]:
		failed.errors.append_array(loaded.errors)
	if not failed.is_ok():
		return failed

	# Domain systems, registered as they are built (build order: climate, atmosphere, biosphere, then providers).
	manager.register_system(ClimateSystem.new(climate.value, config.seed()))
	manager.register_system(AtmosphereSystem.new(atmosphere.value))
	manager.register_system(BiosphereSystem.new(biosphere.value, catalog.value, config.seed()))
	# Personality after them: it only adds modifiers, which reach every system before compute.
	var personality := PersonalitySystem.create(personality_catalog.value, config.personality(), config.seed())
	if not personality.is_ok():
		return personality
	manager.register_system(personality.value)
	# Events after every system whose coefficients they modify; the archetype
	# selects the planet's reactions.
	var events := EventCatalog.load_json(options["events"], schema_result.value, specs, personality_catalog.value.ids())
	if not events.is_ok():
		return events
	var archetype: StringName = personality.value.archetype_id()
	manager.register_system(EventSystem.new(events.value, archetype))
	# The player's hand: it reaches others only through modifiers and commands.
	var interventions := InterventionCatalog.load_json(InterventionCatalog.DEFAULT_PATH, specs, {&"biosphere": BiosphereSystem.COMMANDS})
	if not interventions.is_ok():
		return interventions
	manager.register_system(InterventionSystem.new(interventions.value, (catalog.value as SpeciesCatalog).ids()))
	# The player's purse after it: Sparks and perks, which act on the planet through modifiers.
	var perks := PerkCatalog.load_json(PerkCatalog.DEFAULT_PATH, specs, interventions.value.ids())
	if not perks.is_ok():
		return perks
	manager.register_system(PerkSystem.new(perks.value))

	return SimResult.success({
		"manager": manager,
		"personality": archetype,
		"fingerprints": SaveSystem.fingerprints({
			"parameters": ParameterSchema.DEFAULT_PATH, "climate": options["climate"],
			"atmosphere": options["atmosphere"], "species": options["species"],
			"biosphere": options["biosphere"], "personality": PersonalityCatalog.DEFAULT_PATH,
			"events": options["events"], "interventions": InterventionCatalog.DEFAULT_PATH,
			"perks": PerkCatalog.DEFAULT_PATH,
		}),
	})


## Queues every --act for the next tick. All errors at once.
static func submit_acts(manager: SimulationManager, acts: Array) -> SimResult:
	var result := SimResult.new()
	var hand := manager.system(InterventionSystem.ID) as InterventionSystem
	for text: String in acts:
		var parsed := hand.catalog().parse_text(text)
		var submitted := manager.submit(InterventionSystem.ID, parsed.value["action"], parsed.value["args"]) if parsed.is_ok() else parsed
		result.errors.append_array(submitted.errors)
	return result


## Default save of a decision point: one fixed name, so the loop is always
## --load decision.json --act ... --until decision.
const DECISION_SAVE := "decision.json"


static func create_watcher(manager: SimulationManager) -> SimResult:
	var texts := ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH)
	if not texts.is_ok():
		return texts
	var catalog := (manager.system(InterventionSystem.ID) as InterventionSystem).catalog()
	return SimResult.success(DecisionWatcher.new(catalog.decision_events, catalog.decision_grace, manager.tick(), texts.value,
			manager.snapshot().schema()))


## What the player reads at a decision point: what happened, where it was
## saved, what they can do now and the command that continues the run.
static func decision_report(manager: SimulationManager, watcher: DecisionWatcher, save_path: String) -> PackedStringArray:
	var lines := PackedStringArray(["", "=== Punkt decyzji: tick %d ===" % manager.tick()])
	lines.append_array(watcher.sentences())
	# What the player needs for a hypothesis: the planet's state in its own words.
	var snapshot := manager.snapshot()
	var schema := snapshot.schema()
	var values := PackedStringArray()
	for i in schema.size():
		values.append("%s %.1f" % [schema.def_at(i).display_name(), snapshot.get_value_at(i)])
	lines.append("Planeta (skala 0-100): " + ", ".join(values))
	lines.append("Zapis: %s" % save_path)
	lines.append("Interwencje:")
	var hand := manager.system(InterventionSystem.ID) as InterventionSystem
	var biosphere := manager.system(BiosphereSystem.ID) as BiosphereSystem
	for id in hand.catalog().ids():
		var def := hand.catalog().get_def(id)
		var ready := hand.ready_at(id)
		lines.append("  %-40s %-24s %s" % [InterventionCatalog.usage(def), def.name, "gotowe" if ready <= manager.tick() + 1 else "od ticku %d" % ready])
	if biosphere != null:
		var species := PackedStringArray()
		for data in biosphere.species_ids():
			species.append("%s %.1f%s" % [data, biosphere.population(data), " (wymarłe)" if biosphere.is_lost(data) else ""])
		lines.append("Gatunki (populacja 0-100): " + ", ".join(species))
	lines.append("Dalej: ./godot/run_simulation.sh --load %s --act <interwencja> --until decision --story" % save_path.get_file())
	return lines


## File-name friendly id; the timestamp only names files, it never enters the logs.
static func run_id(seed_value: int) -> String:
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	return "seed%d_%s" % [seed_value, stamp]


## Opens <run_id>.log and <run_id>.jsonl according to the config.
static func create_log(config: SimConfig, id: String, echo: bool) -> SimResult:
	var directory := resolve_directory(config.log_directory())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return SimResult.failure("cannot create log directory %s: %s" % [directory, error_string(error)])

	var result := SimResult.new()
	var text_sinks: Array[LogSink] = []
	var jsonl_sinks: Array[LogSink] = []
	if config.log_text():
		_open_into(directory.path_join(id + ".log"), text_sinks, result)
	if config.log_jsonl():
		_open_into(directory.path_join(id + ".jsonl"), jsonl_sinks, result)
	if echo:
		text_sinks.append(PrintLogSink.new())
	if not result.is_ok():
		for sink in text_sinks + jsonl_sinks:
			sink.close()
		return result
	result.value = SimulationLog.new(text_sinks, jsonl_sinks, config.log_deltas())
	return result


## Opens <run_id>.chronicle.txt if the config asks for it; `echo` prints the
## chronicle to the console. Value is null when the chronicle goes nowhere.
static func create_chronicle(config: SimConfig, id: String, echo: bool, texts_path: String = ChronicleTexts.DEFAULT_PATH,
		number_format: Callable = Callable()) -> SimResult:
	var texts := ChronicleTexts.load_json(texts_path)
	if not texts.is_ok():
		return texts
	texts.value.number_format = number_format
	var result := SimResult.new()
	var sinks: Array[LogSink] = []
	if config.log_chronicle():
		var directory := resolve_directory(config.log_directory())
		var error := DirAccess.make_dir_recursive_absolute(directory)
		if error != OK:
			return SimResult.failure("cannot create log directory %s: %s" % [directory, error_string(error)])
		_open_into(directory.path_join(id + ".chronicle.txt"), sinks, result)
	if echo:
		sinks.append(PrintLogSink.new())
	if not result.is_ok():
		for sink in sinks:
			sink.close()
		return result
	result.value = PlanetChronicle.new(sinks, texts.value) if not sinks.is_empty() else null
	return result


static func _open_into(path: String, sinks: Array[LogSink], result: SimResult) -> void:
	var opened := FileLogSink.open(path)
	if opened.is_ok():
		sinks.append(opened.value)
	else:
		result.errors.append_array(opened.errors)
