extends GdUnitTestSuite
## HintAdvisor: advice at decision points, computed from causes, events and
## what the next stage of life still lacks.

const S := preload("res://simulation/tests/support/biosphere_fixtures.gd")
const I := preload("res://simulation/tests/support/intervention_fixtures.gd")

var _advisor: HintAdvisor
var _names := {"moss": "moss", "tree": "trees", "algae": "algae"}


func before_test() -> void:
	_advisor = HintAdvisor.load_json().value


func _label(act: String) -> String:
	return "<" + act + ">"


func _point(type: StringName, data: Dictionary) -> SimEvent:
	return SimEvent.new(type, 10, &"test", data)


func test_project_hints_are_valid() -> void:
	assert_array(Array(HintAdvisor.load_json().errors)).is_empty()
	assert_bool(_advisor.intro.is_empty()).is_false()


func test_every_extinction_cause_has_advice() -> void:
	for cause in BiosphereSystem.LOSS_CAUSES:
		var lines := _advisor.hints(_point(&"species_extinct", {"species": "moss", "cause": String(cause)}),
				S.snapshot(), null, _names, _label)
		assert_str(lines[0]).override_failure_message("no advice for cause '%s'" % cause).starts_with("Moss ")


func test_advised_acts_exist_in_the_project_catalog() -> void:
	var catalog := I.project_catalog()
	for act in _advisor.advised_acts():
		var parts := act.split(":")
		var def := catalog.get_def(StringName(parts[0]))
		assert_object(def).override_failure_message("unknown intervention in hints: %s" % act).is_not_null()
		if parts.size() > 1:
			assert_bool(def.levels.has(parts[1])).override_failure_message("unknown level in hints: %s" % act).is_true()


func test_extinction_advice_names_the_species_and_the_actions() -> void:
	var lines := _advisor.hints(_point(&"species_extinct", {"species": "moss", "cause": "cold"}), S.snapshot(), null, _names, _label)
	assert_str(lines[0]).is_equal("Moss died out from the cold. A light warming may help them return.")
	assert_str(lines[1]).is_equal("You could try: <mirrors_warm:weak>, <volcanic_awakening>.")


func test_drought_advice() -> void:
	var lines := _advisor.hints(_point(&"world_event_started", {"id": "drought"}), S.snapshot(), null, _names, _label)
	assert_str(lines[0]).starts_with("Drought weakens plants")
	assert_str(lines[1]).contains("<aquifer_release>")


func test_quiet_planet_gets_a_calm_hint() -> void:
	var lines := _advisor.hints(null, S.snapshot(), null, _names, _label)
	assert_array(Array(lines)).is_equal(["The planet is coping on its own. You can wait (0) or try something new."])


func _life() -> BiosphereSystem:
	return BiosphereSystem.new(S.calm(), S.catalog([S.species("algae", {"layer": 0}),
			S.species("moss", {"emerges_from": "algae", "o2_need": 4.0, "biomass_need": 3.0})]), 1)


func test_succession_names_what_the_next_species_lacks() -> void:
	var life := _life()
	life.set_population(&"algae", 30.0)
	var lines := _advisor.hints(null, S.snapshot({"oxygen": 1.0, "biomass": 6.0}), life, _names, _label)
	assert_array(Array(lines)).is_equal(["Next stage of life: moss. Missing: oxygen (1.0, about 4 needed)."])


func test_succession_says_when_conditions_are_good() -> void:
	var life := _life()
	life.set_population(&"algae", 30.0)
	var lines := _advisor.hints(null, S.snapshot({"oxygen": 10.0, "biomass": 6.0}), life, _names, _label)
	assert_str(lines[0]).is_equal("Moss: conditions are good, they will appear on their own or you can sow them.")


func test_succession_skips_species_whose_precursor_is_missing() -> void:
	# Moss comes first in this catalog, but without algae it cannot appear yet.
	var life := BiosphereSystem.new(S.calm(), S.catalog([S.species("moss", {"emerges_from": "algae"}),
			S.species("algae", {"layer": 0})]), 1)
	var lines := _advisor.hints(null, S.snapshot({"temperature": 0.0}), life, _names, _label)
	assert_str(lines[0]).starts_with("Next stage of life: algae. Missing: warmth (temperature 0.0")


func test_missing_needs_lists_every_unmet_requirement() -> void:
	var tree: SpeciesData = S.catalog([S.species("tree", {"water": "precipitation", "water_min": 8.0, "o2_need": 18.0,
			"biomass_need": 20.0, "co2_need": 8.0})]).get_species(&"tree")
	var missing := _advisor.missing_needs(tree, S.snapshot({"temperature": 60.0, "precipitation": 2.0, "oxygen": 5.0,
			"co2": 1.0, "biomass": 4.0}))
	assert_int(missing.size()).is_equal(5)
	assert_str(missing[0]).starts_with("cooler air (temperature 60.0, at most 50)")
	assert_str(missing[1]).starts_with("rain (rainfall 2.0, 8 needed)")


func test_rejects_incomplete_hint_data() -> void:
	var result := HintAdvisor.from_data({"intro": "x", "causes": {"cold": {"text": "x"}}})
	assert_bool(result.is_ok()).is_false()
	assert_int(result.errors.size()).is_greater_equal(4)


func test_needs_are_written_in_the_players_units_when_a_scale_is_set() -> void:
	var species: SpeciesData = S.catalog([S.species("moss", {"t_min": 10.0})]).all()[0]
	var cold := S.snapshot({"temperature": 5.0})
	assert_str(_advisor.missing_needs(species, cold)[0]).is_equal("warmth (temperature 5.0, at least 10 needed)")
	var scale := DisplayScale.from_data({"parameters": {"temperature": {"unit": "°C", "decimals": 1,
			"points": [[0, -30], [100, 70]]}}}, [&"temperature"], [])
	assert_array(Array(scale.errors)).is_empty()
	_advisor.scale = scale.value
	assert_str(_advisor.missing_needs(species, cold)[0]).is_equal("warmth (temperature -25.0 °C, at least -20.0 °C needed)")
