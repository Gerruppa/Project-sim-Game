class_name GameSession
extends RefCounted
## One game, independent of how it is shown: opens the planet, runs it to
## decision points in steps (so a window can show the planet live), saves at
## every decision point and offers the decision screen as data: planet values
## with trends, life, hints, actions with their readiness, species choices.
##
## The console (PlaySession) and the window (ui/GameView) both format this
## data their own way. Actions go through SimulationManager.submit, the same
## commands as --act.

## Ticks without a decision point before a round ends anyway (quiet planet).
const ROUND_LIMIT := 5000
const TICKS_PER_YEAR := 360


## A log sink that hands every line to a Callable (console print, window text).
class LineSink extends LogSink:
	var _write: Callable

	func _init(write: Callable) -> void:
		_write = write

	func write_line(line: String) -> void:
		_write.call(line)


var manager: SimulationManager
var goals: GoalTracker
var advisor: HintAdvisor
var texts: ChronicleTexts
## The player's units for the planet's numbers and what the actions measured.
var display: DisplayScale
## What each species did to the planet since the last decision.
var impact: SpeciesImpact
var hints := true
## False when the game continues a save.
var new_game := true
var save_path := ""
var warnings := PackedStringArray()

var _run: Dictionary
var _saver: RunSaver
var _watcher: DecisionWatcher
var _round_start := 0
## What the previous decision showed, for the change arrows: parameter
## values, species populations and lost flags, and its tick (-1 = none yet).
var _last_values := PackedFloat64Array()
var _last_populations := {}
var _last_lost := {}
var _last_tick := -1
## Actions worth watching: {"id", "name", "level_name", "started", "ends",
## "effect_until"}. Kept in memory; a loaded game starts from the timed
## interventions still in effect.
var _watch: Array[Dictionary] = []
var _watch_loaded := false


## options: as PlaySession.parse_args gives them. chronicle_line(line) gets
## every chronicle sentence as it happens.
static func create(options: Dictionary, chronicle_line: Callable) -> SimResult:
	var opened := SimulationRunner.open_run(options)
	if not opened.is_ok():
		return opened
	var advisor_read := HintAdvisor.load_json()
	var texts_read := ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH)
	var goals_read := GoalTracker.load_json()
	var display_read := _load_display(opened.value["manager"])
	if not advisor_read.is_ok() or not texts_read.is_ok() or not goals_read.is_ok() or not display_read.is_ok():
		var failed := SimResult.new()
		failed.errors = advisor_read.errors + texts_read.errors + goals_read.errors + display_read.errors
		return failed
	var session := GameSession.new()
	session.manager = opened.value["manager"]
	session.advisor = advisor_read.value
	session.texts = texts_read.value
	session.display = display_read.value
	session.advisor.scale = session.display
	session.texts.number_format = session._chronicle_number
	session.hints = options.get("hints", true)
	session.new_game = not opened.value["loaded"]
	session.warnings = opened.value["warnings"]
	var config: SimConfig = opened.value["config"]
	session.save_path = SimulationRunner.resolve_save_path(options.get("save", SimulationRunner.DECISION_SAVE), config)
	session._run = opened.value["run"]
	session._saver = RunSaver.new(session.manager, session._run, "", 0)
	session.goals = GoalTracker.new(goals_read.value, session.manager, String(session._run["personality"]))
	session.goals.load_state(session._run.get("extras", {}).get("goals", {}))
	session.manager.attach_log(session.goals)
	# On disk: the chronicle of the game; the full technical logs only with
	# --full-logs (a long game writes hundreds of MB of them). Tests switch
	# files off with "file_logs": false.
	if options.get("file_logs", true):
		var log_id := SimulationRunner.run_id(config.seed())
		var created: Array[SimResult] = [SimulationRunner.create_chronicle(config, log_id, false, ChronicleTexts.DEFAULT_PATH, session._chronicle_number)]
		if options.get("full_logs", false):
			created.append(SimulationRunner.create_log(config, log_id, false))
		for result: SimResult in created:
			if result.is_ok() and result.value != null:
				session.manager.attach_log(result.value)
	session.manager.attach_log(PlanetChronicle.new([LineSink.new(chronicle_line)], texts_read.value))
	var species: Array[String] = []
	for data in session._biosphere().species_list():
		species.append(String(data.id))
	session.impact = SpeciesImpact.new(species)
	session.manager.attach_log(session.impact)
	session._load_watch()
	return SimResult.success(session)


## A chronicle number in the player's units; a difference converts around the
## parameter's value now (the chronicle writes as events happen).
func _chronicle_number(param: String, measure: String, value: float) -> String:
	return display.chronicle_number(param, measure, value, manager.snapshot().get_value(StringName(param)))


