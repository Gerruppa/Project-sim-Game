class_name BiosphereConfig
extends RefCounted
## Validated biosphere-wide coefficients (fires, photorespiration,
## extinction, noise), loaded from JSON. Species live in SpeciesCatalog.
## Fields are public for readable formulas; treat them as read-only.

const DEFAULT_PATH := "res://resources/biosphere/biosphere.json"

## name -> [min, max, integer]
const SPEC := {
	"extinction_threshold": [0.0, 10.0, false],
	"established_population": [0.0, 100.0, false],
	"growth_noise": [0.0, 1.0, false],
	"growth_scale": [0.0, 10.0, false],
	"stress_scale": [0.0, 10.0, false],
	"fire_rate": [0.0, 1.0, false],
	"fire_o2_low": [0.0, 100.0, false],
	"fire_o2_high": [0.0, 100.0, false],
	"fire_humidity_low": [0.0, 100.0, false],
	"fire_humidity_high": [0.0, 100.0, false],
	"fire_wet_damping": [0.0, 1.0, false],
	"fire_o2": [0.0, 10.0, false],
	"fire_co2": [0.0, 10.0, false],
	"photorespiration_low": [0.0, 100.0, false],
	"photorespiration_high": [0.0, 100.0, false],
	"loss_memory": [0.0, 1.0, false],
	"recolonization": [0.0, 1.0, false],
	"cold_tolerance": [0.0, 40.0, false],
	"heat_tolerance": [0.0, 40.0, false],
	"drought_tolerance": [0.0, 40.0, false],
	"seed_scale": [0.0, 10.0, false],
	"natural_seed_scale": [0.0, 10.0, false],
	"capacity_scale": [0.1, 3.0, false],
	"photosynthesis_scale": [0.0, 3.0, false],
	"fauna_growth_scale": [0.0, 10.0, false],
	"fauna_seed_scale": [0.0, 10.0, false],
	"food_need_scale": [0.1, 2.0, false],
	"graze_scale": [0.0, 10.0, false],
	"pollination": [0.0, 2.0, false],
}
const ORDERED_PAIRS := [
	["fire_o2_low", "fire_o2_high"],
	["fire_humidity_low", "fire_humidity_high"],
	["photorespiration_low", "photorespiration_high"],
	["extinction_threshold", "established_population"],
]

## Below this a shrinking population is gone.
var extinction_threshold: float
## Above this a species counts as established (emergence event).
var established_population: float
var growth_noise: float
## Multiplies every species' growth (planet personality: lushness).
var growth_scale: float
## Multiplies every species' stress mortality (planet personality: protection of life).
var stress_scale: float
var fire_rate: float
var fire_o2_low: float
var fire_o2_high: float
var fire_humidity_low: float
var fire_humidity_high: float
var fire_wet_damping: float
var fire_o2: float
var fire_co2: float
var photorespiration_low: float
var photorespiration_high: float
## Per-tick decay of remembered population losses (extinction causes):
## 0.99 remembers roughly the last 100 ticks.
var loss_memory: float
## Natural seeding of a species that died out, as a share of its normal
## seeding: 0 = gone for good unless the player seeds it, 1 = it returns as
## easily as it first appeared. Makes the player's choices leave a mark.
var recolonization: float
## Perks of resistance: how far (planet scale 0-100) every species' temperature
## window widens on the cold and hot side and its water need drops.
var cold_tolerance: float
var heat_tolerance: float
var drought_tolerance: float
## Multiplies the population a seeding adds, and the natural seeding of species.
var seed_scale: float
var natural_seed_scale: float
## Multiplies every species' capacity and its photosynthesis.
var capacity_scale: float
var photosynthesis_scale: float
## Fauna: multipliers on animals' growth and natural seeding, on the food they
## need before they appear, and on how much they eat; and how much a full
## population of pollinators speeds up the growth of the plants above the soil.
var fauna_growth_scale: float
var fauna_seed_scale: float
var food_need_scale: float
var graze_scale: float
var pollination: float


static func load_json(path: String) -> SimResult:
	var read := CoefficientLoader.read_json(path, "biosphere")
	return from_data(read.value) if read.is_ok() else read


## Validates everything and reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	return CoefficientLoader.fill(BiosphereConfig.new(), data, SPEC, ORDERED_PAIRS, "biosphere")
