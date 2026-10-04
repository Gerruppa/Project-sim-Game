extends GdUnitTestSuite
## Enforces architecture rules that GDScript cannot enforce by itself.
## See docs/architecture.md and docs/simulation.md.

const ROOT := "res://simulation"
const THIS_DIR := "res://simulation/tests/architecture"

## Engine functions whose results may differ between platforms, plus
## global random state. Method calls (obj.name) and definitions
## (func name) are not matched, so SimMath.lerp and _rng.randi are fine.
const FORBIDDEN_CALLS := [
	"sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sinh", "cosh", "tanh",
	"exp", "log", "pow", "lerp", "lerpf", "lerp_angle", "inverse_lerp", "remap",
	"smoothstep", "ease", "move_toward", "hash",
	"randf", "randfn", "randf_range", "randi", "randi_range", "seed", "randomize", "rand_from_seed",
]
const RNG_OWNER := "res://simulation/core/seeded_rng.gd"
const STATE_WRITERS := ["res://simulation/core/planet_state.gd", "res://simulation/core/state_writer.gd"]
## Folders allowed to reference PlanetState. Domain systems get snapshots only.
const STATE_ACCESS_DIRS := ["res://simulation/core/", "res://simulation/scheduling/", "res://simulation/tests/"]


func _scripts(directory: String) -> PackedStringArray:
	var result := PackedStringArray()
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"):
			result.append(directory.path_join(file))
	for sub in DirAccess.get_directories_at(directory):
		var path := directory.path_join(sub)
		if path != THIS_DIR:
			result.append_array(_scripts(path))
	return result


## Source without comments, so documentation may mention forbidden names.
func _code(path: String) -> String:
	var lines := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var comment := line.find("#")
		lines.append(line if comment == -1 else line.substr(0, comment))
	return "\n".join(lines)


func _violations(pattern: String, allowed: Callable) -> PackedStringArray:
	var regex := RegEx.create_from_string(pattern)
	var found := PackedStringArray()
	for path in _scripts(ROOT):
		if allowed.call(path):
			continue
		for match in regex.search_all(_code(path)):
			found.append("%s: %s" % [path, match.get_string().strip_edges()])
	return found


func test_scanner_finds_simulation_scripts() -> void:
	assert_array(Array(_scripts(ROOT))).contains([RNG_OWNER, "res://simulation/core/sim_math.gd"])


func test_simulation_uses_only_deterministic_math() -> void:
	var pattern := "(?<![\\w.])(?<!func )(%s)\\s*\\(" % "|".join(FORBIDDEN_CALLS)
	var found := _violations(pattern, func(_path: String) -> bool: return false)
	assert_array(Array(found)).override_failure_message(
			"Use SimMath / SeededRng instead:\n" + "\n".join(found)).is_empty()


func test_only_seeded_rng_creates_random_generators() -> void:
	var found := _violations("\\bRandomNumberGenerator\\b", func(path: String) -> bool: return path == RNG_OWNER)
	assert_array(Array(found)).override_failure_message("\n".join(found)).is_empty()


func test_only_state_writer_commits_state() -> void:
	var found := _violations("\\b_commit\\s*\\(", func(path: String) -> bool: return path in STATE_WRITERS)
	assert_array(Array(found)).override_failure_message("\n".join(found)).is_empty()


func test_domain_code_never_references_planet_state() -> void:
	var allowed := func(path: String) -> bool:
		for directory: String in STATE_ACCESS_DIRS:
			if path.begins_with(directory):
				return true
		return false
	var found := _violations("\\bPlanetState\\b", allowed)
	assert_array(Array(found)).override_failure_message(
			"Domain code must use PlanetSnapshot:\n" + "\n".join(found)).is_empty()
