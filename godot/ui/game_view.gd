class_name GameView
extends Control
## The game in a window: the planet as a globe in the middle with the
## decision and the chronicle under it, the planet's numbers and life (with
## what each species did) on the left, actions in a column on the right and
## charts behind a button; the run pauses itself at decision points and the
## player acts with buttons. A debug-level visualization (CLAUDE.md:
## simulation -> logs -> debug visualization -> final visualization).
##
## The game is a GameSession, the same one the console plays; this node only
## shows it and turns clicks into GameSession.submit. Options come from the
## command line (as play.sh), or from `options` set before entering the tree.
## Without either (a double-clicked exported game) it starts with a
## new-game screen: random or chosen planet, its character, or the last save.

## Time speeds offered to the player (ticks per second at base rate 1). No
## x1000: players used it to skip the game instead of watching the planet.
const SPEEDS: Array[int] = [5, 10, 25, 50, 100]
const DEFAULT_SPEED := 25
## What the player reads before a live game starts.
const LIVE_INTRO := "Creator patrzy Ci przez ramię. Ludzkość założyła się, że byle głupiec z boskimi mocami potrafi stworzyć życie. " \
		+ "Masz 200 lat, żeby ją przekonać. Jesteś Praktykantem: zbieraj Iskry z bąbelków nad globem, kupuj za nie perki i prowadź planetę, " \
		+ "póki żyje."
const LIVE_RUNNING_TEXT := "Planeta biegnie sama. Zbieraj Iskry z bąbelków, kupuj perki po prawej i działaj, kiedy chcesz; możesz też wstrzymać grę."
## What the trends of the left column count from: a live game has no decision
## points (the trends run from its start), the legacy flow from the last one.
const SINCE_DECISION := "od ostatniej decyzji"
const SINCE_START := "od początku gry"
const RUNNING_TEXT := "Gra sama się zatrzyma, gdy wydarzy się coś ważnego. Możesz też ją zatrzymać i działać."
## The layout is built for this size and scales with the window (project
## stretch settings); nothing inside may ask for more.
const BASE_SIZE := Vector2(1366, 800)
const MIN_WINDOW := Vector2i(1024, 600)
## Ticks between two chart samples.
const SAMPLE_EVERY := 10
const CHART_PARAMS: Array[String] = ["temperature", "humidity", "oxygen", "biomass", "co2"]
## Colours of the life zones (LifeZones): a range life can live in, the margin
## where it only just grows, and a range it cannot.
const ZONE_COLORS := {"good": Color("3fb950"), "poor": Color("d29922"), "bad": Color("f85149")}
## Planet characters on the new-game screen: [personality option, label].
const CHARACTERS := [["random", "losowy"], ["harmonious", "Harmonijna"], ["chaotic", "Chaotyczna"],
		["guardian", "Strażnik"]]

## Set before add_child to skip the command line (tests).
var options := {}
## The command line options are read from; tests replace it.
var command_line := OS.get_cmdline_user_args()

var session: GameSession
var _scheduler: TickScheduler
var _running := false
var _at_decision := false
var _last_sample_tick := -SAMPLE_EVERY

var _info: Label
var _sparks_label: Label
## Headers of the left column; they say what the trends count from.
var _params_title: Label
var _life_title: Label
var _perks: PerkPanel
var _bubbles: BubbleLayer
## How many of session.warnings are in the chronicle already.
var _warnings_shown := 0
var _pause_button: Button
var _speed_buttons: Array[Button] = []
var _planet: PlanetView
var _chart: HistoryChart
var _params: GridContainer
var _life: VBoxContainer
## One per species, in life_rows order: {"bar", "value", "change", "effects"}.
var _life_cells: Array[Dictionary] = []
## The rest of the change: the planet itself and the player's actions.
var _others: Label
var _goals: RichTextLabel
var _chronicle: RichTextLabel
var _decision_title: Label
var _decision_text: RichTextLabel
var _actions: VBoxContainer
## Holds the new-game controls under the decision text.
var _decision_extra: VBoxContainer
var _continue_button: Button
var _action_rows := {}
var _watch_box: VBoxContainer
## action id -> {"label": Label, "bar": ProgressBar}
var _watch_rows := {}
var _param_ids: Array[String] = []
var _zone_styles := {}
var _error: Label
var _new_game_box: HFlowContainer
var _seed_edit: LineEdit
var _character: OptionButton
var _goals_button: Button
var _goals_dialog: AcceptDialog
var _charts_dialog: AcceptDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if get_tree().current_scene == self:
		get_window().min_size = MIN_WINDOW
	_build()
	if options.is_empty():
		if command_line.is_empty():
			_show_new_game()
			return
		var parsed := PlaySession.parse_args(command_line)
		if not parsed.is_ok():
			_show_error("\n".join(parsed.errors) + "\n" + PlaySession.USAGE)
			return
		options = parsed.value
	open_game(options)


