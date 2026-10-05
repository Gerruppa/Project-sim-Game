extends GdUnitTestSuite
## PlanetChronicle: the run told in sentences, only what happened to the planet.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

var _bus: EventBus
var _sink: MemoryLogSink
## The bus does not keep subscribers alive; the test must.
var _chronicle: PlanetChronicle


func before_test() -> void:
	_bus = EventBus.new()
	_sink = MemoryLogSink.new()
	var texts: ChronicleTexts = ChronicleTexts.from_data({
		"species": {"moss": "mchy"},
		"events": {"species_emerged": "Pojawiają się {species}.", "planet_personality": "Planeta budzi się. {description}"},
		"measures": {
			"value": "{param} {value}",
			"change": {"below": "{param} spada o {abs} w {window}", "above": "{param} rośnie o {abs} w {window}"},
			"mean": "m", "min": "m", "max": "m", "range": "m",
			"anomaly": {"below": "a", "above": "a"},
			"drop_from_peak": "{param} {percent}% poniżej szczytu",
		},
	}).value
	_chronicle = PlanetChronicle.new([_sink], texts)
	_chronicle.attach(_bus)
	var state: PlanetState = PlanetState.create(P.schema([P.parameter("humidity", 30.0)])).value
	_chronicle.begin_run(42, state.snapshot(0))


func _publish(type: StringName, tick: int, data: Dictionary) -> void:
	_bus.publish(SimEvent.new(type, tick, &"test", data))
	_bus.flush()


func _fact(measure: String, measured: float, window: int = 500) -> Dictionary:
	return {"param": "humidity", "measure": measure, "window": window, "measured": measured,
			"op": "<", "threshold": 0.0, "met": true}


func test_starts_with_the_seed() -> void:
	assert_str(_sink.lines[0]).is_equal("# Kronika planety | seed 42")


func test_world_event_tells_its_story_with_measured_causes() -> void:
	_publish(&"world_event_started", 734, {"story": "Susza.", "causes": [_fact("value", 24.24), _fact("change", -5.36)]})
	assert_str(_sink.lines[1]).is_equal("[Tick 734] Susza. (Humidity 24,2; Humidity spada o 5,4 w 500)")


func test_story_without_causes_has_no_brackets() -> void:
	_publish(&"world_event_ended", 9, {"story": "Koniec.", "causes": []})
	assert_str(_sink.lines[1]).is_equal("[Tick 9] Koniec.")


func test_signed_phrase_follows_the_sign_of_the_measure() -> void:
	_publish(&"world_event_started", 1, {"story": "S.", "causes": [_fact("change", 2.5)]})
	assert_str(_sink.lines[1]).contains("Humidity rośnie o 2,5 w 500")


func test_fractions_read_as_percent() -> void:
	_publish(&"world_event_started", 1, {"story": "S.", "causes": [_fact("drop_from_peak", 0.314)]})
	assert_str(_sink.lines[1]).contains("Humidity 31% poniżej szczytu")


func test_unknown_parameter_keeps_its_id() -> void:
	var fact := _fact("value", 1.0)
	fact["param"] = "radiation"
	_publish(&"world_event_started", 1, {"story": "S.", "causes": [fact]})
	assert_str(_sink.lines[1]).contains("radiation 1,0")


func test_system_events_use_the_vocabulary_and_species_names() -> void:
	_publish(&"species_emerged", 744, {"species": "moss", "population": 1.0})
	_publish(&"species_emerged", 800, {"species": "lichen", "population": 1.0})
	_publish(&"planet_personality", 1, {"archetype": "guardian", "description": "Czujna."})
	assert_array(Array(_sink.lines.slice(1))).is_equal([
		"[Tick 744] Pojawiają się mchy.",
		"[Tick 800] Pojawiają się lichen.",
		"[Tick 1] Planeta budzi się. Czujna.",
	])


func test_leaves_out_everything_without_a_sentence() -> void:
	_publish(SimEvent.TICK_APPLIED, 1, {})
	_publish(&"species_extinct", 2, {"species": "moss"})
	_publish(&"world_event_started", 3, {"summary": "no story here"})
	assert_int(_sink.lines.size()).is_equal(1)


func test_close_closes_every_sink() -> void:
	_chronicle.close()
	_publish(&"species_emerged", 5, {"species": "moss"})
	assert_int(_sink.lines.size()).is_equal(1)
