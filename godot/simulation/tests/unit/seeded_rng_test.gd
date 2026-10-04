extends GdUnitTestSuite


func _take(rng: SeededRng, count: int) -> Array[int]:
	var values: Array[int] = []
	for i in count:
		values.append(rng.next_u32())
	return values


func test_derive_seed_is_pinned() -> void:
	# Changing the derivation would silently change every saved world.
	# These values come from SHA-256 computed outside Godot.
	assert_int(SeededRng.derive_seed(42, "climate")).is_equal(593049122033243004)
	assert_int(SeededRng.derive_seed(42, "biosphere")).is_equal(747168132385529869)


func test_same_seed_and_stream_give_same_sequence() -> void:
	var a := SeededRng.new(42, "climate")
	var b := SeededRng.new(42, "climate")
	assert_array(_take(a, 20)).is_equal(_take(b, 20))


func test_different_streams_give_different_sequences() -> void:
	var a := SeededRng.new(42, "climate")
	var b := SeededRng.new(42, "biosphere")
	assert_array(_take(a, 20)).is_not_equal(_take(b, 20))


func test_stream_is_independent_of_other_streams() -> void:
	var alone := SeededRng.new(42, "climate")
	var expected := _take(alone, 10)

	var other := SeededRng.new(42, "biosphere")
	_take(other, 50)
	var with_neighbour := SeededRng.new(42, "climate")
	assert_array(_take(with_neighbour, 10)).is_equal(expected)


func test_restored_state_replays_sequence() -> void:
	var rng := SeededRng.new(7, "events")
	_take(rng, 5)
	var saved := rng.get_state()
	var expected := _take(rng, 10)

	var restored := SeededRng.new(7, "events")
	restored.set_state(saved)
	assert_array(_take(restored, 10)).is_equal(expected)


func test_next_unit_float_stays_in_half_open_range() -> void:
	var rng := SeededRng.new(1, "range")
	for i in 1000:
		var value := rng.next_unit_float()
		assert_float(value).is_greater_equal(0.0)
		assert_float(value).is_less(1.0)


func test_next_range_stays_in_bounds() -> void:
	var rng := SeededRng.new(1, "range")
	for i in 1000:
		var value := rng.next_range(-0.5, 0.5)
		assert_float(value).is_greater_equal(-0.5)
		assert_float(value).is_less(0.5)