## Player units, validated against this planet's parameters and interventions.
static func _load_display(manager: SimulationManager) -> SimResult:
	var schema := manager.snapshot().schema()
	var parameters: Array[StringName] = []
	for i in schema.size():
		parameters.append(schema.def_at(i).id())
	var hand := manager.system(InterventionSystem.ID) as InterventionSystem
	var actions: Array[StringName] = [] if hand == null else hand.catalog().ids()
	return DisplayScale.load_json(DisplayScale.DEFAULT_PATH, parameters, actions)


## Starts watching for the next decision point from the current tick.
func begin_round() -> void:
	var catalog := hand().catalog()
	_watcher = DecisionWatcher.new(catalog.decision_events, catalog.decision_grace, manager.tick(), texts,
			manager.snapshot().schema())
	manager.attach_log(_watcher)
	_round_start = manager.tick()


## Runs up to max_ticks ticks, stopping when the round is over. Returns how
## many ran.
func step(max_ticks: int) -> int:
	var executed := 0
	while executed < max_ticks and not round_over():
		if not manager.step():
			break
		executed += 1
	return executed


## A decision point was reached, the planet stayed quiet for ROUND_LIMIT
## ticks, or the simulation halted.
func round_over() -> bool:
	return _watcher == null or _watcher.reached() or manager.is_halted() \
			or manager.tick() - _round_start >= ROUND_LIMIT


## The event that made the decision point, or null (quiet checkpoint).
func decision_point() -> SimEvent:
	return null if _watcher == null else _watcher.point()


## The chronicle sentences of the decision tick, without "[Tick N]".
func decision_sentences() -> PackedStringArray:
	if _watcher == null:
		return PackedStringArray()
	return PackedStringArray(Array(_watcher.sentences()).map(func(s: String) -> String: return s.substr(s.find("] ") + 2)))


## Saves the game; goals ride along so progress survives a load.
func save() -> SimResult:
	_run["extras"] = {"goals": goals.save_state()}
	return _saver.save_to(save_path)


func tick() -> int:
	return manager.tick()


func year() -> int:
	return floori(float(manager.tick()) / TICKS_PER_YEAR) + 1


## Tick of the previous decision (-1 before the first one).
func last_tick() -> int:
	return _last_tick


## Each parameter: {"id", "name", "value" (0-100), "shown" (in the player's
## units), "zone" (LifeZones: none, good, poor or bad) and "change" in those
## units ("" on the first decision)}.
func planet_rows() -> Array[Dictionary]:
	var snapshot := manager.snapshot()
	var schema := snapshot.schema()
	var biosphere := _biosphere()
	var life: Array[SpeciesData] = [] if biosphere == null else LifeZones.relevant(biosphere)
	var rows: Array[Dictionary] = []
	for i in schema.size():
		var id := String(schema.def_at(i).id())
		var value := snapshot.get_value_at(i)
		var change := "" if _last_values.is_empty() else trend(display.change(id, _last_values[i], value), display.decimals(id))
		rows.append({"id": id, "name": display.label(id, schema.def_at(i).display_name()), "value": value,
				"shown": display.shown(id, value),
				"zone": String(LifeZones.zone(StringName(id), value, life)), "change": change})
	return rows


## Each species: {"id", "name", "population", "lost", "shown", "change",
## "effects"}; effects: what it did to the planet since the last decision,
## {"id", "name", "change" (player's units), "shown"}, largest first.
func life_rows() -> Array[Dictionary]:
	var biosphere := _biosphere()
	var rows: Array[Dictionary] = []
	for species in biosphere.species_list():
		var id := String(species.id)
		var population := biosphere.population(species.id)
		var was: float = _last_populations.get(id, -1.0)
		var lost := biosphere.is_lost(species.id)
		var shown := "%.0f" % population if population >= 0.5 else "–"
		var change := ""
		if lost:
			shown = "WYMARŁE"
			change = "wymarły" if not _last_lost.get(id, true) and _last_tick != -1 else ""
		elif _last_tick != -1:
			if _last_lost.get(id, false):
				change = "wróciły"
			elif was < 0.5 and population >= 0.5:
				change = "nowe"
			elif population >= 0.5 or was >= 0.5:
				change = trend(population - was, 0)
		rows.append({"id": id, "name": texts.species.get(id, id), "population": population, "lost": lost,
				"shown": shown, "change": change,
				# A species not yet established has done nothing worth showing.
				"effects": [] if shown == "–" else species_effects(id)})
	return rows


## The rest of the change since the last decision, beside life_rows effects:
## [{"id": SpeciesImpact.PLANET or PLAYER, "name", "effects"}], only groups
## that did something worth showing.
func other_effects() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for pair: Array in [[SpeciesImpact.PLANET, "Reszta planety (skały, oceany, pogoda, zdarzenia)"],
			[SpeciesImpact.PLAYER, "Twoje akcje"]]:
		var effects := species_effects(pair[0])
		if not effects.is_empty():
			rows.append({"id": pair[0], "name": pair[1], "effects": effects})
	return rows


