extends SceneTree
## Console entry point of the simulation.
##   godot --headless --path godot -s res://tools/run_simulation.gd -- [options]
## See SimulationRunner.USAGE for options. Exit code 0 = finished, 1 = halted
## by a rejected batch, 2 = invalid options or data (or a failed --save).

var _manager: SimulationManager
var _saver: RunSaver
var _watcher: DecisionWatcher
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

	var opened := SimulationRunner.open_run(_options)
	if not opened.is_ok():
		_fail(opened.errors, false)
		return
	_manager = opened.value["manager"]
	var config: SimConfig = opened.value["config"]
	var run: Dictionary = opened.value["run"]
	for warning: String in opened.value["warnings"]:
		printerr("WARNING: " + warning)
	if opened.value["loaded"]:
		print("Loaded %s at tick %d" % [_options["load"], _manager.tick()])
	var acted := SimulationRunner.submit_acts(_manager, _options["act"])
	if not acted.is_ok():
		_fail(acted.errors, false)
		return

	_log_id = SimulationRunner.run_id(config.seed())
	var echo_log: bool = not _options["quiet"] and not _options["story"]
	var log_result := SimulationRunner.create_log(config, _log_id, echo_log)
	if not log_result.is_ok():
		_fail(log_result.errors, false)
		return
	_manager.attach_log(log_result.value)
	var chronicle_result := SimulationRunner.create_chronicle(config, _log_id, not _options["quiet"] and _options["story"])
	if not chronicle_result.is_ok():
		_fail(chronicle_result.errors, false)
		return
	if chronicle_result.value != null:
		_manager.attach_log(chronicle_result.value)

	if _options.has("until"):
		var watcher := SimulationRunner.create_watcher(_manager)
		if not watcher.is_ok():
			_fail(watcher.errors, false)
			return
		_watcher = watcher.value
		_manager.attach_log(_watcher)

	var every: int = _options.get("autosave", config.autosave_every())
	var autosave_path := SimulationRunner.resolve_save_path(_log_id + ".autosave.json", config)
	_saver = RunSaver.new(_manager, run, autosave_path, every)

	if _options["realtime"]:
		if not _manager.scheduler().set_speed(_options["speed"]):
			_fail(PackedStringArray(["--speed must be one of %s" % [config.speed_multipliers()]]), false)
			return
		_realtime = true
		_manager.start()
	else:
		for i: int in _options["ticks"]:
			if not _manager.step():
				break
			_autosave()
			if _watcher != null and _watcher.reached():
				break
		_finish()


func _process(delta: float) -> bool:
	if not _realtime:
		return false
	_manager.advance(delta)
	_autosave()
	_elapsed += delta
	# Real time runs several ticks per frame: it stops at the end of the
	# frame in which the decision point happened.
	var decided := _watcher != null and _watcher.reached()
	if _elapsed >= float(_options["seconds"]) or _manager.is_halted() or decided:
		_realtime = false
		_finish()
	return false


## A failed autosave does not stop the run; it is reported.
func _autosave() -> void:
	var saved := _saver.after_ticks()
	for error in saved.errors:
		printerr("autosave failed: " + error)


func _finish() -> void:
	_manager.stop()
	var directory := SimulationRunner.resolve_directory(_manager.config().log_directory())
	print("Simulation finished at tick %d | halted: %s | state hash: %s"
			% [_manager.tick(), "yes" if _manager.is_halted() else "no", _manager.state_hash()])
	print("Logs: %s" % directory.path_join(_log_id + ".{log,jsonl,chronicle.txt}"))
	if FileAccess.file_exists(_saver.autosave_path()):
		print("Autosave: %s" % _saver.autosave_path())
	for error in _manager.errors():
		printerr(error)
	var decided := _watcher != null and _watcher.reached() and not _manager.is_halted()
	if _options.has("save") or decided:
		var name: String = _options.get("save", SimulationRunner.DECISION_SAVE)
		var saved := _saver.save_to(SimulationRunner.resolve_save_path(name, _manager.config()))
		if not saved.is_ok():
			_fail(saved.errors, false)
			return
		print("Saved: %s" % saved.value)
		if decided:
			print("\n".join(SimulationRunner.decision_report(_manager, _watcher, saved.value)))
	elif _watcher != null:
		print("No decision point within %d ticks." % _options["ticks"])
	quit(1 if _manager.is_halted() else 0)


func _fail(errors: PackedStringArray, show_usage: bool) -> void:
	for error in errors:
		printerr(error)
	if show_usage:
		printerr(SimulationRunner.USAGE)
	quit(2)
