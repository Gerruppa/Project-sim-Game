class_name PerkPanel
extends VBoxContainer
## The perk shop in the window: every perk of the two trees ("Środowisko" and
## "Życie") with its cost and a Buy button, or a Refund button once owned.
## Presentation only: it asks (buy_requested / refund_requested) and whoever
## listens decides; the rows it shows come from GameSession.perk_rows.

signal buy_requested(perk_id: String)
signal refund_requested(perk_id: String)

## Tree id -> header text, in the order the trees are shown.
const TREES := {"environment": "Środowisko", "life": "Życie"}
const HEADER_COLOR := Color("8fa3b8")
## The list scrolls inside this height, so ten perks never push the actions out of the window.
const LIST_HEIGHT := 150.0

var _title: Label
var _list: VBoxContainer
## perk id -> {"label": Label, "button": Button, "owned": bool}
var _rows := {}
var _headers: Array[String] = []
## The ids the list was built for, in order; a different set rebuilds it.
var _built: Array[String] = []


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_title = Label.new()
	_title.add_theme_color_override("font_color", HEADER_COLOR)
	add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)


## Brings the rows in line with the perks and the Sparks held.
func refresh(rows: Array[Dictionary], sparks: int) -> void:
	_title.text = "Perki (Iskry: %d)" % sparks
	var ids: Array[String] = []
	for row in rows:
		ids.append(row["id"])
	if ids != _built:
		_build(rows)
		_built = ids
	for row in rows:
		_update(row)


## The perk's line: name, cost and, while a requirement is missing, what it is.
func row_text(perk_id: String) -> String:
	return (_rows[perk_id]["label"] as Label).text if _rows.has(perk_id) else ""


func buy_button(perk_id: String) -> Button:
	return _rows[perk_id]["button"] if _rows.has(perk_id) else null


## The headers of the trees shown, in order.
func headers() -> Array[String]:
	return _headers.duplicate()


## What a press of the perk's button asks for: a refund once it is owned,
## buying otherwise (tests call it instead of clicking).
func press(perk_id: String) -> void:
	if not _rows.has(perk_id):
		return
	if _rows[perk_id]["owned"]:
		refund_requested.emit(perk_id)
	else:
		buy_requested.emit(perk_id)


func _build(rows: Array[Dictionary]) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_headers.clear()
	var trees: Array[String] = []
	for tree: String in TREES:
		trees.append(tree)
	for row in rows:
		if not trees.has(row["tree"]):
			trees.append(row["tree"])
	for tree in trees:
		var in_tree := rows.filter(func(row: Dictionary) -> bool: return row["tree"] == tree)
		if in_tree.is_empty():
			continue
		var header := Label.new()
		header.text = TREES.get(tree, tree)
		header.add_theme_color_override("font_color", HEADER_COLOR)
		_list.add_child(header)
		_headers.append(header.text)
		for row: Dictionary in in_tree:
			_add_row(row["id"])


func _add_row(perk_id: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	_list.add_child(line)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(84, 0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(press.bind(perk_id))
	line.add_child(button)
	_rows[perk_id] = {"label": label, "button": button, "owned": false}


func _update(row: Dictionary) -> void:
	var entry: Dictionary = _rows[row["id"]]
	var label: Label = entry["label"]
	var button: Button = entry["button"]
	var text := "%s · %d" % [row["name"], int(row["cost"])]
	if not row["available"]:
		text += "\nwymaga: " + ", ".join(PackedStringArray(row["missing"]))
	label.text = text
	var tip := str(row["help"])
	if not str(row["side_effect"]).is_empty():
		tip += "\n" + str(row["side_effect"])
	label.tooltip_text = tip
	button.tooltip_text = tip
	entry["owned"] = row["owned"]
	if row["owned"]:
		button.text = "Cofnij (+%d)" % int(row["refund"])
		button.disabled = false
	else:
		button.text = "Kup"
		button.disabled = not (row["available"] and row["affordable"])
