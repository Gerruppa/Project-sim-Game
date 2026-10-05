class_name PlanetChronicle
extends RunObserver
## The story of a run in plain sentences: only what happened to the planet,
## never per-tick numbers. A 15 000 tick run is a few dozen lines instead of
## the full log's ~120 000, so the observer can read it without tools
## (CORE_LOOP.md, stage Observe).
##
## Events carrying a "story" sentence (world events) are written with their
## measured causes; other event types are written only if the vocabulary
## has a sentence for them. Everything else is left out on purpose.

var _sinks: Array[LogSink]
var _texts: ChronicleTexts
var _schema: ParameterSchema


func _init(sinks: Array[LogSink], texts: ChronicleTexts) -> void:
	_sinks = sinks.duplicate()
	_texts = texts


func attach(bus: EventBus) -> void:
	bus.subscribe_all(_on_event)


func begin_run(seed_value: int, initial: PlanetSnapshot) -> void:
	_schema = initial.schema()
	var resumed := "" if initial.tick() == 0 else " | wznowiona od ticku %d" % initial.tick()
	_write("# Kronika planety | seed %d%s" % [seed_value, resumed])


func close() -> void:
	for sink in _sinks:
		sink.close()


func _on_event(event: SimEvent) -> void:
	var sentence := ""
	if typeof(event.data.get("story")) == TYPE_STRING:
		sentence = event.data["story"]
		var causes: Variant = event.data.get("causes")
		if typeof(causes) == TYPE_ARRAY and not (causes as Array).is_empty():
			sentence += " (%s)" % "; ".join(PackedStringArray((causes as Array).map(_phrase)))
	elif _texts.events.has(String(event.type)):
		sentence = _texts.events[String(event.type)].format(_fields(event.data))
	else:
		return
	_write("[Tick %d] %s" % [event.tick, sentence])


## Event data as text; species ids become their names.
func _fields(data: Dictionary) -> Dictionary:
	var fields := {}
	for key: Variant in data:
		fields[key] = str(data[key])
	if fields.has("species"):
		fields["species"] = _texts.species.get(fields["species"], fields["species"])
	return fields


func _phrase(fact: Dictionary) -> String:
	var measured: float = fact["measured"]
	var template: Variant = _texts.measures[fact["measure"]]
	if typeof(template) == TYPE_DICTIONARY:
		template = template["below"] if measured < 0.0 else template["above"]
	return (template as String).format({
		"param": _param_name(fact["param"]),
		"value": _number(measured),
		"abs": _number(absf(measured)),
		"percent": str(roundi(measured * 100.0)),
		"window": str(fact["window"]),
	})


func _param_name(id: String) -> String:
	if _schema != null and _schema.def_of(StringName(id)) != null:
		return _schema.def_of(StringName(id)).display_name()
	return id


## One decimal with a decimal comma: the chronicle is written for people.
static func _number(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")


func _write(line: String) -> void:
	for sink in _sinks:
		sink.write_line(line)
