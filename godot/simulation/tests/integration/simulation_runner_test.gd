extends GdUnitTestSuite

const TEST_DIR := "user://runner_test_runs"


func _config(text: bool = true, jsonl: bool = true, chronicle: bool = true) -> SimConfig:
	return SimConfig.from_data({
		"config_version": 1,
		"seed": 42,
		"base_ticks_per_second": 1,
		"speed_multipliers": [1, 10, 100],
		"max_catch_up_ticks": 1000,
		"personality": "none",
		"log": {"text": text, "jsonl": jsonl, "deltas": true, "chronicle": chronicle, "directory": TEST_DIR},
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
	assert_bool(options["story"]).is_false()
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


func test_default_climate_is_project_file() -> void:
	assert_str(_options([])["climate"]).is_equal(ClimateConfig.DEFAULT_PATH)


func test_parses_climate_file_for_other_planet_characters() -> void:
	assert_str(_options(["--climate", "res://resources/climate/cold_world.json"])["climate"]) \
			.is_equal("res://resources/climate/cold_world.json")


func test_default_atmosphere_is_project_file() -> void:
	assert_str(_options([])["atmosphere"]).is_equal(AtmosphereConfig.DEFAULT_PATH)


func test_parses_atmosphere_file() -> void:
	assert_str(_options(["--atmosphere", "res://resources/atmosphere/volcanic.json"])["atmosphere"]) \
			.is_equal("res://resources/atmosphere/volcanic.json")


func test_default_life_files_are_project_files() -> void:
	var options := _options([])
	assert_str(options["species"]).is_equal(SpeciesCatalog.DEFAULT_PATH)
	assert_str(options["biosphere"]).is_equal(BiosphereConfig.DEFAULT_PATH)


func test_parses_life_files() -> void:
	var options := _options(["--species", "res://a.json", "--biosphere", "res://b.json"])
	assert_str(options["species"]).is_equal("res://a.json")
	assert_str(options["biosphere"]).is_equal("res://b.json")


func test_personality_comes_from_config_unless_forced() -> void:
	assert_bool(_options([]).has("personality")).is_false()
	assert_str(_options(["--personality", "chaotic"])["personality"]).is_equal("chaotic")


func test_rejects_personality_option_without_name() -> void:
	assert_bool(SimulationRunner.parse_args(PackedStringArray(["--personality"])).is_ok()).is_false()


func test_rejects_atmosphere_option_without_path() -> void:
	assert_bool(SimulationRunner.parse_args(PackedStringArray(["--atmosphere"])).is_ok()).is_false()


func test_rejects_climate_option_without_path() -> void:
	assert_bool(SimulationRunner.parse_args(PackedStringArray(["--climate"])).is_ok()).is_false()


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


func test_parses_story_option() -> void:
	assert_bool(_options(["--story"])["story"]).is_true()


func test_create_chronicle_writes_its_file() -> void:
	var result := SimulationRunner.create_chronicle(_config(), "chronicle_file", false)
	assert_array(Array(result.errors)).is_empty()
	var chronicle: PlanetChronicle = result.value
	chronicle.close()
	assert_bool(FileAccess.file_exists(ProjectSettings.globalize_path(TEST_DIR).path_join("chronicle_file.chronicle.txt"))).is_true()


func test_disabled_chronicle_without_echo_goes_nowhere() -> void:
	var result := SimulationRunner.create_chronicle(_config(true, true, false), "no_chronicle", false)
	assert_bool(result.is_ok()).is_true()
	assert_object(result.value).is_null()
	assert_bool(FileAccess.file_exists(ProjectSettings.globalize_path(TEST_DIR).path_join("no_chronicle.chronicle.txt"))).is_false()


func test_disabled_chronicle_can_still_be_echoed() -> void:
	var chronicle: PlanetChronicle = SimulationRunner.create_chronicle(_config(true, true, false), "echo_only", true).value
	assert_object(chronicle).is_not_null()
	chronicle.close()


func test_create_chronicle_fails_on_bad_vocabulary() -> void:
	assert_bool(SimulationRunner.create_chronicle(_config(), "bad_texts", false, "res://missing_chronicle.json").is_ok()).is_false()


func test_chronicle_tells_a_real_run_without_changing_it() -> void:
	var schema: ParameterSchema = ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH).value
	var plain: SimulationManager = SimulationManager.create(_config(), schema).value
	plain.run_ticks(25)
	var told: SimulationManager = SimulationManager.create(_config(), schema).value
	told.attach_log(SimulationRunner.create_chronicle(_config(), "told_run", false).value)
	told.run_ticks(25)
	told.stop()
	assert_str(told.state_hash()).is_equal(plain.state_hash())
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(TEST_DIR).path_join("told_run.chronicle.txt"))
	assert_str(text).starts_with("# Kronika planety | seed 42")


func test_full_batch_run_writes_every_tick() -> void:
	var config := _config()
	var manager: SimulationManager = SimulationManager.create(config, ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH).value).value
	manager.attach_log(SimulationRunner.create_log(config, "full_run", false).value)
	manager.run_ticks(25)
	manager.stop()
	var jsonl := FileAccess.get_file_as_string(ProjectSettings.globalize_path(TEST_DIR).path_join("full_run.jsonl"))
	assert_int(jsonl.split("\n", false).size()).is_equal(26)
