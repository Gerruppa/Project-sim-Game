class_name HintAdvisor
extends RefCounted
## Advice for the player at a decision point, like a tutorial that never
## ends: why it happened, what could help and what the next stage of life
## still lacks. Presentation only; it reads the planet and changes nothing.
##
## Texts live in resources/chronicle/hints.json. Advice about actions comes
## from measurements (docs/gameplay.md); the succession hint is computed from
## species data, so a new species needs no new text.

const DEFAULT_PATH := "res://resources/chronicle/hints.json"
const NEEDS: Array[String] = ["warmth", "cooling", "humidity", "precipitation", "co2", "oxygen", "soil"]

## The parameter each kind of need is measured in.
const NEED_PARAMS := {"warmth": "temperature", "cooling": "temperature", "humidity": "humidity",
		"precipitation": "precipitation", "co2": "co2", "oxygen": "oxygen", "soil": "biomass"}

var intro := PackedStringArray()
## The player's units for the numbers in advice; unset, the plain 0-100 values.
var scale: DisplayScale
var _quiet := ""
var _acts_line := ""
## id -> {"text", "acts"}
var _causes: Dictionary[String, Dictionary] = {}
var _events: Dictionary[String, Dictionary] = {}
## "next", "ready", "lost_ready"
var _succession: Dictionary[String, String] = {}
var _needs: Dictionary[String, String] = {}


static func load_json(path: String = DEFAULT_PATH) -> SimResult:
	var read := CoefficientLoader.read_json(path, "hints")
	return from_data(read.value) if read.is_ok() else read


## Reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	var result := SimResult.new()
	var advisor := HintAdvisor.new()
	var raw_intro: Variant = data.get("intro")
	if typeof(raw_intro) != TYPE_ARRAY or not (raw_intro as Array).all(func(l: Variant) -> bool: return typeof(l) == TYPE_STRING):
		result.add_error("hints: 'intro' must be a list of lines")
	else:
		advisor.intro = PackedStringArray(raw_intro)
	for key: String in ["quiet", "acts_line"]:
		if not _is_text(data.get(key)):
			result.add_error("hints: '%s' must be a non-empty string" % key)
	advisor._quiet = str(data.get("quiet", ""))
	advisor._acts_line = str(data.get("acts_line", ""))
	_read_advice(data.get("causes"), "causes", advisor._causes, result)
	_read_advice(data.get("events"), "events", advisor._events, result)
	_read_texts(data.get("succession"), "succession", ["next", "ready", "lost_ready"], advisor._succession, result)
	_read_texts(data.get("needs"), "needs", NEEDS, advisor._needs, result)
	if result.is_ok():
		result.value = advisor
	return result


static func _read_advice(raw: Variant, key: String, into: Dictionary[String, Dictionary], result: SimResult) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("hints: '%s' must be an object" % key)
		return
	for id: Variant in raw:
		var entry: Variant = raw[id]
		if typeof(entry) != TYPE_DICTIONARY or not _is_text(entry.get("text")) or typeof(entry.get("acts")) != TYPE_ARRAY \
				or not (entry["acts"] as Array).all(func(a: Variant) -> bool: return _is_text(a)):
			result.add_error("hints: %s '%s' needs 'text' and an 'acts' list" % [key, id])
		else:
			into[String(id)] = entry


static func _read_texts(raw: Variant, key: String, needed: Array, into: Dictionary[String, String], result: SimResult) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("hints: '%s' must be an object" % key)
		return
	for id: String in needed:
		if not _is_text(raw.get(id)):
			result.add_error("hints: %s '%s' must be a non-empty string" % [key, id])
		else:
			into[id] = raw[id]


static func _is_text(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not (value as String).is_empty()


## Every intervention named in the advice, for checking against the catalog.
func advised_acts() -> PackedStringArray:
	var acts := PackedStringArray()
	for table: Dictionary in [_causes, _events]:
		for id: Variant in table:
			for act: String in table[id]["acts"]:
				if not acts.has(act):
					acts.append(act)
	return acts


## point: the event that stopped the run (null for a quiet checkpoint).
## names: species id -> name for the player. act_label: Callable(act text)
## -> how the player selects it ("3 (Lustra orbitalne, lekko)").
func hints(point: SimEvent, snapshot: PlanetSnapshot, biosphere: BiosphereSystem, names: Dictionary,
		act_label: Callable) -> PackedStringArray:
	var lines := PackedStringArray()
	if point != null:
		var advice := {}
		if point.type == &"species_extinct":
			advice = _causes.get(str(point.data.get("cause")), {})
		elif point.type == &"world_event_started":
			advice = _events.get(str(point.data.get("id")), {})
		if not advice.is_empty():
			var species: String = names.get(str(point.data.get("species", "")), str(point.data.get("species", "")))
			lines.append((advice["text"] as String).format({"species": _first_upper(species)}))
			if not (advice["acts"] as Array).is_empty():
				var labels := PackedStringArray((advice["acts"] as Array).map(func(a: String) -> String: return str(act_label.call(a))))
				lines.append(_acts_line.format({"acts": ", ".join(labels)}))
	if biosphere != null:
		var stage := _succession_hint(snapshot, biosphere, names)
		if not stage.is_empty():
			lines.append(stage)
	if lines.is_empty():
		lines.append(_quiet)
	return lines


## The first species that is not present while its precursor is: what the
## planet still lacks for it, or that it could come now.
func _succession_hint(snapshot: PlanetSnapshot, biosphere: BiosphereSystem, names: Dictionary) -> String:
	var present := biosphere.established_population()
	for species in biosphere.species_list():
		if biosphere.population(species.id) >= present:
			continue
		if not species.emerges_from.is_empty() and biosphere.population(species.emerges_from) < present:
			continue
		var name: String = names.get(String(species.id), String(species.id))
		var missing := missing_needs(species, snapshot)
		if missing.is_empty():
			var key := "lost_ready" if biosphere.is_lost(species.id) else "ready"
			return _succession[key].format({"species": _first_upper(name)})
		return _succession["next"].format({"species": name, "missing": ", ".join(missing)})
	return ""


## What the species lacks on this planet now, in the player's words (empty = nothing).
func missing_needs(species: SpeciesData, snapshot: PlanetSnapshot) -> PackedStringArray:
	var missing := PackedStringArray()
	var t := snapshot.get_value(Param.TEMPERATURE)
	if t < species.t_min:
		missing.append(_need("warmth", t, species.t_min))
	elif t > species.t_max:
		missing.append(_need("cooling", t, species.t_max))
	var water := snapshot.get_value(species.water)
	if water < species.water_min:
		missing.append(_need(String(species.water), water, species.water_min))
	for check: Array in [["co2", Param.CO2, species.co2_need], ["oxygen", Param.OXYGEN, species.o2_need],
			["soil", Param.BIOMASS, species.biomass_need]]:
		var value := snapshot.get_value(check[1])
		if value < check[2]:
			missing.append(_need(check[0], value, check[2]))
	return missing


func _need(key: String, value: float, need: float) -> String:
	var param: String = NEED_PARAMS[key]
	if scale != null and scale.has_parameter(param):
		return _needs[key].format({"value": scale.shown(param, value), "need": scale.shown(param, need)})
	return _needs[key].format({"value": "%.1f" % value, "need": "%.0f" % need})


static func _first_upper(text: String) -> String:
	return text if text.is_empty() else text.substr(0, 1).to_upper() + text.substr(1)
