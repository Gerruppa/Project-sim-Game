extends GdUnitTestSuite

var _scheduler: TickScheduler


func before_test() -> void:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	_scheduler = TickScheduler.new(config)


func test_starts_at_x1_and_running() -> void:
	assert_int(_scheduler.speed()).is_equal(1)
	assert_bool(_scheduler.is_paused()).is_false()
	assert_float(_scheduler.ticks_per_second()).is_equal(1.0)


func test_one_second_at_x1_is_one_tick() -> void:
	assert_int(_scheduler.advance(1.0)).is_equal(1)


func test_fractions_accumulate_without_losing_ticks() -> void:
	# 10 x 0.1 s sums to 0.9999999999999999 in floating point.
	var total := 0
	for i in 10:
		total += _scheduler.advance(0.1)
	assert_int(total).is_equal(1)


func test_speed_multiplies_tick_rate() -> void:
	assert_bool(_scheduler.set_speed(100)).is_true()
	assert_int(_scheduler.advance(1.0)).is_equal(100)
	assert_float(_scheduler.ticks_per_second()).is_equal(100.0)


func test_rejects_speed_not_in_config() -> void:
	assert_bool(_scheduler.set_speed(5)).is_false()
	assert_int(_scheduler.speed()).is_equal(1)


func test_changing_speed_keeps_partial_progress() -> void:
	_scheduler.advance(0.5)
	_scheduler.set_speed(10)
	assert_int(_scheduler.advance(0.05)).is_equal(1)


func test_pause_stops_ticks_and_resume_continues() -> void:
	_scheduler.advance(0.5)
	_scheduler.pause()
	assert_bool(_scheduler.is_paused()).is_true()
	assert_float(_scheduler.ticks_per_second()).is_equal(0.0)
	assert_int(_scheduler.advance(10.0)).is_equal(0)
	_scheduler.resume()
	assert_int(_scheduler.advance(0.5)).is_equal(1)


func test_resume_keeps_selected_speed() -> void:
	_scheduler.set_speed(10)
	_scheduler.pause()
	_scheduler.resume()
	assert_int(_scheduler.speed()).is_equal(10)


func test_catch_up_is_limited_and_counted() -> void:
	assert_int(_scheduler.advance(5000.0)).is_equal(1000)
	assert_int(_scheduler.dropped_ticks()).is_equal(4000)


func test_invalid_real_time_is_ignored() -> void:
	assert_int(_scheduler.advance(-1.0)).is_equal(0)
	assert_int(_scheduler.advance(NAN)).is_equal(0)
	assert_int(_scheduler.advance(1.0)).is_equal(1)


func test_is_due_follows_interval() -> void:
	assert_bool(TickScheduler.is_due(1, 1)).is_true()
	assert_bool(TickScheduler.is_due(59, 60)).is_false()
	assert_bool(TickScheduler.is_due(60, 60)).is_true()
	assert_bool(TickScheduler.is_due(120, 60)).is_true()
