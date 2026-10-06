class_name BubbleLayer
extends Control
## Clickable Spark bubbles laid over the globe: one round button per bubble of
## the BubbleField, placed where its latitude/longitude falls on the screen and
## hidden while that spot is on the far side of the planet. The layer itself
## ignores the mouse so the globe can still be dragged through it; only the
## buttons catch clicks. Presentation only: it never collects a bubble, it
## just tells whoever listens which one was pressed.

signal bubble_pressed(id: int)

const BUTTON_SIZE := 44.0
## Fill colour by bubble kind: ambient is pale, discovery gold, bloom green.
const KIND_COLORS := {
	"ambient": Color("dbe7f2"),
	"discovery": Color("f2c14e"),
	"bloom": Color("6fcf7a"),
}
const DEFAULT_COLOR := Color("dbe7f2")
const TEXT_COLOR := Color("10141c")

var _planet: PlanetView
var _field: BubbleField
## bubble id -> its button.
var _buttons: Dictionary[int, Button] = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(planet: PlanetView, field: BubbleField) -> void:
	_planet = planet
	_field = field


## Brings the buttons in line with the field: new bubbles get a button, gone
## ones lose it, and every button follows the globe's current turn.
func refresh() -> void:
	if _planet == null or _field == null:
		return
	var alive: Dictionary[int, bool] = {}
	for bubble: Dictionary in _field.bubbles():
		var id: int = bubble["id"]
		alive[id] = true
		if not _buttons.has(id):
			_buttons[id] = _make_button(bubble)
		var button := _buttons[id]
		var point: Variant = _planet.screen_point(float(bubble["lat"]), float(bubble["lon"]))
		button.visible = point != null
		if point != null:
			button.position = (point as Vector2) - button.size * 0.5
	for id: int in _buttons.keys():
		if not alive.has(id):
			var gone := _buttons[id]
			remove_child(gone)
			gone.queue_free()
			_buttons.erase(id)


## Ids of the bubbles whose button is showing, oldest first.
func visible_bubble_ids() -> Array[int]:
	var ids: Array[int] = []
	var all: Array[int] = _buttons.keys()
	all.sort()
	for id in all:
		if _buttons[id].visible:
			ids.append(id)
	return ids


## What a click on the bubble does (tests call it instead of clicking).
func press(id: int) -> void:
	bubble_pressed.emit(id)


func _make_button(bubble: Dictionary) -> Button:
	var id: int = bubble["id"]
	var color: Color = KIND_COLORS.get(bubble["kind"], DEFAULT_COLOR)
	var button := Button.new()
	button.text = "+%d" % int(bubble["value"])
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _round_style(color))
	button.add_theme_stylebox_override("hover", _round_style(color.lightened(0.25)))
	button.add_theme_stylebox_override("pressed", _round_style(color.darkened(0.2)))
	button.pressed.connect(press.bind(id))
	add_child(button)
	return button


static func _round_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(BUTTON_SIZE * 0.5))
	style.border_color = Color(1, 1, 1, 0.55)
	style.set_border_width_all(2)
	return style
