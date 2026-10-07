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
## In live mode the game saves itself whenever the tick crosses a multiple of this.
const AUTOSAVE_TICKS := 1000
## The years the Creator gives the Apprentice.
const GAME_YEARS := 200
## Live mode shows trends as arrows: the change since the oldest of the samples
## taken every TREND_STEP ticks over the last TREND_TICKS.
const TREND_STEP := 90
const TREND_TICKS := 720
## A species counts as moving when its population changed by this much.
const POPULATION_TREND := 1.0
const ARROW_UP := "▲"
const ARROW_DOWN := "▼"


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
## "When do I plant what?" for the window.
var species_guide: SpeciesGuide
var texts: ChronicleTexts
## The player's units for the planet's numbers and what the actions measured.
var display: DisplayScale
## What each species did to the planet since the last decision.
var impact: SpeciesImpact
## Collectible bubbles over the globe: where Sparks come from.
var bubbles: BubbleField
## Early warnings of crises, for the window.
var threat_log: ThreatLog
## New and lost life, for the toasts.
var milestones: MilestoneLog
## Live mode: the window plays without pausing; no round ever ends at a
## decision point, actions wait for their perk and the game autosaves.
var live := false
var hints := true
## False when the game continues a save.
var new_game := true
var save_path := ""
var warnings := PackedStringArray()
## The years the game lasts (tests shorten it).
var game_years := GAME_YEARS
## The player has dismissed the ending card (saved with the game).
var ending_seen := false

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
## The last autosave failed (and was reported); cleared by the next good one.
var _autosave_failing := false
## Live mode: {"tick", "values" (parameters), "populations" (id -> float)}, oldest first.
var _trend_samples: Array[Dictionary] = []