## Opens a game with play.sh options and shows it (intro for a new game).
func open_game(game_options: Dictionary) -> void:
	options = game_options
	# A game in the window runs live unless the options say otherwise.
	options["live"] = options.get("live", true)
	if _new_game_box != null:
		_new_game_box.queue_free()
		_new_game_box = null
	var created := GameSession.create(options, _on_chronicle_line)
	if not created.is_ok():
		_show_error("\n".join(created.errors))
		return
	session = created.value
	_scheduler = session.manager.scheduler()
	_scheduler.set_speed(DEFAULT_SPEED)
	_planet.set_planet(session.manager.config().seed())
	for row in session.planet_rows():
		if CHART_PARAMS.has(row["id"]):
			_chart.add_series(row["id"], row["name"])
	_build_actions()
	_bubbles.setup(_planet, session.bubbles)
	var since := SINCE_START if session.live else SINCE_DECISION
	_params_title.text = "Planeta (zmiana %s)" % since
	_life_title.text = "Życie (populacja 0-100) i jego wpływ %s" % since
	for warning in session.warnings:
		_on_chronicle_line("UWAGA: " + warning)
	_warnings_shown = session.warnings.size()
	if session.new_game:
		_show_intro()
	else:
		start()


## The first screen of a double-clicked game: which planet to play.
func _show_new_game() -> void:
	_decision_title.text = "Genesis Error · nowa planeta"
	_decision_text.text = "Każdy numer to inna planeta. Zostaw pole puste, żeby wylosować; ten sam numer daje zawsze tę samą planetę."
	_new_game_box = HFlowContainer.new()
	_decision_extra.add_child(_new_game_box)
	var seed_label := Label.new()
	seed_label.text = "Numer planety:"
	_new_game_box.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "losowy"
	_seed_edit.custom_minimum_size = Vector2(110, 0)
	_new_game_box.add_child(_seed_edit)
	var character_label := Label.new()
	character_label.text = "  Charakter:"
	_new_game_box.add_child(character_label)
	_character = OptionButton.new()
	for pair: Array in CHARACTERS:
		_character.add_item(str(pair[1]))
		_character.set_item_metadata(_character.item_count - 1, pair[0])
	_new_game_box.add_child(_character)
	var start_button := Button.new()
	start_button.text = "Nowa gra ▶"
	start_button.pressed.connect(new_game)
	_new_game_box.add_child(start_button)
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	if config != null and FileAccess.file_exists(SimulationRunner.resolve_save_path(SimulationRunner.DECISION_SAVE, config)):
		var load_button := Button.new()
		load_button.text = "Wczytaj ostatnią grę"
		load_button.pressed.connect(load_last_game)
		_new_game_box.add_child(load_button)


## Fills the new-game screen as a player would (tests).
func choose_planet(seed_text: String, character: int = 0) -> void:
	_seed_edit.text = seed_text
	_character.select(character)


## Starts the planet chosen on the new-game screen (random when empty).
func new_game() -> void:
	var text := _seed_edit.text.strip_edges()
	var seed_value := text.to_int() if text.is_valid_int() else randi_range(1, 99999)
	var character: String = _character.get_item_metadata(_character.selected)
	open_game(PlaySession.parse_args(PackedStringArray(["--seed", str(seed_value), "--personality", character])).value)


func load_last_game() -> void:
	open_game(PlaySession.parse_args(PackedStringArray(["--load", SimulationRunner.DECISION_SAVE])).value)


