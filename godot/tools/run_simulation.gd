extends SceneTree
## Console entry point of the simulation.
##   godot --headless --path godot -s res://tools/run_simulation.gd -- [options]
## See SimulationRunner.USAGE for options. Exit code 0 = finished, 1 = halted
## by a rejected batch, 2 = invalid options or data.

var _manager: SimulationManager
var _options: Dictionary
var _log_id: String
var _elapsed := 0.0
var _realtime := false


func _init() -> void:
	var parsed := SimulationRunner.parse_args(OS.get_cmdline_user_args())
	if not parsed.is_ok():
		_fail(parsed.errors, true)
		return
	_options = parsed.value

	var config_result := SimConfig.load_json(SimConfig.DEFAULT_PATH)
	var schema_result := ParameterSchema.load_json(ParameterSchema.DEFAULT_PATH)
	if not config_result.is_ok() or not schema_result.is_ok():
		_fail(config_result.errors + schema_result.errors, false)
		return
	var config: SimConfig = config_result.value
	if _options.has("seed"):
		config = config.with_seed(_options["seed"])

	var manager_result := SimulationManager.create(config, schema_result.value)
	if not manager_result.is_ok():
		_fail(manager_result.errors, false)
		return
	_manager = manager_result.value

	# Domain systems, registered as they are built (CLAUDE.md SYSTEM PRIORITY).
	var climate_result := ClimateConfig.load_json(_options["climate"])
	if not climate_result.is_ok():
		_fail(climate_result.errors, false)
		return
	_manager.register_system(ClimateSystem.new(climate_result.value, config.seed()))

	_log_id = SimulationRunner.run_id(config.seed())
	var log_result := SimulationRunner.create_log(config, _log_id, not _options["quiet"])
	if not log_result.is_ok():
		_fail(log_result.errors, false)
		return
	_manager.attach_log(log_result.value)

	if _options["realtime"]:
		if not _manager.scheduler().set_speed(_options["speed"]):
			_fail(PackedStringArray(["--speed must be one of %s" % [config.speed_multipliers()]]), false)
			return
		_realtime = true
		_manager.start()
	else:
		_manager.run_ticks(_options["ticks"])
		_finish()


func _process(delta: float) -> bool:
	if not _realtime:
		return false
	_manager.advance(delta)
	_elapsed += delta
	if _elapsed >= float(_options["seconds"]) or _manager.is_halted():
		_realtime = false
		_finish()
	return false


func _finish() -> void:
	_manager.stop()
	var directory := SimulationRunner.resolve_directory(_manager.config().log_directory())
	print("Simulation finished at tick %d | halted: %s | state hash: %s"
			% [_manager.tick(), "yes" if _manager.is_halted() else "no", _manager.state_hash()])
	print("Logs: %s" % directory.path_join(_log_id + ".{log,jsonl}"))
	for error in _manager.errors():
		printerr(error)
	quit(1 if _manager.is_halted() else 0)


func _fail(errors: PackedStringArray, show_usage: bool) -> void:
	for error in errors:
		printerr(error)
	if show_usage:
		printerr(SimulationRunner.USAGE)
	quit(2)
