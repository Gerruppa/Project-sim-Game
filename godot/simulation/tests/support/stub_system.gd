class_name TestStubSystem
extends SimulationSystem
## Test-only system: returns fixed deltas and records what it saw.

var seen_ticks: Array[int] = []
var seen_values: Array[float] = []

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
	return [Delta.new(_parameter, _amount, _id, &"stub")]