## Lets the planet run until the next decision point.
func start() -> void:
	_at_decision = false
	# Trends shown until the next decision count from here.
	session.remember()
	session.begin_round()
	_scheduler.resume()
	_running = true
	_decision_title.text = "Planeta żyje…"
	_decision_text.text = _running_text()
	_continue_button.visible = false
	_continue_button.text = "Dalej ▶"
	_refresh()


func _running_text() -> String:
	return LIVE_RUNNING_TEXT if session.live else RUNNING_TEXT


func _process(delta: float) -> void:
	if session == null:
		return
	if _running and not _at_decision:
		# Bubbles age only while the planet runs: a pause never costs Sparks.
		session.update_bubbles(delta)
		advance(_scheduler.advance(delta))
	# The globe turns even in a pause, and the bubbles ride on it.
	_bubbles.refresh()


## Runs up to `ticks` ticks of the current round, then updates the view.
## Public so tests can drive the game without real time.
func advance(ticks: int) -> void:
	var done := 0
	while done < ticks and not session.round_over():
		var chunk := mini(SAMPLE_EVERY, ticks - done)
		var ran := session.step(chunk)
		done += ran
		_sample()
		if ran == 0:
			break
	if session.round_over():
		_enter_decision()
	# Warnings that came up while playing (an autosave that failed).
	while _warnings_shown < session.warnings.size():
		_on_chronicle_line("UWAGA: " + session.warnings[_warnings_shown])
		_warnings_shown += 1
	_refresh()


func _sample() -> void:
	if session.tick() - _last_sample_tick < SAMPLE_EVERY:
		return
	_last_sample_tick = session.tick()
	var values := {}
	for row in session.planet_rows():
		values[row["id"]] = row["value"]
	_chart.add_sample(values)


func _enter_decision() -> void:
	_running = false
	_at_decision = true
	if session.manager.is_halted():
		_show_error("Symulacja zatrzymała się z błędem: %s" % ", ".join(session.manager.errors()))
		return
	session.save()
	var lines := PackedStringArray()
	if session.decision_point() != null:
		lines.append("[b]Co się stało:[/b] " + " ".join(session.decision_sentences()))
	else:
		lines.append("[b]Co się stało:[/b] przez %d ticków nic ważnego, planeta żyje spokojnie." % GameSession.ROUND_LIMIT)
	for item in session.goals.take_news():
		lines.append("[color=gold][b]%s[/b][/color]" % item)
		_on_chronicle_line(item)
	if session.hints:
		for hint in session.hint_lines(_act_label):
			lines.append("• " + hint)
	_decision_title.text = "PUNKT DECYZJI · tick %d · rok %d" % [session.tick(), session.year()]
	_decision_text.text = "\n".join(lines)
	_continue_button.visible = true
	_refresh()


func _show_intro() -> void:
	_decision_title.text = "Witaj w Genesis Error"
	_decision_text.text = (LIVE_INTRO if session.live else "\n".join(session.advisor.intro)) \
			+ "\n\nCo jest do zdobycia: cel główny, gwiazdki i ambicje są pod przyciskiem „Cele” na górze okna."
	_continue_button.text = "Zacznij ▶"
	_continue_button.visible = true
	_at_decision = true
	_refresh()


func _on_continue() -> void:
	_continue_button.text = "Dalej ▶"
	start()


func toggle_pause() -> void:
	if session == null or _at_decision:
		return
	_running = not _running
	if _running:
		_scheduler.resume()
		_decision_title.text = "Planeta żyje…"
		_decision_text.text = _running_text()
	else:
		_scheduler.pause()
		_decision_title.text = "PAUZA · tick %d · rok %d" % [session.tick(), session.year()]
		_decision_text.text = "Możesz działać; akcja zacznie się w następnym ticku."
	_refresh()


func set_speed(speed: int) -> void:
	if session != null and _scheduler.set_speed(speed):
		_refresh()


## Everything there is to win, with what is already won (the console's "c").
## The planet keeps its pace; the list only reads the goals.
func show_goals() -> void:
	if session == null:
		return
	_goals_dialog.dialog_text = session.goals.goals_text()
	_goals_dialog.popup_centered(Vector2i(640, 0))


