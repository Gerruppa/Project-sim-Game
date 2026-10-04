class_name LogSink
extends RefCounted
## Destination for log lines (file, console, memory).
## SimulationLog formats; sinks only store or print.


func write_line(_line: String) -> void:
	push_error("LogSink.write_line must be overridden")


func close() -> void:
	pass
