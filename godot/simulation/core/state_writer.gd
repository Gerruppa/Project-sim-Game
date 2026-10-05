class_name StateWriter
extends RefCounted
## The only write path into PlanetState.
##
## Applies one batch of deltas atomically:
## validate all -> sort canonically -> sum per parameter -> clamp -> commit.
## Any invalid delta rejects the whole batch, so a broken model fails
## loudly instead of being hidden by clamping.

var _state: PlanetState


func _init(state: PlanetState) -> void:
	_state = state


func apply(deltas: Array[Delta]) -> ApplyReport:
	var report := ApplyReport.new()
	var schema := _state.schema()
	_validate(deltas, schema, report)
	if not report.is_ok():
		return report

	var sorted := _canonical_order(deltas, schema)

	# Float addition is not associative: the sum must always be built
	# in the same order, regardless of the order systems produced deltas.
	var sums: Dictionary[int, float] = {}
	for delta: Delta in sorted:
		var index := schema.index_of(delta.parameter)
		sums[index] = sums.get(index, 0.0) + delta.amount

	var values := _state.values_copy()
	var indices := sums.keys()
	indices.sort()
	for index: int in indices:
		var definition := schema.def_at(index)
		var requested: float = values[index] + sums[index]
		if not is_finite(requested):
			report.add_error_for(definition.id(), "sum of deltas is not finite")
			continue
		var applied := clampf(requested, definition.min_value(), definition.max_value())
		report.changes.append(ApplyReport.ParameterChange.new(definition.id(), values[index], requested, applied))
		values[index] = applied

	if not report.is_ok():
		report.changes.clear()
		return report
	report.applied_deltas = sorted
	_state._commit(values)
	return report


## Replaces every value with a saved state of the same schema. The only
## write without deltas: a save is a past result, not a new change.
func restore(saved: PlanetState) -> SimResult:
	if saved.schema().ids() != _state.schema().ids():
		return SimResult.failure("restore: saved parameters %s differ from %s" % [saved.schema().ids(), _state.schema().ids()])
	_state._commit(saved.values_copy())
	return SimResult.success(_state)


func _validate(deltas: Array[Delta], schema: ParameterSchema, report: ApplyReport) -> void:
	for delta in deltas:
		if schema.index_of(delta.parameter) == -1:
			report.add_error_for(delta.parameter, "unknown parameter (%s)" % delta)
		elif not is_finite(delta.amount):
			report.add_error_for(delta.parameter, "amount is not finite (%s)" % delta)
		elif delta.source.is_empty() or delta.cause.is_empty():
			report.add_error_for(delta.parameter, "delta needs source and cause (%s)" % delta)


## Total order: parameter, source, cause, amount.
## Each delta gets its sort key once ("%04d source cause") and keys are sorted
## natively; a custom comparator over StringName conversions was 70% of the
## tick time. The space separator sorts below every id character, so a
## shorter id still comes first, exactly as a field-by-field comparison would.
static func _canonical_order(deltas: Array[Delta], schema: ParameterSchema) -> Array[Delta]:
	var groups: Dictionary[String, Array] = {}
	for delta in deltas:
		var key := "%04d %s %s" % [schema.index_of(delta.parameter), delta.source, delta.cause]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(delta)
	var keys := groups.keys()
	keys.sort()
	var sorted: Array[Delta] = []
	for key: String in keys:
		var group: Array = groups[key]
		if group.size() > 1:
			group.sort_custom(func(a: Delta, b: Delta) -> bool: return a.amount < b.amount)
		sorted.append_array(group)
	return sorted