## options: as PlaySession.parse_args gives them. chronicle_line(line) gets
## every chronicle sentence as it happens.
static func create(options: Dictionary, chronicle_line: Callable) -> SimResult:
	var opened := SimulationRunner.open_run(options)
	if not opened.is_ok():
		return opened
	var advisor_read := HintAdvisor.load_json()
	var texts_read := ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH)
	var goals_read := GoalTracker.load_json()
	var guide_read := SpeciesGuide.load_json()
	var display_read := _load_display(opened.value["manager"])
	if not advisor_read.is_ok() or not texts_read.is_ok() or not goals_read.is_ok() or not display_read.is_ok() \
			or not guide_read.is_ok():
		var failed := SimResult.new()
		failed.errors = advisor_read.errors + texts_read.errors + goals_read.errors + display_read.errors + guide_read.errors
		return failed
	var session := GameSession.new()
	session.manager = opened.value["manager"]
	session.advisor = advisor_read.value
	session.texts = texts_read.value
	session.display = display_read.value
	session.species_guide = guide_read.value
	session.advisor.scale = session.display
	session.texts.number_format = session._chronicle_number
	session.hints = options.get("hints", true)
	session.live = options.get("live", false)
	session.new_game = not opened.value["loaded"]
	session.warnings = opened.value["warnings"]
	var config: SimConfig = opened.value["config"]
	session.save_path = SimulationRunner.resolve_save_path(options.get("save", SimulationRunner.DECISION_SAVE), config)
	session._run = opened.value["run"]
	session._saver = RunSaver.new(session.manager, session._run, "", 0)
	session.goals = GoalTracker.new(goals_read.value, session.manager, String(session._run["personality"]))
	session.goals.load_state(session._run.get("extras", {}).get("goals", {}))
	session.manager.attach_log(session.goals)
	var biosphere := session._biosphere()
	var species: Array[String] = []
	for data in biosphere.species_list():
		species.append(String(data.id))
	var bubbles_read := BubbleField.load_json(BubbleField.DEFAULT_PATH, session.manager.config().seed(), species,
			func(id: String) -> float: return biosphere.population(StringName(id)))
	if not bubbles_read.is_ok():
		return bubbles_read
	session.bubbles = bubbles_read.value
	session.milestones = MilestoneLog.new()
	session.manager.attach_log(session.milestones)
	session.threat_log = ThreatLog.new()
	session.threat_log.load_state(session._run.get("extras", {}).get("threats", {}))
	session.manager.attach_log(session.threat_log)
	var counter_errors := session._counter_errors()
	if not counter_errors.is_empty():
		return SimResult.failure("
".join(counter_errors))
	session.bubbles.load_state(session._run.get("extras", {}).get("bubbles", {}))
	session.ending_seen = bool(session._run.get("extras", {}).get("ending_seen", false))
	session.manager.attach_log(session.bubbles)
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
	if live:
		# The game never stops for a decision: nothing to watch for.
		_round_start = manager.tick()
		if _trend_samples.is_empty():
			_sample_trend()
		return
	var catalog := hand().catalog()
	_watcher = DecisionWatcher.new(catalog.decision_events, catalog.decision_grace, manager.tick(), texts,
			manager.snapshot().schema())
	manager.attach_log(_watcher)
	_round_start = manager.tick()


## Runs up to max_ticks ticks, stopping when the round is over. Returns how
## many ran. In live mode it saves the game each time the tick crosses a
## multiple of AUTOSAVE_TICKS.
func step(max_ticks: int) -> int:
	var executed := 0
	while executed < max_ticks and not round_over():
		var before := manager.tick()
		if not manager.step():
			break
		executed += 1
		if live and manager.tick() % TREND_STEP == 0:
			_sample_trend()
		if live and floori(float(manager.tick()) / AUTOSAVE_TICKS) > floori(float(before) / AUTOSAVE_TICKS):
			var saved := save()
			if saved.is_ok():
				_autosave_failing = false
			elif not _autosave_failing:
				# A disk that stays broken is told once, not every 1000 ticks.
				_autosave_failing = true
				warnings.append("Autosave failed: %s" % "; ".join(saved.errors))
	return executed


## A decision point was reached, the planet stayed quiet for ROUND_LIMIT
## ticks, or the simulation halted. Live mode ends only when it halts.
func round_over() -> bool:
	if live:
		return manager.is_halted()
	return _watcher == null or _watcher.reached() or manager.is_halted() \
			or manager.tick() - _round_start >= ROUND_LIMIT


## The event that made the decision point, or null (quiet checkpoint).
func decision_point() -> SimEvent:
	return null if live or _watcher == null else _watcher.point()


## The chronicle sentences of the decision tick, without "[Tick N]".
func decision_sentences() -> PackedStringArray:
	if _watcher == null:
		return PackedStringArray()
	return PackedStringArray(Array(_watcher.sentences()).map(func(s: String) -> String: return s.substr(s.find("] ") + 2)))


## Saves the game; goals and bubble milestones ride along so progress survives a load.
func save() -> SimResult:
	_run["extras"] = {"goals": goals.save_state(), "bubbles": bubbles.save_state(), "ending_seen": ending_seen,
			"threats": threat_log.save_state()}
	return _saver.save_to(save_path)


func tick() -> int:
	return manager.tick()


func year() -> int:
	return GameCalendar.year(manager.tick())


## "Year 29, November" for a tick (-1 = now), with the month names of the display data.
func date_text(tick_number: int = -1) -> String:
	return GameCalendar.date_text(manager.tick() if tick_number < 0 else tick_number, display.months())


## How the game stands: "won" (the goal is reached; wins over the rest), "timeup"
## (the years ran out) or "" (still open).
func outcome() -> String:
	if goals.won():
		return "won"
	if manager.tick() >= game_years * GameCalendar.TICKS_PER_YEAR:
		return "timeup"
	return ""


## What the ending card tells: {"date", "stars", "alive", "total", "perks", "bubbles", "years", "goal"}.
func summary() -> Dictionary:
	var biosphere := _biosphere()
	var alive := 0
	for id in biosphere.species_ids():
		alive += 1 if biosphere.population(id) >= biosphere.established_population() else 0
	return {"date": date_text(), "stars": goals.stars_text(), "alive": alive, "total": biosphere.species_ids().size(),
			"perks": perks().owned().size(), "bubbles": bubbles.collected_count(), "years": game_years,
			"goal": goals.ending_goal_name()}


## The ending card for the current outcome: {"title", "body"} (BBCode).
func ending_card() -> Dictionary:
	var kind := outcome()
	if kind.is_empty():
		return {}
	var card := goals.ending(kind)
	return {"title": card["title"], "body": (card["body"] as String).format(summary())}


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
	var tolerance := Vector3.ZERO if biosphere == null else biosphere.tolerance()
	var rows: Array[Dictionary] = []
	for i in schema.size():
		var id := String(schema.def_at(i).id())
		var value := snapshot.get_value_at(i)
		var change := ""
		if live:
			change = _parameter_arrow(id, i, value)
		elif not _last_values.is_empty():
			change = trend(display.change(id, _last_values[i], value), display.decimals(id))
		rows.append({"id": id, "name": display.label(id, schema.def_at(i).display_name()), "value": value,
				"shown": display.shown(id, value),
				"zone": String(LifeZones.zone(StringName(id), value, life, tolerance)), "change": change})
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
			shown = "LOST"
			change = "" if live else ("lost" if not _last_lost.get(id, true) and _last_tick != -1 else "")
		elif live:
			change = _population_arrow(id, population)
		elif _last_tick != -1:
			if _last_lost.get(id, false):
				change = "back"
			elif was < 0.5 and population >= 0.5:
				change = "new"
			elif population >= 0.5 or was >= 0.5:
				change = trend(population - was, 0)
		rows.append({"id": id, "name": texts.species.get(id, id), "population": population, "lost": lost,
				"shown": shown, "change": change,
				# A species not yet established has done nothing worth showing.
				"effects": [] if shown == "–" or live else species_effects(id)})
	return rows


## The rest of the change since the last decision, beside life_rows effects:
## [{"id": SpeciesImpact.PLANET or PLAYER, "name", "effects"}], only groups
## that did something worth showing.
func other_effects() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for pair: Array in [[SpeciesImpact.PLANET, "The rest of the planet (rocks, oceans, weather, events)"],
			[SpeciesImpact.PLAYER, "Your actions"]]:
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


## "Oxygen +0.4 % of atmosphere, Carbon dioxide −30 ppm" from species_effects.
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
## "levels" ([[id, name], ...]), "default_level", "unlocked" (free or its perk
## is owned), "unlock_perk" (the perk's name, "" for a free action)}.
func actions() -> Array[Dictionary]:
	var catalog := hand().catalog()
	var list: Array[Dictionary] = []
	for id in catalog.ids():
		var def := catalog.get_def(id)
		var levels := []
		for level: String in def.levels:
			levels.append([level, def.levels[level]["name"]])
		var ready_at := hand().ready_at(id)
		var perk := perks().unlocking_perk(id)
		list.append({"id": String(id), "name": def.name, "help": def.help, "ready_at": ready_at,
				"ready": ready_at <= manager.tick() + 1, "ready_in": maxi(0, ready_at - manager.tick() - 1),
				"species": def.args.has("species"), "levels": levels, "default_level": def.default_level,
				"unlocked": perks().unlocks(id), "unlock_perk": "" if perk == null else perk.name})
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
				"state": "lost" if biosphere.is_lost(species.id) else "population %.1f" % biosphere.population(species.id),
				"needs": "conditions good" if missing.is_empty() else "missing: " + ", ".join(missing)})
	return list


