class_name EventCondition
extends RefCounted
## One node of an event condition tree, parsed from data.
##
## Leaves compare a measure of one parameter's recent history with a
## threshold ("humidity anomaly over 500 ticks < -6"); `all`, `any` and
## `not` combine them. Trees are plain data, never parsed text: no
## expression language to validate and nothing in data can call code.
## Treat as read-only after parsing.

const ALL := &"all"
const ANY := &"any"
const NOT := &"not"
const COMPARE := &"compare"
const OPERATORS: Array[String] = ["<", "<=", ">", ">="]
## Longest history a condition may ask for (ticks).
const MAX_WINDOW := 10000

var kind: StringName
var children: Array[EventCondition] = []
var measure: StringName
var param: StringName
var window := 0
var operator: String
var threshold: float


## Reports every problem in `raw` to `result`; returns null if any.
static func parse(raw: Variant, schema: ParameterSchema, label: String, result: SimResult) -> EventCondition:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("%s: a condition must be an object" % label)
		return null
	var data: Dictionary = raw
	var node := EventCondition.new()
	if data.has("all") or data.has("any"):
		node.kind = ALL if data.has("all") else ANY
		var list: Variant = data[String(node.kind)]
		if data.size() != 1 or typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
			result.add_error("%s: '%s' must be the only key and hold a non-empty list" % [label, node.kind])
			return null
		var ok := true
		for i in (list as Array).size():
			var child := parse(list[i], schema, "%s.%s[%d]" % [label, node.kind, i], result)
			ok = ok and child != null
			node.children.append(child)
		return node if ok else null
	if data.has("not"):
		if data.size() != 1:
			result.add_error("%s: 'not' must be the only key" % label)
			return null
		node.kind = NOT
		var child := parse(data["not"], schema, label + ".not", result)
		if child == null:
			return null
		node.children.append(child)
		return node
	return _parse_compare(data, schema, label, result)


static func _parse_compare(data: Dictionary, schema: ParameterSchema, label: String, result: SimResult) -> EventCondition:
	var errors_before := result.errors.size()
	var node := EventCondition.new()
	node.kind = COMPARE
	var measure_value: Variant = data.get("measure")
	if typeof(measure_value) != TYPE_STRING or not ParamHistory.MEASURES.has(StringName(measure_value)):
		result.add_error("%s: 'measure' must be one of %s (or use all/any/not)" % [label, ParamHistory.MEASURES])
	else:
		node.measure = StringName(measure_value)
	var param_value: Variant = data.get("param")
	if typeof(param_value) != TYPE_STRING or schema.index_of(StringName(param_value)) == -1:
		result.add_error("%s: unknown parameter '%s'" % [label, param_value])
	else:
		node.param = StringName(param_value)
	if node.measure == ParamHistory.VALUE:
		if data.has("window"):
			result.add_error("%s: measure 'value' takes no window" % label)
	elif not node.measure.is_empty():
		var window_value: Variant = data.get("window")
		if not is_whole(window_value) or int(window_value) < 1 or int(window_value) > MAX_WINDOW:
			result.add_error("%s: 'window' must be a whole number of ticks in 1..%d" % [label, MAX_WINDOW])
		else:
			node.window = int(window_value)
	var operator_value: Variant = data.get("op")
	if typeof(operator_value) != TYPE_STRING or not OPERATORS.has(operator_value):
		result.add_error("%s: 'op' must be one of %s" % [label, OPERATORS])
	else:
		node.operator = operator_value
	var threshold_value: Variant = data.get("value")
	if (typeof(threshold_value) != TYPE_FLOAT and typeof(threshold_value) != TYPE_INT) or not is_finite(float(threshold_value)):
		result.add_error("%s: 'value' must be a finite number" % label)
	else:
		node.threshold = float(threshold_value)
	for key: Variant in data:
		if not key in ["measure", "param", "window", "op", "value"]:
			result.add_error("%s: unknown key '%s'" % [label, key])
	return node if result.errors.size() == errors_before else null


## Whole number as JSON gives it (JSON numbers arrive as floats).
static func is_whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and float(value) == floorf(value)


func is_met(history: ParamHistory) -> bool:
	match kind:
		ALL:
			for child in children:
				if not child.is_met(history):
					return false
			return true
		ANY:
			for child in children:
				if child.is_met(history):
					return true
			return false
		NOT:
			return not children[0].is_met(history)
	return _compare(history.measure(measure, param, window))


func _compare(measured: float) -> bool:
	match operator:
		"<":
			return measured < threshold
		"<=":
			return measured <= threshold
		">":
			return measured > threshold
	return measured >= threshold


## Adds this tree's history needs to `needs` (parameter id -> samples).
func collect_needs(needs: Dictionary) -> void:
	if kind != COMPARE:
		for child in children:
			child.collect_needs(needs)
		return
	needs[param] = maxi(int(needs.get(param, 0)), ParamHistory.samples_needed(measure, window))


## Every leaf with its measured value: the readable cause of a transition.
func describe(history: ParamHistory) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	if kind != COMPARE:
		for child in children:
			facts.append_array(child.describe(history))
		return facts
	var measured := history.measure(measure, param, window)
	facts.append({"param": String(param), "measure": String(measure), "window": window,
			"measured": measured, "op": operator, "threshold": threshold, "met": _compare(measured)})
	return facts
