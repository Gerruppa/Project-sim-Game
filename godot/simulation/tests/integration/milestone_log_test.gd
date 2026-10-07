extends GdUnitTestSuite
## MilestoneLog: new life, returned life and lost life since the window last looked.


func _emit(bus: EventBus, type: StringName, species: String, tick: int = 1) -> void:
	bus.publish(SimEvent.new(type, tick, &"biosphere", {"species": species, "population": 1.0, "cause": "cold"}))
	bus.flush()


func test_news_arrives_in_order_and_is_cleared_on_read() -> void:
	var bus := EventBus.new()
	var log := MilestoneLog.new()
	log.attach(bus)
	_emit(bus, &"species_emerged", "moss")
	_emit(bus, &"species_extinct", "algae")
	_emit(bus, &"species_returned", "algae")
	var news := log.take_news()
	assert_array(news.map(func(n: Dictionary) -> String: return "%s:%s" % [n["kind"], n["species"]])).is_equal(
			["emerged:moss", "extinct:algae", "returned:algae"])
	assert_array(log.take_news()).is_empty()


func test_ordinary_events_are_ignored() -> void:
	var bus := EventBus.new()
	var log := MilestoneLog.new()
	log.attach(bus)
	bus.publish(SimEvent.new(&"tick_applied", 1, &"pipeline", {}))
	bus.flush()
	assert_array(log.take_news()).is_empty()
