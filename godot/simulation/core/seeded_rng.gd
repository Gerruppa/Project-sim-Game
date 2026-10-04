class_name SeededRng
extends RefCounted
## Deterministic random stream for one simulation system.
##
## Every system owns its own stream derived from the global seed,
## so adding a system never shifts the randomness of other systems.
## Only the integer core of RandomNumberGenerator (PCG32) is used;
## conversion to float goes through SimMath to stay platform independent.

var _rng := RandomNumberGenerator.new()


func _init(global_seed: int, stream_id: String) -> void:
	_rng.seed = derive_seed(global_seed, stream_id)


## Stable across engine versions: SHA-256 instead of hash(), whose
## stability between Godot versions is not documented.
static func derive_seed(global_seed: int, stream_id: String) -> int:
	var digest := ("%d:%s" % [global_seed, stream_id]).sha256_text()
	return digest.substr(0, 15).hex_to_int()


func next_u32() -> int:
	return _rng.randi()


func next_unit_float() -> float:
	return SimMath.u32_to_unit_float(next_u32())


## Uniform value in [from, to).
func next_range(from: float, to: float) -> float:
	return SimMath.lerp(from, to, next_unit_float())


func get_state() -> int:
	return _rng.state


func set_state(state: int) -> void:
	_rng.state = state
