class_name SimulationSystem
extends RefCounted
## Contract of every domain system (Climate, Atmosphere, Biosphere, ...).
##
## A system is a function of the world: it reads a snapshot of the previous
## tick and returns deltas. It never writes PlanetState and never references
## other systems. One level of inheritance only; behaviour comes from
## composition inside each system.


## Unique, stable id. Used as delta source and as SeededRng stream id.
func system_id() -> StringName:
	push_error("SimulationSystem.system_id must be overridden")
	return &""


func compute(_snapshot: PlanetSnapshot) -> Array[Delta]:
	push_error("SimulationSystem.compute must be overridden")
	return []