## The charts of the planet's values over time (a curiosity next to the globe).
func show_charts() -> void:
	_charts_dialog.popup_centered(Vector2i(960, 520))


func charts_visible() -> bool:
	return _charts_dialog.visible


## What a species did since the last decision, as its line under the life
## table shows it ("" when nothing worth showing).
func life_effects_text(species: String) -> String:
	var life := session.life_rows()
	for i in life.size():
		if life[i]["id"] == species and i < _life_cells.size():
			var label: Label = _life_cells[i]["effects"]
			return label.text if label.visible else ""
	return ""


## What the globe shows now (PlanetView.look).
func planet_look() -> Dictionary:
	return _planet.current_look()


## The planet's and the player's share of the change, as shown under life.
func others_text() -> String:
	return _others.text if _others.visible else ""


## The text of the goals window (empty while it is closed).
func goals_window_text() -> String:
	return _goals_dialog.dialog_text if _goals_dialog.visible else ""


## Presses an action's button: the chosen species and level come from its
## selectors. Public for tests. Returns the result of GameSession.submit.
func act(id: String) -> SimResult:
	var row: Dictionary = _action_rows[id]
	var args := {}
	var species: OptionButton = row.get("species")
	if species != null:
		args["species"] = species.get_item_metadata(species.selected)
	var level: OptionButton = row.get("level")
	if level != null:
		args["level"] = level.get_item_metadata(level.selected)
	var submitted := session.submit(id, args)
	if submitted.is_ok():
		_on_chronicle_line("Zrobione: %s." % submitted.value)
	else:
		_on_chronicle_line("Nie da się: %s" % ", ".join(submitted.errors))
	_refresh()
	return submitted


## Picks a bubble (a click on the globe). The Sparks land on the next tick.
func collect_bubble(id: int) -> SimResult:
	var collected := session.collect_bubble(id)
	if not collected.is_ok():
		_on_chronicle_line("Nie da się: %s" % ", ".join(collected.errors))
	_refresh()
	return collected


## Buys a perk of the shop; it works from the next tick.
func buy_perk(id: String) -> SimResult:
	return _perk_done(session.buy_perk(id))


func refund_perk(id: String) -> SimResult:
	return _perk_done(session.refund_perk(id))


func _perk_done(done: SimResult) -> SimResult:
	if done.is_ok():
		_on_chronicle_line("Zrobione: %s." % done.value)
	else:
		_on_chronicle_line("Nie da się: %s" % ", ".join(done.errors))
	_refresh()
	return done


## "Iskry: 12", as the top bar shows them.
func sparks_text() -> String:
	return _sparks_label.text


## The headers over the planet's numbers and over life.
func trend_titles() -> Array[String]:
	return [_params_title.text, _life_title.text]


func bubble_layer() -> BubbleLayer:
	return _bubbles


func perk_panel() -> PerkPanel:
	return _perks


## The error shown instead of the game (empty when the game runs).
func error_text() -> String:
	return _error.text if _error.visible else ""


func at_decision() -> bool:
	return _at_decision


func chronicle_text() -> String:
	return _chronicle.get_parsed_text()


func decision_text() -> String:
	return _decision_title.text + "\n" + _decision_text.get_parsed_text()


## What an action's button says (its name, and the wait while it recharges).
func action_text(id: String) -> String:
	return action_button(id).text


func action_button(id: String) -> Button:
	return _action_rows[id]["button"]


## What the value label of a parameter shows, in the player's units.
func parameter_text(id: String) -> String:
	return (_params.get_child(_param_ids.find(id) * 4 + 2) as Label).text


## The colour of a parameter's value (green, amber or red); Color.TRANSPARENT
## when no species limits it.
func parameter_color(id: String) -> Color:
	var label := _params.get_child(_param_ids.find(id) * 4 + 2) as Label
	return label.get_theme_color("font_color") if label.has_theme_color_override("font_color") else Color.TRANSPARENT


## The lines of the "Działające akcje" panel.
func watch_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for id: String in _watch_rows:
		lines.append((_watch_rows[id]["label"] as Label).text)
	return lines


func _on_chronicle_line(line: String) -> void:
	if _chronicle != null:
		_chronicle.append_text(line + "\n")


