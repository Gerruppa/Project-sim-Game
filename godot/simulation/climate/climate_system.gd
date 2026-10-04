class_name ClimateSystem
extends SimulationSystem
## Game-oriented climate: energy balance, water cycle, clouds and rain.
##
## Owns the dynamics of temperature, humidity, cloud_cover and precipitation.
## Every term of the temperature balance is a separate delta with its own
## cause, so logs explain why the planet warms or cools. Formulas and
## coefficients: docs/climate.md and resources/climate/climate.json.

const ID := &"climate"

var _k: ClimateConfig
var _rng: SeededRng
## Slow, mean-reverting climate wander that pushes the planet across its
## tipping points. Internal state: must be saved by SaveSystem (step 8).
var _drift := 0.0


func _init(config: ClimateConfig, global_seed: int) -> void:
	_k = config
	_rng = SeededRng.new(global_seed, String(ID))


func system_id() -> StringName:
	return ID


## Coefficients in use. The pipeline keeps the ones returned at registration
## as the untouched base and hands back modified copies (personality, events).
func coefficients() -> Object:
	return _k


func coefficient_spec() -> Dictionary:
	return ClimateConfig.SPEC


func apply_coefficients(effective: Object) -> void:
	_k = effective


func drift() -> float:
	return _drift


## Triangle wave in -1..1 from integer tick arithmetic (no sin: determinism policy).
## -1 at the start of the year (winter), +1 in the middle (summer).
static func season_wave(tick: int, period: int) -> float:
	var phase := float(tick % period) / float(period)
	return 1.0 - 4.0 * absf(phase - 0.5)


## Called exactly once per tick by TickPipeline, because it advances the drift.
func compute(snapshot: PlanetSnapshot) -> Array[Delta]:
	var t := snapshot.get_value(Param.TEMPERATURE)
	var h := snapshot.get_value(Param.HUMIDITY)
	var c := snapshot.get_value(Param.CLOUD_COVER)
	var p := snapshot.get_value(Param.PRECIPITATION)
	var b := snapshot.get_value(Param.BIOMASS)
	_drift = clampf(_drift * (1.0 - _k.drift_reversion) + _rng.next_range(-_k.drift_noise, _k.drift_noise),
			-_k.drift_limit, _k.drift_limit)

	var deltas: Array[Delta] = []
	_add_energy_balance(deltas, snapshot.tick(), t, h, c, b)
	_add_water_cycle(deltas, t, h, c, p)
	return deltas


## Temperature relaxes toward a target made of named terms; each term is
## its own delta, and together they sum to thermal_response * (target - t).
## Near 0 every cooling term fades (soft floor): a very cold planet radiates
## little, so it approaches the bottom of the scale instead of hitting it.
func _add_energy_balance(deltas: Array[Delta], tick: int, t: float, h: float, c: float, b: float) -> void:
	var r := _k.thermal_response
	var ice := 1.0 - SimMath.smoothstep(_k.ice_full, _k.ice_free, t)
	var floor_factor := SimMath.smoothstep(0.0, _k.cold_floor, t)
	var terms := [
		[r * (_k.base_temperature - t), &"radiative_balance"],
		[r * _k.season_amplitude * season_wave(tick, _k.season_period_ticks), &"season"],
		[r * _drift, &"climate_drift"],
		[-r * _k.ice_strength * ice, &"ice_albedo"],
		[-r * _k.cloud_albedo * (c - _k.cloud_ref) / 100.0, &"cloud_albedo"],
		[r * _k.vegetation_albedo * b / 100.0, &"vegetation_albedo"],
		[r * _k.greenhouse * (h - _k.greenhouse_ref) / 100.0, &"greenhouse"],
	]
	for term: Array in terms:
		var amount: float = term[0]
		_add(deltas, Param.TEMPERATURE, amount * floor_factor if amount < 0.0 else amount, term[1])


func _add_water_cycle(deltas: Array[Delta], t: float, h: float, c: float, p: float) -> void:
	# Warm air holds more vapor: the same humidity is "drier" when hot.
	var capacity := SimMath.lerp(_k.capacity_cold, _k.capacity_warm, t / 100.0)
	var relative_humidity := clampf(h / capacity, 0.0, 1.0)

	var evaporation := _k.evaporation_rate * _k.water_availability \
			* SimMath.smoothstep(_k.evap_cold, _k.evap_warm, t) * (1.0 - relative_humidity)
	_add(deltas, Param.HUMIDITY, evaporation, &"evaporation")
	_add(deltas, Param.HUMIDITY, -p * _k.rain_efficiency, &"snowfall" if t < _k.snow_temperature else &"rainfall")

	var cloud_target := 100.0 * SimMath.smoothstep(_k.cloud_rh_low, _k.cloud_rh_high, relative_humidity)
	var cloud_change := _k.cloud_response * (cloud_target - c)
	_add(deltas, Param.CLOUD_COVER, cloud_change, &"condensation" if cloud_change > 0.0 else &"dissipation")

	var rain_target := 100.0 * SimMath.smoothstep(_k.rain_cloud_low, _k.rain_cloud_high, c) * relative_humidity
	var rain_change := _k.precipitation_response * (rain_target - p)
	_add(deltas, Param.PRECIPITATION, rain_change, &"rain_forming" if rain_change > 0.0 else &"rain_easing")


## Zero amounts are skipped to keep logs readable.
static func _add(deltas: Array[Delta], parameter: StringName, amount: float, cause: StringName) -> void:
	if amount != 0.0:
		deltas.append(Delta.new(parameter, amount, ID, cause))
