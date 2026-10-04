extends GdUnitTestSuite

const P := preload("res://simulation/tests/support/schema_fixtures.gd")

var _state: PlanetState
var _bus: EventBus
var _pipeline: TickPipeline
var _events: Array[SimEvent] = []


func before_test() -> void:
	_state = PlanetState.create(P.project_schema()).value
	_bus = EventBus.new()
	_pipeline = TickPipeline.new(_state, _bus)
	_events = []
	_bus.subscribe_all(func(event: SimEvent) -> void: _events.append(event))


func test_registered_system_changes_state() -> void:
	_pipeline.register(TestStubSystem.new(&"heater", Param.TEMPERATURE, 2.0), 1)
	assert_bool(_pipeline.execute(1).is_ok()).is_true()
	assert_float(_state.get_value(Param.TEMPERATURE)).is_equal(32.0)


func test_systems_read_snapshot_of_previous_tick() -> void:
	var heater := TestStubSystem.new(&"heater", Param.TEMPERATURE, 5.0)
	var observer := TestStubSystem.new(&"observer", Param.TEMPERATURE, 0.0)
	_pipeline.register(heater, 1)
	_pipeline.register(observer, 1)
	_pipeline.execute(1)
	# The observer runs after the heater but must not see its change.
	assert_array(observer.seen_values).is_equal([30.0])
	assert_array(observer.seen_ticks).is_equal([0])


func test_interval_controls_when_system_runs() -> void:
	var slow := TestStubSystem.new(&"slow")
	_pipeline.register(slow, 3)
	for tick in range(1, 8):
		_pipeline.execute(tick)
	assert_array(slow.seen_ticks).is_equal([2, 5])


func test_rejects_duplicate_system_id() -> void:
	_pipeline.register(TestStubSystem.new(&"heater"), 1)
	var result := _pipeline.register(TestStubSystem.new(&"heater"), 1)
	assert_str("\n".join(result.errors)).contains("heater")


func test_rejects_invalid_interval() -> void:
	assert_bool(_pipeline.register(TestStubSystem.new(&"heater"), 0).is_ok()).is_false()


func test_rejects_system_without_id() -> void:
	assert_bool(_pipeline.register(TestStubSystem.new(&""), 1).is_ok()).is_false()


func test_tick_event_is_delivered_within_the_tick() -> void:
	_pipeline.register(TestStubSystem.new(&"heater"), 1)
	_pipeline.execute(1)
	assert_int(_events.size()).is_equal(1)
	assert_str(_events[0].type).is_equal(String(SimEvent.TICK_APPLIED))
	assert_int(_events[0].tick).is_equal(1)
	assert_object(_events[0].data["report"]).is_instanceof(ApplyReport)


func test_rejected_batch_publishes_rejection_and_keeps_state() -> void:
	_pipeline.register(TestStubSystem.new(&"broken", Param.TEMPERATURE, NAN), 1)
	assert_bool(_pipeline.execute(1).is_ok()).is_false()
	assert_str(_events[0].type).is_equal(String(SimEvent.BATCH_REJECTED))
	assert_float(_state.get_value(Param.TEMPERATURE)).is_equal(30.0)


func test_registration_order_does_not_change_result() -> void:
	var first: PlanetState = PlanetState.create(P.project_schema()).value
	var second: PlanetState = PlanetState.create(P.project_schema()).value
	var a := TickPipeline.new(first, EventBus.new())
	var b := TickPipeline.new(second, EventBus.new())
	a.register(TestStubSystem.new(&"x", Param.HUMIDITY, 0.1), 1)
	a.register(TestStubSystem.new(&"y", Param.HUMIDITY, 0.2), 1)
	a.register(TestStubSystem.new(&"z", Param.HUMIDITY, 0.3), 1)
	b.register(TestStubSystem.new(&"z", Param.HUMIDITY, 0.3), 1)
	b.register(TestStubSystem.new(&"x", Param.HUMIDITY, 0.1), 1)
	b.register(TestStubSystem.new(&"y", Param.HUMIDITY, 0.2), 1)
	for tick in range(1, 50):
		a.execute(tick)
		b.execute(tick)
	assert_str(PlanetStateCodec.state_hash(first)).is_equal(PlanetStateCodec.state_hash(second))
