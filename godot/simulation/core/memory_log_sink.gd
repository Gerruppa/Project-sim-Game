class_name MemoryLogSink
extends LogSink
## Keeps log lines in memory. Used by tests and, later, by in-game views.

var lines := PackedStringArray()
var _closed := false


func write_line(line: String) -> void:
	if not _closed:
		lines.append(line)


func close() -> void:
	_closed = true


func is_closed() -> bool:
	return _closed
