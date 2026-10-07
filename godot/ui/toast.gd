class_name Toast
extends Label
## A short message over the globe ("Moss takes hold!") that fades by itself.
## Never takes a click.

var _remaining := 0.0
var _lifetime := 1.0


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", Color("f2c14e"))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("outline_size", 6)


func show_text(message: String, seconds: float = 4.0) -> void:
	text = message
	_lifetime = maxf(seconds, 0.1)
	_remaining = _lifetime
	modulate.a = 1.0
	visible = true


## What is on screen now ("" once it faded).
func current_text() -> String:
	return text if visible else ""


## Ages the message; the last quarter of its life is a fade.
func advance(seconds: float) -> void:
	if not visible:
		return
	_remaining -= seconds
	if _remaining <= 0.0:
		visible = false
		text = ""
		return
	modulate.a = clampf(_remaining / (_lifetime * 0.25), 0.0, 1.0)


func _process(delta: float) -> void:
	advance(delta)
