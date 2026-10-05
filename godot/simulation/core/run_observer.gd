class_name RunObserver
extends RefCounted
## Watches a run through the EventBus without affecting it: the simulation
## log, the planet chronicle, later UI. SimulationManager keeps observers
## alive (bus subscriptions do not), calls begin_run before the first tick
## and close when the run stops.


func attach(_bus: EventBus) -> void:
	pass


func begin_run(_seed_value: int, _initial: PlanetSnapshot) -> void:
	pass


func close() -> void:
	pass
