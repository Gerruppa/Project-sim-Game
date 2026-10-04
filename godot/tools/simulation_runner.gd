class_name SimulationRunner
extends RefCounted
## Console glue around SimulationManager: command-line options and log files.
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
  --quiet         do not echo the text log to the console
  --climate PATH     climate coefficients file (default res://resources/climate/climate.json)
  --atmosphere PATH  atmosphere coefficients file (default res://resources/atmosphere/atmosphere.json)
  --species PATH     species catalog (default res://resources/biosphere/species.json)
  --biosphere PATH   biosphere coefficients (default res://resources/biosphere/biosphere.json)
                     other files describe planets of a different character"""


static func parse_args(args: PackedStringArray) -> SimResult:
	var result := SimResult.new()
	var options := {"realtime": false, "ticks": DEFAULT_TICKS, "speed": 1, "seconds": DEFAULT_SECONDS,
			"quiet": false, "climate": ClimateConfig.DEFAULT_PATH, "atmosphere": AtmosphereConfig.DEFAULT_PATH,
			"species": SpeciesCatalog.DEFAULT_PATH, "biosphere": BiosphereConfig.DEFAULT_PATH}
	var i := 0
	while i < args.size():
		var arg := args[i]
		match arg:
			"--realtime":
				options["realtime"] = true
			"--quiet":
				options["quiet"] = true
			"--climate", "--atmosphere", "--species", "--biosphere":
				if i + 1 >= args.size() or args[i + 1].begins_with("--"):
					result.add_error("%s needs a file path" % arg)
					break
				i += 1
				options[arg.trim_prefix("--")] = args[i]
			"--seed", "--ticks", "--speed", "--seconds":
				if i + 1 >= args.size():
					result.add_error("%s needs a value" % arg)
					break
				i += 1
				_read_number(arg, args[i], options, result)
			_:
				result.add_error("unknown option %s" % arg)
		i += 1
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
	if key != "seed" and value < 1:
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


static func _open_into(path: String, sinks: Array[LogSink], result: SimResult) -> void:
	var opened := FileLogSink.open(path)
	if opened.is_ok():
		sinks.append(opened.value)
	else:
		result.errors.append_array(opened.errors)