## How the window names an advised act: "Lustra orbitalne (lekko)".
func _act_label(act_text: String) -> String:
	var parts := act_text.split(":")
	for action in session.actions():
		if action["id"] == parts[0]:
			for pair: Array in action["levels"]:
				if parts.size() > 1 and pair[0] == parts[-1]:
					return "%s (%s)" % [action["name"], pair[1]]
			return str(action["name"])
	return act_text


func _refresh() -> void:
	if session == null:
		return
	var running_text := "▶ x%d" % _scheduler.speed() if _running else "⏸ pauza"
	_info.text = "seed %d · rok %d · tick %d   %s" % [session.manager.config().seed(), session.year(), session.tick(),
			running_text]
	_pause_button.text = "Wznów ▶" if not _running and not _at_decision else "Pauza ⏸"
	_pause_button.disabled = _at_decision
	_goals_button.disabled = false
	for button in _speed_buttons:
		button.button_pressed = int(button.get_meta("speed")) == _scheduler.speed()
	var values := {}
	var rows := session.planet_rows()
	for i in rows.size():
		values[rows[i]["id"]] = rows[i]["value"]
		if i * 4 + 3 < _params.get_child_count():
			var bar := _params.get_child(i * 4 + 1) as ProgressBar
			var shown := _params.get_child(i * 4 + 2) as Label
			bar.value = rows[i]["value"]
			_set_cell(shown, rows[i]["shown"])
			_set_cell(_params.get_child(i * 4 + 3) as Label, rows[i]["change"])
			_color_zone(bar, shown, rows[i]["zone"])
	var life := session.life_rows()
	var populations := {}
	for i in life.size():
		populations[life[i]["id"]] = life[i]["population"]
		if i < _life_cells.size():
			var cells := _life_cells[i]
			(cells["bar"] as ProgressBar).value = life[i]["population"]
			_set_cell(cells["value"], life[i]["shown"])
			_set_cell(cells["change"], life[i]["change"])
			var effects := GameSession.effects_text(life[i]["effects"])
			(cells["effects"] as Label).text = effects.replace(", ", " · ")
			(cells["effects"] as Label).visible = not effects.is_empty()
	_others.text = "
".join(PackedStringArray(session.other_effects().map(func(row: Dictionary) -> String:
			return "%s: %s" % [row["name"], GameSession.effects_text(row["effects"]).replace(", ", " · ")])))
	_others.visible = not _others.text.is_empty()
	_planet.show_state(values, populations)
	_goals.text = "\n".join(_goal_lines())
	var allowed := session.tick() > 0 and (session.live or _at_decision or not _running)
	for action in session.actions():
		var row: Dictionary = _action_rows.get(action["id"], {})
		if row.is_empty():
			continue
		var button: Button = row["button"]
		if session.live and not action["unlocked"]:
			button.disabled = true
			button.tooltip_text = "%s\nOdblokuje ją perk „%s”." % [action["help"], action["unlock_perk"]]
			button.text = "%s (wymaga: %s)" % [action["name"], action["unlock_perk"]]
			continue
		var wait := time_text(int(action["ready_in"]))
		button.disabled = not allowed or not action["ready"]
		button.tooltip_text = action["help"] + ("" if action["ready"] else "\nGotowe za %s%s." % [wait, _speed_note()])
		button.text = action["name"] + ("" if action["ready"] else " (%s)" % wait)
	_sparks_label.text = "Iskry: %d" % session.sparks()
	_perks.refresh(session.perk_rows(), session.sparks())
	_update_watch()


## A table cell has a fixed width so the layout never jumps; a text that does
## not fit ends with "…" and shows whole under the mouse.
func _set_cell(cell: Label, text: String) -> void:
	cell.text = text
	cell.tooltip_text = text


## The tick rate of the chosen speed in real time, also while paused: what a
## countdown would run at once the planet runs.
func _ticks_per_second() -> float:
	return session.manager.config().base_ticks_per_second() * _scheduler.speed()


## A number of ticks as the player waits for it: "12 s" at the current speed.
func time_text(ticks: int) -> String:
	return GameSession.seconds_text(ticks, _ticks_per_second())


