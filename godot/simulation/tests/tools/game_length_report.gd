extends SceneTree
## How long does a game last for a simple bot, and how does the shop pay off?
## The bot plays a live game: it catches every bubble, buys the cheapest perk it
## may buy, and plants the next rung of the ladder of life whenever the planting
## guide calls conditions ideal or good. Prints per run the tick of victory, the
## perks bought and the Sparks earned, then the medians.
##   godot --headless --path godot -s res://simulation/tests/tools/game_length_report.gd -- [--seeds N] [--personality NAME] [--ticks N]

const ARCHETYPES := ["harmonious", "chaotic", "guardian"]
## The bot looks at the game every this many ticks.
const LOOK_EVERY := 10


func _init() -> void:
	var seeds := 4
	var ticks := 72000
	var only := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--seeds":
				seeds = int(args[i + 1])
			"--ticks":
				ticks = int(args[i + 1])
			"--personality":
				only = args[i + 1]
	var wins: Array[int] = []
	var perks: Array[int] = []
	var runs := 0
	for archetype: String in ARCHETYPES:
		if not only.is_empty() and only != archetype:
			continue
		for seed_value in range(1, seeds + 1):
			runs += 1
			var run := _play(seed_value, archetype, ticks)
			print("seed %d %-10s victory %s, %d perks, %d Sparks earned, first purchase %d, species reached %s" % [seed_value, archetype,
					"tick %d (year %d)" % [run["won"], GameCalendar.year(run["won"])] if run["won"] >= 0 else "never",
					run["perks"], run["earned"], run["first_purchase"], run["reached"]])
			if run["won"] >= 0:
				wins.append(run["won"])
			perks.append(run["perks"])
	wins.sort()
	perks.sort()
	print("--- %d runs of up to %d ticks: %d victories (%.0f%%), median victory tick %s, median perks bought %d" % [runs, ticks, wins.size(),
			100.0 * wins.size() / maxi(1, runs), str(wins[wins.size() / 2]) if not wins.is_empty() else "-", perks[perks.size() / 2] if not perks.is_empty() else 0])
	quit()


func _play(seed_value: int, archetype: String, ticks: int) -> Dictionary:
	var save := "user://game_length_report_%d_%s.json" % [seed_value, archetype]
	var options: Dictionary = PlaySession.parse_args(PackedStringArray(["--seed", str(seed_value), "--personality", archetype, "--save", save])).value
	options["file_logs"] = false
	options["live"] = true
	var created := GameSession.create(options, func(_line: String) -> void: pass)
	var game: GameSession = created.value
	game.begin_round()
	var earned := 0
	var first_purchase := -1
	while game.tick() < ticks and not game.goals.won():
		if game.step(LOOK_EVERY) == 0:
			break
		for bubble: Dictionary in game.bubbles.bubbles():
			var collected := game.collect_bubble(int(bubble["id"]))
			if collected.is_ok():
				earned += int(collected.value)
		_buy_cheapest(game)
		if first_purchase < 0 and not game.perks().owned().is_empty():
			first_purchase = game.tick()
		_plant_next(game)
	var reached := PackedStringArray()
	for step in game.life_path():
		if step["state"] == "alive":
			reached.append(step["id"])
	return {"won": game.goals.victory_tick() if game.goals.won() else -1, "perks": game.perks().owned().size(), "earned": earned,
			"first_purchase": first_purchase, "reached": ",".join(reached)}


func _buy_cheapest(game: GameSession) -> void:
	var cheapest: Dictionary = {}
	for row in game.perk_rows():
		if row["owned"] or not row["available"] or not row["affordable"] or row["queued"] != "" or not (row["locked_species"] as Array).is_empty():
			continue
		if cheapest.is_empty() or int(row["cost"]) < int(cheapest["cost"]):
			cheapest = row
	if not cheapest.is_empty():
		game.buy_perk(cheapest["id"])


## Plants the next rung of the ladder (or a lost species) when the guide says the planet suits it.
func _plant_next(game: GameSession) -> void:
	var rows := game.species_guide_rows()
	if rows.is_empty() or not rows[0]["ready"]:
		return
	for step in game.life_path():
		if step["state"] == "alive" or step["state"] == "later":
			continue
		for row in rows:
			if row["id"] == step["id"] and (row["verdict"] == &"ideal" or row["verdict"] == &"ok"):
				game.submit("seed_species", {"species": step["id"]})
				return
