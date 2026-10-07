extends GdUnitTestSuite
## BubbleField: collectible Spark bubbles on the globe (game layer).

const SPECIES: Array[String] = ["moss", "algae"]


func _data(overrides: Dictionary = {}) -> Dictionary:
	var data := {
		"bubbles_version": 1, "lifetime_seconds": 15, "max_visible": 8,
		"ambient": {"every_ticks": 600, "value": 1},
		"discovery": {"value": 4},
		"bloom": {"value": 3, "thresholds": [20, 40, 60]},
	}
	data.merge(overrides, true)
	return data


## populations: species id -> population the field reads on every tick.
func _field(populations: Dictionary = {}, seed_value: int = 7, overrides: Dictionary = {}) -> BubbleField:
	var reader := func(id: String) -> float: return float(populations.get(id, 0.0))
	var result := BubbleField.from_data(_data(overrides), seed_value, SPECIES, reader)
	assert(result.is_ok(), "fixture data must be valid: %s" % [result.errors])
	return result.value


func _errors(overrides: Dictionary) -> String:
	var result := BubbleField.from_data(_data(overrides), 1, SPECIES, func(_id: String) -> float: return 0.0)
	assert_bool(result.is_ok()).is_false()
	return "\n".join(result.errors)


func _emerged(tick: int, species: String) -> SimEvent:
	return SimEvent.new(&"species_emerged", tick, &"biosphere", {"species": species, "population": 1.0})


func _kinds(field: BubbleField) -> Array[String]:
	var kinds: Array[String] = []
	for bubble: Dictionary in field.bubbles():
		kinds.append(bubble["kind"])
	return kinds


func test_project_data_is_valid() -> void:
	var result := BubbleField.load_json(BubbleField.DEFAULT_PATH, 1, SPECIES, func(_id: String) -> float: return 0.0)
	assert_bool(result.is_ok()).is_true()
	var field: BubbleField = result.value
	assert_float(field.lifetime()).is_equal(15.0)
	assert_array(field.bubbles()).is_empty()


func test_load_json_reports_missing_file() -> void:
	var result := BubbleField.load_json("res://resources/bubbles/nope.json", 1, SPECIES, func(_id: String) -> float: return 0.0)
	assert_bool(result.is_ok()).is_false()


func test_ambient_bubble_every_600_ticks() -> void:
	var field := _field()
	field.on_tick(600)
	field.on_tick(900)
	assert_int(field.bubbles().size()).is_equal(1)
	field.on_tick(1200)
	var bubbles := field.bubbles()
	assert_int(bubbles.size()).is_equal(2)
	for bubble: Dictionary in bubbles:
		assert_str(bubble["kind"]).is_equal("ambient")
		assert_int(bubble["value"]).is_equal(1)
	field.on_tick(300)
	assert_int(field.bubbles().size()).is_equal(2)


func test_no_ambient_bubble_before_the_first_interval() -> void:
	var field := _field()
	field.on_tick(1)
	field.on_tick(599)
	assert_array(field.bubbles()).is_empty()


func test_species_emerged_spawns_a_discovery_bubble_worth_4() -> void:
	var field := _field()
	field.on_event(_emerged(10, "moss"))
	var bubbles := field.bubbles()
	assert_int(bubbles.size()).is_equal(1)
	assert_str(bubbles[0]["kind"]).is_equal("discovery")
	assert_int(bubbles[0]["value"]).is_equal(4)


func test_other_events_spawn_nothing() -> void:
	var field := _field()
	field.on_event(SimEvent.new(&"species_extinct", 10, &"biosphere", {"species": "moss"}))
	assert_array(field.bubbles()).is_empty()


func test_tick_applied_event_drives_on_tick() -> void:
	var field := _field()
	field.on_event(SimEvent.new(SimEvent.TICK_APPLIED, 600, &"manager", {}))
	assert_array(_kinds(field)).contains_exactly(["ambient"])


