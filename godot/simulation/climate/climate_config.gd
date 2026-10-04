class_name ClimateConfig
extends RefCounted
## Validated ClimateSystem coefficients, loaded from JSON.
##
## Every coefficient is documented in docs/climate.md. Fields are public
## for readable formulas; treat them as read-only after loading.
## Different files describe planets of different character
## (run_simulation.sh --climate <file>).

const DEFAULT_PATH := "res://resources/climate/climate.json"

## name -> [min, max, integer]. Responses are capped at 1 so relaxation
## never overshoots its target (which would make the loop oscillate).
const SPEC := {
	"base_temperature": [0.0, 100.0, false],
	"thermal_response": [0.0001, 1.0, false],
	"season_period_ticks": [2.0, 1000000.0, true],
	"season_amplitude": [0.0, 50.0, false],
	"drift_reversion": [0.0, 1.0, false],
	"drift_noise": [0.0, 10.0, false],
	"drift_limit": [0.0, 50.0, false],
	"ice_strength": [0.0, 100.0, false],
	"ice_full": [0.0, 100.0, false],
	"ice_free": [0.0, 100.0, false],
	"cloud_albedo": [0.0, 100.0, false],
	"cloud_ref": [0.0, 100.0, false],
	"vegetation_albedo": [0.0, 100.0, false],
	"greenhouse": [0.0, 100.0, false],
	"greenhouse_ref": [0.0, 100.0, false],
	"water_availability": [0.0, 1.0, false],
	"evaporation_rate": [0.0, 10.0, false],
	"evap_cold": [0.0, 100.0, false],
	"evap_warm": [0.0, 100.0, false],
	"capacity_cold": [1.0, 100.0, false],
	"capacity_warm": [1.0, 100.0, false],
	"cloud_rh_low": [0.0, 1.0, false],
	"cloud_rh_high": [0.0, 1.0, false],
	"cloud_response": [0.0001, 1.0, false],
	"rain_cloud_low": [0.0, 100.0, false],
	"rain_cloud_high": [0.0, 100.0, false],
	"precipitation_response": [0.0001, 1.0, false],
	"rain_efficiency": [0.0, 1.0, false],
	"snow_temperature": [0.0, 100.0, false],
	"cold_floor": [0.0, 50.0, false],
}
## [lower, upper]: lower must be strictly below upper.
const ORDERED_PAIRS := [
	["ice_full", "ice_free"],
	["evap_cold", "evap_warm"],
	["capacity_cold", "capacity_warm"],
	["cloud_rh_low", "cloud_rh_high"],
	["rain_cloud_low", "rain_cloud_high"],
]

var base_temperature: float
var thermal_response: float
var season_period_ticks: int
var season_amplitude: float
var drift_reversion: float
var drift_noise: float
var drift_limit: float
var ice_strength: float
var ice_full: float
var ice_free: float
var cloud_albedo: float
var cloud_ref: float
var vegetation_albedo: float
var greenhouse: float
var greenhouse_ref: float
var water_availability: float
var evaporation_rate: float
var evap_cold: float
var evap_warm: float
var capacity_cold: float
var capacity_warm: float
var cloud_rh_low: float
var cloud_rh_high: float
var cloud_response: float
var rain_cloud_low: float
var rain_cloud_high: float
var precipitation_response: float
var rain_efficiency: float
var snow_temperature: float
## Width of the soft floor: cooling fades out as temperature approaches 0.
var cold_floor: float


static func load_json(path: String) -> SimResult:
	var read := CoefficientLoader.read_json(path, "climate")
	return from_data(read.value) if read.is_ok() else read


## Validates everything and reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	return CoefficientLoader.fill(ClimateConfig.new(), data, SPEC, ORDERED_PAIRS, "climate")
