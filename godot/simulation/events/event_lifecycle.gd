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

## Transitions returned by advance_warning().
const WARNED := &"warned"
const WARNING_CLEARED := &"warning_cleared"

var phase := INACTIVE
## Consecutive ticks the trigger (Pending) or the end condition (Active) held.
var streak := 0
## Ticks since the start (Active).
var elapsed := 0
## Ticks left (Cooldown).
var cooldown_left := 0
## Set by the transition to ENDED.
var end_reason := &""
## An early warning has been issued and not yet withdrawn.
var warned := false
## Consecutive ticks the warning condition held (before the warning) or failed (after it).
var warn_streak := 0
var calm_streak := 0


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


## Advances the early warning one tick, after advance() on the same sample.
## Only a crisis that has not started can be warned about: once it is Active
## (or cooling down) the warning is over without a word.
func advance_warning(def: EventDef, history: ParamHistory) -> StringName:
	if def.warning == null or not (phase == INACTIVE or phase == PENDING):
		warned = false
		warn_streak = 0
		calm_streak = 0
		return NO_CHANGE
	if def.warning.is_met(history):
		calm_streak = 0
		if warned:
			return NO_CHANGE
		warn_streak += 1
		if warn_streak < def.warning_ticks:
			return NO_CHANGE
		warned = true
		warn_streak = 0
		return WARNED
	warn_streak = 0
	if not warned:
		return NO_CHANGE
	calm_streak += 1
	if calm_streak < def.warning_clear_ticks:
		return NO_CHANGE
	warned = false
	calm_streak = 0
	return WARNING_CLEARED


func _end(def: EventDef, reason: StringName) -> StringName:
	end_reason = reason
	streak = 0
	cooldown_left = def.cooldown
	phase = COOLDOWN if def.cooldown > 0 else INACTIVE
	return ENDED


func to_dict() -> Dictionary:
	return {"phase": String(phase), "streak": streak, "elapsed": elapsed, "cooldown_left": cooldown_left,
			"warned": warned, "warn_streak": warn_streak, "calm_streak": calm_streak}


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
	# Optional: saves from before early warnings have none.
	warned = bool(data.get("warned", false))
	warn_streak = maxi(0, int(data.get("warn_streak", 0)))
	calm_streak = maxi(0, int(data.get("calm_streak", 0)))
	return SimResult.success(self)
