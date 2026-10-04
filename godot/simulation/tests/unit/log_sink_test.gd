extends GdUnitTestSuite


func test_memory_sink_keeps_lines_in_order() -> void:
	var sink := MemoryLogSink.new()
	sink.write_line("a")
	sink.write_line("b")
	assert_array(Array(sink.lines)).is_equal(["a", "b"])


func test_memory_sink_ignores_writes_after_close() -> void:
	var sink := MemoryLogSink.new()
	sink.close()
	sink.write_line("late")
	assert_bool(sink.is_closed()).is_true()
	assert_array(Array(sink.lines)).is_empty()


func test_file_sink_writes_lines_to_disk() -> void:
	var path := "user://log_sink_test.log"
	var result := FileLogSink.open(path)
	assert_bool(result.is_ok()).is_true()
	var sink: FileLogSink = result.value
	sink.write_line("first")
	sink.write_line("second")
	sink.close()
	assert_str(FileAccess.get_file_as_string(path)).is_equal("first\nsecond\n")


func test_file_sink_reports_unwritable_path() -> void:
	var result := FileLogSink.open("user://missing_directory/nested/run.log")
	assert_bool(result.is_ok()).is_false()
	assert_str("\n".join(result.errors)).contains("missing_directory")
