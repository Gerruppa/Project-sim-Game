extends GdUnitTestSuite
## InterventionCatalog: loading, validation and command-line parsing.

const I := preload("res://simulation/tests/support/intervention_fixtures.gd")


func _errors(def: Dictionary) -> String:
	return "\n".join(I.parse([def]).errors)


func test_project_catalog_has_the_five_planned_interventions() -> void:
	var ids := I.project_catalog().ids()
	assert_array(ids).contains_exactly([&"seed_species", &"cull_species", &"mirrors_warm", &"mirrors_cool",
			&"cloud_seeding", &"volcanic_awakening"])
	var catalog := I.project_catalog()
	assert_str(String(catalog.get_def(&"mirrors_warm").cooldown_group)).is_equal("mirrors")
	assert_str(String(catalog.get_def(&"mirrors_cool").cooldown_group)).is_equal("mirrors")


func test_reads_a_definition() -> void:
	var def := I.catalog([I.timed("warm")]).get_def(&"warm")
	assert_str(def.name).is_equal("Test warm")
	assert_int(def.duration).is_equal(10)
	assert_int(def.cooldown).is_equal(20)
	assert_str(String(def.cooldown_group)).is_equal("warm")
	assert_str(def.story["ended"]).is_equal("warm ends.")


func test_follow_ups_fill_in_the_players_arguments() -> void:
	var follow_ups := I.catalog([I.seeding()]).get_def(&"seed").follow_ups(12, {"species": "moss"})
	assert_int(follow_ups.size()).is_equal(1)
	assert_int(follow_ups[0].tick).is_equal(12)
	assert_str(String(follow_ups[0].target)).is_equal("biosphere")
	assert_dict(follow_ups[0].args).is_equal({"species": "moss", "amount": 5.0})


func test_parses_command_line_text() -> void:
	var catalog := I.catalog([I.seeding(), I.timed("warm")])
	assert_dict(catalog.parse_text("seed:moss").value).is_equal({"action": &"seed", "args": {"species": "moss"}})
	assert_dict(catalog.parse_text("warm").value).is_equal({"action": &"warm", "args": {}})
	assert_str("\n".join(catalog.parse_text("seed").errors)).contains("seed:<species>")
	assert_str("\n".join(catalog.parse_text("warm:moss").errors)).contains("no arguments")
	assert_str("\n".join(catalog.parse_text("comet").errors)).contains("seed, warm")


func test_effects_must_reach_something_real() -> void:
	assert_str(_errors(I.timed("x", {"modifiers": [{"target": "climate.sunshine", "operation": "add", "value": 1}]}))).contains("sunshine")
	assert_str(_errors(I.seeding("x", {"commands": [{"target": "biosphere", "action": "mutate", "args": {}}]}))).contains("biosphere.mutate")
	assert_str(_errors(I.seeding("x", {"commands": [{"target": "biosphere", "action": "add_population",
			"args": {"species": "$planet", "amount": 5.0}}]}))).contains("$planet")
	assert_str(_errors(I.seeding("x", {"commands": [{"target": "biosphere", "action": "scale_population",
			"args": {"species": "$species", "factor": 2.0}}]}))).contains("factor")
	assert_str(_errors(I.timed("x", {"modifiers": []}))).contains("at least one")


func test_timing_rules() -> void:
	assert_str(_errors(I.timed("x", {"duration": 0}))).contains("duration of at least 1")
	assert_str(_errors(I.timed("x", {"cooldown": 5}))).contains("cooldown must be at least the duration")
	assert_str(_errors(I.timed("x", {"cooldown": -1}))).contains("cooldown")
	assert_str(_errors(I.timed("x", {"story": {"applied": "Only start."}}))).contains("ended")
	assert_str(_errors(I.seeding("x", {"story": {"applied": "a", "ended": "b"}}))).contains("unexpected story key")


func test_rejects_unknown_keys_args_and_duplicates() -> void:
	assert_str(_errors(I.timed("x", {"price": 3}))).contains("price")
	assert_str(_errors(I.seeding("x", {"args": ["planet"]}))).contains("args")
	assert_str("\n".join(I.parse([I.timed("x"), I.timed("x")]).errors)).contains("duplicate")


func test_reports_all_errors_at_once() -> void:
	var result := I.parse([I.timed("a", {"name": "", "duration": 0}), I.seeding("b", {"cooldown": "soon"})])
	assert_int(result.errors.size()).is_greater_equal(3)
