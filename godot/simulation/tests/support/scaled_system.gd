class_name TestScaledSystem
extends SimulationSystem
## Test-only system with a coefficient file: adds `amount` to temperature.

const SPEC := {"amount": [0.0, 100.0, false]}

var base_config: Config
var _k: Config


class Config:
	var amount: float


func _init(amount: float) -> void:
	base_config = Config.new()
	base_config.amount = amount
	_k = base_config


func system_id() -> StringName:
	return &"scaled"


func coefficients() -> Object:
	return base_config


func coefficient_spec() -> Dictionary:
	return SPEC


func apply_coefficients(effective: Object) -> void:
	_k = effective


func compute(_snapshot: PlanetSnapshot) -> Array[Delta]:
	return [Delta.new(Param.TEMPERATURE, _k.amount, &"scaled", &"amount")]
