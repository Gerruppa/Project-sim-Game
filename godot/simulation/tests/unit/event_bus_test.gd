extends GdUnitTestSuite

var _bus: EventBus
var _received: Array[String] = []


func before_test() -> void:
	_bus = EventBus.new()
	_received = []


func _event(type: StringName, tick: int = 1) -> SimEvent:
	return SimEvent.new(type, tick, &"test", {})


func _record(prefix: String) -> Callable:
	return func(event: SimEvent) -> void: _received.append("%s:%s" % [prefix, event.type])


func test_nothing_is_delivered_before_flush() -> void:
	_bus.subscribe_all(_record("all"))
	_bus.publish(_event(&"a"))
	assert_array(_received).is_empty()
	assert_int(_bus.pending_count()).is_equal(1)


func test_events_are_delivered_in_publish_order() -> void:
	_bus.subscribe_all(_record("all"))
	_bus.publish(_event(&"a"))
	_bus.publish(_event(&"b"))
	_bus.publish(_event(&"c"))
	assert_int(_bus.flush()).is_equal(3)
	assert_array(_received).is_equal(["all:a", "all:b", "all:c"])


func test_typed_subscription_receives_only_its_type() -> void:
	_bus.subscribe(&"b", _record("only_b"))
	_bus.publish(_event(&"a"))
	_bus.publish(_event(&"b"))
	_bus.flush()
	assert_array(_received).is_equal(["only_b:b"])


func test_subscribers_are_called_in_subscription_order() -> void:
	_bus.subscribe(&"a", _record("first"))
	_bus.subscribe_all(_record("second"))
	_bus.subscribe(&"a", _record("third"))
	_bus.publish(_event(&"a"))
	_bus.flush()
	assert_array(_received).is_equal(["first:a", "second:a", "third:a"])


func test_event_published_during_flush_waits_for_next_flush() -> void:
	_bus.subscribe(&"a", func(_event_value: SimEvent) -> void: _bus.publish(_event(&"follow_up")))
	_bus.subscribe_all(_record("all"))
	_bus.publish(_event(&"a"))
	_bus.flush()
	assert_array(_received).is_equal(["all:a"])
	assert_int(_bus.pending_count()).is_equal(1)
	_bus.flush()
	assert_array(_received).is_equal(["all:a", "all:follow_up"])


func test_flush_on_empty_queue_delivers_nothing() -> void:
	assert_int(_bus.flush()).is_equal(0)


class Listener:
	var count := 0

	func on_event(_event_value: SimEvent) -> void:
		count += 1


func test_freed_subscriber_is_dropped_without_error() -> void:
	var listener := Listener.new()
	_bus.subscribe_all(listener.on_event)
	listener = null
	_bus.publish(_event(&"a"))
	assert_int(_bus.flush()).is_equal(1)
	assert_int(_bus.subscriber_count()).is_equal(0)
