class_name SimulationRunner
extends RefCounted
## Console glue around SimulationManager: command-line options, building the
## planet, log files and saves.
##
## Kept out of simulation/ because it does file and process work.
## The SceneTree entry point (run_simulation.gd) only calls into this class,
## so everything here is testable.

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
			"events": EventCatalog.DEFAULT_PATH}
	var i := 0
	while i < args.size():
		var arg := args[i]
		match arg:
			"--realtime":
				options["realtime"] = true
			"--quiet":
				options["quiet"] = true
			"--story":
				options["story"] = true
			"--climate", "--atmosphere", "--species", "--biosphere", "--events", "--personality", "--save", "--load":
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


## Relative paths are resolved against the Godot project directory.
static func resolve_directory(directory: String) -> String:
	if directory.begins_with("res://") or directory.begins_with("user://"):
		return ProjectSettings.globalize_path(directory)
	if directory.is_absolute_path():
		return directory
	return ProjectSettings.globalize_path("res://").path_join(directory).simplify_path()


## A bare file name lives in the save directory; other paths go through
## resolve_directory.
static func resolve_save_path(path: String, config: SimConfig) -> String:
	if path.get_file() == path:
		return resolve_directory(config.save_directory()).path_join(path)
	return resolve_directory(path)


## The planet as the console runs it: every system in CLAUDE.md order.
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

	# Domain systems, registered as they are built (CLAUDE.md SYSTEM PRIORITY).
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

	return SimResult.success({
		"manager": manager,
		"personality": archetype,
		"fingerprints": SaveSystem.fingerprints({
			"parameters": ParameterSchema.DEFAULT_PATH, "climate": options["climate"],
			"atmosphere": options["atmosphere"], "species": options["species"],
			"biosphere": options["biosphere"], "personality": PersonalityCatalog.DEFAULT_PATH,
			"events": options["events"],
		}),
	})


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
static func create_chronicle(config: SimConfig, id: String, echo: bool, texts_path: String = ChronicleTexts.DEFAULT_PATH) -> SimResult:
	var texts := ChronicleTexts.load_json(texts_path)
	if not texts.is_ok():
		return texts
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