## What a species (or SpeciesImpact.PLANET / PLAYER) did since the last
## decision, in the player's units. Every share converts at the same rate
## (_unit_rate), so the shares of a parameter add up to its change in the
## planet table. Changes that round to nothing are left out.
func species_effects(species: String) -> Array[Dictionary]:
	var snapshot := manager.snapshot()
	var schema := snapshot.schema()
	var sums := impact.sums(species)
	var effects: Array[Dictionary] = []
	for i in schema.size():
		var id := String(schema.def_at(i).id())
		if not sums.has(id):
			continue
		var amount := float(sums[id]) * _unit_rate(id, i, snapshot.get_value_at(i))
		var text := trend(amount, display.decimals(id))
		if text == "=":
			continue
		var unit := display.unit(id)
		effects.append({"id": id, "name": display.label(id, schema.def_at(i).display_name()), "change": amount,
				"shown": text.replace("↑ ", "+").replace("↓ ", "−") + ("" if unit.is_empty() else " " + unit)})
	effects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a["change"]) > absf(b["change"]))
	return effects


## Player's units per point of the 0-100 scale over the path the parameter
## took since the last decision (its average slope); the local slope when it
## barely moved or before the first decision.
func _unit_rate(id: String, index: int, now: float) -> float:
	if index < _last_values.size() and absf(now - _last_values[index]) > 0.01:
		return display.change(id, _last_values[index], now) / (now - _last_values[index])
	return display.difference(id, 1.0, now)


## "Tlen +0.4 % atmosfery, Dwutlenek węgla −30 ppm" from species_effects.
static func effects_text(effects: Array) -> String:
	return ", ".join(PackedStringArray(effects.map(func(e: Dictionary) -> String: return "%s %s" % [e["name"], e["shown"]])))


## Marks the current state as "the previous decision" for the next trends.
func remember() -> void:
	var snapshot := manager.snapshot()
	_last_values = PackedFloat64Array()
	for i in snapshot.schema().size():
		_last_values.append(snapshot.get_value_at(i))
	var biosphere := _biosphere()
	for species in biosphere.species_list():
		_last_populations[String(species.id)] = biosphere.population(species.id)
		_last_lost[String(species.id)] = biosphere.is_lost(species.id)
	_last_tick = manager.tick()
	impact.reset()


## Hints for the current decision point; act_label(act) says how the player
## picks an advised action in this interface.
func hint_lines(act_label: Callable) -> PackedStringArray:
	return advisor.hints(decision_point(), manager.snapshot(), _biosphere(), texts.species, act_label)


## Every intervention: {"id", "name", "help", "ready", "ready_at", "ready_in"
## (ticks until it can be used; 0 when ready), "species" (needs a species),
## "levels" ([[id, name], ...]), "default_level"}.
func actions() -> Array[Dictionary]:
	var catalog := hand().catalog()
	var list: Array[Dictionary] = []
	for id in catalog.ids():
		var def := catalog.get_def(id)
		var levels := []
		for level: String in def.levels:
			levels.append([level, def.levels[level]["name"]])
		var ready_at := hand().ready_at(id)
		list.append({"id": String(id), "name": def.name, "help": def.help, "ready_at": ready_at,
				"ready": ready_at <= manager.tick() + 1, "ready_in": maxi(0, ready_at - manager.tick() - 1),
				"species": def.args.has("species"), "levels": levels, "default_level": def.default_level})
	return list


## Actions worth watching, oldest first. Each: {"id", "name", "level_name",
## "phase", "remaining", "fade_min", "fade_max", "progress"}. Phase "queued": starts next
## tick. "running": its modifiers act, "remaining" ticks left. "observe": it has
## ended but its effect still shows; "fade_min" and "fade_max" are the ticks
## until it usually fades (measured, see DisplayScale.effect_ticks).
func active_actions() -> Array[Dictionary]:
	_load_watch()
	var now := manager.tick()
	_watch = _watch.filter(func(entry: Dictionary) -> bool: return now <= maxi(entry["ends"], entry["effect_until"]))
	var list: Array[Dictionary] = []
	for entry in _watch:
		# 0..1 along the whole timeline: the action, then its measured effect.
		var total: int = maxi(entry["ends"], entry["effect_until"]) - entry["started"] + 1
		var row := {"id": entry["id"], "name": entry["name"], "level_name": entry["level_name"], "remaining": 0,
				"fade_min": 0, "fade_max": 0, "progress": clampf(float(now - entry["started"]) / total, 0.0, 1.0)}
		if now < entry["started"]:
			row["phase"] = "queued"
		elif now <= entry["ends"]:
			row["phase"] = "running"
			row["remaining"] = entry["ends"] - now + 1
		else:
			row["phase"] = "observe"
		var span := display.effect_ticks(entry["id"])
		if not span.is_empty():
			row["fade_min"] = maxi(0, entry["started"] + span[0] - now)
			row["fade_max"] = maxi(0, entry["started"] + span[1] - now)
		list.append(row)
	return list


