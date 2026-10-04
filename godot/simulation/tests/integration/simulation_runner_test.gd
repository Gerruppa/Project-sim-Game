extends GdUnitTestSuite

const TEST_DIR := "user://runner_test_runs"


func _config(text: bool = true, jsonl: bool = true) -> SimConfig:
	return SimConfig.from_data({
		"config_version": 1,
		"seed": 42,
		"base_ticks_per_second": 1,
		"speed_multipliers": [1, 10, 100],
		"max_catch_up_ticks": 1000,
		"log": {"text": text, "jsonl": jsonl, "deltas": true, "directory": TEST_DIR},
	}).value


func _options(args: Array) -> Dictionary:
	var result := SimulationRunner.parse_args(PackedStringArray(args))
	assert_array(Array(result.errors)).is_empty()
	return result.value


func test_default_options_run_one_hour_batch() -> void:
	var options := _options([])
	assert_bool(options["realtime"]).is_false()
	assert_int(options["ticks"]).is_equal(3600)
	assert_bool(options["quiet"]).is_false()
	assert_bool(options.has("seed")).is_false()


func test_parses_batch_options() -> void:
	var options := _options(["--seed", "7", "--ticks", "500", "--quiet"])
	assert_int(options["seed"]).is_equal(7)
	assert_int(options["ticks"]).is_equal(500)
	assert_bool(options["quiet"]).is_true()


func test_parses_realtime_options() -> void:
	var options := _options(["--realtime", "--speed", "10", "--seconds", "30"])
	assert_bool(options["realtime"]).is_true()
	assert_int(options["speed"]).is_equal(10)
	assert_float(options["seconds"]).is_equal(30.0)


func test_rejects_unknown_option() -> void:
	assert_str("\n".join(SimulationRunner.parse_args(PackedStringArray(["--fast"])).errors)).contains("--fast")


func test_rejects_missing_or_invalid_values() -> void:
	assert_bool(SimulationRunner.parse_args(PackedStringArray(["--ticks"])).is_ok()).is_false()
	assert_bool(SimulationRunner.parse_args(PackedStringArray(["--ticks", "many"])).is_ok()).is_false()
	assert_bool(SimulationRunner.parse_args(PackedStringArray(["--ticks", "0"])).is_ok()).is_false()


func test_relative_log_directory_resolves_against_project() -> void:
	var resolved := SimulationRunner.resolve_directory("../logs/simulation_runs")
	assert_str(resolved).is_equal(ProjectSettings.globalize_path("res://").path_join("../logs/simulation_runs").simplify_path())


func test_virtual_log_directory_is_globalized() -> void:
	assert_str(SimulationRunner.resolve_directory("user://runs")).is_equal(ProjectSettings.globalize_path("user://runs"))


func test_run_id_contains_seed() -> void:
	assert_str(SimulationRunner.run_id(42)).starts_with("seed42_")
	assert_bool(SimulationRunner.run_id(42).contains(":")).is_false()


func test_create_log_writes_both_files() -> void:
	var result := SimulationRunner.create_log(_config(), "both_files", false)
	assert_array(Array(result.errors)).is_empty()
	var log: SimulationLog = result.value
	log.close()
	var directory := ProjectSettings.globalize_path(TEST_DIR)
	assert_bool(FileAccess.file_exists(directory.path_join("both_files.log"))).is_true()
	assert_bool(FileAccess.file_exists(directory.path_join("both_files.jsonl"))).is_true()


func test_create_log_respects_disabled_formats() -> void:
	var log: SimulationLog = SimulationRunner.create_log(_config(true, false), "text_only", false).value
	log.close()
	var directory := ProjectSettings.globalize_path(TEST_DIR)
	assert_bool(FileAccess.file_exists(directory.path_join("text_only.log"))).is_true()
	assert_bool(FileAccess.file_exists(directory.path_join("text_only.jsonl"))).is_false()


func test_full_batch_run_writes_every_tick() -> void:
	var config := _config()
	var manager: SimulationManager = SimulationManager.create(config, ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH).value).value
	manager.attach_log(SimulationRunner.create_log(config, "full_run", false).value)
	manager.run_ticks(25)
	manager.stop()
	var jsonl := FileAccess.get_file_as_string(ProjectSettings.globalize_path(TEST_DIR).path_join("full_run.jsonl"))
	assert_int(jsonl.split("\n", false).size()).is_equal(26)
