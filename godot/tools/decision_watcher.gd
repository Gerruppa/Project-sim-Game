class_name DecisionWatcher
extends RunObserver
## Watches a run for the first decision point: an event the player should
## react to (a drought starts, a species dies out). The runner stops after
## that tick, saves and asks the player what to do (--until decision).
##
## Observes only; also keeps the run's chronicle in memory, so the stop can
## show the sentences of the decision tick.

var _events: Array[StringName]
var _first_tick: int
var _chronicle: PlanetChronicle
var _sink := MemoryLogSink.new()
var _point: SimEvent = null


## start_tick: tick the run starts from; points count from start_tick + grace.
func _init(events: Array[StringName], grace: int, start_tick: int, texts: ChronicleTexts) -> void:
	_events = events.duplicate()
	_first_tick = start_tick + 1 + grace
	_chronicle = PlanetChronicle.new([_sink], texts)


func attach(bus: EventBus) -> void:
	_chronicle.attach(bus)
	bus.subscribe_all(_on_event)


func begin_run(seed_value: int, initial: PlanetSnapshot) -> void:
	_chronicle.begin_run(seed_value, initial)


func close() -> void:
	_chronicle.close()


func reached() -> bool:
	return _point != null


## The event that made the decision point, or null.
func point() -> SimEvent:
	return _point


## Chronicle sentences of the decision tick (everything that happened in it).
func sentences() -> PackedStringArray:
	var prefix := "[Tick %d]" % _point.tick if _point != null else ""
	var result := PackedStringArray()
	for line in _sink.lines:
		if not prefix.is_empty() and line.begins_with(prefix + " "):
			result.append(line)
	return result


func _on_event(event: SimEvent) -> void:
	if _point == null and event.tick >= _first_tick and _events.has(event.type):
		_point = event
