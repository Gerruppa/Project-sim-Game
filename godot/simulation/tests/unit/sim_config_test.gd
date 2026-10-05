extends GdUnitTestSuite


func _data() -> Dictionary:
	return {
		"config_version": 1,
		"seed": 42,
		"base_ticks_per_second": 1,
		"speed_multipliers": [1, 10, 100],
		"max_catch_up_ticks": 1000,
		"personality": "random",
		"log": {"text": true, "jsonl": true, "deltas": true, "directory": "../logs/simulation_runs"},
	}


func _errors(data: Dictionary) -> String:
	return "\n".join(SimConfig.from_data(data).errors)


func test_valid_data_builds_config() -> void:
	var result := SimConfig.from_data(_data())
	assert_array(Array(result.errors)).is_empty()
	var config: SimConfig = result.value
	assert_int(config.seed()).is_equal(42)
	assert_float(config.base_ticks_per_second()).is_equal(1.0)
	assert_array(config.speed_multipliers()).is_equal([1, 10, 100])
	assert_int(config.max_catch_up_ticks()).is_equal(1000)
	assert_bool(config.log_text()).is_true()
	assert_bool(config.log_jsonl()).is_true()
	assert_bool(config.log_deltas()).is_true()
	assert_str(config.log_directory()).is_equal("../logs/simulation_runs")


func test_project_config_loads() -> void:
	var result := SimConfig.load_json(SimConfig.DEFAULT_PATH)
	assert_array(Array(result.errors)).is_empty()
	assert_float((result.value as SimConfig).base_ticks_per_second()).is_equal(1.0)


func test_with_seed_returns_copy_with_new_seed() -> void:
	var config: SimConfig = SimConfig.from_data(_data()).value
	var other := config.with_seed(7)
	assert_int(other.seed()).is_equal(7)
	assert_int(config.seed()).is_equal(42)
	assert_array(other.speed_multipliers()).is_equal([1, 10, 100])


func test_speed_multipliers_returns_copy() -> void:
	var config: SimConfig = SimConfig.from_data(_data()).value
	config.speed_multipliers().clear()
	assert_int(config.speed_multipliers().size()).is_equal(3)


func test_rejects_non_integer_seed() -> void:
	var data := _data()
	data["seed"] = 4.5
	assert_str(_errors(data)).contains("seed")


func test_rejects_non_positive_tick_rate() -> void:
	var data := _data()
	data["base_ticks_per_second"] = 0
	assert_str(_errors(data)).contains("base_ticks_per_second")


func test_rejects_multipliers_without_one() -> void:
	var data := _data()
	data["speed_multipliers"] = [10, 100]
	assert_str(_errors(data)).contains("speed_multipliers")


func test_rejects_duplicate_or_invalid_multipliers() -> void:
	var data := _data()
	data["speed_multipliers"] = [1, 10, 10]
	assert_str(_errors(data)).contains("speed_multipliers")
	data["speed_multipliers"] = [1, -10]
	assert_str(_errors(data)).contains("speed_multipliers")


func test_rejects_invalid_catch_up_limit() -> void:
	var data := _data()
	data["max_catch_up_ticks"] = 0
	assert_str(_errors(data)).contains("max_catch_up_ticks")


func test_rejects_missing_log_settings() -> void:
	var data := _data()
	data.erase("log")
	assert_str(_errors(data)).contains("log")


func test_rejects_non_boolean_log_flag() -> void:
	var data := _data()
	data["log"]["jsonl"] = "yes"
	assert_str(_errors(data)).contains("jsonl")


func test_chronicle_is_on_unless_disabled() -> void:
	assert_bool((SimConfig.from_data(_data()).value as SimConfig).log_chronicle()).is_true()
	var data := _data()
	data["log"]["chronicle"] = false
	assert_bool((SimConfig.from_data(data).value as SimConfig).log_chronicle()).is_false()
	data["log"]["chronicle"] = "yes"
	assert_str(_errors(data)).contains("chronicle")


func test_reports_all_errors_at_once() -> void:
	var data := _data()
	data["seed"] = "x"
	data["max_catch_up_ticks"] = -1
	assert_int(SimConfig.from_data(data).errors.size()).is_greater_equal(2)


func test_personality_defaults_to_random_draw() -> void:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	assert_str(config.personality()).is_equal("random")


func test_with_personality_returns_copy() -> void:
	var config: SimConfig = SimConfig.from_data(_data()).value
	var forced := config.with_personality(&"chaotic")
	assert_str(forced.personality()).is_equal("chaotic")
	assert_str(config.personality()).is_equal("random")
	assert_str(forced.with_seed(3).personality()).is_equal("chaotic")


func test_rejects_missing_or_empty_personality() -> void:
	var data := _data()
	data["personality"] = ""
	assert_str(_errors(data)).contains("personality")
	data.erase("personality")
	assert_str(_errors(data)).contains("personality")


func test_save_settings_have_defaults() -> void:
	var config: SimConfig = SimConfig.from_data(_data()).value
	assert_str(config.save_directory()).is_equal("../saves")
	assert_int(config.autosave_every()).is_equal(1000)
	var data := _data()
	data["save"] = {"directory": "user://saves", "autosave_every": 0}
	config = SimConfig.from_data(data).value
	assert_str(config.save_directory()).is_equal("user://saves")
	assert_int(config.autosave_every()).is_equal(0)
	assert_int(config.with_seed(7).autosave_every()).is_equal(0)


func test_rejects_bad_save_settings() -> void:
	var data := _data()
	data["save"] = {"directory": "", "autosave_every": -5}
	var errors := _errors(data)
	assert_str(errors).contains("save.directory")
	assert_str(errors).contains("save.autosave_every")
	data["save"] = "../saves"
	assert_str(_errors(data)).contains("save")