## Queues an intervention for the next tick. Value on success: what was
## done, in the player's words ("Seed a species (moss)").
func submit(id: String, args: Dictionary) -> SimResult:
	var def := hand().catalog().get_def(StringName(id))
	if def == null:
		return SimResult.failure("there is no action %s" % id)
	if live and not perks().unlocks(def.id):
		return SimResult.failure("%s requires the perk \"%s\"." % [def.name, perks().unlocking_perk(def.id).name])
	var ready := hand().ready_at(StringName(id))
	if ready > manager.tick() + 1:
		return SimResult.failure("%s is still recharging: available from %s." % [def.name, date_text(ready)])
	# The cooldown starts when the command runs, so a second one queued
	# before that would only be rejected a tick later.
	for queued in manager.command_queue().pending():
		var other := hand().catalog().get_def(queued.action)
		if queued.target == InterventionSystem.ID and other != null and other.cooldown_group == def.cooldown_group:
			return SimResult.failure("%s is already queued for the next tick." % other.name)
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


## "tick" or "ticks" for a count.
static func ticks_word(count: int) -> String:
	return "tick" if count == 1 else "ticks"


## Whole Sparks the player holds.
func sparks() -> int:
	return floori(perks().sparks())


## Sparks queued for the next tick and not yet in the purse (a bubble collected
## while the planet is paused waits for the next tick to run).
func pending_sparks() -> int:
	var total := 0
	for queued in manager.command_queue().pending():
		if queued.target == PerkSystem.ID and queued.action == PerkSystem.ACTION_GRANT:
			total += int(queued.args.get("amount", 0))
	return total


## Crises that loom or rage: {"id", "name", "state" ("warned": announced, not yet
## started; "pending": about to start; "active"), "text" (what is coming),
## "counters": [{"id", "name", "kind" ("perk" or "action"), "owned" (the perk is
## bought, or the action is unlocked)}]}.
func threats() -> Array[Dictionary]:
	var events := manager.system(EventSystem.ID) as EventSystem
	var rows: Array[Dictionary] = []
	if events == null:
		return rows
	var warned := events.warned_ids()
	for id in events.event_ids():
		var phase := events.phase_of(id)
		var state := ""
		if phase == EventLifecycle.ACTIVE:
			state = "active"
		elif phase == EventLifecycle.PENDING:
			state = "pending"
		elif warned.has(id):
			state = "warned"
		if state.is_empty():
			continue
		var info := events.info_of(id)
		var counters: Array[Dictionary] = []
		for counter: String in info["counters"]:
			counters.append(counter_row(counter))
		rows.append({"id": String(id), "name": info["name"], "state": state, "text": info["warning_text"],
				"counters": counters})
	return rows