func test_attach_subscribes_to_the_bus() -> void:
	var field := _field()
	var bus := EventBus.new()
	field.attach(bus)
	bus.publish(SimEvent.new(SimEvent.TICK_APPLIED, 600, &"manager", {}))
	bus.publish(_emerged(600, "moss"))
	bus.flush()
	assert_array(_kinds(field)).contains_exactly(["ambient", "discovery"])


func test_bloom_spawns_once_per_threshold() -> void:
	var populations := {"moss": 25.0}
	var field := _field(populations)
	field.on_tick(1)
	assert_array(_kinds(field)).contains_exactly(["bloom"])
	assert_int(field.bubbles()[0]["value"]).is_equal(3)
	field.on_tick(2)
	assert_int(field.bubbles().size()).is_equal(1)
	populations["moss"] = 45.0
	field.on_tick(3)
	assert_array(_kinds(field)).contains_exactly(["bloom", "bloom"])
	populations["moss"] = 10.0
	field.on_tick(4)
	populations["moss"] = 25.0
	field.on_tick(5)
	assert_int(field.bubbles().size()).is_equal(2)


func test_bloom_is_tracked_per_species() -> void:
	var populations := {"moss": 25.0, "algae": 25.0}
	var field := _field(populations)
	field.on_tick(1)
	assert_array(_kinds(field)).contains_exactly(["bloom", "bloom"])


func test_collect_returns_value_once() -> void:
	var field := _field()
	field.on_event(_emerged(10, "moss"))
	var id: int = field.bubbles()[0]["id"]
	assert_int(field.collect(id)).is_equal(4)
	assert_int(field.collect(id)).is_equal(0)
	assert_array(field.bubbles()).is_empty()


func test_collect_unknown_id_returns_zero() -> void:
	assert_int(_field().collect(99)).is_equal(0)


func test_ids_increase_from_one() -> void:
	var field := _field()
	field.on_event(_emerged(1, "moss"))
	field.on_event(_emerged(2, "algae"))
	var bubbles := field.bubbles()
	assert_int(bubbles[0]["id"]).is_equal(1)
	assert_int(bubbles[1]["id"]).is_equal(2)


func test_bubble_expires_after_lifetime_seconds() -> void:
	var field := _field()
	field.on_event(_emerged(1, "moss"))
	field.update(0.0)
	assert_float(field.bubbles()[0]["age"]).is_equal(0.0)
	field.update(14.9)
	assert_int(field.bubbles().size()).is_equal(1)
	assert_float(field.bubbles()[0]["age"]).is_equal_approx(14.9, 0.0001)
	field.update(0.2)
	assert_array(field.bubbles()).is_empty()


func test_bubbles_returns_copies() -> void:
	var field := _field()
	field.on_event(_emerged(1, "moss"))
	var copy := field.bubbles()
	copy[0]["value"] = 999
	copy.clear()
	assert_int(field.bubbles()[0]["value"]).is_equal(4)


func test_max_visible_drops_the_oldest() -> void:
	var field := _field({}, 7, {"max_visible": 3})
	for i in 4:
		field.on_event(_emerged(i, "moss"))
	var ids: Array[int] = []
	for bubble: Dictionary in field.bubbles():
		ids.append(bubble["id"])
	assert_array(ids).contains_exactly([2, 3, 4])


func test_positions_are_deterministic_for_a_seed_and_within_range() -> void:
	var first := _field({}, 42)
	var second := _field({}, 42)
	var other := _field({}, 43)
	for i in 20:
		first.on_event(_emerged(i, "moss"))
		second.on_event(_emerged(i, "moss"))
		other.on_event(_emerged(i, "moss"))
	var a := first.bubbles()
	var b := second.bubbles()
	var c := other.bubbles()
	var differs := false
	for i in a.size():
		assert_bool(a[i]["lat"] == b[i]["lat"] and a[i]["lon"] == b[i]["lon"]).is_true()
		assert_float(a[i]["lat"]).is_between(-80.0, 80.0)
		assert_float(a[i]["lon"]).is_between(-180.0, 180.0)
		differs = differs or a[i]["lat"] != c[i]["lat"]
	assert_bool(differs).is_true()
	# Two bubbles of one field do not all sit in the same place.
	assert_bool(a[0]["lat"] != a[1]["lat"] or a[0]["lon"] != a[1]["lon"]).is_true()


