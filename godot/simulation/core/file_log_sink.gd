class_name FileLogSink
extends LogSink
## Writes log lines to a file. The directory must already exist.

var _file: FileAccess


static func open(path: String) -> SimResult:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return SimResult.failure("cannot open log file %s: %s" % [path, error_string(FileAccess.get_open_error())])
	var sink := FileLogSink.new()
	sink._file = file
	return SimResult.success(sink)


func write_line(line: String) -> void:
	if _file != null:
		_file.store_line(line)


func close() -> void:
	if _file != null:
		_file.close()
		_file = null
