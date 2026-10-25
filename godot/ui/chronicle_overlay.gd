class_name ChronicleOverlay
extends PanelContainer
## The chronicle as a translucent news ticker over the top of the globe: the
## last few lines of what happened to the planet. The whole story stays
## available through text() (the window opens it in a dialog). It never takes
## a click: bubbles and the globe underneath stay reachable.

## Lines visible at once.
const MAX_LINES := 6
const BACKGROUND := Color(0.05, 0.08, 0.12, 0.45)

var _shown: RichTextLabel
## Every line, never trimmed; invisible, it gives the plain text of the story.
var _all: RichTextLabel
var _recent: Array[String] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	_shown = RichTextLabel.new()
	_shown.bbcode_enabled = true
	_shown.fit_content = true
	_shown.scroll_active = false
	_shown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shown)
	_all = RichTextLabel.new()
	_all.bbcode_enabled = true
	_all.visible = false
	_all.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_all)


func add_line(bbcode: String) -> void:
	_all.append_text(bbcode + "\n")
	_recent.append(bbcode)
	while _recent.size() > MAX_LINES:
		_recent.remove_at(0)
	_shown.text = "\n".join(_recent)


## The whole chronicle as plain text.
func text() -> String:
	return _all.get_parsed_text()


## The lines on screen, oldest first, as plain text.
func visible_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for line in _shown.get_parsed_text().split("\n"):
		if not line.is_empty():
			lines.append(line)
	return lines