## While the planet waits, a countdown only shows what it will take.
func _speed_note() -> String:
	return "" if _running else " przy x%d" % _scheduler.speed()


## Colours a parameter by its life zone; "none" leaves the default look.
func _color_zone(bar: ProgressBar, shown: Label, zone: String) -> void:
	if not ZONE_COLORS.has(zone):
		bar.remove_theme_stylebox_override("fill")
		shown.remove_theme_color_override("font_color")
		return
	if not _zone_styles.has(zone):
		var style := StyleBoxFlat.new()
		style.bg_color = ZONE_COLORS[zone]
		_zone_styles[zone] = style
	bar.add_theme_stylebox_override("fill", _zone_styles[zone])
	shown.add_theme_color_override("font_color", ZONE_COLORS[zone])


## One line and bar per action still worth watching: how long it acts and
## when its effect usually fades, in the player's real seconds.
func _update_watch() -> void:
	var seen := {}
	for action in session.active_actions():
		var id: String = action["id"]
		seen[id] = true
		if not _watch_rows.has(id):
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var bar := ProgressBar.new()
			bar.max_value = 1.0
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 8)
			_watch_box.add_child(label)
			_watch_box.add_child(bar)
			_watch_rows[id] = {"label": label, "bar": bar}
		var row: Dictionary = _watch_rows[id]
		(row["label"] as Label).text = watch_text(action)
		(row["bar"] as ProgressBar).value = action["progress"]
	for id: String in _watch_rows.keys():
		if not seen.has(id):
			(_watch_rows[id]["label"] as Label).queue_free()
			(_watch_rows[id]["bar"] as ProgressBar).queue_free()
			_watch_rows.erase(id)
	_watch_box.visible = not _watch_rows.is_empty()


## "Pył orbitalny (lekko): działa jeszcze 8 s · skutek zwykle widać jeszcze 12–40 s".
func watch_text(action: Dictionary) -> String:
	var name: String = action["name"] + (" (%s)" % action["level_name"] if not (action["level_name"] as String).is_empty() else "")
	var text := ""
	match action["phase"]:
		"queued":
			text = "ruszy w następnym ticku"
		"running":
			text = "działa jeszcze %s" % time_text(int(action["remaining"]))
		_:
			text = "już nie działa"
	if action["fade_max"] > 0:
		var lower := time_text(int(action["fade_min"]))
		var upper := time_text(int(action["fade_max"]))
		text += " · skutek zwykle widać jeszcze %s" % (upper if lower == upper else "%s–%s" % [lower, upper])
	return "%s: %s%s" % [name, text, _speed_note()]


## Goal lines without the console's column padding.
func _goal_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for line in session.goals.status_lines(session.texts.species):
		var colon := line.find(":")
		lines.append(line.substr(0, colon + 1) + " " + line.substr(colon + 1).strip_edges())
	return lines


func _show_error(text: String) -> void:
	_error.text = text
	_error.visible = true
	_running = false


# --- building the window -------------------------------------------------------

## Widths of the side columns; the globe and the console take the rest.
const LEFT_WIDTH := 400.0
const RIGHT_WIDTH := 290.0
const CONSOLE_HEIGHT := 240.0
const SMALL_FONT := 14


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("0d131b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = "Genesis Error"
	title.add_theme_font_size_override("font_size", 20)
	top.add_child(title)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(_info)
	_sparks_label = Label.new()
	_sparks_label.text = "Iskry: 0"
	_sparks_label.add_theme_font_size_override("font_size", 18)
	_sparks_label.add_theme_color_override("font_color", Color("f2c14e"))
	_sparks_label.tooltip_text = "Iskry zbierasz z bąbelków nad globem; kupujesz za nie perki."
	top.add_child(_sparks_label)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)
	_build_left(main)
	_build_center(main)
	_build_right(main)

	_error = Label.new()
	_error.visible = false
	_error.add_theme_color_override("font_color", Color("ff6b6b"))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_error)

	_goals_dialog = AcceptDialog.new()
	_goals_dialog.title = "Cele · co jest do zdobycia"
	_goals_dialog.ok_button_text = "Zamknij"
	_goals_dialog.dialog_autowrap = true
	add_child(_goals_dialog)
	_charts_dialog = AcceptDialog.new()
	_charts_dialog.title = "Wykresy · planeta w czasie"
	_charts_dialog.ok_button_text = "Zamknij"
	add_child(_charts_dialog)
	_chart = HistoryChart.new()
	_chart.custom_minimum_size = Vector2(900, 440)
	_charts_dialog.add_child(_chart)


