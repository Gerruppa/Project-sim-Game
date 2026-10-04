class_name AtmosphereConfig
extends RefCounted
## Validated AtmosphereSystem coefficients, loaded from JSON.
##
## Every coefficient is documented in docs/climate.md (AtmosphereSystem).
## Fields are public for readable formulas; treat them as read-only.

const DEFAULT_PATH := "res://resources/atmosphere/atmosphere.json"

## name -> [min, max, integer]
const SPEC := {
	"co2_greenhouse": [0.0, 5.0, false],
	"co2_ref": [0.0, 100.0, false],
	"volcanic_co2": [0.0, 5.0, false],
	"weathering_rate": [0.0, 10.0, false],
	"weathering_cold": [0.0, 100.0, false],
	"weathering_warm": [0.0, 100.0, false],
	"weathering_dry": [0.0, 10.0, false],
	"weathering_wet": [0.0, 10.0, false],
	"photolysis_rate": [0.0, 5.0, false],
	"crust_oxidation_rate": [0.0, 10.0, false],
	"crust_capacity": [0.0, 1.0, false],
	"volcanic_gas_sink": [0.0, 10.0, false],
}
const ORDERED_PAIRS := [["weathering_cold", "weathering_warm"]]

var co2_greenhouse: float
var co2_ref: float
var volcanic_co2: float
var weathering_rate: float
var weathering_cold: float
var weathering_warm: float
var weathering_dry: float
var weathering_wet: float
var photolysis_rate: float
var crust_oxidation_rate: float
var crust_capacity: float
var volcanic_gas_sink: float


static func load_json(path: String) -> SimResult:
	var read := CoefficientLoader.read_json(path, "atmosphere")
	return from_data(read.value) if read.is_ok() else read


## Validates everything and reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	return CoefficientLoader.fill(AtmosphereConfig.new(), data, SPEC, ORDERED_PAIRS, "atmosphere")
