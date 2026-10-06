class_name PlaySession
extends RefCounted
## The console game: the planet runs until a decision point, the player
## reads what happened, gets hints and picks an action from a numbered menu.
## Every decision point is saved, so the game can stop at any time.
##
## The game itself is a GameSession; this class only turns it into text and
## reads the player's answers. Input and output are Callables, so tests can
## play a scripted session: read() -> String (one line) or null (input
## ended); write(text) prints text as given (lines end with "\n").
## Player guide: docs/jak_grac.md.

const ROUND_LIMIT := GameSession.ROUND_LIMIT
const USAGE := """Usage: play.sh [options]
  --seed N             planet number (each number is another planet)
  --personality NAME   harmonious, chaotic, guardian, random (default) or none
  --load FILE          continue a saved game (default save: decision.json)
  --save FILE          where decision points are saved (default decision.json)
  --no-hints           hide the hints (toggle in game with h)
  --full-logs          also write the full technical logs (.log, .jsonl; large)"""

var _game: GameSession
var _read: Callable
var _write: Callable


static func parse_args(args: PackedStringArray) -> SimResult:
	var result := SimResult.new()
	var options := {"hints": true, "full_logs": false, "save": SimulationRunner.DECISION_SAVE, "act": []}
	var i := 0
	while i < args.size():
		match args[i]:
			"--no-hints":
				options["hints"] = false
			"--full-logs":
				options["full_logs"] = true
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
	var game := GameSession.create(options, func(line: String) -> void: write.call(line + "\n"))
	if not game.is_ok():
		return game
	var session := PlaySession.new()
	session._game = game.value
	session._read = read
	session._write = write
	for warning in session._game.warnings:
		write.call("UWAGA: %s\n" % warning)
	return SimResult.success(session)


## Plays until the player quits, input ends or the simulation halts.
## Returns the exit code: 0 = stopped normally, 1 = the simulation halted.
func play() -> int:
	if _game.new_game:
		_say("\n".join(_game.advisor.intro))
		_say("\n[Enter] zaczyna grę.")
		if _ask() == null:
			return 0
	while true:
		_game.begin_round()
		_game.step(ROUND_LIMIT)
		if _game.manager.is_halted():
			_say("Symulacja zatrzymała się z błędem: %s" % ", ".join(_game.manager.errors()))
			return 1
		var saved := _game.save()
		if not saved.is_ok():
			_say("Nie udało się zapisać gry: %s" % ", ".join(saved.errors))
		_say(screen())
		if not _decide():
			return 0
	return 0


## The decision screen: what happened, the planet, life, hints and menu.
func screen() -> String:
	var lines := PackedStringArray()
	lines.append("\n=== Punkt decyzji: tick %d (rok %d) ===" % [_game.tick(), _game.year()])
	if _game.decision_point() != null:
		lines.append("Co się stało:  " + " ".join(_game.decision_sentences()))
	else:
		lines.append("Co się stało:  przez %d ticków nic ważnego, planeta żyje spokojnie." % ROUND_LIMIT)
	var news := _game.goals.take_news()
	if not news.is_empty():
		lines.append("")
		for item in news:
			lines.append("*** " + item + " ***")
		if _game.goals.won() and _game.goals.victory_tick() > _game.last_tick():
			lines.append("Możesz grać dalej: ambicje wciąż czekają.")
		lines.append("")
	lines.append_array(_game.goals.status_lines(_game.texts.species))
	if _game.last_tick() == -1:
		lines.append("Planeta:")
	else:
		var ago := _game.tick() - _game.last_tick()
		lines.append("Planeta (zmiana od poprzedniej decyzji, %d %s temu):" % [ago, GameSession.ticks_word(ago)])
	for row in _game.planet_rows():
		lines.append("  %-20s %16s   %s" % [row["name"], row["shown"], row["change"]])
	lines.append("Życie:")
	for row in _game.life_rows():
		var effects := GameSession.effects_text(row["effects"])
		lines.append(("  %-10s %7s   %-8s %s" % [row["name"], row["shown"], row["change"],
				"" if effects.is_empty() else "wpływ: " + effects]).strip_edges(false, true))
	for row in _game.other_effects():
		lines.append("  %s: %s" % [row["name"], GameSession.effects_text(row["effects"])])
	lines.append_array(_watch_lines())
	_game.remember()
	if _game.hints:
		lines.append("")
		lines.append("Podpowiedź:")
		for hint in _game.hint_lines(_act_label):
			lines.append(" • " + hint)
	lines.append("")
	lines.append(menu())
	return "\n".join(lines)


func menu() -> String:
	var lines := PackedStringArray(["Co robisz?"])
	var actions := _game.actions()
	for i in actions.size():
		var action: Dictionary = actions[i]
		lines.append(" %d) %-26s %s" % [i + 1, action["name"], "gotowe" if action["ready"] else _cooldown_text(action)])
	lines.append(" 0) Czekaj, nic nie rób (albo Enter)")
	lines.append(" ?) Wyjaśnij akcje   c) Cele   h) %s podpowiedzi   q) Zapisz i wyjdź" % ("Ukryj" if _game.hints else "Pokaż"))
	return "\n".join(lines)


## "za 300 ticków (od ticku 1631)": the console has no real-time clock, so the
## wait is counted in ticks, like everything else it shows.
func _cooldown_text(action: Dictionary) -> String:
	return "za %d %s (od ticku %d)" % [action["ready_in"], GameSession.ticks_word(int(action["ready_in"])), action["ready_at"]]


