class_name BubbleField
extends RunObserver
## Collectible bubbles floating over the globe; each one is worth Sparks when
## the player clicks it in time. Watches the run, changes nothing in it: the
## caller collects a bubble and hands the Sparks to the PerkSystem.
##
## Three kinds: "ambient" (a trickle, every N ticks), "discovery" (a species
## emerged) and "bloom" (a species crossed a new population threshold, once
## per threshold). Data: resources/bubbles/bubbles.json.
##
## Bubble positions come from a RandomNumberGenerator seeded with
## seed_value + id: this is game layer, outside the simulation, so the
## simulation's determinism rules do not apply, but a seed still shows the
## same bubbles in the same places. Bubbles live in real seconds: whoever
## drives the field calls update(seconds), and simply stops calling it while
## the game is paused. Only the bloom milestones, the next id and the ambient
## clock are saved; bubbles on screen are not (they are seconds-lived).

const DEFAULT_PATH := "res://resources/bubbles/bubbles.json"
const KEYS: Array[String] = ["bubbles_version", "lifetime_seconds", "max_visible", "ambient", "discovery", "bloom"]
const AMBIENT_KEYS: Array[String] = ["every_ticks", "value"]
const DISCOVERY_KEYS: Array[String] = ["value"]
const BLOOM_KEYS: Array[String] = ["value", "thresholds"]
const MAX_LATITUDE := 80.0
## With a centre provider a bubble lands within this many degrees of the
## centre (the part of the globe the player is looking at).
const CENTER_LAT_SPREAD := 25.0
const CENTER_LON_SPREAD := 35.0

var _lifetime := 15.0
var _max_visible := 8
var _ambient_every := 600
var _ambient_value := 1
var _discovery_value := 4
var _bloom_value := 3
var _thresholds: Array[int] = []

var _seed := 0
var _species: Array[String] = []
var _population_of: Callable
## Optional: () -> Vector2(lat_deg, lon_deg), where new bubbles should appear.
var _center_provider: Callable

var _bubbles: Array[Dictionary] = []
var _next_id := 1
var _last_ambient := 0
## species id -> index of the highest bloom threshold reached so far.
var _bloom_reached: Dictionary[String, int] = {}


## population_of.call(species_id: String) -> float. Value: the BubbleField.
static func load_json(path: String, seed_value: int, species: Array[String], population_of: Callable) -> SimResult:
	var read := CoefficientLoader.read_json(path, "bubbles")
	return from_data(read.value, seed_value, species, population_of) if read.is_ok() else read


## Reports all errors at once.
static func from_data(data: Dictionary, seed_value: int, species: Array[String], population_of: Callable) -> SimResult:
	var result := SimResult.new()
	for key: Variant in data:
		if not KEYS.has(key):
			result.add_error("bubbles: unknown key '%s'" % key)
	var field := BubbleField.new()
	field._seed = seed_value
	field._species = species.duplicate()
	field._population_of = population_of
	var lifetime: Variant = data.get("lifetime_seconds")
	if not _is_number(lifetime) or not is_finite(float(lifetime)) or float(lifetime) <= 0.0:
		result.add_error("bubbles: 'lifetime_seconds' must be a number above 0")
	else:
		field._lifetime = float(lifetime)
	field._max_visible = _whole(data.get("max_visible"), 1, "max_visible", result)
	var ambient := _section(data, "ambient", AMBIENT_KEYS, result)
	field._ambient_every = _whole(ambient.get("every_ticks"), 1, "ambient.every_ticks", result)
	var most := int(PerkSystem.MAX_GRANT)
	field._ambient_value = _whole(ambient.get("value"), 1, "ambient.value", result, most)
	var discovery := _section(data, "discovery", DISCOVERY_KEYS, result)
	field._discovery_value = _whole(discovery.get("value"), 1, "discovery.value", result, most)
	var bloom := _section(data, "bloom", BLOOM_KEYS, result)
	field._bloom_value = _whole(bloom.get("value"), 1, "bloom.value", result, most)
	_parse_thresholds(bloom.get("thresholds"), field, result)
	if result.is_ok():
		result.value = field
	return result


static func _section(data: Dictionary, name: String, keys: Array[String], result: SimResult) -> Dictionary:
	var raw: Variant = data.get(name)
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("bubbles: '%s' must be an object with %s" % [name, keys])
		return {}
	for key: Variant in raw:
		if not keys.has(key):
			result.add_error("bubbles: unknown key '%s.%s'" % [name, key])
	return raw


## Strictly increasing whole populations in 0..100.
static func _parse_thresholds(raw: Variant, field: BubbleField, result: SimResult) -> void:
	var message := "bubbles: bloom.thresholds must be a non-empty, strictly increasing list of whole numbers in 0..100"
	if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
		result.add_error(message)
		return
	var thresholds: Array[int] = []
	for value: Variant in raw:
		if not _is_number(value) or not is_finite(float(value)) or float(value) != floorf(float(value)) \
				or float(value) < 0.0 or float(value) > 100.0 \
				or (not thresholds.is_empty() and int(value) <= thresholds[-1]):
			result.add_error(message)
			return
		thresholds.append(int(value))
	field._thresholds = thresholds


