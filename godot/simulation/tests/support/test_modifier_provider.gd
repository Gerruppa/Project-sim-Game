class_name TestModifierProvider
extends ModifierProvider
## Test-only provider: adds the given modifiers on the given ticks.

## tick -> Array[Modifier]
var schedule := {}


func system_id() -> StringName:
	return &"test_provider"


func provide_modifiers(_snapshot: PlanetSnapshot, tick: int, registry: ModifierRegistry) -> void:
	for modifier: Modifier in schedule.get(tick, []):
		registry.add(modifier)
