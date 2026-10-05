class_name PlaySession
extends RefCounted
## The console game: the planet runs until a decision point, the player
## reads what happened, gets hints and picks an action from a numbered menu.
## Every decision point is saved, so the game can stop at any time.
##
## Input and output are Callables, so tests can play a scripted session:
## read() -> String (one line) or null (input ended); write(text) prints text
## as given (lines end with "\n"). Actions go through the same commands as
## --act. Player guide: docs/jak_grac.md.

## Ticks without a decision point before the game stops anyway.
const ROUND_LIMIT := 5000
const TICKS_PER_YEAR := 360
const USAGE := """Usage: play.sh [options]
  --seed N             planet number (each number is another planet)
  --personality NAME   harmonious, chaotic, guardian, random (default) or none
  --load FILE          continue a saved game (default save: decision.json)
  --save FILE          where decision points are saved (default decision.json)
  --no-hints           hide the hints (toggle in game with h)"""


## A log sink that writes through the session's output.
class SessionSink extends LogSink:
	var _write: Callable

	func _init(write: Callable) -> void:
		_write = write

	func write_line(line: String) -> void:
		_write.call(line + "\n")


var _manager: SimulationManager
var _run: Dictionary
var _goals: GoalTracker
var _saver: RunSaver
var _save_path: String
var _advisor: HintAdvisor
var _texts: ChronicleTexts
var _hints := true
var _new_game := true
var _read: Callable
var _write: Callable
## What the previous decision screen showed, for the change arrows:
## parameter values, species populations and lost flags, and its tick.
## Empty until the first screen of this session.
var _last_values := PackedFloat64Array()
var _last_populations := {}
var _last_lost := {}
var _last_tick := -1


static func parse_args(args: PackedStringArray) -> SimResult:
	var result := SimResult.new()
	var options := {"hints": true, "save": SimulationRunner.DECISION_SAVE, "act": []}
	var i := 0
	while i < args.size():
		match args[i]:
			"--no-hints":
				options["hints"] = false
			"--seed", "--personality", "--load", "--save":
				if i + 1 >= args.size():
					result.add_error("%s needs a value" % args[i])
					break
				var key := args[i].trim_prefix("--")
				options[key] = args[i + 1].to_int() if key == "seed" else args[i + 1]
				if key == "seed" and not args[i + 1].is_valid_int():
					result.add_error("--seed must be an integer")
				i += 1
			_:
				result.add_error("unknown option %s" % args[i])
		i += 1
	if options.has("load") and (options.has("seed") or options.has("personality")):
		result.add_error("--load takes seed and personality from the save; drop --seed/--personality")
	if result.is_ok():
		var defaults: Dictionary = SimulationRunner.parse_args(PackedStringArray()).value
		defaults.merge(options, true)
		result.value = defaults
	return result


static func create(options: Dictionary, read: Callable, write: Callable) -> SimResult:
	var opened := SimulationRunner.open_run(options)
	if not opened.is_ok():
		return opened
	var advisor := HintAdvisor.load_json()
	var texts := ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH)
	var goals := GoalTracker.load_json()
	if not advisor.is_ok() or not texts.is_ok() or not goals.is_ok():
		var failed := SimResult.new()
		failed.errors = advisor.errors + texts.errors + goals.errors
		return failed
	var session := PlaySession.new()
	session._manager = opened.value["manager"]
	session._advisor = advisor.value
	session._texts = texts.value
	session._hints = options["hints"]
	session._new_game = not opened.value["loaded"]
	session._read = read
	session._write = write
	var config: SimConfig = opened.value["config"]
	session._save_path = SimulationRunner.resolve_save_path(options["save"], config)
	session._run = opened.value["run"]
	session._saver = RunSaver.new(session._manager, session._run, "", 0)
	session._goals = GoalTracker.new(goals.value, session._manager, String(session._run["personality"]))
	session._goals.load_state(session._run.get("extras", {}).get("goals", {}))
	session._manager.attach_log(session._goals)
	for warning: String in opened.value["warnings"]:
		write.call("UWAGA: %s\n" % warning)
	# Full logs on disk as in every run (tests switch them off with
	# "file_logs": false); the chronicle also goes to the player.
	if options.get("file_logs", true):
		var log_id := SimulationRunner.run_id(config.seed())
		var log := SimulationRunner.create_log(config, log_id, false)
		var chronicle := SimulationRunner.create_chronicle(config, log_id, false)
		for created: SimResult in [log, chronicle]:
			if created.is_ok() and created.value != null:
				session._manager.attach_log(created.value)
	session._manager.attach_log(PlanetChronicle.new([SessionSink.new(write)], texts.value))
	return SimResult.success(session)


