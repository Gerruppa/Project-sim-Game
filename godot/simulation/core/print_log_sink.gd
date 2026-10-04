class_name PrintLogSink
extends LogSink
## Echoes log lines to the console (stdout).


func write_line(line: String) -> void:
	print(line)