## Left: the planet's numbers, life with what each species did, running
## actions and goals. Scrolls, so it never makes the window taller.
func _build_left(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var small := Theme.new()
	small.default_font_size = SMALL_FONT
	scroll.theme = small
	parent.add_child(scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	scroll.add_child(left)
	_params = GridContainer.new()
	_params.columns = 4
	_params.add_theme_constant_override("h_separation", 8)
	_params_title = _title_label("Planeta (zmiana %s)" % SINCE_DECISION)
	left.add_child(_params_title)
	left.add_child(_params)
	_life_title = _title_label("Życie (populacja 0-100) i jego wpływ %s" % SINCE_DECISION)
	left.add_child(_life_title)
	_life = VBoxContainer.new()
	_life.add_theme_constant_override("separation", 2)
	left.add_child(_life)
	_others = Label.new()
	_others.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_others.add_theme_color_override("font_color", Color("9fb4c8"))
	_others.add_theme_font_size_override("font_size", 13)
	left.add_child(_others)
	_watch_box = VBoxContainer.new()
	_watch_box.visible = false
	left.add_child(_watch_box)
	_watch_box.add_child(_title_label("Działające akcje"))
	_goals = RichTextLabel.new()
	_goals.fit_content = true
	_goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_goals)
	var charts_button := Button.new()
	charts_button.text = "Wykresy"
	charts_button.tooltip_text = "Jak zmieniały się wartości planety w czasie."
	charts_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	charts_button.pressed.connect(show_charts)
	left.add_child(charts_button)


## Middle: the globe, and under it the decision beside the chronicle.
func _build_center(parent: Control) -> void:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	parent.add_child(center)
	_planet = PlanetView.new()
	_planet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_planet)
	_bubbles = BubbleLayer.new()
	_bubbles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_planet.add_child(_bubbles)
	_bubbles.bubble_pressed.connect(collect_bubble)
	var console := HBoxContainer.new()
	console.custom_minimum_size = Vector2(0, CONSOLE_HEIGHT)
	console.add_theme_constant_override("separation", 8)
	center.add_child(console)

	var decision := PanelContainer.new()
	decision.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decision.size_flags_stretch_ratio = 1.3
	console.add_child(decision)
	var box := VBoxContainer.new()
	decision.add_child(box)
	_decision_title = Label.new()
	_decision_title.add_theme_font_size_override("font_size", 16)
	# A long title is cut, never widening the window.
	_decision_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_decision_title)
	_decision_text = RichTextLabel.new()
	_decision_text.bbcode_enabled = true
	_decision_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_decision_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_decision_text.scroll_active = true
	box.add_child(_decision_text)
	_decision_extra = VBoxContainer.new()
	box.add_child(_decision_extra)

	var chronicle := VBoxContainer.new()
	chronicle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console.add_child(chronicle)
	chronicle.add_child(_title_label("Kronika planety"))
	_chronicle = RichTextLabel.new()
	_chronicle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chronicle.scroll_following = true
	_chronicle.selection_enabled = true
	_chronicle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chronicle.add_child(_chronicle)


