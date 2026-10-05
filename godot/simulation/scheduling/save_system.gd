class_name SaveSystem
extends RefCounted
## Saves a run between ticks and continues it as if it was never stopped.
##
## A save holds the planet (PlanetStateCodec), the tick and every system's
## own state under its system_id. Modifiers are not saved: providers
## register them again from their restored state (one source of truth).
## SaveSystem never knows a concrete system, so a new system only adds
## save_state/load_state. Format: docs/simulation.md (Zapis).

const FORMAT := "genesis_save"
const SAVE_VERSION := 1
## Migrations from older versions: version -> Callable(Dictionary) -> Dictionary.
## Empty until the format changes (save_version 1 is the first).
const MIGRATIONS := {}


## `run` describes how the planet was built:
##   personality: archetype id; data_fingerprints: file name -> SHA-256;
##   lineage: saves this run continues (placeholder for branching runs).
static func capture(manager: SimulationManager, run: Dictionary) -> Dictionary:
	var planet := PlanetStateCodec.encode(manager.current_state())
	planet["state_hash"] = manager.state_hash()
	var systems := {}
	for system in manager.systems():
		systems[String(system.system_id())] = system.save_state()
	return {
		"format": FORMAT,
		"save_version": SAVE_VERSION,
		"engine": Engine.get_version_info()["string"],
		"seed": ExactCodec.int_to_text(manager.config().seed()),
		"tick": manager.tick(),
		"personality": String(run.get("personality", PersonalityCatalog.NONE)),
		"data_fingerprints": run.get("data_fingerprints", {}),
		"lineage": run.get("lineage", []),
		"planet": planet,
		"systems": systems,
		"commands": manager.command_queue().save_state(),
	}


## Checks the envelope and returns what is needed to build the planet
## before restoring it: {"seed", "tick", "personality", "lineage"}.
static func read_header(data: Dictionary) -> SimResult:
	var result := SimResult.new()
	if data.get("format") != FORMAT:
		return SimResult.failure("save: not a Genesis Error save (format must be '%s')" % FORMAT)
	var version: Variant = data.get("save_version")
	if not (typeof(version) in [TYPE_INT, TYPE_FLOAT]) or float(version) != floorf(float(version)):
		return SimResult.failure("save: 'save_version' must be an integer")
	if int(version) > SAVE_VERSION:
		return SimResult.failure("save: version %d is newer than this build reads (%d)" % [int(version), SAVE_VERSION])
	if int(version) < SAVE_VERSION and not MIGRATIONS.has(int(version)):
		return SimResult.failure("save: version %d can no longer be read (current %d)" % [int(version), SAVE_VERSION])
	var seed_read := ExactCodec.int_from_text(data.get("seed"), "save: 'seed'")
	result.errors.append_array(seed_read.errors)
	var tick: Variant = data.get("tick")
	if not (typeof(tick) in [TYPE_INT, TYPE_FLOAT]) or float(tick) < 0.0 or float(tick) != floorf(float(tick)):
		result.add_error("save: 'tick' must be an integer >= 0")
	if typeof(data.get("personality")) != TYPE_STRING or (data["personality"] as String).is_empty():
		result.add_error("save: 'personality' must be an archetype id or \"none\"")
	if typeof(data.get("lineage", [])) != TYPE_ARRAY:
		result.add_error("save: 'lineage' must be a list")
	for key: String in ["planet", "systems"]:
		if typeof(data.get(key)) != TYPE_DICTIONARY:
			result.add_error("save: '%s' must be an object" % key)
	if result.is_ok():
		result.value = {"seed": seed_read.value, "tick": int(tick), "personality": StringName(data["personality"]),
				"lineage": data.get("lineage", [])}
	return result


