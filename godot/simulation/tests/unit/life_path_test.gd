extends GdUnitTestSuite
## LifePath: the ladder of life, from bacteria up, with the next rung and what
## it still needs.

const B := preload("res://simulation/tests/support/biosphere_fixtures.gd")
const P := preload("res://simulation/tests/support/schema_fixtures.gd")
const I := preload("res://simulation/tests/support/intervention_fixtures.gd")

const NAMES := {"algae": "algae", "moss": "moss", "shrub": "shrubs", "tree": "trees"}


func _scale() -> DisplayScale:
	var ids: Array[StringName] = []
	var schema := P.project_schema()
	for i in schema.size():
		ids.append(schema.def_at(i).id())
	return DisplayScale.load_json(DisplayScale.DEFAULT_PATH, ids, I.project_catalog().ids()).value


## algae -> moss -> shrub -> tree, listed out of order on purpose.
func _biosphere(populations: Dictionary = {}) -> BiosphereSystem:
	var list := [
		B.species("tree", {"layer": 3, "emerges_from": "shrub", "t_min": 20.0}),
		B.species("algae", {"layer": 0}),
		B.species("shrub", {"layer": 2, "emerges_from": "moss", "t_min": 20.0}),
		B.species("moss", {"layer": 1, "emerges_from": "algae", "t_min": 20.0, "t_max": 35.0, "t_margin": 8.0}),
	]
	var system := BiosphereSystem.new(B.calm(), B.catalog(list), 1)
	for id: String in populations:
		system.set_population(StringName(id), populations[id])
	return system


func _steps(biosphere: BiosphereSystem, values: Dictionary = {}) -> Array[Dictionary]:
	var guide := SpeciesGuide.load_json().value as SpeciesGuide
	return LifePath.steps(biosphere, B.snapshot(values), guide, _scale(), NAMES)


func _ids(steps: Array[Dictionary]) -> Array:
	return steps.map(func(s: Dictionary) -> String: return s["id"])


func _states(steps: Array[Dictionary]) -> Array:
	return steps.map(func(s: Dictionary) -> String: return s["state"])


func test_steps_follow_the_succession_order() -> void:
	assert_array(_ids(_steps(_biosphere()))).is_equal(["algae", "moss", "shrub", "tree"])


func test_only_one_step_is_next() -> void:
	var steps := _steps(_biosphere({"algae": 20.0, "moss": 10.0}))
	assert_array(_states(steps)).is_equal(["alive", "alive", "next", "later"])
	assert_bool(steps[2]["is_next"]).is_true()
	assert_bool(steps[3]["is_next"]).is_false()


func test_the_first_step_is_next_on_an_empty_planet() -> void:
	assert_array(_states(_steps(_biosphere()))).is_equal(["next", "later", "later", "later"])


func test_a_species_that_vanished_is_the_next_step_again() -> void:
	var biosphere := _biosphere({"algae": 20.0, "moss": 10.0, "shrub": 5.0})
	biosphere.set_population(&"moss", 0.0)
	# Dying out is noticed by the simulation; a population set to 0 is simply absent.
	var steps := _steps(biosphere)
	assert_str(steps[1]["state"]).is_equal("next")


func test_progress_is_how_well_the_planet_suits_the_next_step() -> void:
	var cold := _steps(_biosphere({"algae": 20.0}), {"temperature": 5.0})
	assert_float(cold[1]["progress"]).is_equal(0.0)
	var warm := _steps(_biosphere({"algae": 20.0}), {"temperature": 28.0})
	assert_float(warm[1]["progress"]).is_greater(0.9)


func test_the_blocker_names_what_is_missing_in_the_players_units() -> void:
	var steps := _steps(_biosphere({"algae": 20.0}), {"temperature": 5.0})
	assert_str(steps[1]["blocker"]).contains("Temperature").contains("°C").contains("needs")


func test_the_blocker_is_empty_when_nothing_is_missing() -> void:
	var steps := _steps(_biosphere({"algae": 20.0}), {"temperature": 28.0, "humidity": 40.0})
	assert_str(steps[1]["blocker"]).is_empty()


func test_steps_carry_the_players_names_and_populations() -> void:
	var steps := _steps(_biosphere({"algae": 20.0}))
	assert_str(steps[0]["name"]).is_equal("algae")
	assert_float(steps[0]["population"]).is_equal(20.0)
	assert_str(steps[2]["name"]).is_equal("shrubs")
