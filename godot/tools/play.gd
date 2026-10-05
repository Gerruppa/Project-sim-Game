extends SceneTree
## Console game entry point: menu, hints and decision points.
##   godot --headless --path godot -s res://tools/play.gd -- [options]
## See PlaySession.USAGE. Exit code 0 = stopped, 1 = simulation halted,
## 2 = invalid options or data.


func _init() -> void:
	var parsed := PlaySession.parse_args(OS.get_cmdline_user_args())
	if not parsed.is_ok():
		for error in parsed.errors:
			printerr(error)
		printerr(PlaySession.USAGE)
		quit(2)
		return
	var session := PlaySession.create(parsed.value, ConsoleInput.read_line, func(text: String) -> void: printraw(text))
	if not session.is_ok():
		for error in session.errors:
			printerr(error)
		quit(2)
		return
	quit((session.value as PlaySession).play())
