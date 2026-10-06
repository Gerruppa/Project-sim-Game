class_name SpeciesImpact
extends RunObserver
## What each species did to the planet since the last decision: the sum of
## the deltas the simulation applied with a cause named after it
## ("algae_photosynthesis", "tree_wildfire"). Measured, not estimated, so the
## player reads who really oxygenated, dried or burned the planet.
##
## Every other delta counts too, so the lines add up to what really changed:
## the player's actions (PLAYER) and the rest of the planet (PLANET: rocks,
## oceans, weather, world events, its character).
##
## Listens to TICK_APPLIED on the bus; never changes the simulation. A loaded
## game counts from the moment it was loaded.

const PLAYER := "player"
const PLANET := "planet"

## species id, PLAYER or PLANET -> {parameter id -> sum of applied deltas on
## the 0-100 scale}
var _sums := {}
var _species: Array[String] = []


## species: the ids whose causes are counted.
func _init(species: Array[String]) -> void:
	_species = species


func attach(bus: EventBus) -> void:
	bus.subscribe(SimEvent.TICK_APPLIED, _on_tick)


## Starts a new count (at every decision).
func reset() -> void:
	_sums.clear()


func _on_tick(event: SimEvent) -> void:
	var report: ApplyReport = event.data["report"]
	for delta: Delta in report.applied_deltas:
		var id := owner(delta)
		var sums: Dictionary = _sums.get_or_add(id, {})
		var param := String(delta.parameter)
		sums[param] = float(sums.get(param, 0.0)) + delta.amount


## Who a delta belongs to: the species its cause names ("algae" for
## "algae_photosynthesis"), PLAYER for an intervention, else PLANET.
func owner(delta: Delta) -> String:
	if delta.source == InterventionSystem.ID:
		return PLAYER
	var text := String(delta.cause)
	for id in _species:
		if text.begins_with(id + "_"):
			return id
	return PLANET


## {parameter id -> summed change on the 0-100 scale} since the last reset;
## who: a species id, PLAYER or PLANET.
func sums(who: String) -> Dictionary:
	return (_sums.get(who, {}) as Dictionary).duplicate()
