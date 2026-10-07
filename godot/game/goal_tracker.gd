class_name GoalTracker
extends RunObserver
## The player's goals: the main goal (a mature planet: every stage of life
## alive at once for a while), stars for how it was reached, and ambitions
## unlocked along the way. Watches the run, changes nothing in it.
##
## Data: resources/goals/goals.json. Ambition kinds are fixed in code and
## parameterised in data: parameter, species, event_survived,
## player_returned, victory_untouched. Optional: "before_year" (parameter,
## species), "min_alive" and "species" + "min_population" checked when the
## event ends (event_survived). Progress is saved in the game save
## ("extras"), so it survives a load. Design: docs/gameplay.md.

const DEFAULT_PATH := "res://resources/goals/goals.json"
const KINDS: Array[String] = ["parameter", "species", "event_survived", "player_returned", "victory_untouched"]
const TICKS_PER_YEAR := 360

var _data: Dictionary
var _manager: SimulationManager
var _archetype: String

var _interventions := 0
## A leveled action used at more than its weakest level.
var _heavy_hand := false
var _extinctions := 0
## Species the player seeded since they last died out.
var _seeded: Array[String] = []
## Running world events -> still no extinction during them.
var _running: Dictionary[String, bool] = {}
## Consecutive ticks with every stage of life alive.
var _streak := 0
## {"tick", "stars": [ids]} once won, else empty.
var _victory := {}
## ambition id -> tick reached
var _achieved: Dictionary[String, int] = {}
## Sentences about what was just reached, for the next screen.
var _news := PackedStringArray()


static func load_json(path: String = DEFAULT_PATH) -> SimResult:
	var read := CoefficientLoader.read_json(path, "goals")
	if not read.is_ok():
		return read
	return validate(read.value)


## Value: the data itself when valid. Reports all errors at once.
static func validate(data: Dictionary) -> SimResult:
	var result := SimResult.new()
	var victory: Variant = data.get("victory")
	if typeof(victory) != TYPE_DICTIONARY or typeof(victory.get("species")) != TYPE_ARRAY \
			or (victory["species"] as Array).is_empty() or not _is_number(victory.get("for_ticks")) \
			or not _is_number(victory.get("min_population")) or typeof(victory.get("name")) != TYPE_STRING:
		result.add_error("goals: 'victory' needs name, species, min_population and for_ticks")
	var ending: Variant = data.get("ending")
	for kind: String in ["won", "timeup"]:
		var card: Variant = ending.get(kind) if typeof(ending) == TYPE_DICTIONARY else null
		if typeof(card) != TYPE_DICTIONARY or typeof(card.get("title")) != TYPE_STRING or typeof(card.get("body")) != TYPE_STRING:
			result.add_error("goals: 'ending.%s' needs a title and a body" % kind)
	var stars: Variant = data.get("stars")
	if typeof(stars) != TYPE_ARRAY:
		result.add_error("goals: 'stars' must be a list")
	else:
		var ids := (stars as Array).map(func(s: Variant) -> Variant: return s.get("id") if typeof(s) == TYPE_DICTIONARY else null)
		for needed: String in ["no_losses", "fast", "light_hand"]:
			if not ids.has(needed):
				result.add_error("goals: star '%s' is missing" % needed)
	var ambitions: Variant = data.get("ambitions")
	if typeof(ambitions) != TYPE_ARRAY:
		result.add_error("goals: 'ambitions' must be a list")
	else:
		for ambition: Variant in ambitions:
			if typeof(ambition) != TYPE_DICTIONARY or typeof(ambition.get("id")) != TYPE_STRING \
					or typeof(ambition.get("name")) != TYPE_STRING or not KINDS.has(ambition.get("kind")):
				result.add_error("goals: ambition %s needs id, name and a kind from %s" % [ambition, KINDS])
	if result.is_ok():
		result.value = data
	return result


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


func _init(data: Dictionary, manager: SimulationManager, archetype: String) -> void:
	_data = data
	_manager = manager
	_archetype = archetype


func attach(bus: EventBus) -> void:
	bus.subscribe_all(_on_event)


