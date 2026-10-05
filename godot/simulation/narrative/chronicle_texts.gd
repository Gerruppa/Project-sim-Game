class_name ChronicleTexts
extends RefCounted
## Vocabulary of the planet chronicle, loaded from JSON: species names,
## sentences for system events, causes of extinction and phrases for
## condition measures.
##
## Presentation only; nothing here reaches the simulation. Parameter names
## come from the schema (display_name) and world event sentences from the
## event definitions, so no name is stored twice.

const DEFAULT_PATH := "res://resources/chronicle/chronicle.json"
## Measures phrased by sign: "below" for negative values, "above" otherwise.
const SIGNED := ["below", "above"]

## species id -> name
var species: Dictionary[String, String] = {}
## event type -> sentence with {field} placeholders from the event data
var events: Dictionary[String, String] = {}
## loss cause id (BiosphereSystem.LOSS_CAUSES) -> phrase for {cause}
var causes: Dictionary[String, String] = {}
## measure -> phrase (String) or {"below", "above"} phrases
var measures: Dictionary[String, Variant] = {}


static func load_json(path: String) -> SimResult:
	var read := CoefficientLoader.read_json(path, "chronicle")
	return from_data(read.value) if read.is_ok() else read


## Reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	var result := SimResult.new()
	var texts := ChronicleTexts.new()
	_read_strings(data.get("species"), "species", texts.species, result)
	_read_strings(data.get("events"), "events", texts.events, result)
	_read_strings(data.get("causes"), "causes", texts.causes, result)
	var raw_measures: Variant = data.get("measures")
	if typeof(raw_measures) != TYPE_DICTIONARY:
		result.add_error("chronicle: 'measures' must be an object")
	else:
		for measure in ParamHistory.MEASURES:
			var phrase: Variant = (raw_measures as Dictionary).get(String(measure))
			if _is_text(phrase) or (typeof(phrase) == TYPE_DICTIONARY and (phrase as Dictionary).size() == 2
					and _is_text(phrase.get("below")) and _is_text(phrase.get("above"))):
				texts.measures[String(measure)] = phrase
			else:
				result.add_error("chronicle: measure '%s' needs a phrase or {\"below\", \"above\"} phrases" % measure)
	if result.is_ok():
		result.value = texts
	return result


static func _read_strings(raw: Variant, key: String, into: Dictionary[String, String], result: SimResult) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("chronicle: '%s' must be an object of strings" % key)
		return
	for id: Variant in raw:
		if not _is_text(raw[id]):
			result.add_error("chronicle: %s '%s' must be a non-empty string" % [key, id])
		else:
			into[String(id)] = raw[id]


static func _is_text(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not (value as String).is_empty()
