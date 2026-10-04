class_name ParamHistory
extends RefCounted
## Recent values of the parameters that event conditions look at.
##
## One ring buffer per tracked parameter, sized by the longest window that
## reads it. Measures always fold the window oldest -> newest and never keep
## running sums: float addition is not associative, so a running sum would
## depend on how long the history is and a restored run would drift away
## from a continuous one.

const FORMAT := "param_history"

const VALUE := &"value"
const CHANGE := &"change"
const MEAN := &"mean"
const MIN := &"min"
const MAX := &"max"
const RANGE := &"range"
const ANOMALY := &"anomaly"
const DROP_FROM_PEAK := &"drop_from_peak"
const MEASURES: Array[StringName] = [VALUE, CHANGE, MEAN, MIN, MAX, RANGE, ANOMALY, DROP_FROM_PEAK]

## Tracked ids in a fixed (sorted) order.
var _ids: Array[StringName] = []
var _capacity: Dictionary[StringName, int] = {}
var _buffers: Dictionary[StringName, PackedFloat64Array] = {}
## Samples recorded since the start; every buffer records together, so
## each buffer's write position is _recorded % capacity.
var _recorded := 0
## Window folds of the newest sample ("id:window:fold" -> value). Events
## share windows (max and drop_from_peak, trigger and end), so each fold
## runs once per tick. Cleared by record(); never saved.
var _folds: Dictionary[String, float] = {}


## capacities: parameter id -> number of samples to keep (>= 1).
func _init(capacities: Dictionary) -> void:
	var names: Array[String] = []
	for id: StringName in capacities:
		names.append(String(id))
	names.sort()
	for name in names:
		var id := StringName(name)
		_ids.append(id)
		_capacity[id] = maxi(int(capacities[id]), 1)
		var buffer := PackedFloat64Array()
		buffer.resize(_capacity[id])
		_buffers[id] = buffer


## Samples one measure needs: `change` compares with the value `window`
## ticks ago, so it needs one more than the others.
static func samples_needed(measure: StringName, window: int) -> int:
	match measure:
		VALUE:
			return 1
		CHANGE:
			return window + 1
		_:
			return window


func ids() -> Array[StringName]:
	return _ids.duplicate()


func recorded() -> int:
	return _recorded


func record(snapshot: PlanetSnapshot) -> void:
	for id in _ids:
		_buffers[id][_recorded % _capacity[id]] = snapshot.get_value(id)
	_recorded += 1
	_folds.clear()


## Value `ticks_ago` samples back; 0 is the newest.
func ago(id: StringName, ticks_ago: int) -> float:
	return _buffers[id][(_recorded - 1 - ticks_ago) % _capacity[id]]


## The caller makes sure enough samples exist (samples_needed).
func measure(kind: StringName, id: StringName, window: int) -> float:
	var now := ago(id, 0)
	match kind:
		VALUE:
			return now
		CHANGE:
			return now - ago(id, window)
		MEAN:
			return _mean(id, window)
		MIN:
			return _extreme(id, window, false)
		MAX:
			return _extreme(id, window, true)
		RANGE:
			return _extreme(id, window, true) - _extreme(id, window, false)
		ANOMALY:
			return now - _mean(id, window)
		DROP_FROM_PEAK:
			var peak := _extreme(id, window, true)
			return 0.0 if peak <= 0.0 else (peak - now) / peak
	push_error("ParamHistory: unknown measure '%s'" % kind)
	return NAN


## The folds read the buffer directly, without a call or lookup per sample:
## over 500-tick windows they are most of EventSystem's cost. The order is
## still oldest -> newest, so results are the same bits as before.
func _mean(id: StringName, window: int) -> float:
	var key := "%s:%d:mean" % [id, window]
	if _folds.has(key):
		return _folds[key]
	var buffer: PackedFloat64Array = _buffers[id]
	var capacity: int = _capacity[id]
	var index := (_recorded - window) % capacity
	var sum := 0.0
	for _k in window:
		sum += buffer[index]
		index += 1
		if index == capacity:
			index = 0
	_folds[key] = sum / float(window)
	return _folds[key]


func _extreme(id: StringName, window: int, highest: bool) -> float:
	var key := "%s:%d:%s" % [id, window, "max" if highest else "min"]
	if _folds.has(key):
		return _folds[key]
	var buffer: PackedFloat64Array = _buffers[id]
	var capacity: int = _capacity[id]
	var index := (_recorded - window) % capacity
	var result := buffer[index]
	for _k in window - 1:
		index += 1
		if index == capacity:
			index = 0
		if highest:
			result = maxf(result, buffer[index])
		else:
			result = minf(result, buffer[index])
	_folds[key] = result
	return result


## Exact bytes of every buffer, oldest -> newest.
func to_dict() -> Dictionary:
	var values := {}
	for id in _ids:
		var ordered := PackedFloat64Array()
		for k in range(_available(id) - 1, -1, -1):
			ordered.append(ago(id, k))
		values[String(id)] = _encode(ordered)
	return {"format": FORMAT, "recorded": _recorded, "values_exact": values}


func load_dict(data: Dictionary) -> SimResult:
	if data.get("format") != FORMAT:
		return SimResult.failure("history: format must be '%s'" % FORMAT)
	var raw_recorded: Variant = data.get("recorded")
	if (typeof(raw_recorded) != TYPE_INT and typeof(raw_recorded) != TYPE_FLOAT) or float(raw_recorded) < 0.0:
		return SimResult.failure("history: 'recorded' must be a non-negative number")
	var raw_values: Variant = data.get("values_exact")
	if typeof(raw_values) != TYPE_DICTIONARY or (raw_values as Dictionary).size() != _ids.size():
		return SimResult.failure("history: 'values_exact' must hold exactly %s" % [_ids])
	var recorded_value := int(raw_recorded)
	var restored: Dictionary[StringName, PackedFloat64Array] = {}
	for id in _ids:
		var text: Variant = (raw_values as Dictionary).get(String(id))
		if typeof(text) != TYPE_STRING:
			return SimResult.failure("history: missing values for '%s'" % id)
		var ordered := _decode(text)
		if ordered.size() != mini(recorded_value, _capacity[id]):
			return SimResult.failure("history: '%s' holds %d values, expected %d"
					% [id, ordered.size(), mini(recorded_value, _capacity[id])])
		var buffer := PackedFloat64Array()
		buffer.resize(_capacity[id])
		for j in ordered.size():
			buffer[(recorded_value - ordered.size() + j) % _capacity[id]] = ordered[j]
		restored[id] = buffer
	_buffers = restored
	_recorded = recorded_value
	_folds.clear()
	return SimResult.success(self)


## Marshalls reports an engine error for empty data, so an empty buffer
## (saved before the first tick) is stored as an empty string.
static func _encode(values: PackedFloat64Array) -> String:
	return "" if values.is_empty() else Marshalls.raw_to_base64(values.to_byte_array())


static func _decode(text: String) -> PackedFloat64Array:
	return PackedFloat64Array() if text.is_empty() else Marshalls.base64_to_raw(text).to_float64_array()


func _available(id: StringName) -> int:
	return mini(_recorded, _capacity[id])
