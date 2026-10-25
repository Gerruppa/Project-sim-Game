extends GdUnitTestSuite
## The real planet with its animals, left alone: insects follow the moss, small
## animals the shrubs, large mammals the trees; never before their food.
## (tools/life_timeline.gd prints the same for more seeds and archetypes.)

const SEEDS: Array[int] = [1, 2, 3]
const TICKS := 16000

## seed -> {species id -> first tick it established itself}
var _first: Dictionary[int, Dictionary] = {}


func before() -> void:
	for seed_value in SEEDS:
		_first[seed_value] = _play(seed_value)


func _play(seed_value: int) -> Dictionary:
	var options: Dictionary = SimulationRunner.parse_args(PackedStringArray(["--seed", str(seed_value), "--personality", "harmonious"])).value
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_seed(seed_value).with_personality(&"harmonious")
	var manager: SimulationManager = SimulationRunner.build_planet(config, options).value["manager"]
	var seen := {}
	manager.event_bus().subscribe(&"species_emerged", func(event: SimEvent) -> void:
		if not seen.has(event.data["species"]):
			seen[event.data["species"]] = event.tick)
	assert_int(manager.run_ticks(TICKS)).is_equal(TICKS)
	var oxygen := manager.snapshot().get_value(Param.OXYGEN)
	assert_bool(is_finite(oxygen) and oxygen >= 0.0 and oxygen <= 100.0).is_true()
	return seen


func test_every_stage_of_life_has_its_place_in_the_ladder() -> void:
	var catalog := SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value as SpeciesCatalog
	assert_int(catalog.size()).is_equal(8)
	for id: StringName in [&"insects", &"small_animals", &"large_mammals"]:
		assert_bool(catalog.get_species(id).is_fauna()).is_true()


func test_animals_never_appear_before_their_food() -> void:
	for seed_value in SEEDS:
		var first: Dictionary = _first[seed_value]
		for pair: Array in [["insects", "moss"], ["small_animals", "shrub"], ["large_mammals", "tree"]]:
			if first.has(pair[0]):
				assert_bool(first.has(pair[1]) and first[pair[0]] > first[pair[1]]).override_failure_message(
						"seed %d: %s appeared before %s" % [seed_value, pair[0], pair[1]]).is_true()


func test_insects_follow_the_moss_within_thirty_years() -> void:
	for seed_value in SEEDS:
		var first: Dictionary = _first[seed_value]
		assert_bool(first.has("insects")).override_failure_message("seed %d: no insects in %d ticks" % [seed_value, TICKS]).is_true()
		assert_int(first["insects"]).is_less(30 * GameCalendar.TICKS_PER_YEAR)


func test_small_animals_arrive_on_most_planets() -> void:
	var reached := 0
	for seed_value in SEEDS:
		reached += 1 if (_first[seed_value] as Dictionary).has("small_animals") else 0
	assert_int(reached).is_greater_equal(2)


func test_the_chronicle_names_the_animals() -> void:
	var texts := ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH).value as ChronicleTexts
	assert_str(texts.species["insects"]).is_equal("insects")
	assert_str(texts.species["small_animals"]).is_equal("small animals")
	assert_str(texts.species["large_mammals"]).is_equal("large mammals")
	for cause: String in ["hunger", "grazed"]:
		assert_str(texts.causes[cause]).is_not_empty()
