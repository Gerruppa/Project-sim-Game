extends GdUnitTestSuite
## Spark economy measured with a "perfect player" bot: every tick it collects
## every bubble and buys the cheapest perk it can afford. The bounds come from
## the spec (section 3.2): the first perk early, the whole shop within the
## game, and a bubble rate a human can keep up with. If a bound fails, tune
## resources/perks/perks.json or resources/bubbles/bubbles.json, not this file.
## Each seed's 30 000-tick game runs once in before(); the tests read the record.

const TICKS := 30000
const SEEDS: Array[int] = [13, 42]
const PERK_COUNT := 10
const TICKS_PER_MINUTE_X25 := 1500.0
const TICKS_PER_MINUTE_X50 := 3000.0

## seed -> {"first_purchase_tick", "all_owned_tick", "owned", "bubble_sparks", "passive_sparks",
## "sparks_granted", "bubbles", "bubbles_per_1000", "bubbles_per_minute_x25", "bubbles_per_minute_x50"}
var _runs: Dictionary[int, Dictionary] = {}


func before() -> void:
	for seed_value in SEEDS:
		_runs[seed_value] = _play(seed_value)


func _play(seed_value: int) -> Dictionary:
	var save := "user://perk_economy_test/seed_%d.json" % seed_value
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--seed", str(seed_value), "--save", save])).value
	options["file_logs"] = false
	options["live"] = true
	var created := GameSession.create(options, func(_line: String) -> void: pass)
	assert_array(Array(created.errors)).is_empty()
	var game: GameSession = created.value
	game.begin_round()
	var first_purchase_tick := -1
	var all_owned_tick := -1
	var bubble_sparks := 0
	var spent := 0
	var highest_id := 0
	while game.tick() < TICKS:
		for bubble: Dictionary in game.bubbles.bubbles():
			highest_id = maxi(highest_id, int(bubble["id"]))
			var collected := game.collect_bubble(int(bubble["id"]))
			if collected.is_ok():
				bubble_sparks += int(collected.value)
		if game.step(1) == 0:
			break
		var cheapest: Dictionary = {}
		for row: Dictionary in game.perk_rows():
			if row["available"] and row["affordable"] and not row["owned"] \
					and (cheapest.is_empty() or int(row["cost"]) < int(cheapest["cost"])):
				cheapest = row
		if not cheapest.is_empty() and game.buy_perk(cheapest["id"]).is_ok():
			spent += int(cheapest["cost"])
			if first_purchase_tick < 0:
				first_purchase_tick = game.tick()
		if all_owned_tick < 0 and game.perks().owned().size() == PERK_COUNT:
			all_owned_tick = game.tick()
	game.step(2)
	if all_owned_tick < 0 and game.perks().owned().size() == PERK_COUNT:
		all_owned_tick = game.tick()
	var passive := game.perks().sparks() + float(spent) - float(bubble_sparks)
	var per_1000 := float(highest_id) * 1000.0 / float(TICKS)
	var run := {
		"first_purchase_tick": first_purchase_tick, "all_owned_tick": all_owned_tick,
		"owned": game.perks().owned().size(), "bubble_sparks": bubble_sparks, "passive_sparks": passive,
		"sparks_granted": float(bubble_sparks) + passive, "bubbles": highest_id, "bubbles_per_1000": per_1000,
		"bubbles_per_minute_x25": per_1000 * TICKS_PER_MINUTE_X25 / 1000.0,
		"bubbles_per_minute_x50": per_1000 * TICKS_PER_MINUTE_X50 / 1000.0,
	}
	print("perk_economy seed %d: first purchase tick %d, all %d perks at tick %d, Sparks %.1f (bubbles %d + passive %.1f), %d bubbles = %.2f per 1000 ticks = %.2f/min at x25, %.2f/min at x50" % [
			seed_value, first_purchase_tick, run["owned"], all_owned_tick, run["sparks_granted"], bubble_sparks, passive,
			highest_id, per_1000, run["bubbles_per_minute_x25"], run["bubbles_per_minute_x50"]])
	return run


func test_first_perk_is_bought_early() -> void:
	for seed_value in SEEDS:
		var tick: int = _runs[seed_value]["first_purchase_tick"]
		assert_bool(tick > 0 and tick <= 600).override_failure_message("seed %d: first purchase at tick %d, wanted 1..600" % [seed_value, tick]).is_true()


func test_the_whole_shop_is_bought_within_the_game() -> void:
	for seed_value in SEEDS:
		var run: Dictionary = _runs[seed_value]
		assert_int(run["owned"]).override_failure_message("seed %d owns %d of %d perks" % [seed_value, run["owned"], PERK_COUNT]).is_equal(PERK_COUNT)
		var tick: int = run["all_owned_tick"]
		assert_bool(tick > 0 and tick < TICKS).override_failure_message("seed %d: all perks owned at tick %d" % [seed_value, tick]).is_true()


func test_sparks_granted_stay_in_the_designed_range() -> void:
	for seed_value in SEEDS:
		var granted: float = _runs[seed_value]["sparks_granted"]
		assert_bool(granted >= 80.0 and granted <= 260.0).override_failure_message("seed %d: %.1f Sparks granted, wanted 80..260" % [seed_value, granted]).is_true()


func test_bubble_rate_matches_the_target() -> void:
	for seed_value in SEEDS:
		var rate: float = _runs[seed_value]["bubbles_per_1000"]
		assert_bool(rate >= 2.7 and rate <= 4.0).override_failure_message("seed %d: %.2f bubbles per 1000 ticks, wanted 2.7..4.0 (4-6 per minute at x25)" % [seed_value, rate]).is_true()