## Plays until the player quits, input ends or the simulation halts.
## Returns the exit code: 0 = stopped normally, 1 = the simulation halted.
func play() -> int:
	if _new_game:
		_say("\n".join(_advisor.intro))
		_say("\n[Enter] zaczyna grę.")
		if _ask() == null:
			return 0
	while true:
		var point := _run_round()
		if _manager.is_halted():
			_say("Symulacja zatrzymała się z błędem: %s" % ", ".join(_manager.errors()))
			return 1
		# Goals ride along in the save, so progress survives a load.
		_run["extras"] = {"goals": _goals.save_state()}
		var saved := _saver.save_to(_save_path)
		if not saved.is_ok():
			_say("Nie udało się zapisać gry: %s" % ", ".join(saved.errors))
		_say(screen(point))
		if not _decide():
			return 0
	return 0


## Runs the planet until a decision point or ROUND_LIMIT ticks.
## Returns the watcher, whose point() is null for a quiet checkpoint.
func _run_round() -> DecisionWatcher:
	var catalog := _hand().catalog()
	var watcher := DecisionWatcher.new(catalog.decision_events, catalog.decision_grace, _manager.tick(), _texts,
			_manager.snapshot().schema())
	_manager.attach_log(watcher)
	for i in ROUND_LIMIT:
		if not _manager.step() or watcher.reached():
			break
	return watcher


## The decision screen: what happened, the planet, life, hints and menu.
func screen(watcher: DecisionWatcher) -> String:
	var lines := PackedStringArray()
	var tick := _manager.tick()
	lines.append("\n=== Punkt decyzji: tick %d (rok %d) ===" % [tick, floori(float(tick) / TICKS_PER_YEAR) + 1])
	if watcher.point() != null:
		lines.append("Co się stało:  " + " ".join(PackedStringArray(Array(watcher.sentences()).map(
				func(s: String) -> String: return s.substr(s.find("] ") + 2)))))
	else:
		lines.append("Co się stało:  przez %d ticków nic ważnego, planeta żyje spokojnie." % ROUND_LIMIT)
	var news := _goals.take_news()
	if not news.is_empty():
		lines.append("")
		for item in news:
			lines.append("*** " + item + " ***")
		if _goals.won() and _goals.victory_tick() > _last_tick:
			lines.append("Możesz grać dalej: ambicje wciąż czekają.")
		lines.append("")
	lines.append_array(_goals.status_lines(_texts.species))
	lines.append_array(_planet_lines())
	lines.append_array(_life_lines())
	_remember()
	if _hints:
		lines.append("")
		lines.append("Podpowiedź:")
		for hint in _advisor.hints(watcher.point(), _manager.snapshot(), _biosphere(), _texts.species, _act_label):
			lines.append(" • " + hint)
	lines.append("")
	lines.append(menu())
	return "\n".join(lines)


func menu() -> String:
	var lines := PackedStringArray(["Co robisz?"])
	var catalog := _hand().catalog()
	var ids := catalog.ids()
	for i in ids.size():
		var def := catalog.get_def(ids[i])
		var ready := _hand().ready_at(ids[i])
		lines.append(" %d) %-26s %s" % [i + 1, def.name, "gotowe" if ready <= _manager.tick() + 1 else "od ticku %d" % ready])
	lines.append(" 0) Czekaj, nic nie rób (albo Enter)")
	lines.append(" ?) Wyjaśnij akcje   c) Cele   h) %s podpowiedzi   q) Zapisz i wyjdź" % ("Ukryj" if _hints else "Pokaż"))
	return "\n".join(lines)


