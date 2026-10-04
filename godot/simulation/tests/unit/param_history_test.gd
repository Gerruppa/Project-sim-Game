extends GdUnitTestSuite
## ParamHistory: ring buffers, trend measures and exact save/restore.

const E := preload("res://simulation/tests/support/event_fixtures.gd")

const H := &"humidity"


func test_measures_over_a_window() -> void:
	var history := E.history_of(H, [10.0, 20.0, 30.0, 40.0])
	assert_float(history.measure(ParamHistory.VALUE, H, 0)).is_equal(40.0)
	assert_float(history.measure(ParamHistory.CHANGE, H, 3)).is_equal(30.0)
	assert_float(history.measure(ParamHistory.MEAN, H, 4)).is_equal(25.0)
	assert_float(history.measure(ParamHistory.MEAN, H, 2)).is_equal(35.0)
	assert_float(history.measure(ParamHistory.MIN, H, 3)).is_equal(20.0)
	assert_float(history.measure(ParamHistory.MAX, H, 4)).is_equal(40.0)
	assert_float(history.measure(ParamHistory.RANGE, H, 4)).is_equal(30.0)
	assert_float(history.measure(ParamHistory.ANOMALY, H, 4)).is_equal(15.0)


func test_drop_from_peak_is_a_fraction_of_the_window_maximum() -> void:
	var history := E.history_of(H, [50.0, 80.0, 60.0])
	assert_float(history.measure(ParamHistory.DROP_FROM_PEAK, H, 3)).is_equal_approx(0.25, 1e-12)
	# The peak left the window: only 60 remains.
	assert_float(history.measure(ParamHistory.DROP_FROM_PEAK, H, 1)).is_equal(0.0)


func test_drop_from_peak_of_an_empty_planet_is_zero() -> void:
	var history := E.history_of(H, [0.0, 0.0])
	assert_float(history.measure(ParamHistory.DROP_FROM_PEAK, H, 2)).is_equal(0.0)


func test_ring_buffer_keeps_only_the_newest_samples() -> void:
	var history := E.history_of(H, [1.0, 2.0, 3.0, 4.0, 5.0], 3)
	assert_int(history.recorded()).is_equal(5)
	assert_float(history.ago(H, 0)).is_equal(5.0)
	assert_float(history.ago(H, 2)).is_equal(3.0)
	assert_float(history.measure(ParamHistory.MEAN, H, 3)).is_equal(4.0)


func test_samples_needed_by_measure() -> void:
	assert_int(ParamHistory.samples_needed(ParamHistory.VALUE, 0)).is_equal(1)
	assert_int(ParamHistory.samples_needed(ParamHistory.CHANGE, 10)).is_equal(11)
	assert_int(ParamHistory.samples_needed(ParamHistory.MEAN, 10)).is_equal(10)


func test_save_and_restore_continue_bit_identically() -> void:
	var values := [0.1, 0.2, 0.30000000000000004, 1.0 / 3.0, 7.7, 2.0 / 7.0, 9.9]
	var continuous := E.history_of(H, values, 4)
	var interrupted := E.history_of(H, values.slice(0, 5), 4)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(interrupted.to_dict()))
	var restored := ParamHistory.new({H: 4})
	assert_bool(restored.load_dict(saved).is_ok()).is_true()
	for value: float in values.slice(5):
		restored.record(E.snapshot({"humidity": value}))
	assert_int(restored.recorded()).is_equal(continuous.recorded())
	for k in 4:
		assert_float(restored.ago(H, k)).is_equal(continuous.ago(H, k))
	assert_float(restored.measure(ParamHistory.MEAN, H, 4)).is_equal(continuous.measure(ParamHistory.MEAN, H, 4))


func test_restore_rejects_mismatched_data() -> void:
	var history := ParamHistory.new({H: 4})
	var saved := E.history_of(H, [1.0, 2.0], 4).to_dict()
	saved["recorded"] = 3
	assert_bool(history.load_dict(saved).is_ok()).is_false()
	assert_bool(ParamHistory.new({&"oxygen": 4}).load_dict(E.history_of(H, [1.0], 4).to_dict()).is_ok()).is_false()
	assert_bool(history.load_dict({"format": "other"}).is_ok()).is_false()


func test_failed_restore_keeps_the_previous_history() -> void:
	var history := E.history_of(H, [1.0, 2.0], 4)
	var broken := history.to_dict()
	broken["recorded"] = 9
	history.load_dict(broken)
	assert_int(history.recorded()).is_equal(2)
	assert_float(history.ago(H, 0)).is_equal(2.0)


func test_empty_history_round_trips() -> void:
	var saved := ParamHistory.new({H: 4}).to_dict()
	var restored := ParamHistory.new({H: 4})
	assert_bool(restored.load_dict(JSON.parse_string(JSON.stringify(saved))).is_ok()).is_true()
	assert_int(restored.recorded()).is_equal(0)


func test_measures_follow_every_new_sample() -> void:
	# Window folds are cached per tick; a new sample must invalidate them.
	var history := E.history_of(H, [10.0, 20.0], 2)
	assert_float(history.measure(ParamHistory.MEAN, H, 2)).is_equal(15.0)
	assert_float(history.measure(ParamHistory.MAX, H, 2)).is_equal(20.0)
	history.record(E.snapshot({"humidity": 40.0}))
	assert_float(history.measure(ParamHistory.MEAN, H, 2)).is_equal(30.0)
	assert_float(history.measure(ParamHistory.MAX, H, 2)).is_equal(40.0)
	assert_float(history.measure(ParamHistory.DROP_FROM_PEAK, H, 2)).is_equal(0.0)