## `maximum` (when above 0): a bubble worth more than the PerkSystem pays for
## one grant would vanish on the click and pay nothing.
static func _whole(value: Variant, minimum: int, key: String, result: SimResult, maximum: int = 0) -> int:
	if not _is_number(value) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < minimum:
		result.add_error("bubbles: '%s' must be a whole number of at least %d" % [key, minimum])
		return minimum
	if maximum > 0 and float(value) > maximum:
		result.add_error("bubbles: '%s' must be at most %d (the most one Spark grant pays)" % [key, maximum])
		return minimum
	return int(value)


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


func attach(bus: EventBus) -> void:
	bus.subscribe_all(on_event)


func on_event(event: SimEvent) -> void:
	match event.type:
		SimEvent.TICK_APPLIED:
			on_tick(event.tick)
		&"species_emerged":
			_spawn("discovery", _discovery_value)


func on_tick(tick: int) -> void:
	if tick - _last_ambient >= _ambient_every:
		_last_ambient = tick
		_spawn("ambient", _ambient_value)
	for id: String in _species:
		var reached := _threshold_index(float(_population_of.call(id)))
		if reached > _bloom_reached.get(id, -1):
			_bloom_reached[id] = reached
			_spawn("bloom", _bloom_value)


## Ages every bubble by `seconds` and removes the expired ones.
func update(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var alive: Array[Dictionary] = []
	for bubble: Dictionary in _bubbles:
		bubble["age"] = float(bubble["age"]) + seconds
		if float(bubble["age"]) < _lifetime:
			alive.append(bubble)
	_bubbles = alive


## Copies, oldest first.
func bubbles() -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for bubble: Dictionary in _bubbles:
		copies.append(bubble.duplicate())
	return copies


## The Sparks the bubble was worth, or 0 when there is no such bubble (already
## collected or expired: a double click pays once).
func collect(id: int) -> int:
	for i in _bubbles.size():
		if _bubbles[i]["id"] == id:
			var value: int = _bubbles[i]["value"]
			_bubbles.remove_at(i)
			return value
	return 0


func lifetime() -> float:
	return _lifetime


## Where new bubbles appear: provider.call() -> Vector2(lat_deg, lon_deg), the
## part of the globe the player looks at. A new bubble lands within
## CENTER_LAT_SPREAD / CENTER_LON_SPREAD degrees of it (drawn from the same
## seeded generator). Without a provider bubbles spread over the whole globe.
func set_center_provider(provider: Callable) -> void:
	_center_provider = provider


func save_state() -> Dictionary:
	return {"bloom": _bloom_reached.duplicate(), "next_id": _next_id, "last_ambient": _last_ambient}


## Missing or damaged data starts fresh; it never blocks a game. Bubbles on
## screen are not restored.
func load_state(data: Dictionary) -> void:
	_bubbles.clear()
	_bloom_reached.clear()
	var bloom: Variant = data.get("bloom", {})
	if typeof(bloom) == TYPE_DICTIONARY:
		for id: Variant in bloom:
			if _is_number(bloom[id]):
				_bloom_reached[str(id)] = int(bloom[id])
	var next_id: Variant = data.get("next_id", 1)
	_next_id = maxi(1, int(next_id)) if _is_number(next_id) else 1
	var last_ambient: Variant = data.get("last_ambient", 0)
	_last_ambient = int(last_ambient) if _is_number(last_ambient) else 0


## Index of the highest threshold the population reached, -1 when none.
func _threshold_index(population: float) -> int:
	var index := -1
	for i in _thresholds.size():
		if population >= float(_thresholds[i]):
			index = i
	return index


func _spawn(kind: String, value: int) -> void:
	var id := _next_id
	_next_id += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + id
	var lat := 0.0
	var lon := 0.0
	if _center_provider.is_valid():
		var center: Vector2 = _center_provider.call()
		lat = clampf(center.x + rng.randf_range(-CENTER_LAT_SPREAD, CENTER_LAT_SPREAD), -MAX_LATITUDE, MAX_LATITUDE)
		lon = wrapf(center.y + rng.randf_range(-CENTER_LON_SPREAD, CENTER_LON_SPREAD), -180.0, 180.0)
	else:
		lat = rng.randf_range(-MAX_LATITUDE, MAX_LATITUDE)
		lon = rng.randf_range(-180.0, 180.0)
	var bubble := {"id": id, "kind": kind, "value": value, "age": 0.0, "lat": lat, "lon": lon}
	while _bubbles.size() >= _max_visible:
		_bubbles.remove_at(0)
	_bubbles.append(bubble)