## Right: actions one under another, then time and the way on.
func _build_right(parent: Control) -> void:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	right.add_theme_constant_override("separation", 6)
	parent.add_child(right)
	var small := Theme.new()
	small.default_font_size = SMALL_FONT
	_perks = PerkPanel.new()
	_perks.theme = small
	_perks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_perks.buy_requested.connect(buy_perk)
	_perks.refund_requested.connect(refund_perk)
	right.add_child(_perks)
	right.add_child(_title_label("Akcje"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_theme_constant_override("separation", 6)
	scroll.add_child(_actions)

	right.add_child(_title_label("Tempo"))
	var speeds := HBoxContainer.new()
	right.add_child(speeds)
	for speed in SPEEDS:
		var button := Button.new()
		button.text = "x%d" % speed
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("speed", speed)
		button.pressed.connect(set_speed.bind(speed))
		_speed_buttons.append(button)
		speeds.add_child(button)
	_pause_button = Button.new()
	_pause_button.text = "Pauza ⏸"
	_pause_button.pressed.connect(toggle_pause)
	right.add_child(_pause_button)
	_continue_button = Button.new()
	_continue_button.text = "Dalej ▶"
	_continue_button.visible = false
	_continue_button.custom_minimum_size = Vector2(0, 44)
	_continue_button.add_theme_font_size_override("font_size", 18)
	_continue_button.pressed.connect(_on_continue)
	right.add_child(_continue_button)
	_goals_button = Button.new()
	_goals_button.text = "Cele ★"
	_goals_button.tooltip_text = "Cel główny, gwiazdki i ambicje: co jest do zdobycia."
	_goals_button.disabled = true
	_goals_button.pressed.connect(show_goals)
	right.add_child(_goals_button)


func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("8fa3b8"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A parameter: name, bar, value and change; value and change cells have
## fixed widths, so new texts never widen the window.
func _fill_params(names: Array) -> void:
	for name: String in names:
		var label := Label.new()
		label.text = name
		_params.add_child(label)
		_params.add_child(_bar())
		_params.add_child(_cell(118, HORIZONTAL_ALIGNMENT_RIGHT))
		_params.add_child(_cell(70, HORIZONTAL_ALIGNMENT_LEFT))


## A species: name, bar, population and change on one line; under it what
## it did to the planet since the last decision.
func _fill_life(names: Array) -> void:
	_life_cells.clear()
	for name: String in names:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		_life.add_child(line)
		var label := Label.new()
		label.text = name
		label.custom_minimum_size = Vector2(80, 0)
		line.add_child(label)
		var bar := _bar()
		line.add_child(bar)
		var value := _cell(70, HORIZONTAL_ALIGNMENT_RIGHT)
		line.add_child(value)
		var change := _cell(70, HORIZONTAL_ALIGNMENT_LEFT)
		line.add_child(change)
		var effects := Label.new()
		effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effects.add_theme_color_override("font_color", Color("9fb4c8"))
		effects.add_theme_font_size_override("font_size", 13)
		effects.visible = false
		_life.add_child(effects)
		_life_cells.append({"bar": bar, "value": value, "change": change, "effects": effects})


func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(30, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bar


func _cell(width: float, alignment: HorizontalAlignment) -> Label:
	var cell := Label.new()
	cell.custom_minimum_size = Vector2(width, 0)
	cell.horizontal_alignment = alignment
	cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	return cell


func _build_actions() -> void:
	_param_ids.clear()
	for row in session.planet_rows():
		_param_ids.append(row["id"])
	_fill_params(session.planet_rows().map(func(r: Dictionary) -> String: return r["name"]))
	_fill_life(session.life_rows().map(func(r: Dictionary) -> String: return r["name"]))
	for action in session.actions():
		var row := {}
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 2)
		_actions.add_child(group)
		var button := Button.new()
		button.text = action["name"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(func() -> void: act(action["id"]))
		group.add_child(button)
		row["button"] = button
		var choices := HBoxContainer.new()
		if action["species"]:
			choices.add_child(_choice(session.species_choices().map(
					func(c: Dictionary) -> Array: return [c["id"], c["name"]]), ""))
			row["species"] = choices.get_child(-1)
		if not (action["levels"] as Array).is_empty():
			choices.add_child(_choice(action["levels"], action["default_level"]))
			row["level"] = choices.get_child(-1)
		if choices.get_child_count() > 0:
			group.add_child(choices)
		else:
			choices.free()
		_action_rows[action["id"]] = row


## A list of [id, name] pairs to choose from, `selected` chosen first.
func _choice(pairs: Array, selected: String) -> OptionButton:
	var list := OptionButton.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.fit_to_longest_item = false
	list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for pair: Array in pairs:
		list.add_item(str(pair[1]))
		list.set_item_metadata(list.item_count - 1, pair[0])
		if pair[0] == selected:
			list.select(list.item_count - 1)
	return list
