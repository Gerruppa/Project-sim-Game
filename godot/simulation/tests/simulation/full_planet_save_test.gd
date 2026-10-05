extends GdUnitTestSuite
## The whole planet, every archetype: save at tick N, load into a freshly
## built planet, run on == one continuous run. Same state hash and the same
## events at the same ticks (no species emerging twice, no event restarting).
## The save is taken inside an active world event when the run has one, so
## restored lifecycles and modifiers are exercised.

const TOTAL := 6000
const FALLBACK_SPLIT := 3000
const ARCHETYPES := ["harmonious", "chaotic", "guardian"]


## Every notification except tick reports, as comparable text.
class EventRecorder extends RunObserver:
	var lines := PackedStringArray()

	func attach(bus: EventBus) -> void:
		bus.subscribe_all(_on_event)

	func _on_event(event: SimEvent) -> void:
		if event.type != SimEvent.TICK_APPLIED:
			lines.append("%d %s %s" % [event.tick, event.type, event.data.get("summary", event.data)])


func _planet(archetype: String) -> Dictionary:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value.with_personality(StringName(archetype))
	var built := SimulationRunner.build_planet(config, SimulationRunner.parse_args(PackedStringArray()).value)
	assert_array(Array(built.errors)).is_empty()
	return built.value


func _run_info(planet: Dictionary) -> Dictionary:
	return {"personality": planet["personality"], "data_fingerprints": planet["fingerprints"], "lineage": []}


## A tick inside the first world event that lasts long enough, else FALLBACK_SPLIT.
static func _split_tick(lines: PackedStringArray) -> int:
	for line in lines:
		var tick := line.get_slice(" ", 0).to_int() + 20
		if line.contains(" world_event_started ") and tick < TOTAL - 500 and _active_at(lines, tick) > 0:
			return tick
	return FALLBACK_SPLIT


## World events running after tick `tick` was applied.
static func _active_at(lines: PackedStringArray, tick: int) -> int:
	var active := 0
	for line in lines:
		if line.get_slice(" ", 0).to_int() <= tick:
			if line.contains(" world_event_started "):
				active += 1
			elif line.contains(" world_event_ended "):
				active -= 1
	return active


func test_save_and_load_continue_every_archetype_identically() -> void:
	var inside_an_event := 0
	for archetype: String in ARCHETYPES:
		var continuous := _planet(archetype)
		var whole := EventRecorder.new()
		(continuous["manager"] as SimulationManager).attach_log(whole)
		(continuous["manager"] as SimulationManager).run_ticks(TOTAL)
		var split := _split_tick(whole.lines)
		if split != FALLBACK_SPLIT:
			inside_an_event += 1

		var first := _planet(archetype)
		var before := EventRecorder.new()
		(first["manager"] as SimulationManager).attach_log(before)
		(first["manager"] as SimulationManager).run_ticks(split)
		var save_text := JSON.stringify(SaveSystem.capture(first["manager"], _run_info(first)), "\t", true, true)

		var second := _planet(archetype)
		var restored := SaveSystem.restore(second["manager"], JSON.parse_string(save_text), _run_info(second))
		assert_array(Array(restored.errors)).override_failure_message(archetype).is_empty()
		assert_array(Array(restored.warnings)).override_failure_message(archetype).is_empty()
		var after := EventRecorder.new()
		(second["manager"] as SimulationManager).attach_log(after)
		(second["manager"] as SimulationManager).run_ticks(TOTAL - split)

		assert_str((second["manager"] as SimulationManager).state_hash()) \
				.override_failure_message("%s: state differs after loading at tick %d" % [archetype, split]) \
				.is_equal((continuous["manager"] as SimulationManager).state_hash())
		assert_array(Array(before.lines + after.lines)) \
				.override_failure_message("%s: events differ after loading at tick %d" % [archetype, split]) \
				.is_equal(Array(whole.lines))
	# At least one planet must be saved mid-event, or the lifecycle restore is untested.
	assert_int(inside_an_event).is_greater_equal(1)