func _on_event(event: SimEvent) -> void:
	match event.type:
		SimEvent.TICK_APPLIED:
			_on_tick(event.tick)
		&"species_extinct":
			_extinctions += 1
			_seeded.erase(str(event.data.get("species")))
			for id in _running:
				_running[id] = false
		&"species_returned":
			if _seeded.has(str(event.data.get("species"))):
				_reach_kind("player_returned", event.tick)
		&"world_event_started":
			_running[str(event.data.get("id"))] = true
		&"world_event_ended":
			var id := str(event.data.get("id"))
			if _running.get(id, false):
				for ambition: Dictionary in _ambitions():
					if ambition["kind"] == "event_survived" and ambition.get("event") == id and _survived(ambition):
						_reach(ambition, event.tick)
			_running.erase(id)
		&"intervention_applied":
			_interventions += 1
			if event.data.has("level") and event.data["level"] != _weakest_level(str(event.data.get("id"))):
				_heavy_hand = true
			if event.data.get("id") == "seed_species" and event.data.has("species"):
				_seeded.append(str(event.data["species"]))


func _on_tick(tick: int) -> void:
	var snapshot := _manager.snapshot()
	for ambition: Dictionary in _ambitions():
		if _achieved.has(ambition["id"]):
			continue
		if ambition.has("before_year") and year(tick) >= int(ambition["before_year"]):
			continue
		match ambition["kind"]:
			"parameter":
				var value := snapshot.get_value(StringName(ambition["param"]))
				if (value > float(ambition["value"])) if ambition["op"] == ">" else (value < float(ambition["value"])):
					_reach(ambition, tick)
			"species":
				if (not ambition.has("archetype") or ambition["archetype"] == _archetype) \
						and _population(str(ambition["species"])) >= float(ambition["min_population"]):
					_reach(ambition, tick)
	if not _victory.is_empty():
		return
	_streak = _streak + 1 if missing_stages().is_empty() else 0
	if _streak >= int(_data["victory"]["for_ticks"]):
		_win(tick)


func _win(tick: int) -> void:
	var stars: Array[String] = []
	for star: Dictionary in _data["stars"]:
		var earned := false
		match star["id"]:
			"no_losses":
				earned = _extinctions == 0
			"fast":
				earned = year(tick) < int(star["max_years"])
			"light_hand":
				# Doing nothing is "Nie ruszaj", not a light hand.
				earned = _interventions >= int(star.get("min_interventions", 0)) \
						and _interventions <= int(star["max_interventions"]) and not _heavy_hand
		if earned:
			stars.append(star["id"])
	_victory = {"tick": tick, "stars": stars}
	_news.append("VICTORY: %s in year %d. Stars: %s." % [_data["victory"]["name"], year(tick), stars_text()])
	if _interventions == 0:
		_reach_kind("victory_untouched", tick)


## Extra conditions an event_survived ambition checks when the event ends.
func _survived(ambition: Dictionary) -> bool:
	if ambition.has("min_alive"):
		var alive := 0
		for id: String in _data["victory"]["species"]:
			alive += 1 if _population(id) >= float(_data["victory"]["min_population"]) else 0
		if alive < int(ambition["min_alive"]):
			return false
	if ambition.has("species") and _population(str(ambition["species"])) < float(ambition.get("min_population", 1.0)):
		return false
	return true


func _reach_kind(kind: String, tick: int) -> void:
	for ambition: Dictionary in _ambitions():
		if ambition["kind"] == kind:
			_reach(ambition, tick)


func _reach(ambition: Dictionary, tick: int) -> void:
	if _achieved.has(ambition["id"]):
		return
	_achieved[ambition["id"]] = tick
	_news.append("Ambition reached: %s (%s)." % [ambition["name"], ambition.get("text", "")])


## Stages of life not alive now, by species id.
func missing_stages() -> Array[String]:
	var missing: Array[String] = []
	for id: String in _data["victory"]["species"]:
		if _population(id) < float(_data["victory"]["min_population"]):
			missing.append(id)
	return missing


## The name of the main goal ("Mature planet").
func ending_goal_name() -> String:
	return str(_data["victory"]["name"])


## The title and body (with {placeholders}) of the ending card: "won" or "timeup".
func ending(kind: String) -> Dictionary:
	return _data["ending"][kind]


func won() -> bool:
	return not _victory.is_empty()


func victory_tick() -> int:
	return _victory.get("tick", -1)


func stars() -> Array:
	return _victory.get("stars", [])


## "★★☆ (No losses, Fast)"
func stars_text() -> String:
	var earned := PackedStringArray()
	var marks := ""
	for star: Dictionary in _data["stars"]:
		if stars().has(star["id"]):
			earned.append(star["name"])
			marks += "★"
		else:
			marks += "☆"
	return marks + ("" if earned.is_empty() else " (%s)" % ", ".join(earned))


