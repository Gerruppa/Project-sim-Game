class_name ThreatStrip
extends VBoxContainer
## The crises over the globe: one line for each that looms (amber) or rages
## (red) with the perks and actions that help against it. Presentation only: a
## press on a helper (counter_pressed) is passed on and whoever listens decides.
## The strip lets the mouse through everywhere except on its buttons, so the
## bubbles underneath stay reachable.

signal counter_pressed(kind: String, id: String)

const WARNED_COLOR := Color(0.55, 0.38, 0.05, 0.55)
const ACTIVE_COLOR := Color(0.55, 0.12, 0.10, 0.55)

## event id -> {"label": Label, "box": HBoxContainer, "buttons": Dictionary (counter id -> Button),
## "kinds": Dictionary (counter id -> kind), "signature": String}
var _rows := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)


## Rows from GameSession.threats().
func refresh(rows: Array[Dictionary]) -> void:
	var seen := {}
	for row in rows:
		var id: String = row["id"]
		seen[id] = true
		if not _rows.has(id) or _rows[id]["signature"] != _signature(row):
			_remove(id)
			_add(row)
		(_rows[id]["label"] as Label).text = _line(row)
	for id: String in _rows.keys():
		if not seen.has(id):
			_remove(id)


## The crisis line as the player reads it ("" when it is not shown).
func row_text(event_id: String) -> String:
	return (_rows[event_id]["label"] as Label).text if _rows.has(event_id) else ""


## The helpers' button texts, a bought one marked with a tick.
func counter_texts(event_id: String) -> PackedStringArray:
	var texts := PackedStringArray()
	if _rows.has(event_id):
		for button: Button in (_rows[event_id]["buttons"] as Dictionary).values():
			texts.append(button.text)
	return texts


## What a press on a helper does (tests call it instead of clicking).
func press_counter(event_id: String, counter_id: String) -> void:
	if _rows.has(event_id) and (_rows[event_id]["kinds"] as Dictionary).has(counter_id):
		counter_pressed.emit(_rows[event_id]["kinds"][counter_id], counter_id)


## What forces a rebuild of a row: its state and its helpers.
func _signature(row: Dictionary) -> String:
	return "%s|%s" % [row["state"], ",".join((row["counters"] as Array).map(
			func(c: Dictionary) -> String: return "%s%s" % [c["id"], c["owned"]]))]


func _line(row: Dictionary) -> String:
	match row["state"]:
		"active":
			return "● %s is under way" % row["name"]
		"pending":
			return "⚠ %s is about to start" % row["name"]
	return "⚠ %s is coming: %s" % [row["name"], row["text"]]


func _add(row: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = ACTIVE_COLOR if row["state"] == "active" else WARNED_COLOR
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := HFlowContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("h_separation", 6)
	panel.add_child(box)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(260, 0)
	box.add_child(label)
	var buttons := {}
	var kinds := {}
	for counter: Dictionary in row["counters"]:
		var button := Button.new()
		button.text = ("✓ " if counter["owned"] else "") + str(counter["name"])
		button.pressed.connect(press_counter.bind(row["id"], counter["id"]))
		box.add_child(button)
		buttons[counter["id"]] = button
		kinds[counter["id"]] = counter["kind"]
	_rows[row["id"]] = {"panel": panel, "label": label, "buttons": buttons, "kinds": kinds, "signature": _signature(row)}


func _remove(id: String) -> void:
	if _rows.has(id):
		(_rows[id]["panel"] as Node).queue_free()
		_rows.erase(id)
