class_name ModifierProvider
extends SimulationSystem
## A system that shapes the planet only through modifiers (PersonalitySystem,
## EventSystem). TickPipeline calls provide_modifiers in phase 2, before any
## system computes, and detect in phase 5, after the tick's state is applied.
## Providers usually return no deltas.


## Adds or removes modifiers for tick `tick`. Reads the snapshot of tick-1.
func provide_modifiers(_snapshot: PlanetSnapshot, _tick: int, _registry: ModifierRegistry) -> void:
	pass


## Reacts to the state tick `tick` just produced. Modifiers changed here take
## effect from phase 2 of the next tick. Runs every tick, whatever the
## registration interval; not called when the tick's batch was rejected.
func detect(_snapshot: PlanetSnapshot, _tick: int, _registry: ModifierRegistry) -> void:
	pass


## After load_state: registers the modifiers the restored state implies.
## The registry is never saved; providers are its only source of truth.
func restore_modifiers(_registry: ModifierRegistry) -> void:
	pass


func compute(_snapshot: PlanetSnapshot) -> Array[Delta]:
	return []
