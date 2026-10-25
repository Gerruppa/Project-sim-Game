class_name SpeciesGuide
extends RefCounted
## "When do I plant what?": for each species, how well the planet suits it
## right now (ideal, good, weak, too early, waiting for another species), what
## is missing and what the species likes, in the player's words and units.
## Presentation only: it reads the planet and changes nothing.
##
## The verdict follows the same fit the biosphere grows by
## (BiosphereSystem.fit_of), cut at the thresholds in
## resources/guide/guide.json (a readability choice, not a simulation rule).

const DEFAULT_PATH := "res://resources/guide/guide.json"
const VERDICTS: Array[String] = ["ideal", "ok", "weak", "blocked", "waiting"]
const CAUSES: Array[String] = ["heat", "cold", "drought", "co2_starvation", "oxygen_lack", "poor_soil"]
const NEEDS: Array[String] = ["temperature", "water", "co2", "oxygen", "soil"]
const RANGES: Array[String] = ["between", "at_least", "at_most"]
## A need with a high limit at the top of the scale reads as "at least".
const TOP := 100.0

var _ideal := 0.8
var _ok := 0.4
var _blocked_below := 0.02
var _labels: Dictionary[String, String] = {}
var _short: Dictionary[String, String] = {}
var _why: Dictionary[String, String] = {}
var _needs: Dictionary[String, String] = {}
var _range: Dictionary[String, String] = {}


static func load_json(path: String = DEFAULT_PATH) -> SimResult:
	var read := CoefficientLoader.read_json(path, "guide")
	return from_data(read.value) if read.is_ok() else read


## Reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	var result := SimResult.new()
	var guide := SpeciesGuide.new()
	var thresholds: Variant = data.get("thresholds")
	if typeof(thresholds) != TYPE_DICTIONARY or not _is_fraction(thresholds.get("ideal")) \
			or not _is_fraction(thresholds.get("ok")) or not _is_fraction(thresholds.get("blocked_below")) \
			or not (float(thresholds["blocked_below"]) < float(thresholds["ok"]) and float(thresholds["ok"]) < float(thresholds["ideal"])):
		result.add_error("guide: 'thresholds' needs blocked_below < ok < ideal, each in 0..1")
	else:
		guide._ideal = float(thresholds["ideal"])
		guide._ok = float(thresholds["ok"])
		guide._blocked_below = float(thresholds["blocked_below"])
	_read_texts(data.get("labels"), "labels", VERDICTS, guide._labels, result)
	_read_texts(data.get("short"), "short", VERDICTS, guide._short, result)
	_read_texts(data.get("why"), "why", CAUSES, guide._why, result)
	_read_texts(data.get("needs"), "needs", NEEDS, guide._needs, result)
	_read_texts(data.get("range"), "range", RANGES, guide._range, result)
	if result.is_ok():
		result.value = guide
	return result


static func _is_fraction(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) >= 0.0 and float(value) <= 1.0


static func _read_texts(raw: Variant, key: String, needed: Array[String], into: Dictionary[String, String], result: SimResult) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("guide: '%s' must be an object" % key)
		return
	for id in needed:
		var text: Variant = (raw as Dictionary).get(id)
		if typeof(text) != TYPE_STRING or (text as String).is_empty():
			result.add_error("guide: %s '%s' must be a non-empty string" % [key, id])
		else:
			into[id] = text


## One species: {"id", "name", "verdict" (StringName of VERDICTS), "label",
## "short", "fit" (0..1), "alive", "why" (what is missing, "" when nothing),
## "needs": [{"name", "range", "now", "state" (good|poor|bad)}]}.
## names: species id -> the player's word for it.
func guide(species: SpeciesData, snapshot: PlanetSnapshot, biosphere: BiosphereSystem, scale: DisplayScale,
		names: Dictionary) -> Dictionary:
	var present := biosphere.established_population()
	var alive := biosphere.population(species.id) >= present
	var fit := biosphere.fit_of(species.id, snapshot)
	var verdict := &"ideal"
	var why := ""
	var precursor := String(species.emerges_from)
	if not alive and not precursor.is_empty() and biosphere.population(species.emerges_from) < present:
		verdict = &"waiting"
		why = "waiting for %s" % names.get(precursor, precursor)
	elif fit < _blocked_below:
		verdict = &"blocked"
	elif fit < _ok:
		verdict = &"weak"
	elif fit < _ideal:
		verdict = &"ok"
	if verdict == &"blocked" or verdict == &"weak":
		why = _why[String(species.limiting_factor(snapshot, biosphere.tolerance().x, biosphere.tolerance().y, biosphere.tolerance().z))]
	var label := _labels[String(verdict)].format({"why": why, "precursor": names.get(precursor, precursor)})
	return {"id": String(species.id), "name": names.get(String(species.id), String(species.id)), "verdict": verdict,
			"label": label, "short": _short[String(verdict)], "fit": fit, "alive": alive, "why": why,
			"needs": _need_rows(species, snapshot, scale, biosphere.tolerance())}


## The things the species needs, each with where it lives well, the value now
## and whether that value suits it.
func _need_rows(species: SpeciesData, snapshot: PlanetSnapshot, scale: DisplayScale, tolerance: Vector3) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for pair: Array in [["temperature", Param.TEMPERATURE], ["water", species.water], ["co2", Param.CO2],
			["oxygen", Param.OXYGEN], ["soil", Param.BIOMASS]]:
		var param: StringName = pair[1]
		var limits := LifeZones.limits_of(param, species, tolerance)
		if limits.is_empty():
			continue
		var value := snapshot.get_value(param)
		rows.append({"name": _needs[pair[0]], "range": _range_text(String(param), limits, scale),
				"now": scale.shown(String(param), value), "state": String(LifeZones.state_of(param, value, species, tolerance))})
	return rows


func _range_text(param: String, limits: Array[float], scale: DisplayScale) -> String:
	var low := scale.shown(param, limits[0])
	var high := scale.shown(param, limits[1])
	if limits[1] >= TOP:
		return _range["at_least"].format({"low": low})
	if limits[0] <= 0.0:
		return _range["at_most"].format({"high": high})
	return _range["between"].format({"low": low, "high": high})
