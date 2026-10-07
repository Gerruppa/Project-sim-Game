class_name LifeZones
extends RefCounted
## Which colour a planet value gets: is it a range the life that is here, or
## that may come next, can live in? Derived from the species data, so the
## "green zone" follows the succession (bacteria tolerate 5-70 degrees,
## trees want 20-45) instead of being one fixed target. A parameter no
## relevant species cares about gets no colour at all.
##
## GOOD: inside the range some relevant species lives in. POOR: only in the
## margin where it still grows but suffers. BAD: outside every range. The same
## limits as SpeciesData.suitability, read-only, nothing reaches the simulation.

const NONE := &"none"
const GOOD := &"good"
const POOR := &"poor"
const BAD := &"bad"
## A species counts as alive here from this population (what the tables show).
const ALIVE := 0.5
const TOP := 100.0


## Species that colour the planet: alive now, plus the ones that could appear
## next (no precursor needed, or the precursor is alive).
static func relevant(biosphere: BiosphereSystem) -> Array[SpeciesData]:
	var result: Array[SpeciesData] = []
	for species in biosphere.species_list():
		var alive := biosphere.population(species.id) >= ALIVE
		var next := not alive and (species.emerges_from.is_empty() or biosphere.population(species.emerges_from) >= ALIVE)
		if alive or next:
			result.append(species)
	return result


## NONE when no species in the list limits this parameter, else the best state
## any of them gives.
static func zone(param: StringName, value: float, species: Array[SpeciesData], tolerance: Vector3 = Vector3.ZERO) -> StringName:
	var best := NONE
	for one in species:
		var limits := _limits(param, one, tolerance)
		if limits.is_empty():
			continue
		var state := _state(value, limits)
		if best == NONE or _rank(state) > _rank(best):
			best = state
	return best


## [low, high, margin below low, margin above high] where the species lives
## well, or [] when it does not limit this parameter.
static func limits_of(param: StringName, species: SpeciesData, tolerance: Vector3 = Vector3.ZERO) -> Array[float]:
	return _limits(param, species, tolerance)


## GOOD, POOR or BAD: how a value of the parameter suits the species.
static func state_of(param: StringName, value: float, species: SpeciesData, tolerance: Vector3 = Vector3.ZERO) -> StringName:
	var limits := _limits(param, species, tolerance)
	return NONE if limits.is_empty() else _state(value, limits)


static func _limits(param: StringName, species: SpeciesData, tolerance: Vector3 = Vector3.ZERO) -> Array[float]:
	if param == Param.TEMPERATURE:
		return [species.t_min - tolerance.x, species.t_max + tolerance.y, species.t_margin, species.t_margin]
	if param == species.water:
		return [species.water_min - tolerance.z, TOP, species.water_margin, 0.0]
	if param == Param.CO2 and species.co2_need > 0.0:
		return [species.co2_need, TOP, species.co2_need, 0.0]
	if param == Param.BIOMASS and species.biomass_need > 0.0:
		return [species.biomass_need, TOP, species.biomass_need * 0.5, 0.0]
	if param == Param.OXYGEN and (species.o2_need > 0.0 or species.o2_max > 0.0):
		var high := species.o2_max if species.o2_max > 0.0 else TOP
		return [species.o2_need, high, species.o2_need * 0.5, species.o2_max]
	return []


static func _state(value: float, limits: Array[float]) -> StringName:
	if value >= limits[0] and value <= limits[1]:
		return GOOD
	# Growth stops exactly at the far edge of a margin (smoothstep reaches 0 there).
	if value < limits[0] and value > limits[0] - limits[2]:
		return POOR
	if value > limits[1] and value < limits[1] + limits[3]:
		return POOR
	return BAD


static func _rank(state: StringName) -> int:
	return 2 if state == GOOD else 1 if state == POOR else 0
