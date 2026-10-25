class_name LifePathBar
extends VBoxContainer
## The ladder of life over the globe: one chip for each rung (alive, the next
## one with a progress bar, lost, still out of reach) and under it a line
## saying what the next rung needs. This is where the player sees what is
## happening between sowing moss and growing a tree, and what comes next.
## Presentation only.

const CHIP_COLORS := {"alive": Color("2f7d3b"), "next": Color("b7791f"), "lost": Color("9b2c2c"), "later": Color("2d3a4a")}

## species id -> {"chip": PanelContainer, "label": Label, "bar": ProgressBar, "state": String}
var _chips := {}
var _built: Array[String] = []
var _chips_row: HBoxContainer
var _next_label: Label


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_chips_row = HBoxContainer.new()
	_chips_row.add_theme_constant_override("separation", 4)
	add_child(_chips_row)
	_next_label = Label.new()
	_next_label.add_theme_color_override("font_color", Color("c9d6e3"))
	_next_label.add_theme_font_size_override("font_size", 14)
	_next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_next_label)


## Rows from GameSession.life_path().
func refresh(steps: Array[Dictionary]) -> void:
	var ids: Array[String] = []
	for step in steps:
		ids.append(step["id"])
	if ids != _built:
		_build(ids)
		_built = ids
	var next_text := "Every stage of life is alive."
	for step in steps:
		var entry: Dictionary = _chips[step["id"]]
		entry["state"] = step["state"]
		(entry["label"] as Label).text = str(step["name"]).capitalize()
		var style := StyleBoxFlat.new()
		style.bg_color = CHIP_COLORS.get(step["state"], CHIP_COLORS["later"])
		style.set_corner_radius_all(5)
		style.set_content_margin_all(4)
		(entry["chip"] as PanelContainer).add_theme_stylebox_override("panel", style)
		var bar: ProgressBar = entry["bar"]
		bar.visible = step["is_next"]
		bar.value = float(step["progress"]) * 100.0
		(entry["chip"] as Control).tooltip_text = "%s: %s" % [step["name"], _state_words(step)]
		if step["is_next"]:
			var needs := str(step["blocker"])
			next_text = "Next: %s · %s" % [step["name"], needs if not needs.is_empty() else "conditions are right, it will appear soon"]
	_next_label.text = next_text
	_next_label.tooltip_text = next_text


## "alive", "next", "lost" or "later" for a species' chip ("" for an unknown one).
func chip_state(species_id: String) -> String:
	return _chips[species_id]["state"] if _chips.has(species_id) else ""


## The line under the chips: what the next rung needs.
func next_text() -> String:
	return _next_label.text


## 0..1 progress shown on the next rung's chip.
func progress_of(species_id: String) -> float:
	return (_chips[species_id]["bar"] as ProgressBar).value / 100.0 if _chips.has(species_id) else 0.0


func _state_words(step: Dictionary) -> String:
	match step["state"]:
		"alive":
			return "alive"
		"next":
			return "the next stage of life"
		"lost":
			return "died out"
	return "not yet"


func _build(ids: Array[String]) -> void:
	for child in _chips_row.get_children():
		_chips_row.remove_child(child)
		child.queue_free()
	_chips.clear()
	for id in ids:
		var chip := PanelContainer.new()
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		chip.add_child(box)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		box.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 5)
		bar.visible = false
		box.add_child(bar)
		_chips_row.add_child(chip)
		_chips[id] = {"chip": chip, "label": label, "bar": bar, "state": "later"}
