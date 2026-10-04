extends SceneTree
## Regenerates the golden trace. Run only after an intentional change
## (engine upgrade, deterministic math change) and commit the result
## in a separate commit:
##   godot --headless --path . -s res://simulation/tests/tools/write_golden_trace.gd

const GoldenTrace := preload("res://simulation/tests/support/golden_trace.gd")


func _init() -> void:
	var lines := GoldenTrace.generate()
	var error := GoldenTrace.write_file(lines)
	if error != OK:
		printerr("Failed to write %s: %s" % [GoldenTrace.PATH, error_string(error)])
		quit(1)
		return
	print("Wrote %d checkpoints to %s" % [lines.size(), GoldenTrace.PATH])
	quit(0)
