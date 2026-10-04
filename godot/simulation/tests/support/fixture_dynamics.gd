class_name TestFixtureDynamics
extends RefCounted
## Test-only stand-in for domain systems.
##
## Produces coupled, noisy deltas from a snapshot so the pipeline can be
## exercised before Climate, Atmosphere and Biosphere exist.
## Not a planet model and not balanced. Follows the deterministic math
## policy, so the golden trace measures the same operations real systems use.

const STREAM_ID := "test_fixture"

var _rng: SeededRng


func _init(global_seed: int) -> void:
	_rng = SeededRng.new(global_seed, STREAM_ID)


func rng_state() -> int:
	return _rng.get_state()


func set_rng_state(state: int) -> void:
	_rng.set_state(state)


func compute(snapshot: PlanetSnapshot) -> Array[Delta]:
	var t := snapshot.get_value(Param.TEMPERATURE)
	var h := snapshot.get_value(Param.HUMIDITY)
	var o := snapshot.get_value(Param.OXYGEN)
	var b := snapshot.get_value(Param.BIOMASS)
	var deltas: Array[Delta] = []

	var target_t := SimMath.lerp(25.0, 55.0, SimMath.smoothstep(0.0, 60.0, b))
	deltas.append(Delta.new(Param.TEMPERATURE, (target_t - t) * 0.01 + _rng.next_range(-0.4, 0.4), &"fixture_climate", &"drift"))
	var target_h := SimMath.lerp(5.0, 85.0, SimMath.smoothstep(10.0, 60.0, t))
	deltas.append(Delta.new(Param.HUMIDITY, (target_h - h) * 0.02 + _rng.next_range(-0.5, 0.5), &"fixture_climate", &"evaporation"))

	var suitability := SimMath.smoothstep(5.0, 40.0, h) * (1.0 - SimMath.smoothstep(55.0, 90.0, t))
	var growth := (0.05 + b * 0.03 * (1.0 - b / 100.0)) * SimMath.int_pow(suitability, 2)
	var dieback := b * 0.01 * (1.0 - suitability)
	deltas.append(Delta.new(Param.BIOMASS, growth - dieback + _rng.next_range(-0.05, 0.05), &"fixture_biosphere", &"growth"))
	deltas.append(Delta.new(Param.HUMIDITY, b * 0.002, &"fixture_biosphere", &"transpiration"))
	deltas.append(Delta.new(Param.TEMPERATURE, -b * 0.001, &"fixture_biosphere", &"shading"))
	deltas.append(Delta.new(Param.OXYGEN, b * 0.01, &"fixture_biosphere", &"photosynthesis"))

	deltas.append(Delta.new(Param.OXYGEN, -o * 0.004, &"fixture_atmosphere", &"oxidation"))
	return deltas
