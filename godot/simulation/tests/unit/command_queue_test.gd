extends GdUnitTestSuite
## CommandQueue and SimCommand: order, timing and saving of outside requests.


func _command(tick: int, action: String) -> SimCommand:
	return SimCommand.new(tick, &"interventions", StringName(action))


func test_takes_only_the_commands_of_a_tick_in_submission_order() -> void:
	var queue := CommandQueue.new()
	queue.push(_command(2, "b"))
	queue.push(_command(1, "a"))
	queue.push(_command(2, "c"))
	assert_array(queue.take(1).map(func(c: SimCommand) -> String: return String(c.action))).is_equal(["a"])
	assert_array(queue.take(2).map(func(c: SimCommand) -> String: return String(c.action))).is_equal(["b", "c"])
	assert_array(queue.pending()).is_empty()


func test_commands_for_a_tick_that_already_ran_are_dropped() -> void:
	var queue := CommandQueue.new()
	queue.push(_command(3, "late"))
	queue.push(_command(9, "future"))
	assert_array(queue.take(5)).is_empty()
	assert_int(queue.pending().size()).is_equal(1)


func test_pending_commands_survive_a_save() -> void:
	var queue := CommandQueue.new()
	queue.push(SimCommand.new(7, &"interventions", &"seed", {"species": "moss"}))
	queue.push(_command(8, "cull"))
	var restored := CommandQueue.new()
	assert_bool(restored.load_state(JSON.parse_string(JSON.stringify(queue.save_state()))).is_ok()).is_true()
	var taken := restored.take(7)
	assert_str(String(taken[0].action)).is_equal("seed")
	assert_dict(taken[0].args).is_equal({"species": "moss"})
	restored.push(_command(8, "after"))
	assert_array(restored.take(8).map(func(c: SimCommand) -> String: return String(c.action))).is_equal(["cull", "after"])


func test_rejects_damaged_commands() -> void:
	assert_bool(SimCommand.from_dict({"tick": -1, "sequence": 0, "target": "x", "action": "y"}).is_ok()).is_false()
	assert_bool(SimCommand.from_dict({"tick": 1, "sequence": 0, "target": "", "action": "y"}).is_ok()).is_false()
	assert_bool(SimCommand.from_dict({"tick": 1, "sequence": 0, "target": "x", "action": "y", "args": []}).is_ok()).is_false()
	assert_bool(CommandQueue.new().load_state({"pending": [{"tick": 1}]}).is_ok()).is_false()
