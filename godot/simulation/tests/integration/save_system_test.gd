extends GdUnitTestSuite
## SaveSystem on the real planet: capture, validation, files.

const TEST_DIR := "user://save_system_test"


func _config(seed_value: int = 42, personality: String = "guardian") -> SimConfig:
	return SimConfig.from_data({
		"config_version": 1,
		"seed": seed_value,
		"base_ticks_per_second": 1,
		"speed_multipliers": [1, 10, 100],
		"max_catch_up_ticks": 1000,
		"personality": personality,
		"log": {"text": false, "jsonl": false, "deltas": false, "chronicle": false, "directory": TEST_DIR},
	}).value


## {"manager", "personality", "fingerprints"}
func _planet(seed_value: int = 42, personality: String = "guardian") -> Dictionary:
	var built := SimulationRunner.build_planet(_config(seed_value, personality), SimulationRunner.parse_args(PackedStringArray()).value)
	assert_array(Array(built.errors)).is_empty()
	return built.value


func _run(planet: Dictionary) -> Dictionary:
	return {"personality": planet["personality"], "data_fingerprints": planet["fingerprints"], "lineage": []}


## Capture after `ticks`, passed through JSON text as a file would be.
func _saved(ticks: int = 30, seed_value: int = 42, personality: String = "guardian") -> Dictionary:
	var planet := _planet(seed_value, personality)
	(planet["manager"] as SimulationManager).run_ticks(ticks)
	return JSON.parse_string(JSON.stringify(SaveSystem.capture(planet["manager"], _run(planet))))


func _restore(data: Dictionary, seed_value: int = 42, personality: String = "guardian") -> SimResult:
	var planet := _planet(seed_value, personality)
	return SaveSystem.restore(planet["manager"], data, _run(planet))


func _errors(data: Dictionary) -> String:
	return "\n".join(_restore(data).errors)


func test_capture_holds_the_envelope_and_every_system() -> void:
	var data := _saved(5)
	assert_str(data["format"]).is_equal("genesis_save")
	assert_int(int(data["save_version"])).is_equal(1)
	assert_str(data["seed"]).is_equal("42")
	assert_int(int(data["tick"])).is_equal(5)
	assert_str(data["personality"]).is_equal("guardian")
	assert_array((data["systems"] as Dictionary).keys()).contains_exactly_in_any_order(
			["climate", "atmosphere", "biosphere", "personality", "events"])
	assert_dict(data["systems"]["atmosphere"]).is_empty()
	assert_array(data["lineage"]).is_empty()
	assert_array((data["data_fingerprints"] as Dictionary).keys()).contains(["climate", "species", "events"])


func test_restore_continues_where_the_save_ended() -> void:
	var continuous := _planet()
	(continuous["manager"] as SimulationManager).run_ticks(60)
	var restored := _restore(_saved(30))
	assert_array(Array(restored.errors)).is_empty()
	assert_array(Array(restored.warnings)).is_empty()
	var manager: SimulationManager = restored.value
	assert_int(manager.tick()).is_equal(30)
	manager.run_ticks(30)
	assert_str(manager.state_hash()).is_equal((continuous["manager"] as SimulationManager).state_hash())


func test_rejects_another_planet_with_all_errors_at_once() -> void:
	var errors := "\n".join(_restore(_saved(5, 7, "chaotic")).errors)
	assert_str(errors).contains("seed 7")
	assert_str(errors).contains("personality 'chaotic'")


func test_rejects_missing_and_unknown_systems() -> void:
	var data := _saved(5)
	(data["systems"] as Dictionary).erase("biosphere")
	data["systems"]["geology"] = {}
	var errors := _errors(data)
	assert_str(errors).contains("no state for system 'biosphere'")
	assert_str(errors).contains("'geology' is not part of this planet")


func test_rejects_damaged_planet_values() -> void:
	var data := _saved(5)
	var values := Marshalls.base64_to_raw(data["planet"]["values_exact"]).to_float64_array()
	values[0] += 1.0
	data["planet"]["values_exact"] = Marshalls.raw_to_base64(values.to_byte_array())
	assert_str(_errors(data)).contains("state_hash")


func test_rejects_damaged_system_state() -> void:
	var data := _saved(5)
	data["systems"]["climate"]["rng_state"] = 1.0
	assert_str(_errors(data)).contains("climate")


func test_rejects_other_formats_and_versions() -> void:
	var data := _saved(1)
	data["format"] = "planet_state"
	assert_str(_errors(data)).contains("not a Genesis Error save")
	data = _saved(1)
	data["save_version"] = 2
	assert_str(_errors(data)).contains("newer")
	data["save_version"] = 0
	assert_str(_errors(data)).contains("can no longer be read")


func test_restore_needs_a_fresh_manager() -> void:
	var planet := _planet()
	(planet["manager"] as SimulationManager).run_ticks(1)
	assert_str("\n".join(SaveSystem.restore(planet["manager"], _saved(5), _run(planet)).errors)).contains("has not run yet")


func test_changed_data_files_only_warn() -> void:
	var data := _saved(5)
	data["data_fingerprints"]["climate"] = "0000"
	var restored := _restore(data)
	assert_bool(restored.is_ok()).is_true()
	assert_str("\n".join(restored.warnings)).contains("'climate' changed")


func test_read_header_names_what_builds_the_planet() -> void:
	var header := SaveSystem.read_header(_saved(12))
	assert_array(Array(header.errors)).is_empty()
	assert_int(header.value["seed"]).is_equal(42)
	assert_int(header.value["tick"]).is_equal(12)
	assert_str(header.value["personality"]).is_equal("guardian")


func test_write_replaces_an_existing_save_and_reads_back() -> void:
	var path := ProjectSettings.globalize_path(TEST_DIR).path_join("replace.json")
	assert_bool(SaveSystem.write(path, {"a": 1}).is_ok()).is_true()
	var written := SaveSystem.write(path, _saved(3))
	assert_array(Array(written.errors)).is_empty()
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()
	var read := SaveSystem.read(path)
	assert_int(int(read.value["tick"])).is_equal(3)


func test_read_reports_missing_or_broken_files() -> void:
	var directory := ProjectSettings.globalize_path(TEST_DIR)
	assert_str("\n".join(SaveSystem.read(directory.path_join("missing.json")).errors)).contains("not found")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("broken.json"), FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_str("\n".join(SaveSystem.read(directory.path_join("broken.json")).errors)).contains("JSON error")