## A perk or action named by event data: {"id", "name", "kind", "owned"}.
func counter_row(counter: String) -> Dictionary:
	var def := perks().catalog().get_def(StringName(counter))
	if def != null:
		return {"id": counter, "name": def.name, "kind": "perk", "owned": perks().owns(def.id)}
	var action := hand().catalog().get_def(StringName(counter))
	return {"id": counter, "name": action.name, "kind": "action", "owned": perks().unlocks(action.id)}


## Counters named in event data that are neither a perk nor an action.
func _counter_errors() -> Array[String]:
	var errors: Array[String] = []
	var events := manager.system(EventSystem.ID) as EventSystem
	if events == null:
		return errors
	for id in events.event_ids():
		for counter: String in events.info_of(id)["counters"]:
			if perks().catalog().get_def(StringName(counter)) == null and hand().catalog().get_def(StringName(counter)) == null:
				errors.append("event '%s': counter '%s' is neither a perk nor an action" % [id, counter])
	return errors


## The ladder of life with the next rung and what it needs (LifePath.steps).
func life_path() -> Array[Dictionary]:
	return LifePath.steps(_biosphere(), manager.snapshot(), species_guide, display, texts.species)


## The cheapest perk whose requirements are met and that is not bought yet:
## {"name", "cost", "missing" (Sparks still needed, 0 when affordable)}; empty
## when none is left.
func next_perk_goal() -> Dictionary:
	var best := {}
	for row in perk_rows():
		if row["owned"] or not row["available"]:
			continue
		if best.is_empty() or int(row["cost"]) < int(best["cost"]):
			best = {"name": row["name"], "cost": int(row["cost"]), "missing": maxi(0, int(row["cost"]) - sparks())}
	return best


## Every species with how well the planet suits it (SpeciesGuide.guide) and what
## the Plant button needs: {"verb", "ready" (the seeding action has recharged)}.
func species_guide_rows() -> Array[Dictionary]:
	var biosphere := _biosphere()
	var snapshot := manager.snapshot()
	var ready := hand().ready_at(&"seed_species") <= manager.tick() + 1
	# A seeding queued for the next tick has not started its cooldown yet, but a second one would be refused.
	for queued in manager.command_queue().pending():
		if queued.target == InterventionSystem.ID and queued.action == &"seed_species":
			ready = false
	var rows: Array[Dictionary] = []
	for species in biosphere.species_list():
		var row := species_guide.guide(species, snapshot, biosphere, display, texts.species)
		row["verb"] = "Release" if species.is_fauna() else "Plant"
		row["ready"] = ready
		rows.append(row)
	return rows


## The Sparks the player can still spend: the purse less the buys waiting for
## the next tick, plus the refunds waiting (a paused game does not run them yet).
func spendable_sparks() -> int:
	var total := perks().sparks()
	for queued in manager.command_queue().pending():
		if queued.target != PerkSystem.ID:
			continue
		var def := perks().catalog().get_def(StringName(str(queued.args.get("perk", ""))))
		if def == null:
			continue
		if queued.action == PerkSystem.ACTION_BUY:
			total -= float(def.cost)
		elif queued.action == PerkSystem.ACTION_REFUND:
			total += float(perks().refund_of(def))
	return floori(total)


## "buy" or "refund" while that command waits for the next tick, else "".
func _queued_perk_action(perk_id: StringName) -> String:
	for queued in manager.command_queue().pending():
		if queued.target == PerkSystem.ID and str(queued.args.get("perk", "")) == String(perk_id):
			return String(queued.action)
	return ""


## The branches of the perk window in display order: {"id", "name", "help"}.
func perk_branches() -> Array[Dictionary]:
	return perks().catalog().branches()


## Names of the species a perk waits for that have never lived on this planet.
func _unmet_species(def: PerkDef) -> Array[String]:
	var biosphere := _biosphere()
	var unmet: Array[String] = []
	for id in def.requires_species:
		if biosphere.population(id) < biosphere.established_population() and not biosphere.is_lost(id):
			unmet.append(str(texts.species.get(String(id), String(id))))
	return unmet


