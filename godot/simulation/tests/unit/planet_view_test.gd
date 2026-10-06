extends GdUnitTestSuite
## The globe shows the planet's state: PlanetView.look turns values into what
## is drawn (tests read the look, not pixels), and the player turns it.

const START := {"temperature": 30.0, "humidity": 15.0, "oxygen": 2.0, "cloud_cover": 10.0}


func _with(changes: Dictionary) -> Dictionary:
	var values := START.duplicate()
	values.merge(changes, true)
	return PlanetView.look(values, {})


func test_cold_brings_the_ice_toward_the_equator() -> void:
	var start: float = _with({})["ice_line"]
	assert_float(_with({"temperature": 10.0})["ice_line"]).is_less(start)
	assert_float(_with({"temperature": 0.0})["ice_line"]).is_equal_approx(0.25, 0.0001)
	# Hot planet: no ice at all (the edge is above the pole, |sin| = 1).
	assert_float(_with({"temperature": 60.0})["ice_line"]).is_greater(1.0)


func test_a_wet_planet_has_more_sea_and_less_desert() -> void:
	var dry := _with({"humidity": 5.0})
	var wet := _with({"humidity": 50.0})
	assert_float(wet["sea_level"]).is_less(dry["sea_level"])
	assert_float(wet["dryness"]).is_equal(0.0)
	assert_float(dry["dryness"]).is_greater(0.9)


func test_oxygen_turns_the_air_blue() -> void:
	var thin: Color = _with({"oxygen": 0.0})["air_color"]
	var rich: Color = _with({"oxygen": 30.0})["air_color"]
	assert_bool(thin == PlanetView.LOW_O2_AIR).is_true()
	assert_bool(rich == PlanetView.RICH_O2_AIR).is_true()
	assert_float(_with({"oxygen": 30.0})["air_strength"]).is_greater(_with({"oxygen": 0.0})["air_strength"])


func test_life_covers_its_share_of_the_ground() -> void:
	var look := PlanetView.look(START, {"algae": 30.0, "tree": 90.0})
	assert_float(look["algae"]).is_equal_approx(0.5, 0.0001)
	assert_float(look["tree"]).is_equal(1.0)
	assert_float(look["moss"]).is_equal(0.0)


func test_the_player_turns_and_zooms_within_limits() -> void:
	var view: PlanetView = auto_free(PlanetView.new())
	view.auto_spin = false
	view.turn(Vector2(0.5, 10.0))
	assert_float(view.rotation_now().x).is_equal_approx(PlanetView.MAX_TILT, 0.0001)
	assert_float(view.rotation_now().y).is_equal_approx(0.5, 0.0001)
	view.zoom(-100.0)
	assert_float(view.distance()).is_equal_approx(PlanetView.ZOOM_MIN, 0.0001)
	view.zoom(100.0)
	assert_float(view.distance()).is_equal_approx(PlanetView.ZOOM_MAX, 0.0001)


func test_show_state_keeps_the_look() -> void:
	var view: PlanetView = auto_free(PlanetView.new())
	view.show_state({"temperature": 10.0}, {"moss": 60.0})
	assert_float(view.current_look()["moss"]).is_equal(1.0)
	assert_float(view.current_look()["ice_line"]).is_less(_with({})["ice_line"])
