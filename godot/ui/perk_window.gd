class_name PerkWindow
extends PanelContainer
## The perk window: a large card over the globe, opened with the game paused
## so there is time to read. A tab for each branch, in the middle each line of
## perks as a chain of tiers (Cold resistance I, II, III), on the right the
## description of the chosen perk with its price in the world and the Buy
## button. Presentation only: it asks (buy_requested, refund_requested) and
## whoever listens decides; the rows it shows come from GameSession.perk_rows.

signal buy_requested(perk_id: String)
signal refund_requested(perk_id: String)
signal closed

const BACKGROUND := Color(0.06, 0.09, 0.14, 0.97)
const BORDER := Color("3b5573")
const CHIP_COLORS := {"owned": Color("2f7d3b"), "available": Color("b7791f"), "unaffordable": Color("5d6b7a"),
		"locked": Color("2d3a4a"), "queued": Color("3f6fb0")}
const ROMAN: Array[String] = ["", "I", "II", "III"]

var _rows: Array[Dictionary] = []
var _branches: Array[Dictionary] = []
var _sparks := 0
var _branch := ""
var _selected := ""
var _open := false

var _sparks_label: Label
var _tabs: HBoxContainer
var _lines: VBoxContainer
var _detail: RichTextLabel
var _buy: Button
var _tab_buttons: Dictionary[String, Button] = {}
var _line_labels: Array[String] = []
## perk id -> its chip button, for the lines on screen.
var _chips: Dictionary[String, Button] = {}


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Perks"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f2c14e"))
	header.add_child(title)
	_sparks_label = Label.new()
	_sparks_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sparks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_sparks_label)
	var close_button := Button.new()
	close_button.text = "Close (P)"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	root.add_child(_tabs)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.4
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", 10)
	scroll.add_child(_lines)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.custom_minimum_size = Vector2(240, 0)
	body.add_child(side)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_detail)
	_buy = Button.new()
	_buy.custom_minimum_size = Vector2(0, 40)
	_buy.pressed.connect(_on_buy_pressed)
	side.add_child(_buy)


## Shows the window. focus_id: a perk to select (its branch opens first).
func open(rows: Array[Dictionary], branches: Array[Dictionary], sparks: int, focus_id: String = "") -> void:
	_branches = branches
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_branch = str(branches[0]["id"]) if not branches.is_empty() else ""
	_selected = ""
	var focus := _row_of(focus_id, rows)
	if not focus.is_empty():
		_branch = str(focus["branch"])
		_selected = focus_id
	_rows = rows
	_sparks = sparks
	_build_tabs()
	_rebuild()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func is_open() -> bool:
	return _open


## Brings the window in line with the perks and the Sparks (the game keeps
## its own state; this only redraws).
func refresh(rows: Array[Dictionary], sparks: int) -> void:
	_rows = rows
	_sparks = sparks
	_rebuild()


func select(perk_id: String) -> void:
	if not _row_of(perk_id, _rows).is_empty():
		_selected = perk_id
		_rebuild()


func selected_id() -> String:
	return _selected


func current_branch() -> String:
	return _branch


func set_branch(branch_id: String) -> void:
	if _tab_buttons.has(branch_id):
		_branch = branch_id
		_selected = ""
		_rebuild()


func tab_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for branch in _branches:
		labels.append(str(branch["name"]))
	return labels


## The names of the lines of the shown branch, top to bottom.
func line_names() -> PackedStringArray:
	return PackedStringArray(_line_labels)


## "owned", "available", "unaffordable", "locked" or "queued" for a perk on screen ("" if not shown).
func chip_state(perk_id: String) -> String:
	var row := _row_of(perk_id, _rows)
	return "" if row.is_empty() else _state_of(row)


## The description of the chosen perk as plain text.
func detail_text() -> String:
	return _detail.get_parsed_text()


func buy_button() -> Button:
	return _buy


## What a press of the Buy (or Refund) button asks for (tests call it instead of clicking).
func press_buy() -> void:
	_on_buy_pressed()


func _state_of(row: Dictionary) -> String:
	if row["queued"] != "":
		return "queued"
	if row["owned"]:
		return "owned"
	if not row["available"] or not (row["locked_species"] as Array).is_empty():
		return "locked"
	return "available" if row["affordable"] else "unaffordable"