## Reads choices until the player lets the planet run on (true) or quits
## (false). Several actions can be queued before letting it run.
func _decide() -> bool:
	while true:
		var answer: Variant = _ask()
		if answer == null:
			return false
		var choice := (answer as String).strip_edges().to_lower()
		match choice:
			"", "0":
				return true
			"q":
				_say("Zapisano: %s\nWróć do gry: ./godot/play.sh --load %s" % [_save_path, _save_path.get_file()])
				return false
			"?":
				_say(_help())
			"c":
				_say(_goals.goals_text())
			"h":
				_hints = not _hints
				_say("Podpowiedzi %s." % ("włączone" if _hints else "ukryte"))
			_:
				if not choice.is_valid_int() or int(choice) < 1 or int(choice) > _hand().catalog().ids().size():
					_say("Nie rozumiem „%s”. Wpisz numer z menu, 0, ?, c, h albo q." % choice)
					continue
				if _act(_hand().catalog().ids()[int(choice) - 1]):
					_say("Możesz zrobić coś jeszcze albo nacisnąć Enter, żeby puścić planetę dalej.")
	return true


## Asks for the intervention's arguments and queues it. True when queued.
func _act(id: StringName) -> bool:
	var def := _hand().catalog().get_def(id)
	var ready := _hand().ready_at(id)
	if ready > _manager.tick() + 1:
		_say("%s jeszcze się odnawia: dostępne od ticku %d." % [def.name, ready])
		return false
	var args := {}
	if def.args.has("species"):
		var species: Variant = _choose_species()
		if species == null:
			return false
		args["species"] = species
	if not def.levels.is_empty():
		var level: Variant = _choose_level(def)
		if level == null:
			return false
		args["level"] = level
	var submitted := _manager.submit(InterventionSystem.ID, id, args)
	if not submitted.is_ok():
		_say("Nie da się: %s" % ", ".join(submitted.errors))
		return false
	_say("Zrobione: %s%s." % [def.name, _args_text(def, args)])
	return true


func _choose_species() -> Variant:
	var biosphere := _biosphere()
	var list := biosphere.species_list()
	var lines := PackedStringArray(["Który gatunek?"])
	for i in list.size():
		var species := list[i]
		var name: String = _texts.species.get(String(species.id), String(species.id))
		var state := "wymarłe" if biosphere.is_lost(species.id) else "populacja %.1f" % biosphere.population(species.id)
		var missing := _advisor.missing_needs(species, _manager.snapshot())
		var needs := "warunki dobre" if missing.is_empty() else "brakuje: " + ", ".join(missing)
		lines.append(" %d) %-9s %-16s %s" % [i + 1, name, state, needs])
	lines.append(" 0) Wróć")
	_say("\n".join(lines))
	while true:
		var answer: Variant = _ask()
		if answer == null or (answer as String).strip_edges() in ["", "0"]:
			return null
		var text := (answer as String).strip_edges()
		if text.is_valid_int() and int(text) >= 1 and int(text) <= list.size():
			return String(list[int(text) - 1].id)
		_say("Wpisz numer gatunku (1-%d) albo 0." % list.size())
	return null


func _choose_level(def: InterventionDef) -> Variant:
	var levels := def.levels.keys()
	var lines := PackedStringArray(["Jak mocno?"])
	for i in levels.size():
		var marker := " (domyślnie)" if levels[i] == def.default_level else ""
		lines.append(" %d) %s%s" % [i + 1, def.levels[levels[i]]["name"], marker])
	lines.append(" 0) Wróć   (Enter = domyślnie)")
	_say("\n".join(lines))
	while true:
		var answer: Variant = _ask()
		if answer == null:
			return null
		var text := (answer as String).strip_edges()
		if text.is_empty():
			return def.default_level
		if text == "0":
			return null
		if text.is_valid_int() and int(text) >= 1 and int(text) <= levels.size():
			return levels[int(text) - 1]
		_say("Wpisz numer poziomu (1-%d), Enter albo 0." % levels.size())
	return null


