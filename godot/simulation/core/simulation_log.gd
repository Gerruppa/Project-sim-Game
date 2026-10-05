class_name SimulationLog
extends RunObserver
## Writes every tick as human-readable text and as JSON Lines.
##
## Text is for reading runs; JSON Lines (one JSON object per line) is for
## tools such as balance analysis. Both are produced from the same events,
## so they always describe the same run. Logs are part of gameplay design:
## every change carries its causes.

const VALUE_FORMAT := "%.3f"
const DELTA_FORMAT := "%+.3f"
## Causes smaller than this print as +0.000; the text log folds them into a
## count to stay readable. JSON Lines always keeps every delta.
const NEGLIGIBLE := 0.0005

var _text_sinks: Array[LogSink]
var _jsonl_sinks: Array[LogSink]
var _include_deltas: bool


func _init(text_sinks: Array[LogSink], jsonl_sinks: Array[LogSink], include_deltas: bool) -> void:
	_text_sinks = text_sinks.duplicate()
	_jsonl_sinks = jsonl_sinks.duplicate()
	_include_deltas = include_deltas


func attach(bus: EventBus) -> void:
	bus.subscribe_all(_on_event)


func begin_run(seed_value: int, initial: PlanetSnapshot) -> void:
	var schema := initial.schema()
	var parts := PackedStringArray()
	var values := {}
	for i in schema.size():
		var id := String(schema.def_at(i).id())
		parts.append("%s=%s" % [id, VALUE_FORMAT % initial.get_value_at(i)])
		values[id] = initial.get_value_at(i)
	var engine: String = Engine.get_version_info()["string"]

	_text("# Genesis Error simulation log")
	_text("# seed: %d | engine: %s | schema: v%d" % [seed_value, engine, schema.version()])
	_text("[Tick %d] initial %s" % [initial.tick(), " ".join(parts)])
	_json({
		"record": "run_start",
		"seed": seed_value,
		"engine": engine,
		"schema_version": schema.version(),
		"parameters": Array(schema.ids()).map(func(id: StringName) -> String: return String(id)),
		"initial": values,
	})


func close() -> void:
	for sink in _text_sinks + _jsonl_sinks:
		sink.close()


func _on_event(event: SimEvent) -> void:
	match event.type:
		SimEvent.TICK_APPLIED:
			_log_tick(event.tick, event.data["report"])
		SimEvent.BATCH_REJECTED:
			_log_rejected(event.tick, event.data["report"])
		_:
			_log_generic(event)


func _log_tick(tick: int, report: ApplyReport) -> void:
	var records: Array[Dictionary] = []
	if report.changes.is_empty():
		_text("[Tick %d] no changes" % tick)
	for change in report.changes:
		var deltas := report.applied_deltas.filter(
				func(delta: Delta) -> bool: return delta.parameter == change.parameter)
		_text(_change_line(tick, change, deltas))
		records.append(_change_record(change, deltas))
	_json({"record": "tick", "tick": tick, "changes": records})


func _change_line(tick: int, change: ApplyReport.ParameterChange, deltas: Array) -> String:
	var line := "[Tick %d] %s %s -> %s (%s)" % [tick, change.parameter,
			VALUE_FORMAT % change.old_value, VALUE_FORMAT % change.new_value,
			DELTA_FORMAT % (change.new_value - change.old_value)]
	if _include_deltas and not deltas.is_empty():
		var causes := PackedStringArray()
		var negligible := 0
		for delta: Delta in deltas:
			if absf(delta.amount) < NEGLIGIBLE:
				negligible += 1
				continue
			causes.append("%s:%s %s" % [delta.source, delta.cause, DELTA_FORMAT % delta.amount])
		if negligible > 0:
			causes.append("+%d negligible" % negligible)
		line += " [%s]" % ", ".join(causes)
	if change.saturated:
		line += " SATURATED (requested %s)" % (VALUE_FORMAT % change.requested_value)
	return line


func _change_record(change: ApplyReport.ParameterChange, deltas: Array) -> Dictionary:
	var record := {
		"parameter": String(change.parameter),
		"old": change.old_value,
		"new": change.new_value,
		"requested": change.requested_value,
		"saturated": change.saturated,
	}
	if _include_deltas:
		record["deltas"] = deltas.map(func(delta: Delta) -> Dictionary:
			return {"source": String(delta.source), "cause": String(delta.cause), "amount": delta.amount})
	return record


func _log_rejected(tick: int, report: ApplyReport) -> void:
	for error in report.errors:
		_text("[Tick %d] REJECTED %s" % [tick, error])
	_json({"record": "rejected", "tick": tick, "errors": Array(report.errors)})


## Events that carry a readable "summary" print it instead of raw data;
## JSON Lines always keep the full data.
func _log_generic(event: SimEvent) -> void:
	if typeof(event.data.get("summary")) == TYPE_STRING:
		_text("[Tick %d] EVENT %s from %s: %s" % [event.tick, event.type, event.source, event.data["summary"]])
	else:
		_text("[Tick %d] EVENT %s from %s %s" % [event.tick, event.type, event.source, _stringify(event.data)])
	_json({"record": "event", "tick": event.tick, "type": String(event.type),
			"source": String(event.source), "data": event.data})


func _text(line: String) -> void:
	for sink in _text_sinks:
		sink.write_line(line)


func _json(record: Dictionary) -> void:
	var line := _stringify(record)
	for sink in _jsonl_sinks:
		sink.write_line(line)


## Sorted keys and full precision: identical runs give identical bytes.
static func _stringify(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)
