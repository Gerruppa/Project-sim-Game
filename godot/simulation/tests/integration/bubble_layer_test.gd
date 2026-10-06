extends GdUnitTestSuite
## The globe projects a latitude/longitude onto the screen (PlanetView.screen_point)
## and the bubble layer lays one clickable button per Spark bubble over it,
## hiding the ones on the far side. Runs headless: no pixels, only positions.

const DATA := {
	"lifetime_seconds": 15,
	"max_visible": 8,
	"ambient": {"every_ticks": 600, "value": 1},
	"discovery": {"value": 4},
	"bloom": {"value": 3, "thresholds": [20, 40, 60]},
}
const SIZE := Vector2(800, 600)

var _planet: PlanetView
var _layer: BubbleLayer


func before_test() -> void:
	_planet = PlanetView.new()
	_planet.auto_spin = false
	_planet.size = SIZE
	add_child(_planet)
	_planet.set_planet(7)


func after_test() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
	_planet.queue_free()


## A field with `count` ambient bubbles on the globe, and a layer over it.
func _open_layer(count: int) -> BubbleField:
	var species: Array[String] = []
	var field: BubbleField = BubbleField.from_data(DATA, 7, species, func(_id: String) -> float: return 0.0).value
	for i in count:
		field.on_tick(600 * (i + 1))
	_layer = BubbleLayer.new()
	_layer.size = SIZE
	_planet.add_child(_layer)
	_layer.setup(_planet, field)
	_layer.refresh()
	return field


## A longitude on the equator that faces the camera.
func _visible_lon() -> float:
	for step in 12:
		var lon := step * 30.0
		if _planet.screen_point(0.0, lon) != null:
			return lon
	return NAN


func test_a_point_on_the_visible_side_has_a_screen_position() -> void:
	await get_tree().process_frame
	var inside := false
	for step in 12:
		var point: Variant = _planet.screen_point(0.0, step * 30.0)
		if point != null and Rect2(Vector2.ZERO, SIZE).has_point(point as Vector2):
			inside = true
	assert_bool(inside).is_true()


func test_the_same_point_is_hidden_after_turning_the_globe_half_way() -> void:
	await get_tree().process_frame
	var lon := _visible_lon()
	assert_bool(is_nan(lon)).is_false()
	assert_object(_planet.screen_point(0.0, lon)).is_not_null()
	_planet.turn(Vector2(PI, 0.0))
	assert_object(_planet.screen_point(0.0, lon)).is_null()


func test_layer_shows_a_button_per_visible_bubble_and_hides_far_side_ones() -> void:
	await get_tree().process_frame
	var field := _open_layer(8)
	var expected: Array[int] = []
	for bubble in field.bubbles():
		if _planet.screen_point(bubble["lat"], bubble["lon"]) != null:
			expected.append(bubble["id"])
	var shown := _layer.visible_bubble_ids()
	shown.sort()
	assert_array(expected).is_not_empty()
	assert_int(expected.size()).is_less(8)
	assert_array(shown).is_equal(expected)
	# Turning the globe moves the buttons with it: the shown set follows the new view.
	_planet.turn(Vector2(1.0, 0.0))
	_layer.refresh()
	var after: Array[int] = []
	for bubble in field.bubbles():
		if _planet.screen_point(bubble["lat"], bubble["lon"]) != null:
			after.append(bubble["id"])
	assert_array(_layer.visible_bubble_ids()).is_equal(after)


func test_pressing_a_bubble_emits_its_id() -> void:
	await get_tree().process_frame
	var field := _open_layer(3)
	var id: int = field.bubbles()[1]["id"]
	monitor_signals(_layer)
	_layer.press(id)
	await assert_signal(_layer).is_emitted("bubble_pressed", [id])


func test_expired_bubble_loses_its_button() -> void:
	await get_tree().process_frame
	var field := _open_layer(3)
	field.update(16.0)
	_layer.refresh()
	assert_array(_layer.visible_bubble_ids()).is_empty()
	assert_int(_layer.get_child_count()).is_equal(0)