func _help() -> String:
	var lines := PackedStringArray(["Akcje:"])
	var catalog := _hand().catalog()
	var ids := catalog.ids()
	for i in ids.size():
		var def := catalog.get_def(ids[i])
		lines.append(" %d) %s: %s" % [i + 1, def.name, def.help])
	lines.append("Czas odnowienia: po użyciu akcja jest niedostępna do podanego ticku.")
	return "\n".join(lines)


## How the player picks an advised act: "3 (Lustra orbitalne, lekko)".
func _act_label(act: String) -> String:
	var parts := act.split(":")
	var ids := _hand().catalog().ids()
	var index := ids.find(StringName(parts[0]))
	if index == -1:
		return act
	var def := _hand().catalog().get_def(ids[index])
	var level := ""
	if parts.size() > 1 and def.levels.has(parts[-1]):
		level = ", " + str(def.levels[parts[-1]]["name"])
	return "%d (%s%s)" % [index + 1, def.name, level]


func _args_text(def: InterventionDef, args: Dictionary) -> String:
	var parts := PackedStringArray()
	if args.has("species"):
		parts.append(_texts.species.get(args["species"], args["species"]))
	if args.has("level"):
		parts.append(str(def.levels[args["level"]]["name"]))
	return "" if parts.is_empty() else " (%s)" % ", ".join(parts)


## Parameters with the change since the previous decision screen.
func _planet_lines() -> PackedStringArray:
	var snapshot := _manager.snapshot()
	var schema := snapshot.schema()
	var lines := PackedStringArray()
	if _last_tick == -1:
		lines.append("Planeta:")
	else:
		var ago := _manager.tick() - _last_tick
		lines.append("Planeta (zmiana od poprzedniej decyzji, %d %s temu):" % [ago, _ticks_word(ago)])
	for i in schema.size():
		var value := snapshot.get_value_at(i)
		var change := "" if _last_values.is_empty() else trend(value - _last_values[i], 1)
		lines.append("  %-20s %6.1f   %s" % [schema.def_at(i).display_name(), value, change])
	return lines


## Species with their population and what changed: new, gone, back.
func _life_lines() -> PackedStringArray:
	var biosphere := _biosphere()
	var lines := PackedStringArray(["Życie:"])
	for species in biosphere.species_list():
		var id := String(species.id)
		var name: String = _texts.species.get(id, id)
		var population := biosphere.population(species.id)
		var was: float = _last_populations.get(id, -1.0)
		var shown := "%.0f" % population if population >= 0.5 else "–"
		var change := ""
		if biosphere.is_lost(species.id):
			shown = "WYMARŁE"
			change = "wymarły od ostatniej decyzji" if not _last_lost.get(id, true) and _last_tick != -1 else ""
		elif _last_tick != -1:
			if _last_lost.get(id, false):
				change = "wróciły"
			elif was < 0.5 and population >= 0.5:
				change = "nowe"
			elif population >= 0.5 or was >= 0.5:
				change = trend(population - was, 0)
		lines.append("  %-10s %7s   %s" % [name, shown, change])
	return lines


func _remember() -> void:
	var snapshot := _manager.snapshot()
	_last_values = PackedFloat64Array()
	for i in snapshot.schema().size():
		_last_values.append(snapshot.get_value_at(i))
	var biosphere := _biosphere()
	for species in biosphere.species_list():
		_last_populations[String(species.id)] = biosphere.population(species.id)
		_last_lost[String(species.id)] = biosphere.is_lost(species.id)
	_last_tick = _manager.tick()


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
static func _ticks_word(count: int) -> String:
	if count == 1:
		return "tick"
	var last := count % 10
	var last_two := count % 100
	return "ticki" if last >= 2 and last <= 4 and (last_two < 12 or last_two > 14) else "ticków"


func _hand() -> InterventionSystem:
	return _manager.system(InterventionSystem.ID) as InterventionSystem


func _biosphere() -> BiosphereSystem:
	return _manager.system(BiosphereSystem.ID) as BiosphereSystem


func _say(text: String) -> void:
	_write.call(text + "\n")


func _ask() -> Variant:
	_write.call("> ")
	return _read.call()