## A game loaded in the middle of an action: its modifiers are still in effect.
func _load_watch() -> void:
	if _watch_loaded:
		return
	_watch_loaded = true
	for entry in hand().active():
		var def := hand().catalog().get_def(StringName(entry["id"]))
		var level := def.level_of(entry["args"])
		_watch.append(_watch_entry(def, level, int(entry["started"])))


func _watch_entry(def: InterventionDef, level: String, started: int) -> Dictionary:
	var span := display.effect_ticks(String(def.id))
	var ends := started + def.duration - 1 if def.duration > 0 else started
	return {"id": String(def.id), "name": def.name, "level_name": "" if level.is_empty() else str(def.levels[level]["name"]),
			"started": started, "ends": ends, "effect_until": started + (span[1] if not span.is_empty() else 0)}


## Species the player can seed or cull: {"id", "name", "state", "needs"}.
func species_choices() -> Array[Dictionary]:
	var biosphere := _biosphere()
	var list: Array[Dictionary] = []
	for species in biosphere.species_list():
		var missing := advisor.missing_needs(species, manager.snapshot())
		list.append({"id": String(species.id), "name": texts.species.get(String(species.id), String(species.id)),
				"state": "wymarłe" if biosphere.is_lost(species.id) else "populacja %.1f" % biosphere.population(species.id),
				"needs": "warunki dobre" if missing.is_empty() else "brakuje: " + ", ".join(missing)})
	return list


## Queues an intervention for the next tick. Value on success: what was
## done, in the player's words ("Zasiew gatunku (mchy)").
func submit(id: String, args: Dictionary) -> SimResult:
	var def := hand().catalog().get_def(StringName(id))
	if def == null:
		return SimResult.failure("nie ma akcji %s" % id)
	var ready := hand().ready_at(StringName(id))
	if ready > manager.tick() + 1:
		return SimResult.failure("%s jeszcze się odnawia: dostępne od ticku %d." % [def.name, ready])
	# The cooldown starts when the command runs, so a second one queued
	# before that would only be rejected a tick later.
	for queued in manager.command_queue().pending():
		var other := hand().catalog().get_def(queued.action)
		if queued.target == InterventionSystem.ID and other != null and other.cooldown_group == def.cooldown_group:
			return SimResult.failure("%s jest już zaplanowane na następny tick." % other.name)
	var submitted := manager.submit(InterventionSystem.ID, StringName(id), args)
	if not submitted.is_ok():
		return submitted
	_load_watch()
	if def.duration > 0 or not display.effect_ticks(id).is_empty():
		_watch.append(_watch_entry(def, def.level_of(args) if not def.levels.is_empty() else "", (submitted.value as SimCommand).tick))
	return SimResult.success(def.name + _args_text(def, args))


func _args_text(def: InterventionDef, args: Dictionary) -> String:
	var parts := PackedStringArray()
	if args.has("species"):
		parts.append(texts.species.get(args["species"], args["species"]))
	if args.has("level"):
		parts.append(str(def.levels[args["level"]]["name"]))
	return "" if parts.is_empty() else " (%s)" % ", ".join(parts)


## "↑ 9.5", "↓ 0.6" or "=" when the change does not show at this precision.
static func trend(change: float, decimals: int) -> String:
	var shown := absf(change)
	var precision := 1.0
	for i in decimals:
		precision /= 10.0
	if shown < 0.5 * precision:
		return "="
	return ("↑ " if change > 0.0 else "↓ ") + (("%." + str(decimals) + "f") % shown)


## "12 s" or "1 min 05 s" for a number of ticks at `ticks_per_second` (always
## rounded up, so a countdown never shows 0 s before it is ready).
static func seconds_text(ticks: int, ticks_per_second: float) -> String:
	if ticks_per_second <= 0.0:
		return "–"
	var seconds := ceili(float(ticks) / ticks_per_second)
	if seconds < 60:
		return "%d s" % seconds
	var minutes := floori(float(seconds) / 60.0)
	return "%d min %02d s" % [minutes, seconds - minutes * 60]


## Polish plural of "tick" for a count.
static func ticks_word(count: int) -> String:
	if count == 1:
		return "tick"
	var last := count % 10
	var last_two := count % 100
	return "ticki" if last >= 2 and last <= 4 and (last_two < 12 or last_two > 14) else "ticków"


func hand() -> InterventionSystem:
	return manager.system(InterventionSystem.ID) as InterventionSystem


func _biosphere() -> BiosphereSystem:
	return manager.system(BiosphereSystem.ID) as BiosphereSystem
