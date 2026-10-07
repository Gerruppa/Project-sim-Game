class_name SpeciesPanel
extends VBoxContainer
## The planting guide in the window: every species with a coloured dot for how
## well the planet suits it now, a few words of why, and a button to plant (or
## release) it. The tooltip lists what the species needs and what the planet
## has. Presentation only: it asks (plant_requested) and whoever listens decides.

signal plant_requested(species_id: String)

const DOT_COLORS := {&"ideal": Color("3fb950"), &"ok": Color("8bc34a"), &"weak": Color("d29922"),
		&"blocked": Color("f85149"), &"waiting": Color("6e7f91")}
const NEED_COLORS := {"good": "3fb950", "poor": "d29922", "bad": "f85149"}

## species id -> {"dot": ColorRect, "name": Label, "verdict": Label, "button": Button, "line": Control}
var _rows := {}
## The ids the rows were built for, in order; a different set rebuilds them.
var _built: Array[String] = []


func _init() -> void:
	add_theme_constant_override("separation", 3)


## Brings the rows in line with SpeciesGuide rows (GameSession.species_guide_rows).
func refresh(rows: Array[Dictionary]) -> void:
	var ids: Array[String] = []
	for row in rows:
		ids.append(row["id"])
	if ids != _built:
		_build(ids)
		_built = ids
	for row in rows:
		_update(row)


## "moss · Ideal" — the line as the player reads it.
func row_text(species_id: String) -> String:
	if not _rows.has(species_id):
		return ""
	return "%s · %s" % [(_rows[species_id]["name"] as Label).text, (_rows[species_id]["verdict"] as Label).text]


## What the species needs and what the planet has, as the tooltip shows it.
func row_tooltip(species_id: String) -> String:
	return (_rows[species_id]["line"] as Control).tooltip_text if _rows.has(species_id) else ""


func plant_button(species_id: String) -> Button:
	return _rows[species_id]["button"] if _rows.has(species_id) else null


func dot_color(species_id: String) -> Color:
	return (_rows[species_id]["dot"] as ColorRect).color if _rows.has(species_id) else Color.TRANSPARENT


## What a press of the species' button asks for (tests call it instead of clicking).
func press(species_id: String) -> void:
	if _rows.has(species_id):
		plant_requested.emit(species_id)


func _build(ids: Array[String]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rows.clear()
	for id in ids:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(line)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(dot)
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(76, 0)
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_child(name_label)
		var verdict := Label.new()
		verdict.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		verdict.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		verdict.add_theme_color_override("font_color", Color("9fb4c8"))
		verdict.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_child(verdict)
		var button := Button.new()
		button.custom_minimum_size = Vector2(70, 0)
		button.pressed.connect(press.bind(id))
		line.add_child(button)
		_rows[id] = {"dot": dot, "name": name_label, "verdict": verdict, "button": button, "line": line}


func _update(row: Dictionary) -> void:
	var entry: Dictionary = _rows[row["id"]]
	(entry["dot"] as ColorRect).color = DOT_COLORS.get(row["verdict"], Color.WHITE)
	(entry["name"] as Label).text = str(row["name"])
	(entry["verdict"] as Label).text = str(row["short"])
	var button: Button = entry["button"]
	button.text = str(row["verb"])
	button.disabled = not row["ready"]
	var lines := PackedStringArray([str(row["label"])])
	for need: Dictionary in row["needs"]:
		lines.append("%s: %s (now %s)" % [need["name"], need["range"], need["now"]])
	(entry["line"] as Control).tooltip_text = "\n".join(lines)