## Every perk: {"id", "name", "help", "tree", "cost", "owned", "affordable"
## (the Sparks cover the cost), "available" (requirements owned), "missing"
## (names of the requirements not owned), "side_effect", "refund" (Sparks
## back when refunded)}, in catalog order.
func perk_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var spendable := spendable_sparks()
	for def in perks().catalog().defs():
		var missing: Array[String] = []
		for id in perks().missing_requirements(def.id):
			missing.append(perks().catalog().get_def(id).name)
		rows.append({"id": String(def.id), "name": def.name, "help": def.help, "tree": String(def.tree), "cost": def.cost,
				"branch": String(def.tree), "line": String(def.line), "tier": def.tier, "locked_species": _unmet_species(def),
				"owned": perks().owns(def.id), "affordable": spendable >= def.cost, "available": missing.is_empty(),
				"queued": _queued_perk_action(def.id),
				"missing": missing, "side_effect": def.side_effect, "refund": perks().refund_of(def)})
	return rows


## Queues buying a perk for the next tick. Value on success: the perk's name.
## The balance is checked now, so Sparks granted in the same tick do not count yet.
func buy_perk(id: String) -> SimResult:
	var def := perks().catalog().get_def(StringName(id))
	if def != null:
		var unmet := _unmet_species(def)
		if not unmet.is_empty():
			return SimResult.failure("Discover first: %s." % ", ".join(unmet))
	return _perk_command(PerkSystem.ACTION_BUY, id)


## Queues a refund of a perk (part of its cost comes back). Value: its name.
func refund_perk(id: String) -> SimResult:
	return _perk_command(PerkSystem.ACTION_REFUND, id)


func _perk_command(action: StringName, id: String) -> SimResult:
	var submitted := manager.submit(PerkSystem.ID, action, {"perk": id})
	if not submitted.is_ok():
		return submitted
	return SimResult.success(perks().catalog().get_def(StringName(id)).name)


## Takes the bubble and queues its Sparks for the next tick. Value: how many.
## A bubble gone already (a double click, or it expired) pays nothing.
func collect_bubble(id: int) -> SimResult:
	var value := bubbles.collect(id)
	if value == 0:
		return SimResult.failure("The bubble is already gone.")
	var granted := manager.submit(PerkSystem.ID, PerkSystem.ACTION_GRANT, {"amount": value, "source": "bubble"})
	if not granted.is_ok():
		return granted
	return SimResult.success(value)


## Ages the bubbles by real seconds; the window calls it while the game runs.
func update_bubbles(seconds: float) -> void:
	bubbles.update(seconds)


func hand() -> InterventionSystem:
	return manager.system(InterventionSystem.ID) as InterventionSystem


func perks() -> PerkSystem:
	return manager.system(PerkSystem.ID) as PerkSystem


func _biosphere() -> BiosphereSystem:
	return manager.system(BiosphereSystem.ID) as BiosphereSystem


## Records the planet and its life now, keeping the last TREND_TICKS of samples.
func _sample_trend() -> void:
	var snapshot := manager.snapshot()
	var values := PackedFloat64Array()
	for i in snapshot.schema().size():
		values.append(snapshot.get_value_at(i))
	var populations := {}
	var biosphere := _biosphere()
	for species in biosphere.species_list():
		populations[String(species.id)] = biosphere.population(species.id)
	_trend_samples.append({"tick": manager.tick(), "values": values, "populations": populations})
	while _trend_samples.size() > TREND_TICKS / TREND_STEP + 1:
		_trend_samples.remove_at(0)


## "▲", "▼" or "" for a parameter against the oldest trend sample.
func _parameter_arrow(id: String, index: int, now: float) -> String:
	if _trend_samples.is_empty() or _trend_samples[0]["tick"] >= manager.tick():
		return ""
	var then: float = (_trend_samples[0]["values"] as PackedFloat64Array)[index]
	var delta := display.change(id, then, now)
	return _arrow(delta, trend(delta, display.decimals(id)) != "=")


## "▲", "▼" or "" for a species against the oldest trend sample.
func _population_arrow(id: String, now: float) -> String:
	if _trend_samples.is_empty() or _trend_samples[0]["tick"] >= manager.tick():
		return ""
	var delta := now - float(_trend_samples[0]["populations"].get(id, 0.0))
	return _arrow(delta, absf(delta) >= POPULATION_TREND)


static func _arrow(delta: float, moving: bool) -> String:
	if not moving:
		return ""
	return ARROW_UP if delta > 0.0 else ARROW_DOWN
