extends GdUnitTestSuite
## SpeciesGuide: for each species, how well the planet suits it right now and
## why not, in the player's words and units.

const B := preload("res://simulation/tests/support/biosphere_fixtures.gd")
const P := preload("res://simulation/tests/support/schema_fixtures.gd")
const I := preload("res://simulation/tests/support/intervention_fixtures.gd")

const NAMES := {"moss": "moss", "shrub": "shrubs"}


func _scale() -> DisplayScale:
	var ids: Array[StringName] = []
	var schema := P.project_schema()
	for i in schema.size():
		ids.append(schema.def_at(i).id())
	var loaded := DisplayScale.load_json(DisplayScale.DEFAULT_PATH, ids, I.project_catalog().ids())
	assert_array(Array(loaded.errors)).is_empty()
	return loaded.value


func _guide() -> SpeciesGuide:
	var loaded := SpeciesGuide.load_json()
	assert_array(Array(loaded.errors)).is_empty()
	return loaded.value


## Moss lives at 20-35 (margin 8) with water 22+; shrubs need moss and rain.
func _biosphere(populations: Dictionary = {}) -> BiosphereSystem:
	var list := [
		B.species("moss", {"layer": 1, "t_min": 20.0, "t_max": 35.0, "t_margin": 8.0, "water_min": 22.0, "water_margin": 8.0}),
		B.species("shrub", {"layer": 2, "emerges_from": "moss", "t_min": 20.0, "t_max": 45.0, "water": "precipitation",
				"water_min": 5.0, "water_margin": 4.0}),
	]
	var system := BiosphereSystem.new(B.calm(), B.catalog(list), 1)
	for id: String in populations:
		system.set_population(StringName(id), populations[id])
	return system


func _row(biosphere: BiosphereSystem, snapshot: PlanetSnapshot, species_id: String) -> Dictionary:
	return _guide().guide(biosphere.species_list().filter(func(s: SpeciesData) -> bool: return s.id == StringName(species_id))[0],
			snapshot, biosphere, _scale(), NAMES)


func test_ideal_when_every_need_is_met() -> void:
	var row := _row(_biosphere(), B.snapshot({"temperature": 28.0, "humidity": 40.0}), "moss")
	assert_str(String(row["verdict"])).is_equal("ideal")
	assert_str(row["label"]).is_equal("Ideal conditions")
	assert_float(row["fit"]).is_greater_equal(0.8)


func test_blocked_names_the_missing_need() -> void:
	var row := _row(_biosphere(), B.snapshot({"temperature": 5.0, "humidity": 40.0}), "moss")
	assert_str(String(row["verdict"])).is_equal("blocked")
	assert_str(row["label"]).is_equal("Too early: too cold")
	assert_str(row["why"]).contains("cold")


func test_in_between_conditions_are_weak_or_good() -> void:
	var good := _row(_biosphere(), B.snapshot({"temperature": 17.0, "humidity": 40.0}), "moss")
	assert_str(String(good["verdict"])).is_equal("ok")
	assert_str(good["label"]).is_equal("Good conditions")
	var weak := _row(_biosphere(), B.snapshot({"temperature": 14.0, "humidity": 40.0}), "moss")
	assert_str(String(weak["verdict"])).is_equal("weak")
	assert_str(weak["label"]).is_equal("Weak conditions")


func test_waiting_for_the_precursor() -> void:
	var row := _row(_biosphere(), B.snapshot({"temperature": 30.0, "precipitation": 20.0}), "shrub")
	assert_str(String(row["verdict"])).is_equal("waiting")
	assert_str(row["label"]).is_equal("Waiting for moss")


func test_a_shrub_is_ideal_once_its_moss_lives() -> void:
	var row := _row(_biosphere({"moss": 30.0}), B.snapshot({"temperature": 30.0, "precipitation": 20.0}), "shrub")
	assert_str(String(row["verdict"])).is_equal("ideal")


func test_needs_report_good_poor_and_bad_in_the_players_units() -> void:
	var row := _row(_biosphere(), B.snapshot({"temperature": 16.0, "humidity": 40.0}), "moss")
	var temperature: Dictionary = row["needs"].filter(func(n: Dictionary) -> bool: return n["name"] == "Temperature")[0]
	assert_str(temperature["state"]).is_equal("poor")
	assert_str(temperature["range"]).contains("°C").contains(" to ")
	assert_str(temperature["now"]).contains("°C")


func test_the_guide_changes_nothing() -> void:
	var biosphere := _biosphere({"moss": 12.0})
	var before := biosphere.save_state()
	_row(biosphere, B.snapshot({"temperature": 28.0}), "moss")
	assert_dict(biosphere.save_state()).is_equal(before)


func test_fit_of_matches_the_species_suitability() -> void:
	var biosphere := _biosphere()
	var snapshot := B.snapshot({"temperature": 17.0, "humidity": 40.0})
	var species: SpeciesData = biosphere.species_list()[0]
	assert_float(biosphere.fit_of(&"moss", snapshot)).is_equal(species.suitability(snapshot))
	assert_float(biosphere.fit_of(&"nope", snapshot)).is_equal(0.0)