func test_save_state_keeps_bloom_milestones_not_bubbles() -> void:
	var populations := {"moss": 45.0}
	var field := _field(populations)
	field.on_tick(700)
	assert_int(field.bubbles().size()).is_equal(2)
	var saved := field.save_state()
	var restored := _field(populations)
	restored.load_state(saved)
	assert_array(restored.bubbles()).is_empty()
	restored.on_tick(701)
	assert_array(restored.bubbles()).is_empty()
	# Ambient timing and ids continue.
	restored.on_tick(1300)
	var bubbles := restored.bubbles()
	assert_int(bubbles.size()).is_equal(1)
	assert_int(bubbles[0]["id"]).is_greater(2)
	# A higher threshold than the saved one still blooms.
	populations["moss"] = 65.0
	restored.on_tick(1301)
	assert_array(_kinds(restored)).contains_exactly(["ambient", "bloom"])


func test_save_state_survives_a_json_round_trip() -> void:
	var field := _field({"moss": 45.0})
	field.on_tick(700)
	var json := JSON.new()
	assert_int(json.parse(JSON.stringify(field.save_state()))).is_equal(OK)
	var restored := _field({"moss": 45.0})
	restored.load_state(json.data)
	restored.on_tick(701)
	assert_array(restored.bubbles()).is_empty()


func test_load_state_ignores_damaged_data() -> void:
	var field := _field()
	field.load_state({"bloom": "nonsense", "next_id": "x"})
	field.on_event(_emerged(1, "moss"))
	assert_int(field.bubbles()[0]["id"]).is_equal(1)


func test_rejects_bad_data() -> void:
	assert_str(_errors({"bloom": {"value": 3, "thresholds": [20, 140]}})).contains("thresholds")
	assert_str(_errors({"bloom": {"value": 3, "thresholds": [-5, 40]}})).contains("thresholds")
	assert_str(_errors({"bloom": {"value": 3, "thresholds": [40, 20]}})).contains("thresholds")
	assert_str(_errors({"bloom": {"value": 3, "thresholds": []}})).contains("thresholds")
	assert_str(_errors({"ambient": {"every_ticks": 0, "value": 1}})).contains("every_ticks")
	assert_str(_errors({"ambient": {"every_ticks": -600, "value": 1}})).contains("every_ticks")
	assert_str(_errors({"ambient": {"every_ticks": 600.5, "value": 1}})).contains("every_ticks")
	assert_str(_errors({"lifetime_seconds": 0})).contains("lifetime_seconds")
	assert_str(_errors({"max_visible": 0})).contains("max_visible")
	assert_str(_errors({"discovery": {"value": 0}})).contains("value")
	assert_str(_errors({"discovery": {"value": 4, "extra": 1}})).contains("extra")
	assert_str(_errors({"colour": 1})).contains("colour")


func test_reports_all_errors_at_once() -> void:
	var result := BubbleField.from_data(_data({"lifetime_seconds": 0, "max_visible": 0, "ambient": {"every_ticks": 0, "value": 1}}),
			1, SPECIES, func(_id: String) -> float: return 0.0)
	assert_int(result.errors.size()).is_greater_equal(3)


## "ambient.value" etc. above the most one grant can pay would let a collect fail after the bubble is gone.
func test_rejects_values_above_the_perk_systems_max_grant() -> void:
	var limit := int(PerkSystem.MAX_GRANT)
	assert_str(_errors({"ambient": {"every_ticks": 600, "value": limit + 1}})).contains("ambient.value")
	assert_str(_errors({"discovery": {"value": limit + 1}})).contains("discovery.value")
	assert_str(_errors({"bloom": {"value": limit + 1, "thresholds": [20]}})).contains("bloom.value")
	var all_three := BubbleField.from_data(_data({"ambient": {"every_ticks": 600, "value": 500}, "discovery": {"value": 101},
			"bloom": {"value": 1000, "thresholds": [20]}}), 1, SPECIES, func(_id: String) -> float: return 0.0)
	assert_int(all_three.errors.size()).is_equal(3)
	var at_the_limit := BubbleField.from_data(_data({"ambient": {"every_ticks": 600, "value": limit}, "discovery": {"value": limit},
			"bloom": {"value": limit, "thresholds": [20]}}), 1, SPECIES, func(_id: String) -> float: return 0.0)
	assert_bool(at_the_limit.is_ok()).is_true()


