class_name SpeciesData
extends RefCounted
## One species as a population, never as individuals.
##
## Answers the CLAUDE.md species questions in data: what it needs
## (temperature window, water, CO2, oxygen, soil), what it consumes and
## produces (oxygen, co2_uptake, respiration, transpiration) and how it
## competes (layer, shade, capacity). Loaded by SpeciesCatalog; treat as read-only.

## Parameters a species may draw water from.
const WATER_SOURCES: Array[StringName] = [&"humidity", &"precipitation"]
## name -> [min, max, integer]
const SPEC := {
	"layer": [0.0, 10.0, true],
	"weight": [0.0, 1.0, false],
	"growth": [0.0, 1.0, false],
	"capacity": [1.0, 100.0, false],
	"t_min": [0.0, 100.0, false],
	"t_max": [0.0, 100.0, false],
	"t_margin": [0.0, 50.0, false],
	"water_min": [0.0, 100.0, false],
	"water_margin": [0.0, 50.0, false],
	"co2_need": [0.0, 100.0, false],
	"o2_need": [0.0, 100.0, false],
	"o2_max": [0.0, 100.0, false],
	"o2_refuge": [0.0, 1.0, false],
	"biomass_need": [0.0, 100.0, false],
	"shade": [0.0, 1.0, false],
	"flammable": [0.0, 1.0, false],
	"base_mortality": [0.0, 1.0, false],
	"stress_mortality": [0.0, 1.0, false],
	"seed": [0.0, 1.0, false],
	"oxygen": [0.0, 5.0, false],
	"co2_uptake": [0.0, 5.0, false],
	"respiration": [0.0, 5.0, false],
	"transpiration": [0.0, 5.0, false],
}
const ORDERED_PAIRS := [["t_min", "t_max"]]
const TEXT_FIELDS: Array[String] = ["id", "water", "emerges_from"]

var id: StringName
## Parameter id supplying water (humidity or precipitation).
var water: StringName
## Precursor species id; empty for species that arise spontaneously.
var emerges_from: StringName
## Height order: higher layers shade lower ones (0 = soil and water, not shaded).
var layer: int
## Contribution to planet biomass at population 100.
var weight: float
var growth: float
var capacity: float
var t_min: float
var t_max: float
var t_margin: float
var water_min: float
var water_margin: float
var co2_need: float
var o2_need: float
## Oxygen level where an anaerobe starts to suffer (0 = tolerates oxygen).
var o2_max: float
## Share of capacity that survives in oxygen-free niches when oxygen is high.
var o2_refuge: float
var biomass_need: float
var shade: float
var flammable: float
var base_mortality: float
var stress_mortality: float
var seed: float
var oxygen: float
var co2_uptake: float
var respiration: float
var transpiration: float


## How well the environment suits the species, 0..1. Multiplicative:
## any missing need (cold, drought, no soil) stops growth.
func suitability(snapshot: PlanetSnapshot) -> float:
	var t := snapshot.get_value(Param.TEMPERATURE)
	var temperature_fit := SimMath.smoothstep(t_min - t_margin, t_min, t) \
			* (1.0 - SimMath.smoothstep(t_max, t_max + t_margin, t))
	var water_fit := SimMath.smoothstep(water_min - water_margin, water_min, snapshot.get_value(water))
	var co2_fit := 1.0 if co2_need == 0.0 else SimMath.smoothstep(0.0, co2_need, snapshot.get_value(Param.CO2))
	var oxygen_fit := 1.0 if o2_need == 0.0 \
			else SimMath.smoothstep(o2_need * 0.5, o2_need, snapshot.get_value(Param.OXYGEN))
	var soil_fit := 1.0 if biomass_need == 0.0 \
			else SimMath.smoothstep(biomass_need * 0.5, biomass_need, snapshot.get_value(Param.BIOMASS))
	return temperature_fit * water_fit * co2_fit * oxygen_fit * soil_fit


## Oxygen-sensitive species keep only their refuge share of capacity once
## oxygen rises: anaerobes retreat to oxygen-free niches instead of vanishing.
func oxygen_capacity_factor(oxygen_level: float) -> float:
	if o2_max == 0.0:
		return 1.0
	return o2_refuge + (1.0 - o2_refuge) * (1.0 - SimMath.smoothstep(o2_max, o2_max * 2.0, oxygen_level))