## Restores a save into a manager built the same way (same seed, systems
## and personality), before its first tick. Changed data files are warnings:
## the run continues, but no longer as the original would have.
## On failure the manager must be discarded.
static func restore(manager: SimulationManager, data: Dictionary, run: Dictionary) -> SimResult:
	var header := read_header(_migrated(data))
	if not header.is_ok():
		return header
	data = _migrated(data)
	var result := SimResult.new()
	if manager.is_started():
		result.add_error("save: restore needs a manager that has not run yet")
	if header.value["seed"] != manager.config().seed():
		result.add_error("save: seed %d differs from this planet's seed %d" % [header.value["seed"], manager.config().seed()])
	var personality := String(run.get("personality", PersonalityCatalog.NONE))
	if String(header.value["personality"]) != personality:
		result.add_error("save: personality '%s' differs from this planet's '%s'" % [header.value["personality"], personality])
	_check_systems(manager, data["systems"], result)
	_compare_fingerprints(data.get("data_fingerprints", {}), run.get("data_fingerprints", {}), result)

	var decoded := PlanetStateCodec.decode(manager.current_state().schema(), data["planet"])
	result.errors.append_array(decoded.errors)
	result.warnings.append_array(decoded.warnings)
	# The hash covers the parameter list, so it is checked only while the
	# schema is unchanged (otherwise the codec maps values by id and warns).
	var current_ids: Array = Array(manager.current_state().schema().ids()).map(
			func(id: StringName) -> String: return String(id))
	if decoded.is_ok() and data["planet"].get("parameter_order") == current_ids \
			and PlanetStateCodec.state_hash(decoded.value) != data["planet"].get("state_hash"):
		result.add_error("save: planet values do not match their state_hash (damaged file)")
	if not result.is_ok():
		return result

	var restored := manager.restore(header.value["tick"], decoded.value)
	result.errors.append_array(restored.errors)
	# Optional: saves from before commands existed have none queued.
	var commands: Variant = data.get("commands", {})
	if typeof(commands) != TYPE_DICTIONARY:
		result.add_error("save: 'commands' must be an object")
	else:
		result.errors.append_array(manager.command_queue().load_state(commands).errors)
	for system in manager.systems():
		var loaded := system.load_state(data["systems"][String(system.system_id())])
		result.errors.append_array(loaded.errors)
	if not result.is_ok():
		return result
	for system in manager.systems():
		if system is ModifierProvider:
			(system as ModifierProvider).restore_modifiers(manager.modifier_registry())
	result.value = manager
	return result


static func _check_systems(manager: SimulationManager, saved: Dictionary, result: SimResult) -> void:
	var ids: Array[String] = []
	for system in manager.systems():
		ids.append(String(system.system_id()))
		var state: Variant = saved.get(String(system.system_id()))
		if state == null:
			result.add_error("save: no state for system '%s'" % system.system_id())
		elif typeof(state) != TYPE_DICTIONARY:
			result.add_error("save: state of system '%s' must be an object" % system.system_id())
	for id: Variant in saved:
		if not ids.has(id):
			result.add_error("save: system '%s' is not part of this planet" % id)


static func _compare_fingerprints(saved: Variant, current: Dictionary, result: SimResult) -> void:
	if typeof(saved) != TYPE_DICTIONARY:
		result.add_warning("save has no data fingerprints; cannot check the data files")
		return
	var names: Array = (saved as Dictionary).keys()
	for name: Variant in current:
		if not names.has(name):
			names.append(name)
	names.sort()
	for name: Variant in names:
		if saved.get(name) != current.get(name):
			result.add_warning("data file '%s' changed since the save; the run continues differently" % name)


static func _migrated(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("save_version")
	if not (typeof(version) in [TYPE_INT, TYPE_FLOAT]):
		return data
	var migrated := data
	for from_version in range(int(version), SAVE_VERSION):
		if MIGRATIONS.has(from_version):
			migrated = (MIGRATIONS[from_version] as Callable).call(migrated)
	return migrated


## SHA-256 of each data file: name -> hex digest ("" if unreadable).
static func fingerprints(paths: Dictionary) -> Dictionary:
	var digests := {}
	for name: Variant in paths:
		digests[name] = FileAccess.get_sha256(paths[name])
	return digests


## Writes through a temporary file, so a crash never leaves half a save.
static func write(path: String, data: Dictionary) -> SimResult:
	var directory := path.get_base_dir()
	var made := DirAccess.make_dir_recursive_absolute(directory)
	if made != OK:
		return SimResult.failure("cannot create save directory %s: %s" % [directory, error_string(made)])
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return SimResult.failure("cannot write %s: %s" % [temporary, error_string(FileAccess.get_open_error())])
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.close()
	var renamed := DirAccess.rename_absolute(temporary, path)
	if renamed != OK:
		return SimResult.failure("cannot move %s to %s: %s" % [temporary, path, error_string(renamed)])
	return SimResult.success(path)


static func read(path: String) -> SimResult:
	if not FileAccess.file_exists(path):
		return SimResult.failure("save file not found: %s" % path)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return SimResult.failure("save JSON error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return SimResult.failure("save root must be an object: %s" % path)
	return SimResult.success(json.data)
