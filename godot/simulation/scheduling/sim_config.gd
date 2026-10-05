class_name SimConfig
extends RefCounted
## Validated simulation settings: seed, tick rate, speeds, logging.
##
## Loaded from JSON. Immutable; with_seed() returns a modified copy
## for command-line overrides.

const DEFAULT_PATH := "res://resources/simulation/sim_config.json"
## Largest integer a JSON number (double) holds exactly.
const MAX_EXACT_INT := 9007199254740992.0
const LOG_FLAGS: Array[String] = ["text", "jsonl", "deltas"]

var _seed: int
var _base_ticks_per_second: float
var _speed_multipliers: Array[int] = []
var _max_catch_up_ticks: int
var _log_flags: Dictionary[String, bool] = {}
var _log_directory: String
## Archetype id, "random" (drawn from the seed) or "none".
var _personality: StringName


static func load_json(path: String) -> SimResult:
	if not FileAccess.file_exists(path):
		return SimResult.failure("config file not found: %s" % path)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return SimResult.failure("config JSON error in %s at line %d: %s"
				% [path, json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return SimResult.failure("config root must be an object: %s" % path)
	return from_data(json.data)


## Validates everything and reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	var result := SimResult.new()
	var config := SimConfig.new()

	if not _is_whole(data.get("config_version")) or float(data["config_version"]) < 1.0:
		result.add_error("config_version must be a positive integer")
	if not _is_whole(data.get("seed")) or absf(float(data["seed"])) > MAX_EXACT_INT:
		result.add_error("seed must be an integer within +/- 2^53")
	else:
		config._seed = int(data["seed"])

	var rate: Variant = data.get("base_ticks_per_second")
	if not _is_number(rate) or not is_finite(float(rate)) or float(rate) <= 0.0:
		result.add_error("base_ticks_per_second must be a positive number")
	else:
		config._base_ticks_per_second = float(rate)

	config._speed_multipliers = _read_multipliers(data.get("speed_multipliers"), result)

	if not _is_whole(data.get("max_catch_up_ticks")) or float(data["max_catch_up_ticks"]) < 1.0:
		result.add_error("max_catch_up_ticks must be an integer >= 1")
	else:
		config._max_catch_up_ticks = int(data["max_catch_up_ticks"])

	_read_log(data.get("log"), config, result)

	if typeof(data.get("personality")) != TYPE_STRING or (data["personality"] as String).is_empty():
		result.add_error("personality must be an archetype id, \"random\" or \"none\"")
	else:
		config._personality = StringName(data["personality"])

	if result.is_ok():
		result.value = config
	return result


static func _read_multipliers(raw: Variant, result: SimResult) -> Array[int]:
	var multipliers: Array[int] = []
	if typeof(raw) != TYPE_ARRAY:
		result.add_error("speed_multipliers must be a list of positive integers including 1")
		return multipliers
	for value: Variant in raw:
		if not _is_whole(value) or float(value) < 1.0 or multipliers.has(int(value)):
			result.add_error("speed_multipliers must hold unique positive integers")
			return multipliers
		multipliers.append(int(value))
	if not multipliers.has(1):
		result.add_error("speed_multipliers must include 1")
	return multipliers


static func _read_log(raw: Variant, config: SimConfig, result: SimResult) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("log must be an object with text, jsonl, deltas, directory")
		return
	var log_data := raw as Dictionary
	for flag in LOG_FLAGS:
		if typeof(log_data.get(flag)) != TYPE_BOOL:
			result.add_error("log.%s must be true or false" % flag)
		else:
			config._log_flags[flag] = log_data[flag]
	# Optional, so older configs keep working: the chronicle is on by default.
	if log_data.has("chronicle") and typeof(log_data["chronicle"]) != TYPE_BOOL:
		result.add_error("log.chronicle must be true or false")
	else:
		config._log_flags["chronicle"] = log_data.get("chronicle", true)
	if typeof(log_data.get("directory")) != TYPE_STRING or (log_data["directory"] as String).is_empty():
		result.add_error("log.directory must be a non-empty path")
	else:
		config._log_directory = log_data["directory"]


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


static func _is_whole(value: Variant) -> bool:
	return _is_number(value) and is_finite(float(value)) and float(value) == floorf(float(value))


func with_seed(seed_value: int) -> SimConfig:
	var copy := SimConfig.new()
	copy._seed = seed_value
	copy._base_ticks_per_second = _base_ticks_per_second
	copy._speed_multipliers = _speed_multipliers.duplicate()
	copy._max_catch_up_ticks = _max_catch_up_ticks
	copy._log_flags = _log_flags.duplicate()
	copy._log_directory = _log_directory
	copy._personality = _personality
	return copy


func with_personality(choice: StringName) -> SimConfig:
	var copy := with_seed(_seed)
	copy._personality = choice
	return copy


func personality() -> StringName:
	return _personality


func seed() -> int:
	return _seed


func base_ticks_per_second() -> float:
	return _base_ticks_per_second


func speed_multipliers() -> Array[int]:
	return _speed_multipliers.duplicate()


func max_catch_up_ticks() -> int:
	return _max_catch_up_ticks


func log_text() -> bool:
	return _log_flags.get("text", false)


func log_jsonl() -> bool:
	return _log_flags.get("jsonl", false)


func log_deltas() -> bool:
	return _log_flags.get("deltas", false)


func log_chronicle() -> bool:
	return _log_flags.get("chronicle", false)


## Relative paths are resolved against the Godot project directory.
func log_directory() -> String:
	return _log_directory