## The shortest way round the globe between two longitudes, in degrees.
func _lon_gap(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0


func test_center_provider_places_bubbles_near_the_center() -> void:
	var field := _field()
	field.set_center_provider(func() -> Vector2: return Vector2(10.0, 170.0))
	for i in 8:
		field.on_tick(600 * (i + 1))
	assert_int(field.bubbles().size()).is_equal(8)
	for bubble: Dictionary in field.bubbles():
		assert_float(bubble["lat"]).is_between(10.0 - 25.0, 10.0 + 25.0)
		assert_float(_lon_gap(bubble["lon"], 170.0)).is_between(-35.0, 35.0)
		assert_float(bubble["lon"]).is_between(-180.0, 180.0)


func test_center_provider_clamps_latitude_and_wraps_longitude() -> void:
	var field := _field()
	field.set_center_provider(func() -> Vector2: return Vector2(-79.0, -179.0))
	for i in 8:
		field.on_tick(600 * (i + 1))
	var wrapped := false
	for bubble: Dictionary in field.bubbles():
		assert_float(bubble["lat"]).is_between(-80.0, -79.0 + 25.0)
		assert_float(bubble["lon"]).is_between(-180.0, 180.0)
		assert_float(_lon_gap(bubble["lon"], -179.0)).is_between(-35.0, 35.0)
		wrapped = wrapped or float(bubble["lon"]) > 100.0
	assert_bool(wrapped).override_failure_message("no bubble crossed the date line").is_true()


func test_center_provider_follows_the_view_at_every_spawn() -> void:
	var field := _field()
	var center := [Vector2(0.0, 0.0)]
	field.set_center_provider(func() -> Vector2: return center[0])
	field.on_tick(600)
	center[0] = Vector2(0.0, 120.0)
	field.on_tick(1200)
	var bubbles := field.bubbles()
	assert_float(_lon_gap(bubbles[0]["lon"], 0.0)).is_between(-35.0, 35.0)
	assert_float(_lon_gap(bubbles[1]["lon"], 120.0)).is_between(-35.0, 35.0)


func test_center_provider_keeps_a_seed_deterministic() -> void:
	var a := _field({}, 7)
	var b := _field({}, 7)
	for field: BubbleField in [a, b]:
		field.set_center_provider(func() -> Vector2: return Vector2(5.0, 60.0))
		for i in 4:
			field.on_tick(600 * (i + 1))
	assert_array(a.bubbles()).is_equal(b.bubbles())


func test_without_a_provider_bubbles_still_spread_over_the_whole_globe() -> void:
	var field := _field()
	for i in 8:
		field.on_tick(600 * (i + 1))
	var far := false
	for bubble: Dictionary in field.bubbles():
		far = far or absf(float(bubble["lon"])) > 90.0
	assert_bool(far).is_true()


func test_collected_count_counts_each_bubble_once() -> void:
	var field := _field()
	field.on_event(_emerged(1, "moss"))
	field.on_event(_emerged(2, "algae"))
	assert_int(field.collected_count()).is_equal(0)
	var id: int = field.bubbles()[0]["id"]
	field.collect(id)
	field.collect(id)
	assert_int(field.collected_count()).is_equal(1)


func test_collected_count_is_saved_and_old_saves_start_at_zero() -> void:
	var field := _field()
	field.on_event(_emerged(1, "moss"))
	field.collect(field.bubbles()[0]["id"])
	var restored := _field()
	restored.load_state(field.save_state())
	assert_int(restored.collected_count()).is_equal(1)
	restored.load_state({"bloom": {}, "next_id": 3})
	assert_int(restored.collected_count()).is_equal(0)
