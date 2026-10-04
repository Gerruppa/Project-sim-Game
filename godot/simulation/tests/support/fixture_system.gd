class_name TestFixtureSystem
extends SimulationSystem
## Test-only adapter: runs TestFixtureDynamics as a registered system,
## so the real TickPipeline can be exercised before domain systems exist.

var _dynamics: TestFixtureDynamics


func _init(global_seed: int) -> void:
	_dynamics = TestFixtureDynamics.new(global_seed)


func system_id() -> StringName:
	return &"test_fixture"


func compute(snapshot: PlanetSnapshot) -> Array[Delta]:
	return _dynamics.compute(snapshot)
