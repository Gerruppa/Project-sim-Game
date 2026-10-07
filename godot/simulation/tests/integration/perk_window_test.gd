extends GdUnitTestSuite
## The perk window: a card over the globe with a tab for each branch, a chain
## of tiers for each line and the description of the chosen perk.

var _window: PerkWindow


func before_test() -> void:
	_window = PerkWindow.new()
	add_child(_window)


func after_test() -> void:
	_window.queue_free()


func _branches() -> Array[Dictionary]:
	return [{"id": "resistance", "name": "Resistance", "help": "Life that endures."},
			{"id": "sowing", "name": "Sowing", "help": "More life planted."}]


func _row(id: String, branch: String, line: String, tier: int, name: String, cost: int, extra: Dictionary = {}) -> Dictionary:
	var row := {"id": id, "name": name, "help": "%s helps." % name, "tree": branch, "branch": branch, "line": line, "tier": tier,
			"cost": cost, "owned": false, "affordable": true, "available": true, "missing": [], "locked_species": [],
			"side_effect": "%s hurts a little." % name, "refund": int(cost * 0.7), "queued": ""}
	row.merge(extra, true)
	return row


func _rows() -> Array[Dictionary]:
	return [
		_row("cold_1", "resistance", "cold", 1, "Cold resistance I", 5),
		_row("cold_2", "resistance", "cold", 2, "Cold resistance II", 9, {"available": false, "affordable": false,
				"missing": ["Cold resistance I"]}),
		_row("heat_1", "resistance", "heat", 1, "Heat resistance I", 5),
		_row("sow_1", "sowing", "sow", 1, "Generous sowing I", 5),
		_row("bugs_1", "sowing", "bugs", 1, "Swarms I", 6, {"locked_species": ["insects"], "available": true}),
	]


func test_open_shows_the_branches_and_the_first_one() -> void:
	_window.open(_rows(), _branches(), 6)
	assert_bool(_window.is_open()).is_true()
	assert_array(_window.tab_labels()).is_equal(["Resistance", "Sowing"])
	assert_str(_window.current_branch()).is_equal("resistance")
	assert_array(_window.line_names()).is_equal(["Cold resistance", "Heat resistance"])


func test_switching_branch_switches_the_lines() -> void:
	_window.open(_rows(), _branches(), 6)
	_window.set_branch("sowing")
	assert_str(_window.current_branch()).is_equal("sowing")
	assert_array(_window.line_names()).is_equal(["Generous sowing", "Swarms"])


func test_tier_chips_show_the_chain_and_its_state() -> void:
	_window.open(_rows(), _branches(), 6)
	assert_str(_window.chip_state("cold_1")).is_equal("available")
	assert_str(_window.chip_state("cold_2")).is_equal("locked")
	var rows := _rows()
	rows[0]["owned"] = true
	rows[1]["available"] = true
	rows[1]["missing"] = []
	rows[1]["affordable"] = false
	_window.refresh(rows, 6)
	assert_str(_window.chip_state("cold_1")).is_equal("owned")
	assert_str(_window.chip_state("cold_2")).is_equal("unaffordable")
	rows[1]["affordable"] = true
	_window.refresh(rows, 12)
	assert_str(_window.chip_state("cold_2")).is_equal("available")


func test_a_queued_perk_waits_for_the_next_tick() -> void:
	var rows := _rows()
	rows[0]["queued"] = "buy"
	_window.open(rows, _branches(), 6)
	assert_str(_window.chip_state("cold_1")).is_equal("queued")
	_window.select("cold_1")
	assert_bool(_window.buy_button().disabled).is_true()
	assert_str(_window.buy_button().text).contains("next tick")


func test_selecting_a_perk_shows_what_it_does_and_what_it_costs_in_the_world() -> void:
	_window.open(_rows(), _branches(), 6)
	_window.select("cold_1")
	assert_str(_window.selected_id()).is_equal("cold_1")
	var text := _window.detail_text()
	assert_str(text).contains("Cold resistance I").contains("Cold resistance I helps.").contains("hurts a little.")
	assert_str(text).contains("5 Sparks").contains("Tier 1 of 2")


func test_a_locked_perk_names_what_it_waits_for() -> void:
	_window.open(_rows(), _branches(), 6)
	_window.select("cold_2")
	assert_str(_window.detail_text()).contains("Requires: Cold resistance I")
	assert_bool(_window.buy_button().disabled).is_true()
	_window.set_branch("sowing")
	_window.select("bugs_1")
	assert_str(_window.detail_text()).contains("Discover first: insects")
	assert_str(_window.chip_state("bugs_1")).is_equal("locked")
	assert_bool(_window.buy_button().disabled).is_true()


func test_the_buy_button_asks_to_buy_and_is_off_without_sparks() -> void:
	_window.open(_rows(), _branches(), 6)
	_window.select("cold_1")
	assert_str(_window.buy_button().text).contains("Buy")
	assert_bool(_window.buy_button().disabled).is_false()
	monitor_signals(_window)
	_window.press_buy()
	await assert_signal(_window).is_emitted("buy_requested", ["cold_1"])
	var poor := _rows()
	poor[0]["affordable"] = false
	_window.refresh(poor, 2)
	assert_bool(_window.buy_button().disabled).is_true()
	assert_str(_window.buy_button().text).contains("more Sparks")


func test_an_owned_perk_offers_a_refund() -> void:
	var rows := _rows()
	rows[0]["owned"] = true
	_window.open(rows, _branches(), 6)
	_window.select("cold_1")
	assert_str(_window.buy_button().text).is_equal("Refund (+3)")
	assert_bool(_window.buy_button().disabled).is_false()
	monitor_signals(_window)
	_window.press_buy()
	await assert_signal(_window).is_emitted("refund_requested", ["cold_1"])


func test_opening_with_a_focus_picks_its_branch_and_perk() -> void:
	_window.open(_rows(), _branches(), 6, "sow_1")
	assert_str(_window.current_branch()).is_equal("sowing")
	assert_str(_window.selected_id()).is_equal("sow_1")


func test_closing_tells_whoever_listens() -> void:
	_window.open(_rows(), _branches(), 6)
	monitor_signals(_window)
	_window.close()
	assert_bool(_window.is_open()).is_false()
	await assert_signal(_window).is_emitted("closed")


func test_a_closed_window_ignores_the_mouse() -> void:
	assert_bool(_window.visible).is_false()
	assert_int(_window.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_window.open(_rows(), _branches(), 6)
	assert_int(_window.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_the_window_fits_the_minimum_window() -> void:
	_window.open(_rows(), _branches(), 6)
	await await_idle_frame()
	var needed := _window.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(GameView.MIN_WINDOW.x)
	assert_float(needed.y).is_less_equal(GameView.MIN_WINDOW.y)
