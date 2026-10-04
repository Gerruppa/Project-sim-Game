class_name ModifierRegistry
extends RefCounted
## Active modifiers and their effect on system coefficients (tick phase 2).
##
## Resolution per coefficient: base -> + every add -> x every multiply ->
## clamp to the spec range. Modifiers are folded in canonical order, because
## float multiplication is not associative either: registration order never
## changes the bits. Effective configs are copies; base configs stay intact.

var _specs: Dictionary[StringName, Dictionary] = {}
var _modifiers: Array[Modifier] = []
var _version := 0


## Declares which coefficients of a system may be modified.
func register_target(system_id: StringName, spec: Dictionary) -> void:
	_specs[system_id] = spec


func has_target(system_id: StringName) -> bool:
	return _specs.has(system_id)


func add(modifier: Modifier) -> SimResult:
	var parts := String(modifier.target).split(".")
	if parts.size() != 2 or not _specs.has(StringName(parts[0])):
		return SimResult.failure("modifier target '%s' must be <system>.<coefficient> of a registered system" % modifier.target)
	if not _specs[StringName(parts[0])].has(parts[1]):
		return SimResult.failure("system '%s' has no coefficient '%s'" % [parts[0], parts[1]])
	if not Modifier.OPERATIONS.has(modifier.operation):
		return SimResult.failure("modifier operation must be add or multiply (%s)" % modifier)
	if not is_finite(modifier.value):
		return SimResult.failure("modifier value must be finite (%s)" % modifier)
	_modifiers.append(modifier)
	_version += 1
	return SimResult.success(modifier)


## Removes modifiers whose last active tick has passed. Returns how many.
func expire(tick: int) -> int:
	return _remove(func(m: Modifier) -> bool: return m.expires_at != Modifier.PERMANENT and m.expires_at <= tick)


func remove_source(source: StringName) -> int:
	return _remove(func(m: Modifier) -> bool: return m.source == source)


## Changes whenever the set of modifiers changes; lets the pipeline skip
## recomputing effective configs on ticks where nothing changed.
func version() -> int:
	return _version


## Copy, in canonical order.
func modifiers() -> Array[Modifier]:
	return _canonical(_modifiers)


## Effective copy of `base` with every modifier for `system_id` applied.
func resolve(system_id: StringName, base: Object) -> Object:
	var spec: Dictionary = _specs.get(system_id, {})
	var effective: Object = base.get_script().new()
	for name: String in spec:
		effective.set(name, base.get(name))
	var by_coefficient: Dictionary[String, Array] = {}
	for modifier in _canonical(_modifiers):
		if modifier.system_id() == system_id:
			if not by_coefficient.has(modifier.coefficient()):
				by_coefficient[modifier.coefficient()] = []
			by_coefficient[modifier.coefficient()].append(modifier)
	for name: String in by_coefficient:
		effective.set(name, _fold(float(base.get(name)), by_coefficient[name], spec[name]))
	return effective


static func _fold(base_value: float, modifiers_for_coefficient: Array, rule: Array) -> Variant:
	var added := base_value
	for modifier: Modifier in modifiers_for_coefficient:
		if modifier.operation == Modifier.ADD:
			added += modifier.value
	var result := added
	for modifier: Modifier in modifiers_for_coefficient:
		if modifier.operation == Modifier.MULTIPLY:
			result *= modifier.value
	result = clampf(result, rule[0], rule[1])
	return int(roundf(result)) if rule[2] else result


## Target, operation, source, then value: a total order.
static func _canonical(list: Array[Modifier]) -> Array[Modifier]:
	var sorted := list.duplicate()
	sorted.sort_custom(func(a: Modifier, b: Modifier) -> bool:
		var key_a := "%s %s %s" % [a.target, a.operation, a.source]
		var key_b := "%s %s %s" % [b.target, b.operation, b.source]
		return key_a < key_b if key_a != key_b else a.value < b.value)
	return sorted


func _remove(should_remove: Callable) -> int:
	var kept: Array[Modifier] = _modifiers.filter(func(m: Modifier) -> bool: return not should_remove.call(m))
	var removed := _modifiers.size() - kept.size()
	if removed > 0:
		_modifiers = kept
		_version += 1
	return removed
