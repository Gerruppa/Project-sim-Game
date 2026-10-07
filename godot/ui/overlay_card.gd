class_name OverlayCard
extends PanelContainer
## A card floating in the middle of the globe: the welcome, the planet to
## choose, a crisis warning, the ending. It says something, offers a few
## buttons and (through content()) room for extra controls. Closed it is
## invisible and lets every click through to the globe.
## Presentation only: it reports which button was pressed and whoever listens decides.

signal button_pressed(id: String)

const BACKGROUND := Color(0.06, 0.09, 0.14, 0.94)
const BORDER := Color("3b5573")
const WIDTH := 520.0

var _title: Label
var _body: RichTextLabel
var _content: VBoxContainer
var _buttons: HBoxContainer
## id -> Button for the buttons of the card being shown.
var _button_by_id: Dictionary[String, Button] = {}


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color("f2c14e"))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_body)
	_content = VBoxContainer.new()
	box.add_child(_content)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 8)
	box.add_child(_buttons)


## buttons: [[id, label], ...], left to right.
func show_card(title: String, body_bbcode: String, buttons: Array) -> void:
	_title.text = title
	_body.text = body_bbcode
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_button_by_id.clear()
	for pair: Array in buttons:
		var button := Button.new()
		button.text = str(pair[1])
		button.custom_minimum_size = Vector2(120, 36)
		button.pressed.connect(press.bind(str(pair[0])))
		_buttons.add_child(button)
		_button_by_id[str(pair[0])] = button
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func hide_card() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return visible


func title_text() -> String:
	return _title.text


## The card's text without markup.
func body_text() -> String:
	return _body.get_parsed_text()


## Room for extra controls between the text and the buttons.
func content() -> VBoxContainer:
	return _content


## The labels of the buttons, left to right.
func button_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for child in _buttons.get_children():
		if not child.is_queued_for_deletion():
			labels.append((child as Button).text)
	return labels


## What a click on the button does (tests call it instead of clicking).
func press(id: String) -> void:
	button_pressed.emit(id)
