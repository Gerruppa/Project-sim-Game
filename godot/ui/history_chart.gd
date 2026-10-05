class_name HistoryChart
extends Control
## Parameters over time as lines on a 0-100 scale, so the player sees trends
## and the moment a crisis began. Keeps the last CAPACITY samples.
## Presentation only.

const CAPACITY := 600
const BACKGROUND := Color("111822")
const GRID := Color(1, 1, 1, 0.08)
const TEXT := Color(1, 1, 1, 0.6)
## Parameter id -> line colour; the legend uses the names given in add_series.
const COLORS := {
	"temperature": Color("ff8a5c"), "humidity": Color("5cc8ff"), "oxygen": Color("b8e986"),
	"biomass": Color("3f9b4a"), "co2": Color("c9a0ff"),
}

var _names := {}
var _series := {}


func add_series(id: String, name: String) -> void:
	_names[id] = name
	_series[id] = []


## values: parameter id -> value; ids without a series are ignored.
func add_sample(values: Dictionary) -> void:
	for id: String in _series:
		var samples: Array = _series[id]
		samples.append(float(values.get(id, 0.0)))
		if samples.size() > CAPACITY:
			samples.pop_front()
	queue_redraw()


func clear() -> void:
	for id: String in _series:
		(_series[id] as Array).clear()
	queue_redraw()


func sample_count() -> int:
	return 0 if _series.is_empty() else (_series.values()[0] as Array).size()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var font := ThemeDB.fallback_font
	for level: int in [0, 25, 50, 75, 100]:
		var y := _y(level)
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID, 1.0)
		draw_string(font, Vector2(4, y - 2), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
	var legend_x := 34.0
	for id: String in _series:
		var color: Color = COLORS.get(id, Color.WHITE)
		var samples: Array = _series[id]
		if samples.size() >= 2:
			var points := PackedVector2Array()
			var step := size.x / float(CAPACITY - 1)
			var start := float(CAPACITY - samples.size()) * step
			for i in samples.size():
				points.append(Vector2(start + i * step, _y(samples[i])))
			draw_polyline(points, color, 2.0, true)
		draw_string(font, Vector2(legend_x, 14), _names[id], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		legend_x += font.get_string_size(_names[id], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0


func _y(value: float) -> float:
	var top := 20.0
	return top + (size.y - top - 4.0) * (1.0 - clampf(value, 0.0, 100.0) / 100.0)
