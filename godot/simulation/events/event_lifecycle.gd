class_name EventLifecycle
extends RefCounted
## Phase of one event: Inactive -> Pending -> Active -> Cooldown -> Inactive.
##
## Pending: the trigger holds, but not yet for trigger_ticks in a row.
## Active: the event's modifiers are registered.
## Cooldown: modifiers are gone and the trigger is not checked.
## A pure state machine: EventSystem turns its transitions into modifiers
## and notifications. Different trigger and end conditions (hysteresis),
## for_ticks and min_duration keep events from flickering; max_duration
## and cooldown keep a self-reinforcing event from never ending.

const INACTIVE := &"inactive"
const PENDING := &"pending"
const ACTIVE := &"active"
const COOLDOWN := &"cooldown"
const PHASES: Array[StringName] = [INACTIVE, PENDING, ACTIVE, COOLDOWN]

## Transitions returned by advance().
const NO_CHANGE := &""
const STARTED := &"started"
const ENDED := &"ended"

## Why an active event ended.
const END_CONDITIONS := &"conditions"
const END_MAX_DURATION := &"max_duration"

var phase := INACTIVE
## Consecutive ticks the trigger (Pending) or the end condition (Active) held.
var streak := 0
## Ticks since the start (Active).
var elapsed := 0
## Ticks left (Cooldown).
var cooldown_left := 0
## Set by the transition to ENDED.
var end_reason := &""


## Advances one tick on the newest history sample.
func advance(def: EventDef, history: ParamHistory) -> StringName:
	match phase:
		INACTIVE, PENDING:
			if not def.trigger.is_met(history):
				phase = INACTIVE
				streak = 0
				return NO_CHANGE
			streak += 1
			if streak < def.trigger_ticks:
				phase = PENDING
				return NO_CHANGE
			phase = ACTIVE
			streak = 0
			elapsed = 0
			return STARTED
		ACTIVE:
			elapsed += 1
			if elapsed >= def.max_duration:
				return _end(def, END_MAX_DURATION)
			if elapsed < def.min_duration:
				return NO_CHANGE
			streak = streak + 1 if def.end.is_met(history) else 0
			return _end(def, END_CONDITIONS) if streak >= def.end_ticks else NO_CHANGE
		COOLDOWN:
			cooldown_left -= 1
			if cooldown_left <= 0:
				phase = INACTIVE
	return NO_CHANGE


func _end(def: EventDef, reason: StringName) -> StringName:
	end_reason = reason
	streak = 0
	cooldown_left = def.cooldown
	phase = COOLDOWN if def.cooldown > 0 else INACTIVE
	return ENDED


func to_dict() -> Dictionary:
	return {"phase": String(phase), "streak": streak, "elapsed": elapsed, "cooldown_left": cooldown_left}


func load_dict(data: Variant) -> SimResult:
	if typeof(data) != TYPE_DICTIONARY or not PHASES.has(StringName(str(data.get("phase")))):
		return SimResult.failure("lifecycle needs a 'phase' in %s" % [PHASES])
	for key: String in ["streak", "elapsed", "cooldown_left"]:
		if not EventCondition.is_whole(data.get(key)) or int(data[key]) < 0:
			return SimResult.failure("lifecycle: '%s' must be a whole number >= 0" % key)
	phase = StringName(data["phase"])
	streak = int(data["streak"])
	elapsed = int(data["elapsed"])
	cooldown_left = int(data["cooldown_left"])
	return SimResult.success(self)
