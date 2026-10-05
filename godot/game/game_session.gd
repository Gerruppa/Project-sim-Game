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


## options: as PlaySession.parse_args gives them. chronicle_line(line) gets
## every chronicle sentence as it happens.
static func create(options: Dictionary, chronicle_line: Callable) -> SimResult:
	var opened := SimulationRunner.open_run(options)
	if not opened.is_ok():
		return opened
	var advisor_read := HintAdvisor.load_json()
	var texts_read := ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH)
	var goals_read := GoalTracker.load_json()
	if not advisor_read.is_ok() or not texts_read.is_ok() or not goals_read.is_ok():
		var failed := SimResult.new()
		failed.errors = advisor_read.errors + texts_read.errors + goals_read.errors
		return failed
	var session := GameSession.new()
	session.manager = opened.value["manager"]
	session.advisor = advisor_read.value
	session.texts = texts_read.value
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
		var created: Array[SimResult] = [SimulationRunner.create_chronicle(config, log_id, false)]
		if options.get("full_logs", false):
			created.append(SimulationRunner.create_log(config, log_id, false))
		for result: SimResult in created:
			if result.is_ok() and result.value != null:
				session.manager.attach_log(result.value)
	session.manager.attach_log(PlanetChronicle.new([LineSink.new(chronicle_line)], texts_read.value))
	return SimResult.success(session)


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


## Each parameter: {"name", "value", "change"} ("" on the first decision).
func planet_rows() -> Array[Dictionary]:
	var snapshot := manager.snapshot()
	var schema := snapshot.schema()
	var rows: Array[Dictionary] = []
	for i in schema.size():
		var value := snapshot.get_value_at(i)
		rows.append({"id": String(schema.def_at(i).id()), "name": schema.def_at(i).display_name(), "value": value,
				"change": "" if _last_values.is_empty() else trend(value - _last_values[i], 1)})
	return rows


## Each species: {"id", "name", "population", "lost", "shown", "change"}.
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
			change = "wymarły od ostatniej decyzji" if not _last_lost.get(id, true) and _last_tick != -1 else ""
		elif _last_tick != -1:
			if _last_lost.get(id, false):
				change = "wróciły"
			elif was < 0.5 and population >= 0.5:
				change = "nowe"
			elif population >= 0.5 or was >= 0.5:
				change = trend(population - was, 0)
		rows.append({"id": id, "name": texts.species.get(id, id), "population": population, "lost": lost,
				"shown": shown, "change": change})
	return rows


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


## Hints for the current decision point; act_label(act) says how the player
## picks an advised action in this interface.
func hint_lines(act_label: Callable) -> PackedStringArray:
	return advisor.hints(decision_point(), manager.snapshot(), _biosphere(), texts.species, act_label)


## Every intervention: {"id", "name", "help", "ready", "ready_at", "species"
## (needs a species), "levels" ([[id, name], ...]), "default_level"}.
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
				"ready": ready_at <= manager.tick() + 1, "species": def.args.has("species"), "levels": levels,
				"default_level": def.default_level})
	return list


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
