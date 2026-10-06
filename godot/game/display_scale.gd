class_name DisplayScale
extends RefCounted
## How the player reads the planet's numbers. The simulation keeps every
## parameter on one normalized 0-100 scale (docs/architecture.md); this class
## only translates it into what the numbers mean on a real planet: the mean
## temperature in °C, rainfall in mm a year and so on. Presentation only:
## nothing here reaches the simulation, saves or logs.
##
## Each parameter maps through anchor points [[value, shown], ...]: every
## threshold the game reacts to sits where the same thing happens on Earth (an
## ice age starts at 16, shown as 0 °C; fires start at oxygen 22, shown as
## 16 %), linear between the anchors and increasing everywhere. A step of the
## same size is therefore not the same shown change everywhere. Parameters
## missing from the file stay on 0-100. Also holds how long an action's effect
## stays worth watching (measured with tests/tools/intervention_trace.gd,
## docs/gameplay.md). Data: resources/display/display.json.

const DEFAULT_PATH := "res://resources/display/display.json"
## Measures of ParamHistory that are levels (they convert like a value); the
## others (change, range, anomaly) are differences.
const LEVEL_MEASURES: Array[String] = ["value", "mean", "min", "max"]

## parameter id -> {"label": String ("" = the schema name), "unit": String,
## "decimals": int, "points": PackedFloat64Array pairs (value, shown, ...)}
var _parameters: Dictionary[String, Dictionary] = {}
## action id -> [first, last] ticks after the action in which its effect shows
var _effect_ticks: Dictionary[String, Array] = {}


static func load_json(path: String, parameter_ids: Array[StringName], action_ids: Array[StringName]) -> SimResult:
	var read := CoefficientLoader.read_json(path, "display")
	return from_data(read.value, parameter_ids, action_ids) if read.is_ok() else read


## Reports all errors at once. Names must exist: a typo is a load error, not a
## parameter that silently stays on 0-100.
static func from_data(data: Dictionary, parameter_ids: Array[StringName], action_ids: Array[StringName]) -> SimResult:
	var result := SimResult.new()
	var scale := DisplayScale.new()
	var parameters: Variant = data.get("parameters")
	if typeof(parameters) != TYPE_DICTIONARY:
		result.add_error("display: 'parameters' must be an object")
	else:
		for id: Variant in parameters:
			scale._read_parameter(String(id), parameters[id], parameter_ids, result)
	var actions: Variant = data.get("actions", {})
	if typeof(actions) != TYPE_DICTIONARY:
		result.add_error("display: 'actions' must be an object")
	else:
		for id: Variant in actions:
			scale._read_action(String(id), actions[id], action_ids, result)
	if result.is_ok():
		result.value = scale
	return result


func _read_parameter(id: String, raw: Variant, known: Array[StringName], result: SimResult) -> void:
	var label := "display parameter '%s'" % id
	if not known.has(StringName(id)):
		result.add_error("%s: not a parameter of the planet; known: %s" % [label, ", ".join(PackedStringArray(known.map(func(k: StringName) -> String: return String(k))))])
		return
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("%s: must be an object" % label)
		return
	var decimals: Variant = raw.get("decimals")
	var ok := true
	if typeof(raw.get("unit")) != TYPE_STRING or (raw["unit"] as String).is_empty():
		result.add_error("%s: 'unit' must be a non-empty string" % label)
		ok = false
	if typeof(raw.get("label", "")) != TYPE_STRING:
		result.add_error("%s: 'label' must be a string" % label)
		ok = false
	if not (typeof(decimals) in [TYPE_INT, TYPE_FLOAT]) or float(decimals) != floorf(float(decimals)) or float(decimals) < 0.0 or float(decimals) > 3.0:
		result.add_error("%s: 'decimals' must be a whole number 0..3" % label)
		ok = false
	var points := _read_points(raw.get("points"))
	if points.is_empty():
		result.add_error("%s: 'points' must be [[value, shown], ...]: at least two, both increasing, from 0 to 100" % label)
		ok = false
	if ok:
		_parameters[id] = {"label": raw.get("label", ""), "unit": raw["unit"], "decimals": int(decimals), "points": points}


