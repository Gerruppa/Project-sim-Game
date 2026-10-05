class_name GameView
extends Control
## The game in a window: the planet drawn live, its parameters over time,
## life, the chronicle and goals; the run pauses itself at decision points
## and the player acts with buttons. A debug-level visualization (CLAUDE.md:
## simulation -> logs -> debug visualization -> final visualization).
##
## The game is a GameSession, the same one the console plays; this node only
## shows it and turns clicks into GameSession.submit. Options come from the
## command line (as play.sh), or from `options` set before entering the tree.
## Without either (a double-clicked exported game) it starts with a
## new-game screen: random or chosen planet, its character, or the last save.

## Time speeds offered to the player (ticks per second at base rate 1).
const SPEEDS: Array[int] = [10, 100, 1000]
const DEFAULT_SPEED := 100
## Ticks between two chart samples.
const SAMPLE_EVERY := 10
const CHART_PARAMS: Array[String] = ["temperature", "humidity", "oxygen", "biomass", "co2"]
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
var _pause_button: Button
var _speed_buttons: Array[Button] = []
var _planet: PlanetView
var _chart: HistoryChart
var _params: GridContainer
var _life: GridContainer
var _goals: RichTextLabel
var _chronicle: RichTextLabel
var _decision_title: Label
var _decision_text: RichTextLabel
var _actions: HFlowContainer
var _continue_button: Button
var _action_rows := {}
var _error: Label
var _new_game_box: HBoxContainer
var _seed_edit: LineEdit
var _character: OptionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	for row in session.planet_rows():
		if CHART_PARAMS.has(row["id"]):
			_chart.add_series(row["id"], row["name"])
	_build_actions()
	for warning in session.warnings:
		_on_chronicle_line("UWAGA: " + warning)
	if session.new_game:
		_show_intro()
	else:
		start()


## The first screen of a double-clicked game: which planet to play.
func _show_new_game() -> void:
	_decision_title.text = "Genesis Error · nowa planeta"
	_decision_text.text = "Każdy numer to inna planeta. Zostaw pole puste, żeby wylosować; ten sam numer daje zawsze tę samą planetę."
	_new_game_box = HBoxContainer.new()
	_actions.add_child(_new_game_box)
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
	_decision_text.text = "Gra sama się zatrzyma, gdy wydarzy się coś ważnego. Możesz też ją zatrzymać i działać."
	_continue_button.visible = false
	_continue_button.text = "Dalej ▶"
	_refresh()


func _process(delta: float) -> void:
	if session == null or not _running or _at_decision:
		return
	advance(_scheduler.advance(delta))


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
	_decision_text.text = "\n".join(session.advisor.intro)
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
		_decision_text.text = "Gra sama się zatrzyma, gdy wydarzy się coś ważnego. Możesz też ją zatrzymać i działać."
	else:
		_scheduler.pause()
		_decision_title.text = "PAUZA · tick %d · rok %d" % [session.tick(), session.year()]
		_decision_text.text = "Możesz działać; akcja zacznie się w następnym ticku."
	_refresh()


func set_speed(speed: int) -> void:
	if session != null and _scheduler.set_speed(speed):
		_refresh()


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


## The error shown instead of the game (empty when the game runs).
func error_text() -> String:
	return _error.text if _error.visible else ""


func at_decision() -> bool:
	return _at_decision


func chronicle_text() -> String:
	return _chronicle.get_parsed_text()


