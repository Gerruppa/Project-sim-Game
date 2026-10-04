class_name TestStubSystem
extends SimulationSystem
## Test-only system: returns fixed deltas and records what it saw.

var seen_ticks: Array[int] = []
var seen_values: Array[float] = []
## When set, emits this event type on every compute.
var event_type := &""

var _id: StringName
var _parameter: StringName
var _amount: float


func _init(id_value: StringName, parameter: StringName = Param.TEMPERATURE, amount: float = 1.0) -> void:
	_id = id_value
	_parameter = parameter
	_amount = amount


func system_id() -> StringName:
	return _id


func compute(snapshot: PlanetSnapshot) -> Array[Delta]:
	seen_ticks.append(snapshot.tick())
	seen_values.append(snapshot.get_value(_parameter))
	if not event_type.is_empty():
		emit_event(event_type, {"seen_tick": snapshot.tick()})
	return [Delta.new(_parameter, _amount, _id, &"stub")]