func _row_of(perk_id: String, rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if row["id"] == perk_id:
			return row
	return {}


func _build_tabs() -> void:
	for child in _tabs.get_children():
		_discard(child)
	_tab_buttons.clear()
	for branch in _branches:
		var button := Button.new()
		button.text = str(branch["name"])
		button.tooltip_text = str(branch["help"])
		button.toggle_mode = true
		button.pressed.connect(set_branch.bind(str(branch["id"])))
		_tabs.add_child(button)
		_tab_buttons[str(branch["id"])] = button


func _rebuild() -> void:
	_sparks_label.text = "Sparks: %d" % _sparks
	for id: String in _tab_buttons:
		_tab_buttons[id].button_pressed = id == _branch
	for child in _lines.get_children():
		_discard(child)
	_chips.clear()
	_line_labels.clear()
	var lines: Array[String] = []
	for row in _rows:
		if row["branch"] == _branch and not lines.has(row["line"]):
			lines.append(row["line"])
	if _selected.is_empty() and not lines.is_empty():
		_selected = _first_of(lines[0])
	for line in lines:
		_add_line(line)
	_show_detail()


## Hides a control and frees it at the end of the frame (it may be the one whose
## signal is being handled, so it cannot be freed at once).
func _discard(child: Node) -> void:
	if child is CanvasItem:
		(child as CanvasItem).visible = false
	child.queue_free()


func _first_of(line: String) -> String:
	for row in _rows:
		if row["line"] == line and row["tier"] == 1:
			return row["id"]
	return ""


func _add_line(line: String) -> void:
	var tiers := _rows.filter(func(r: Dictionary) -> bool: return r["line"] == line and r["branch"] == _branch)
	tiers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["tier"] < b["tier"])
	var multi := tiers.size() > 1
	var name := str(tiers[0]["name"]).trim_suffix(" " + ROMAN[int(tiers[0]["tier"])])
	_line_labels.append(name)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_lines.add_child(box)
	var label := Label.new()
	label.text = name
	label.add_theme_color_override("font_color", Color("8fa3b8"))
	box.add_child(label)
	var chain := HBoxContainer.new()
	chain.add_theme_constant_override("separation", 4)
	box.add_child(chain)
	for i in tiers.size():
		var row: Dictionary = tiers[i]
		if i > 0:
			var arrow := Label.new()
			arrow.text = "→"
			chain.add_child(arrow)
		var chip := Button.new()
		chip.text = "%s · %d" % [ROMAN[int(row["tier"])] if multi else "✦", int(row["cost"])]
		chip.custom_minimum_size = Vector2(72, 38)
		chip.toggle_mode = true
		chip.button_pressed = row["id"] == _selected
		chip.pressed.connect(select.bind(str(row["id"])))
		_color_chip(chip, _state_of(row))
		chain.add_child(chip)
		_chips[row["id"]] = chip


func _color_chip(chip: Button, state: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = CHIP_COLORS.get(state, CHIP_COLORS["locked"])
	style.set_corner_radius_all(5)
	style.set_content_margin_all(4)
	for slot: String in ["normal", "hover", "pressed"]:
		chip.add_theme_stylebox_override(slot, style)


func _show_detail() -> void:
	var row := _row_of(_selected, _rows)
	if row.is_empty():
		_detail.text = ""
		_buy.text = ""
		_buy.disabled = true
		return
	var tiers := _rows.filter(func(r: Dictionary) -> bool: return r["line"] == row["line"])
	var lines := PackedStringArray(["[b]%s[/b]" % row["name"]])
	if tiers.size() > 1:
		lines.append("Tier %d of %d" % [row["tier"], tiers.size()])
	lines.append("")
	lines.append("What it does: %s" % row["help"])
	lines.append("Price in the world: %s" % row["side_effect"])
	lines.append("")
	lines.append("Cost: %d Sparks · refund %d" % [row["cost"], row["refund"]])
	if not (row["missing"] as Array).is_empty():
		lines.append("Requires: %s" % ", ".join(PackedStringArray(row["missing"])))
	if not (row["locked_species"] as Array).is_empty():
		lines.append("Discover first: %s" % ", ".join(PackedStringArray(row["locked_species"])))
	_detail.text = "\n".join(lines)
	if row["queued"] != "":
		_buy.text = "Starts on the next tick"
		_buy.disabled = true
	elif row["owned"]:
		_buy.text = "Refund (+%d)" % int(row["refund"])
		_buy.disabled = false
	elif not row["available"] or not (row["locked_species"] as Array).is_empty():
		_buy.text = "Locked"
		_buy.disabled = true
	elif not row["affordable"]:
		_buy.text = "%d more Sparks needed" % maxi(1, int(row["cost"]) - _sparks)
		_buy.disabled = true
	else:
		_buy.text = "Buy (%d)" % int(row["cost"])
		_buy.disabled = false


func _on_buy_pressed() -> void:
	var row := _row_of(_selected, _rows)
	if row.is_empty():
		return
	if row["owned"]:
		refund_requested.emit(_selected)
	else:
		buy_requested.emit(_selected)
