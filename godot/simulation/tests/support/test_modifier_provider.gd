class_name TestModifierProvider
extends ModifierProvider
## Test-only provider: adds the given modifiers on the given ticks, in
## phase 2 (schedule) or phase 5 (detect_schedule), and records detect calls.

## tick -> Array[Modifier]
var schedule := {}


func system_id() -> StringName:
	return &"test_provider"


func provide_modifiers(_snapshot: PlanetSnapshot, tick: int, registry: ModifierRegistry) -> void:
	for modifier: Modifier in schedule.get(tick, []):
		registry.add(modifier)


## tick -> Array[Modifier], added in phase 5 (Detect).
var detect_schedule := {}
## [tick, snapshot tick, temperature] for every detect call.
var detected: Array[Array] = []


func detect(snapshot: PlanetSnapshot, tick: int, registry: ModifierRegistry) -> void:
	detected.append([tick, snapshot.tick(), snapshot.get_value(Param.TEMPERATURE)])
	for modifier: Modifier in detect_schedule.get(tick, []):
		registry.add(modifier)
