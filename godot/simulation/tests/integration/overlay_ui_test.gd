extends GdUnitTestSuite
## The pieces that float over the globe: the card (intro, ending, warnings),
## the translucent chronicle and the toast.


func _card() -> OverlayCard:
	var card := OverlayCard.new()
	add_child(card)
	return auto_free(card)


func test_card_shows_title_body_and_buttons() -> void:
	var card := _card()
	monitor_signals(card)
	card.show_card("Congratulations", "You did it.", [["again", "Play again"], ["quit", "Quit"]])
	assert_bool(card.is_open()).is_true()
	assert_str(card.title_text()).is_equal("Congratulations")
	assert_str(card.body_text()).is_equal("You did it.")
	assert_array(card.button_labels()).is_equal(["Play again", "Quit"])
	card.press("quit")
	await assert_signal(card).is_emitted("button_pressed", ["quit"])


func test_a_closed_card_is_hidden_and_ignores_the_mouse() -> void:
	var card := _card()
	assert_bool(card.is_open()).is_false()
	assert_bool(card.visible).is_false()
	assert_int(card.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	card.show_card("T", "B", [])
	assert_int(card.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	card.hide_card()
	assert_bool(card.visible).is_false()


func test_card_content_is_a_place_for_extra_controls() -> void:
	var card := _card()
	var label := Label.new()
	card.content().add_child(label)
	assert_bool(label.is_inside_tree()).is_true()


func test_showing_a_card_again_replaces_the_buttons() -> void:
	var card := _card()
	card.show_card("A", "a", [["x", "X"]])
	card.show_card("B", "b", [["y", "Y"], ["z", "Z"]])
	assert_array(card.button_labels()).is_equal(["Y", "Z"])


func test_chronicle_keeps_only_the_last_lines_visible() -> void:
	var chronicle := ChronicleOverlay.new()
	add_child(chronicle)
	auto_free(chronicle)
	for i in 10:
		chronicle.add_line("line %d" % i)
	assert_int(chronicle.visible_lines().size()).is_equal(ChronicleOverlay.MAX_LINES)
	assert_str(chronicle.visible_lines()[-1]).is_equal("line 9")
	for i in 10:
		assert_str(chronicle.text()).contains("line %d" % i)


func test_chronicle_understands_bbcode_and_never_blocks_clicks() -> void:
	var chronicle := ChronicleOverlay.new()
	add_child(chronicle)
	auto_free(chronicle)
	chronicle.add_line("[color=gold][b]Won[/b][/color]")
	assert_str(chronicle.text()).contains("Won").not_contains("[b]")
	assert_int(chronicle.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	for child in chronicle.find_children("*", "Control", true, false):
		if child is ScrollBar:
			continue
		assert_int((child as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_toast_expires() -> void:
	var toast := Toast.new()
	add_child(toast)
	auto_free(toast)
	assert_str(toast.current_text()).is_empty()
	toast.show_text("Moss takes hold!", 2.0)
	assert_str(toast.current_text()).is_equal("Moss takes hold!")
	toast.advance(1.0)
	assert_str(toast.current_text()).is_equal("Moss takes hold!")
	toast.advance(1.5)
	assert_str(toast.current_text()).is_empty()
	assert_bool(toast.visible).is_false()
	assert_int(toast.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func _threat(state: String = "warned", owned: bool = false) -> Dictionary:
	return {"id": "ice_age", "name": "Ice age", "state": state, "text": "The planet is cooling.",
			"counters": [{"id": "perk_mirrors_warm", "name": "Orbital mirrors", "kind": "perk", "owned": owned},
					{"id": "mirrors_warm", "name": "Warm up", "kind": "action", "owned": true}]}


func test_the_threat_strip_names_the_crisis_and_what_helps() -> void:
	var strip := ThreatStrip.new()
	add_child(strip)
	auto_free(strip)
	strip.refresh([_threat()])
	assert_str(strip.row_text("ice_age")).contains("Ice age").contains("coming").contains("The planet is cooling.")
	assert_array(strip.counter_texts("ice_age")).is_equal(["Orbital mirrors", "✓ Warm up"])
	strip.refresh([_threat("active", true)])
	assert_str(strip.row_text("ice_age")).contains("under way")
	assert_array(strip.counter_texts("ice_age")).is_equal(["✓ Orbital mirrors", "✓ Warm up"])
	strip.refresh([])
	assert_str(strip.row_text("ice_age")).is_empty()


func test_the_threat_strip_lets_the_mouse_through_except_on_buttons() -> void:
	var strip := ThreatStrip.new()
	add_child(strip)
	auto_free(strip)
	strip.refresh([_threat()])
	assert_int(strip.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	monitor_signals(strip)
	strip.press_counter("ice_age", "perk_mirrors_warm")
	await assert_signal(strip).is_emitted("counter_pressed", ["perk", "perk_mirrors_warm"])