## Flat (value, shown, value, shown, ...) or empty when the anchors are not
## usable: fewer than two, not increasing in both, or not spanning 0..100.
static func _read_points(raw: Variant) -> PackedFloat64Array:
	var flat := PackedFloat64Array()
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 2:
		return flat
	for pair: Variant in raw:
		if typeof(pair) != TYPE_ARRAY or (pair as Array).size() != 2 \
				or not (pair as Array).all(func(n: Variant) -> bool: return typeof(n) in [TYPE_INT, TYPE_FLOAT]):
			return PackedFloat64Array()
		if not flat.is_empty() and (float(pair[0]) <= flat[-2] or float(pair[1]) <= flat[-1]):
			return PackedFloat64Array()
		flat.append(float(pair[0]))
		flat.append(float(pair[1]))
	if flat[0] != 0.0 or flat[-2] != 100.0:
		return PackedFloat64Array()
	return flat


func _read_action(id: String, raw: Variant, known: Array[StringName], result: SimResult) -> void:
	var label := "display action '%s'" % id
	if not known.has(StringName(id)):
		result.add_error("%s: not an intervention; known: %s" % [label, ", ".join(PackedStringArray(known.map(func(k: StringName) -> String: return String(k))))])
		return
	var span: Variant = raw.get("effect_ticks") if typeof(raw) == TYPE_DICTIONARY else null
	if typeof(span) != TYPE_ARRAY or (span as Array).size() != 2 \
			or not (span as Array).all(func(t: Variant) -> bool: return typeof(t) in [TYPE_INT, TYPE_FLOAT] and float(t) >= 0.0 and float(t) == floorf(float(t))) \
			or float(span[0]) > float(span[1]):
		result.add_error("%s: 'effect_ticks' must be [first, last] ticks, first <= last" % label)
		return
	_effect_ticks[id] = [int(span[0]), int(span[1])]


func has_parameter(id: String) -> bool:
	return _parameters.has(id)


## The planet value in the player's units (unchanged without a mapping).
## Outside 0..100 the nearest segment continues.
func to_display(id: String, value: float) -> float:
	if not _parameters.has(id):
		return value
	var points: PackedFloat64Array = _parameters[id]["points"]
	var segment := 0
	while segment + 4 < points.size() and value > points[segment + 2]:
		segment += 2
	var x0 := points[segment]
	var y0 := points[segment + 1]
	var x1 := points[segment + 2]
	var y1 := points[segment + 3]
	return y0 + (value - x0) * (y1 - y0) / (x1 - x0)


## The shown change between two planet values: exact on every scale.
func change(id: String, from_value: float, to_value: float) -> float:
	return to_display(id, to_value) - to_display(id, from_value)


## A difference of `delta` points measured around the value `around`, in the
## player's units: the change across a span of that size centred there. Exact
## inside one segment, an estimate across anchors (the chronicle knows only
## the difference, not where it started).
func difference(id: String, delta: float, around: float) -> float:
	return change(id, around - delta * 0.5, around + delta * 0.5)


## The name the player sees ("Średnia temperatura"), or `fallback`.
func label(id: String, fallback: String) -> String:
	var own: String = _parameters[id]["label"] if _parameters.has(id) else ""
	return fallback if own.is_empty() else own


func unit(id: String) -> String:
	return _parameters[id]["unit"] if _parameters.has(id) else ""


func decimals(id: String) -> int:
	return _parameters[id]["decimals"] if _parameters.has(id) else 1


## "12.4 °C"; "37.5" for a parameter without a mapping.
func shown(id: String, value: float) -> String:
	return _with_unit(id, ("%." + str(decimals(id)) + "f") % to_display(id, value))


## A number as the chronicle writes it: decimal comma, unit included. `measure`
## says whether the number is a level or a difference (see LEVEL_MEASURES);
## a difference converts around the parameter's current value `around`.
func chronicle_number(id: String, measure: String, value: float, around: float) -> String:
	var number := to_display(id, value) if LEVEL_MEASURES.has(measure) else difference(id, value, around)
	return _with_unit(id, (("%." + str(decimals(id)) + "f") % number).replace(".", ","))


func _with_unit(id: String, number: String) -> String:
	return number if not _parameters.has(id) else number + " " + unit(id)


## [first, last] ticks after the action in which its effect shows, or [] when
## it was never measured.
func effect_ticks(action_id: String) -> Array:
	return _effect_ticks.get(action_id, [])
