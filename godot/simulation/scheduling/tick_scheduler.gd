class_name TickScheduler
extends RefCounted
## Converts real time into a number of simulation ticks.
##
## The tick has a fixed size. Speed only changes how many ticks run per
## real second (x1 = base_ticks_per_second), so the simulation result
## after N ticks never depends on speed, pauses or frame rate.

## Absorbs float error when real time arrives in fractions (10 x 0.1 s).
const EPSILON := 1e-9

var _base_ticks_per_second: float
var _allowed_speeds: Array[int]
var _max_catch_up_ticks: int
var _speed := 1
var _paused := false
var _pending := 0.0
var _dropped := 0


func _init(config: SimConfig) -> void:
	_base_ticks_per_second = config.base_ticks_per_second()
	_allowed_speeds = config.speed_multipliers()
	_max_catch_up_ticks = config.max_catch_up_ticks()


## True when a system with the given interval runs on this tick.
static func is_due(tick: int, interval: int) -> bool:
	return tick % interval == 0


func speed() -> int:
	return _speed


## Returns false and keeps the current speed if the value is not configured.
func set_speed(multiplier: int) -> bool:
	if not _allowed_speeds.has(multiplier):
		return false
	_speed = multiplier
	return true


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


func ticks_per_second() -> float:
	return 0.0 if _paused else _base_ticks_per_second * _speed


## Ticks skipped because a single advance exceeded max_catch_up_ticks.
## The simulation slows down instead of freezing while it catches up.
func dropped_ticks() -> int:
	return _dropped


## Adds real time and returns how many ticks are due now.
func advance(real_seconds: float) -> int:
	if _paused or not is_finite(real_seconds) or real_seconds <= 0.0:
		return 0
	_pending += real_seconds * ticks_per_second()
	var due := int(floorf(_pending + EPSILON))
	_pending = maxf(_pending - due, 0.0)
	if due > _max_catch_up_ticks:
		_dropped += due - _max_catch_up_ticks
		due = _max_catch_up_ticks
	return due
