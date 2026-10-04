class_name ModifierProvider
extends SimulationSystem
## A system that shapes the planet only through modifiers (PersonalitySystem
## now, EventSystem later). TickPipeline calls provide_modifiers in phase 2,
## before any system computes. Providers usually return no deltas.


## Adds or removes modifiers for tick `tick`. Reads the snapshot of tick-1.
func provide_modifiers(_snapshot: PlanetSnapshot, _tick: int, _registry: ModifierRegistry) -> void:
	pass


func compute(_snapshot: PlanetSnapshot) -> Array[Delta]:
	return []
