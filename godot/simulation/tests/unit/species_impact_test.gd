extends GdUnitTestSuite
## SpeciesImpact sums the applied deltas by who caused them: a species named
## in the cause, the player's interventions, or the rest of the planet.

var _impact: SpeciesImpact
var _bus: EventBus


func before_test() -> void:
	_impact = SpeciesImpact.new(["algae", "tree"])
	_bus = EventBus.new()
	_impact.attach(_bus)


func _tick(deltas: Array[Delta]) -> void:
	var report := ApplyReport.new()
	report.applied_deltas = deltas
	_bus.publish(SimEvent.new(SimEvent.TICK_APPLIED, 1, &"test", {"report": report}))
	_bus.flush()


func test_sums_each_species_by_its_cause() -> void:
	_tick([Delta.new(&"oxygen", 0.5, &"biosphere", &"algae_photosynthesis"),
			Delta.new(&"oxygen", -0.1, &"biosphere", &"algae_respiration"),
			Delta.new(&"co2", 0.2, &"biosphere", &"tree_wildfire")])
	_tick([Delta.new(&"oxygen", 0.5, &"biosphere", &"algae_photosynthesis")])
	assert_float(_impact.sums("algae")["oxygen"]).is_equal_approx(0.9, 0.000001)
	assert_float(_impact.sums("tree")["co2"]).is_equal_approx(0.2, 0.000001)
	assert_bool(_impact.sums("tree").has("oxygen")).is_false()


func test_the_rest_goes_to_the_player_or_the_planet() -> void:
	_tick([Delta.new(&"temperature", -1.0, InterventionSystem.ID, &"mirrors_cool"),
			Delta.new(&"oxygen", -0.3, &"atmosphere", &"crust_oxidation"),
			Delta.new(&"humidity", 0.4, &"climate", &"evaporation")])
	assert_float(_impact.sums(SpeciesImpact.PLAYER)["temperature"]).is_equal(-1.0)
	assert_float(_impact.sums(SpeciesImpact.PLANET)["oxygen"]).is_equal(-0.3)
	assert_float(_impact.sums(SpeciesImpact.PLANET)["humidity"]).is_equal(0.4)


func test_a_cause_only_starting_like_a_species_is_not_it() -> void:
	# "treeline" is not "tree_": only id + "_" belongs to a species.
	_tick([Delta.new(&"humidity", 0.4, &"climate", &"treeline_frost")])
	assert_bool(_impact.sums("tree").is_empty()).is_true()
	assert_float(_impact.sums(SpeciesImpact.PLANET)["humidity"]).is_equal(0.4)


func test_reset_starts_a_new_count() -> void:
	_tick([Delta.new(&"oxygen", 0.5, &"biosphere", &"algae_photosynthesis")])
	_impact.reset()
	assert_bool(_impact.sums("algae").is_empty()).is_true()


func test_sums_are_a_copy() -> void:
	_tick([Delta.new(&"oxygen", 0.5, &"biosphere", &"algae_photosynthesis")])
	_impact.sums("algae")["oxygen"] = 99.0
	assert_float(_impact.sums("algae")["oxygen"]).is_equal(0.5)