func achieved() -> Dictionary[String, int]:
	return _achieved.duplicate()


func streak() -> int:
	return _streak


## What was reached since the last call (cleared on read).
func take_news() -> PackedStringArray:
	var news := _news
	_news = PackedStringArray()
	return news


## Lines for the decision screen. names: species id -> player's word.
func status_lines(names: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var victory: Dictionary = _data["victory"]
	if won():
		lines.append("Goal:          %s reached in year %d  %s" % [victory["name"], year(victory_tick()), stars_text()])
	else:
		var missing := missing_stages()
		var total: int = (victory["species"] as Array).size()
		if missing.is_empty():
			lines.append("Goal:          %s: every stage of life is alive, %s to go (%s of %s)"
					% [victory["name"], GameCalendar.duration_text(int(victory["for_ticks"]) - _streak), GameCalendar.duration_text(_streak),
					GameCalendar.duration_text(int(victory["for_ticks"]))])
		else:
			var words := PackedStringArray(missing.map(func(id: String) -> String: return str(names.get(id, id))))
			lines.append("Goal:          %s: stages of life %d/%d, missing: %s" % [victory["name"], total - missing.size(), total, ", ".join(words)])
	var reached := PackedStringArray()
	for ambition: Dictionary in _ambitions():
		if _achieved.has(ambition["id"]):
			reached.append(ambition["name"])
	lines.append("Ambitions:     %d/%d%s" % [reached.size(), _ambitions().size(), "" if reached.is_empty() else ": " + ", ".join(reached)])
	return lines


## Every goal with its state, for the "c" (cele) screen.
func goals_text() -> String:
	var lines := PackedStringArray(["Main goal: %s. %s" % [_data["victory"]["name"], _data["victory"]["text"]], "Stars:"])
	for star: Dictionary in _data["stars"]:
		lines.append("  %s %s: %s" % ["★" if stars().has(star["id"]) else "☆", star["name"], (star["text"] as String).format(star)])
	lines.append("Ambitions:")
	for ambition: Dictionary in _ambitions():
		var mark := "[x]" if _achieved.has(ambition["id"]) else "[ ]"
		lines.append("  %s %s: %s" % [mark, ambition["name"], ambition.get("text", "")])
	return "\n".join(lines)


static func year(tick: int) -> int:
	return floori(float(tick) / TICKS_PER_YEAR) + 1


func save_state() -> Dictionary:
	return {"interventions": _interventions, "heavy_hand": _heavy_hand, "extinctions": _extinctions,
			"seeded": _seeded.duplicate(), "running": _running.duplicate(), "streak": _streak,
			"victory": _victory.duplicate(true), "achieved": _achieved.duplicate()}


## Missing or damaged progress starts fresh; it never blocks a game.
func load_state(data: Dictionary) -> void:
	_interventions = int(data.get("interventions", 0))
	_heavy_hand = bool(data.get("heavy_hand", false))
	_extinctions = int(data.get("extinctions", 0))
	_seeded.clear()
	for id: Variant in data.get("seeded", []):
		_seeded.append(str(id))
	_running.clear()
	var running: Variant = data.get("running", {})
	if typeof(running) == TYPE_DICTIONARY:
		for id: Variant in running:
			_running[str(id)] = bool(running[id])
	_streak = int(data.get("streak", 0))
	var victory: Variant = data.get("victory", {})
	_victory = {} if typeof(victory) != TYPE_DICTIONARY or victory.is_empty() \
			else {"tick": int(victory.get("tick", 0)), "stars": Array(victory.get("stars", []))}
	_achieved.clear()
	var achieved: Variant = data.get("achieved", {})
	if typeof(achieved) == TYPE_DICTIONARY:
		for id: Variant in achieved:
			_achieved[str(id)] = int(achieved[id])


func _ambitions() -> Array:
	return _data["ambitions"]


func _population(id: String) -> float:
	var biosphere := _manager.system(BiosphereSystem.ID) as BiosphereSystem
	return 0.0 if biosphere == null else biosphere.population(StringName(id))


func _weakest_level(intervention_id: String) -> String:
	var hand := _manager.system(InterventionSystem.ID) as InterventionSystem
	var def := hand.catalog().get_def(StringName(intervention_id)) if hand != null else null
	if def == null or def.levels.is_empty():
		return ""
	var weakest := ""
	for level: String in def.levels:
		if weakest.is_empty() or float(def.levels[level]["scale"]) < float(def.levels[weakest]["scale"]):
			weakest = level
	return weakest
