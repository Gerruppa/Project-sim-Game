extends RefCounted
## The golden trace: fixed scenario, state hash every EVERY ticks.
## Shared by golden_trace_test.gd and tools/write_golden_trace.gd.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

const PATH := "res://simulation/tests/golden/fixture_trace.txt"
const SEED := 42
const TICKS := 10000
const EVERY := 100


static func generate() -> PackedStringArray:
	return TestFixtureScenario.start(P.project_schema(), SEED).run_with_checkpoints(TICKS, EVERY)


## Checkpoint lines without comments; empty if the file is missing.
static func read_file() -> PackedStringArray:
	var lines := PackedStringArray()
	if not FileAccess.file_exists(PATH):
		return lines
	for line in FileAccess.get_file_as_string(PATH).split("\n", false):
		if not line.begins_with("#"):
			lines.append(line.strip_edges())
	return lines


static func write_file(lines: PackedStringArray) -> Error:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_line("# Golden trace of TestFixtureScenario.")
	file.store_line("# engine: %s" % Engine.get_version_info()["string"])
	file.store_line("# seed: %d, ticks: %d, checkpoint every: %d" % [SEED, TICKS, EVERY])
	file.store_line("# format: <tick> <sha256 of exact planet state>")
	for line in lines:
		file.store_line(line)
	file.close()
	return OK
