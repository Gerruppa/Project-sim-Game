class_name EventBus
extends RefCounted
## Queued notification channel between simulation modules and observers.
##
## publish() only queues. flush() runs in the pipeline's Dispatch phase and
## delivers the queued events in publish order, to subscribers in
## subscription order. Events published while flushing wait for the next
## flush, so delivery never re-enters and order stays deterministic.
## Godot signals are not used because they call listeners immediately.

var _queue: Array[SimEvent] = []
## Each entry: [event type or &"" for all events, handler].
var _subscribers: Array[Array] = []


func subscribe(type: StringName, handler: Callable) -> void:
	_subscribers.append([type, handler])


func subscribe_all(handler: Callable) -> void:
	_subscribers.append([&"", handler])


func publish(event: SimEvent) -> void:
	_queue.append(event)


func pending_count() -> int:
	return _queue.size()


func subscriber_count() -> int:
	return _subscribers.size()


## Delivers events queued before this call. Returns how many were delivered.
## A Callable does not keep its RefCounted object alive; subscribers whose
## object was freed are dropped instead of failing the whole tick.
func flush() -> int:
	var batch := _queue
	_queue = []
	_subscribers = _subscribers.filter(func(subscriber: Array) -> bool: return (subscriber[1] as Callable).is_valid())
	for event in batch:
		for subscriber in _subscribers:
			var type: StringName = subscriber[0]
			var handler: Callable = subscriber[1]
			if (type.is_empty() or type == event.type) and handler.is_valid():
				handler.call(event)
	return batch.size()
