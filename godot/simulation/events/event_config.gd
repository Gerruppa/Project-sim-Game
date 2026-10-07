class_name EventConfig
extends RefCounted
## How the crises of a planet behave as a whole: how hard they hit and how long
## they rest. The two numbers are coefficients, so perks (the Shield branch)
## turn them like any other: severity pulls every modifier of a starting crisis
## toward "no change", cooldown_scale stretches the rest after it.
## Data: resources/events/event_config.json.

const DEFAULT_PATH := "res://resources/events/event_config.json"

## name -> [min, max, integer]
const SPEC := {
	"severity": [0.1, 1.0, false],
	"cooldown_scale": [0.1, 10.0, false],
}
const ORDERED_PAIRS := []

## 1 = a crisis hits as written in data; less softens it (applies when it starts).
var severity: float
## 1 = the rest after a crisis is as written; more makes crises rarer.
var cooldown_scale: float


static func load_json(path: String = DEFAULT_PATH) -> SimResult:
	var read := CoefficientLoader.read_json(path, "event_config")
	return from_data(read.value) if read.is_ok() else read


## Validates everything and reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	return CoefficientLoader.fill(EventConfig.new(), data, SPEC, ORDERED_PAIRS, "event_config")


## Crises exactly as written in data.
static func neutral() -> EventConfig:
	var config := EventConfig.new()
	config.severity = 1.0
	config.cooldown_scale = 1.0
	return config
