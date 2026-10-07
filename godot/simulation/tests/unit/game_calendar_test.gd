extends GdUnitTestSuite
## GameCalendar: ticks as the player reads time ("Year 29, November").

const MONTHS: PackedStringArray = ["January", "February", "March", "April", "May", "June", "July", "August",
		"September", "October", "November", "December"]


func test_date_at_tick_zero_is_year_one_january() -> void:
	assert_str(GameCalendar.date_text(0, MONTHS)).is_equal("Year 1, January")


func test_last_tick_of_the_year_is_december() -> void:
	assert_str(GameCalendar.date_text(359, MONTHS)).is_equal("Year 1, December")


func test_the_year_rolls_over() -> void:
	assert_str(GameCalendar.date_text(360, MONTHS)).is_equal("Year 2, January")


func test_year_29_november() -> void:
	assert_str(GameCalendar.date_text(28 * 360 + 10 * 30, MONTHS)).is_equal("Year 29, November")


func test_month_changes_every_thirty_ticks() -> void:
	assert_int(GameCalendar.month_index(29)).is_equal(0)
	assert_int(GameCalendar.month_index(30)).is_equal(1)
	assert_int(GameCalendar.year(719)).is_equal(2)


func test_duration_text() -> void:
	assert_str(GameCalendar.duration_text(150)).is_equal("5 mo.")
	assert_str(GameCalendar.duration_text(1170)).is_equal("3 y. 3 mo.")
	assert_str(GameCalendar.duration_text(0)).is_equal("0 mo.")
	assert_str(GameCalendar.duration_text(720)).is_equal("2 y.")


func test_chronicle_line_gets_a_date_instead_of_a_tick() -> void:
	var line := GameCalendar.localize_line("[Tick 10380] Life takes hold: moss.", MONTHS)
	assert_str(line).is_equal("Year 29, November: Life takes hold: moss.")


func test_a_line_without_a_tick_prefix_is_left_alone() -> void:
	assert_str(GameCalendar.localize_line("WARNING: x", MONTHS)).is_equal("WARNING: x")
	assert_str(GameCalendar.localize_line("Done: Hardiness.", MONTHS)).is_equal("Done: Hardiness.")
