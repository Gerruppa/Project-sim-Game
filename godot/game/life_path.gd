class_name LifePath
extends RefCounted
## The ladder of life as the player climbs it: bacteria, algae, moss, shrubs,
## trees (and later the animals). Each rung is alive, the next one, lost, or
## still out of reach; the next one shows how close the planet is to
## supporting it and what it still lacks. Presentation only.

## One rung: {"id", "name", "state" ("alive", "next", "lost" or "later"),
## "is_next", "population", "progress" (0..1), "blocker" ("" when nothing is missing)}.
static func steps(biosphere: BiosphereSystem, snapshot: PlanetSnapshot, guide: SpeciesGuide, scale: DisplayScale,
		names: Dictionary) -> Array[Dictionary]:
	var present := biosphere.established_population()
	var ordered := _in_succession_order(biosphere.species_list())
	var rows: Array[Dictionary] = []
	var next_found := false
	for species in ordered:
		var alive := biosphere.population(species.id) >= present
		var precursor_alive := species.emerges_from.is_empty() or biosphere.population(species.emerges_from) >= present
		var is_next := not alive and precursor_alive and not next_found
		next_found = next_found or is_next
		var state := "alive" if alive else "next" if is_next else "later"
		var row := {"id": String(species.id), "name": names.get(String(species.id), String(species.id)), "state": state,
				"is_next": is_next, "population": biosphere.population(species.id), "progress": 1.0 if alive else 0.0,
				"blocker": ""}
		if is_next:
			var advice := guide.guide(species, snapshot, biosphere, scale, names)
			row["progress"] = float(advice["fit"]) * biosphere.food_progress(species.id)
			row["blocker"] = blocker_text(advice)
		rows.append(row)
	return rows


## What the next rung still needs: the needs that are not fully met, with where
## the planet stands ("Temperature 5 °C, needs 15 °C to 45 °C"), or why it waits.
static func blocker_text(advice: Dictionary) -> String:
	if advice["verdict"] == &"waiting":
		return str(advice["why"])
	var parts := PackedStringArray()
	for need: Dictionary in advice["needs"]:
		if need["state"] != "good":
			parts.append("%s %s, needs %s" % [need["name"], need["now"], need["range"]])
	return "; ".join(parts)


## Species in the order life climbs: a species after the one it grows from,
## otherwise as listed.
static func _in_succession_order(species_list: Array[SpeciesData]) -> Array[SpeciesData]:
	var ordered: Array[SpeciesData] = []
	var pending := species_list.duplicate()
	while not pending.is_empty():
		var placed := false
		for species: SpeciesData in pending:
			var ready := species.emerges_from.is_empty() or ordered.any(func(o: SpeciesData) -> bool: return o.id == species.emerges_from)
			if ready:
				ordered.append(species)
				pending.erase(species)
				placed = true
				break
		if not placed:
			# A cycle is rejected by the catalog; keep the rest as listed rather than loop forever.
			ordered.append_array(pending)
			break
	return ordered
