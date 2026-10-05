extends GdUnitTestSuite
## InterventionCatalog: loading, validation and command-line parsing.

const I := preload("res://simulation/tests/support/intervention_fixtures.gd")


func _errors(def: Dictionary) -> String:
	return "\n".join(I.parse([def]).errors)


func test_project_catalog_has_the_planned_interventions() -> void:
	var ids := I.project_catalog().ids()
	assert_array(ids).contains_exactly([&"seed_species", &"cull_species", &"mirrors_warm", &"mirrors_cool",
			&"cloud_seeding", &"aquifer_release", &"volcanic_awakening"])
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


func _levels(default_level: String = "strong") -> Dictionary:
	return {"default": default_level, "options": {"weak": {"scale": 0.25, "name": "lekko"}, "strong": {"scale": 1.0, "name": "mocno"}}}


func test_reads_levels_and_scales_modifiers() -> void:
	var def := I.catalog([I.timed("warm", {"levels": _levels()})]).get_def(&"warm")
	assert_str(def.default_level).is_equal("strong")
	assert_float(def.scaled_value({"operation": "add", "value": 8.0}, "weak")).is_equal(2.0)
	assert_float(def.scaled_value({"operation": "add", "value": 8.0}, "strong")).is_equal(8.0)
	# multiply scales the distance from 1: x3 at a quarter is x1.5
	assert_float(def.scaled_value({"operation": "multiply", "value": 3.0}, "weak")).is_equal(1.5)
	assert_float(def.scaled_value({"operation": "multiply", "value": 0.6}, "weak")).is_equal(0.9)


func test_project_mirrors_and_dust_have_three_levels() -> void:
	for id: StringName in [&"mirrors_warm", &"mirrors_cool"]:
		var def := I.project_catalog().get_def(id)
		assert_array(def.levels.keys()).contains_exactly_in_any_order(["weak", "medium", "strong"])
		assert_str(def.default_level).is_equal("strong")


func test_command_line_takes_an_optional_level() -> void:
	var catalog := I.catalog([I.timed("warm", {"levels": _levels()}), I.seeding()])
	assert_dict(catalog.parse_text("warm:weak").value).is_equal({"action": &"warm", "args": {"level": "weak"}})
	assert_dict(catalog.parse_text("warm").value).is_equal({"action": &"warm", "args": {}})
	assert_str("\n".join(catalog.parse_text("warm:hot").errors)).contains("unknown level 'hot'")
	assert_str("\n".join(catalog.parse_text("seed:moss:weak").errors)).contains("seed:<species>")
	assert_str(InterventionCatalog.usage(catalog.get_def(&"warm"))).is_equal("warm[:weak|strong]")


func test_rejects_bad_levels() -> void:
	assert_str(_errors(I.timed("x", {"levels": _levels("medium")}))).contains("default")
	assert_str(_errors(I.timed("x", {"levels": {"default": "a", "options": {"a": {"scale": 1.5, "name": "x"}}}}))).contains("scale")
	assert_str(_errors(I.timed("x", {"levels": {"default": "a", "options": {"a": {"scale": 0.5}}}}))).contains("name")
	assert_str(_errors(I.seeding("x", {"levels": _levels()}))).contains("has none")