func decision_text() -> String:
	return _decision_title.text + "\n" + _decision_text.get_parsed_text()


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
	for button in _speed_buttons:
		button.button_pressed = int(button.get_meta("speed")) == _scheduler.speed()
	var values := {}
	var rows := session.planet_rows()
	for i in rows.size():
		values[rows[i]["id"]] = rows[i]["value"]
		if i * 4 + 3 < _params.get_child_count():
			(_params.get_child(i * 4 + 1) as ProgressBar).value = rows[i]["value"]
			(_params.get_child(i * 4 + 2) as Label).text = "%.1f" % rows[i]["value"]
			(_params.get_child(i * 4 + 3) as Label).text = rows[i]["change"]
	_planet.show_state(values)
	var life := session.life_rows()
	for i in life.size():
		if i * 4 + 3 < _life.get_child_count():
			(_life.get_child(i * 4 + 1) as ProgressBar).value = life[i]["population"]
			(_life.get_child(i * 4 + 2) as Label).text = life[i]["shown"]
			(_life.get_child(i * 4 + 3) as Label).text = life[i]["change"]
	_goals.text = "\n".join(_goal_lines())
	var allowed := session.tick() > 0 and (_at_decision or not _running)
	for action in session.actions():
		var row: Dictionary = _action_rows.get(action["id"], {})
		if row.is_empty():
			continue
		var button: Button = row["button"]
		button.disabled = not allowed or not action["ready"]
		button.tooltip_text = action["help"] + ("" if action["ready"] else "\nDostępne od ticku %d." % action["ready_at"])
		button.text = action["name"] + ("" if action["ready"] else " (od %d)" % action["ready_at"])


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
	top.add_child(_info)
	for speed in SPEEDS:
		var button := Button.new()
		button.text = "x%d" % speed
		button.toggle_mode = true
		button.set_meta("speed", speed)
		button.pressed.connect(set_speed.bind(speed))
		_speed_buttons.append(button)
		top.add_child(button)
	_pause_button = Button.new()
	_pause_button.text = "Pauza ⏸"
	_pause_button.pressed.connect(toggle_pause)
	top.add_child(_pause_button)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	root.add_child(middle)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	middle.add_child(left)
	_planet = PlanetView.new()
	_planet.custom_minimum_size = Vector2(280, 280)
	left.add_child(_planet)
	_goals = RichTextLabel.new()
	_goals.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_goals.fit_content = true
	_goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_goals)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(center)
	_chart = HistoryChart.new()
	_chart.custom_minimum_size = Vector2(0, 200)
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_chart)
	var tables := HBoxContainer.new()
	tables.add_theme_constant_override("separation", 20)
	center.add_child(tables)
	_params = _table(tables, "Planeta (zmiana od ostatniej decyzji)")
	_life = _table(tables, "Życie (populacja 0-100)")

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	middle.add_child(right)
	var chronicle_title := Label.new()
	chronicle_title.text = "Kronika planety"
	right.add_child(chronicle_title)
	_chronicle = RichTextLabel.new()
	_chronicle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chronicle.scroll_following = true
	_chronicle.selection_enabled = true
	_chronicle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_chronicle)

	var decision := PanelContainer.new()
	decision.custom_minimum_size = Vector2(0, 190)
	root.add_child(decision)
	var box := VBoxContainer.new()
	decision.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_decision_title = Label.new()
	_decision_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decision_title.add_theme_font_size_override("font_size", 16)
	header.add_child(_decision_title)
	_continue_button = Button.new()
	_continue_button.text = "Dalej ▶"
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue)
	header.add_child(_continue_button)
	_decision_text = RichTextLabel.new()
	_decision_text.bbcode_enabled = true
	_decision_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_decision_text.custom_minimum_size = Vector2(0, 70)
	_decision_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_decision_text.scroll_active = true
	box.add_child(_decision_text)
	_actions = HFlowContainer.new()
	box.add_child(_actions)

	_error = Label.new()
	_error.visible = false
	_error.add_theme_color_override("font_color", Color("ff6b6b"))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_error)


## A titled 4-column table (name, bar, value, change) under `parent`.
func _table(parent: Control, title_text: String) -> GridContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var title := Label.new()
	title.text = title_text
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	column.add_child(grid)
	return grid


func _fill_table(grid: GridContainer, names: Array) -> void:
	for name: String in names:
		var label := Label.new()
		label.text = name
		grid.add_child(label)
		var bar := ProgressBar.new()
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(70, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		var value := Label.new()
		value.custom_minimum_size = Vector2(48, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
		var change := Label.new()
		change.custom_minimum_size = Vector2(52, 0)
		grid.add_child(change)


func _build_actions() -> void:
	_fill_table(_params, session.planet_rows().map(func(r: Dictionary) -> String: return r["name"]))
	_fill_table(_life, session.life_rows().map(func(r: Dictionary) -> String: return r["name"]))
	for action in session.actions():
		var row := {}
		var group := HBoxContainer.new()
		_actions.add_child(group)
		var button := Button.new()
		button.text = action["name"]
		button.pressed.connect(func() -> void: act(action["id"]))
		group.add_child(button)
		row["button"] = button
		if action["species"]:
			var species := OptionButton.new()
			for choice in session.species_choices():
				species.add_item(choice["name"])
				species.set_item_metadata(species.item_count - 1, choice["id"])
			group.add_child(species)
			row["species"] = species
		if not (action["levels"] as Array).is_empty():
			var level := OptionButton.new()
			for pair: Array in action["levels"]:
				level.add_item(str(pair[1]))
				level.set_item_metadata(level.item_count - 1, pair[0])
				if pair[0] == action["default_level"]:
					level.select(level.item_count - 1)
			group.add_child(level)
			row["level"] = level
		_action_rows[action["id"]] = row
