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

	var sorted := deltas.duplicate()
	sorted.sort_custom(_canonical_order.bind(schema))

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


func _validate(deltas: Array[Delta], schema: ParameterSchema, report: ApplyReport) -> void:
	for delta in deltas:
		if schema.index_of(delta.parameter) == -1:
			report.add_error_for(delta.parameter, "unknown parameter (%s)" % delta)
		elif not is_finite(delta.amount):
			report.add_error_for(delta.parameter, "amount is not finite (%s)" % delta)
		elif delta.source.is_empty() or delta.cause.is_empty():
			report.add_error_for(delta.parameter, "delta needs source and cause (%s)" % delta)


## Total order: parameter, source, cause, amount.
## StringName is compared as String because its own < operator is not
## guaranteed to compare text.
static func _canonical_order(a: Delta, b: Delta, schema: ParameterSchema) -> bool:
	var index_a := schema.index_of(a.parameter)
	var index_b := schema.index_of(b.parameter)
	if index_a != index_b:
		return index_a < index_b
	if a.source != b.source:
		return String(a.source) < String(b.source)
	if a.cause != b.cause:
		return String(a.cause) < String(b.cause)
	return a.amount < b.amount
