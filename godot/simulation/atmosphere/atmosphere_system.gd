class_name AtmosphereSystem
extends SimulationSystem
## Air and rock: the carbon cycle (volcanoes vs weathering) and oxygen
## sources and sinks.
##
## Owns the dynamics of oxygen, co2 and crust_oxidation and contributes the
## CO2 greenhouse term to temperature. A pure function of the snapshot:
## no randomness and no internal state, so nothing to save.
## Formulas and coefficients: docs/climate.md, resources/atmosphere/atmosphere.json.

const ID := &"atmosphere"

var _k: AtmosphereConfig


func _init(config: AtmosphereConfig) -> void:
	_k = config


func system_id() -> StringName:
	return ID


## Coefficients in use. The pipeline keeps the ones returned at registration
## as the untouched base and hands back modified copies (personality, events).
func coefficients() -> Object:
	return _k


func coefficient_spec() -> Dictionary:
	return AtmosphereConfig.SPEC


func apply_coefficients(effective: Object) -> void:
	_k = effective


func compute(snapshot: PlanetSnapshot) -> Array[Delta]:
	var deltas: Array[Delta] = []
	_add_carbon_cycle(deltas, snapshot)
	_add_oxygen(deltas, snapshot)
	return deltas


## Volcanoes add CO2; weathering of rock removes it, faster when warm and wet.
## Under ice there is no rain and no weathering, so CO2 builds up until the
## greenhouse thaws the planet.
func _add_carbon_cycle(deltas: Array[Delta], snapshot: PlanetSnapshot) -> void:
	var co2 := snapshot.get_value(Param.CO2)
	var warmth := SimMath.smoothstep(_k.weathering_cold, _k.weathering_warm, snapshot.get_value(Param.TEMPERATURE))
	var wetness := _k.weathering_dry + _k.weathering_wet * snapshot.get_value(Param.PRECIPITATION) / 100.0
	_add(deltas, Param.CO2, _k.volcanic_co2, &"volcanic_outgassing")
	_add(deltas, Param.CO2, -_k.weathering_rate * co2 / 100.0 * warmth * wetness, &"silicate_weathering")
	_add(deltas, Param.TEMPERATURE, _k.co2_greenhouse * (co2 - _k.co2_ref) / 100.0, &"co2_greenhouse")


## Fresh crust absorbs oxygen until it is oxidized; only then can oxygen
## accumulate (the Great Oxidation tipping point once life produces oxygen).
func _add_oxygen(deltas: Array[Delta], snapshot: PlanetSnapshot) -> void:
	var oxygen := snapshot.get_value(Param.OXYGEN)
	var fresh_crust := 1.0 - snapshot.get_value(Param.CRUST_OXIDATION) / 100.0
	var absorbed := _k.crust_oxidation_rate * oxygen / 100.0 * fresh_crust
	_add(deltas, Param.OXYGEN, _k.photolysis_rate * snapshot.get_value(Param.HUMIDITY) / 100.0, &"photolysis")
	_add(deltas, Param.OXYGEN, -absorbed, &"crust_oxidation")
	_add(deltas, Param.CRUST_OXIDATION, absorbed * _k.crust_capacity, &"crust_oxidation")
	_add(deltas, Param.OXYGEN, -_k.volcanic_gas_sink * oxygen / 100.0, &"volcanic_gases")


## Zero amounts are skipped to keep logs readable.
static func _add(deltas: Array[Delta], parameter: StringName, amount: float, cause: StringName) -> void:
	if amount != 0.0:
		deltas.append(Delta.new(parameter, amount, ID, cause))