## What the player's earlier actions are doing now, so they know when to watch.
func _watch_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for action in _game.active_actions():
		var name: String = action["name"] + (" (%s)" % action["level_name"] if not (action["level_name"] as String).is_empty() else "")
		var text := ""
		match action["phase"]:
			"queued":
				text = "ruszy w następnym ticku"
			"running":
				text = "działa jeszcze %d %s" % [action["remaining"], GameSession.ticks_word(int(action["remaining"]))]
			_:
				text = "już nie działa"
		if action["fade_max"] > 0:
			text += "; skutek zwykle widać jeszcze %s" % _fade_text(action)
		lines.append("  %s: %s" % [name, text])
	if not lines.is_empty():
		lines.insert(0, "W toku (akcje, których skutek warto obserwować):")
	return lines


func _fade_text(action: Dictionary) -> String:
	if action["fade_min"] == action["fade_max"]:
		return "%d %s" % [action["fade_max"], GameSession.ticks_word(int(action["fade_max"]))]
	return "%d–%d %s" % [action["fade_min"], action["fade_max"], GameSession.ticks_word(int(action["fade_max"]))]


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
				_say("Zapisano: %s\nWróć do gry: ./godot/play.sh --load %s" % [_game.save_path, _game.save_path.get_file()])
				return false
			"?":
				_say(_help())
			"c":
				_say(_game.goals.goals_text())
			"h":
				_game.hints = not _game.hints
				_say("Podpowiedzi %s." % ("włączone" if _game.hints else "ukryte"))
			_:
				var actions := _game.actions()
				if not choice.is_valid_int() or int(choice) < 1 or int(choice) > actions.size():
					_say("Nie rozumiem „%s”. Wpisz numer z menu, 0, ?, c, h albo q." % choice)
					continue
				if _act(actions[int(choice) - 1]):
					_say("Możesz zrobić coś jeszcze albo nacisnąć Enter, żeby puścić planetę dalej.")
	return true


## Asks for the intervention's arguments and queues it. True when queued.
func _act(action: Dictionary) -> bool:
	if not action["ready"]:
		_say("%s jeszcze się odnawia: dostępne od ticku %d." % [action["name"], action["ready_at"]])
		return false
	var args := {}
	if action["species"]:
		var species: Variant = _choose_species()
		if species == null:
			return false
		args["species"] = species
	if not (action["levels"] as Array).is_empty():
		var level: Variant = _choose_level(action)
		if level == null:
			return false
		args["level"] = level
	var submitted := _game.submit(action["id"], args)
	if not submitted.is_ok():
		_say("Nie da się: %s" % ", ".join(submitted.errors))
		return false
	_say("Zrobione: %s." % submitted.value)
	return true


func _choose_species() -> Variant:
	var list := _game.species_choices()
	var lines := PackedStringArray(["Który gatunek?"])
	for i in list.size():
		lines.append(" %d) %-9s %-16s %s" % [i + 1, list[i]["name"], list[i]["state"], list[i]["needs"]])
	lines.append(" 0) Wróć")
	_say("\n".join(lines))
	while true:
		var answer: Variant = _ask()
		if answer == null or (answer as String).strip_edges() in ["", "0"]:
			return null
		var text := (answer as String).strip_edges()
		if text.is_valid_int() and int(text) >= 1 and int(text) <= list.size():
			return list[int(text) - 1]["id"]
		_say("Wpisz numer gatunku (1-%d) albo 0." % list.size())
	return null


func _choose_level(action: Dictionary) -> Variant:
	var levels: Array = action["levels"]
	var lines := PackedStringArray(["Jak mocno?"])
	for i in levels.size():
		var marker := " (domyślnie)" if levels[i][0] == action["default_level"] else ""
		lines.append(" %d) %s%s" % [i + 1, levels[i][1], marker])
	lines.append(" 0) Wróć   (Enter = domyślnie)")
	_say("\n".join(lines))
	while true:
		var answer: Variant = _ask()
		if answer == null:
			return null
		var text := (answer as String).strip_edges()
		if text.is_empty():
			return action["default_level"]
		if text == "0":
			return null
		if text.is_valid_int() and int(text) >= 1 and int(text) <= levels.size():
			return levels[int(text) - 1][0]
		_say("Wpisz numer poziomu (1-%d), Enter albo 0." % levels.size())
	return null


func _help() -> String:
	var lines := PackedStringArray(["Akcje:"])
	var actions := _game.actions()
	for i in actions.size():
		lines.append(" %d) %s: %s" % [i + 1, actions[i]["name"], actions[i]["help"]])
	lines.append("Czas odnowienia: po użyciu akcja jest niedostępna do podanego ticku.")
	return "\n".join(lines)


## How the player picks an advised act here: "3 (Lustra orbitalne, lekko)".
func _act_label(act: String) -> String:
	var parts := act.split(":")
	var actions := _game.actions()
	for i in actions.size():
		if actions[i]["id"] == parts[0]:
			var level := ""
			for pair: Array in actions[i]["levels"]:
				if parts.size() > 1 and pair[0] == parts[-1]:
					level = ", " + str(pair[1])
			return "%d (%s%s)" % [i + 1, actions[i]["name"], level]
	return act


## Kept for callers of the console API; the rule lives in GameSession.
static func trend(change: float, decimals: int) -> String:
	return GameSession.trend(change, decimals)


func _say(text: String) -> void:
	_write.call(text + "\n")


func _ask() -> Variant:
	_write.call("> ")
	return _read.call()
