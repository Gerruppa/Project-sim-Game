extends GdUnitTestSuite

const P := preload("res://simulation/tests/support/schema_fixtures.gd")


func test_new_state_starts_with_initial_values() -> void:
	var state: PlanetState = PlanetState.create(P.schema()).value
	assert_float(state.get_value(&"temperature")).is_equal(35.0)
	assert_float(state.get_value(&"biomass")).is_equal(0.0)


func test_overrides_replace_initial_values() -> void:
	var result := PlanetState.create(P.schema(), {"temperature": 60.0, &"biomass": 12.5})
	assert_bool(result.is_ok()).is_true()
	var state: PlanetState = result.value
	assert_float(state.get_value(&"temperature")).is_equal(60.0)
	assert_float(state.get_value(&"biomass")).is_equal(12.5)


func test_override_with_unknown_id_fails() -> void:
	var result := PlanetState.create(P.schema(), {"pressure": 10.0})
	assert_str("\n".join(result.errors)).contains("pressure")


func test_override_outside_limits_fails() -> void:
	var result := PlanetState.create(P.schema(), {"temperature": 150.0})
	assert_str("\n".join(result.errors)).contains("temperature")


func test_override_with_non_finite_value_fails() -> void:
	assert_bool(PlanetState.create(P.schema(), {"temperature": NAN}).is_ok()).is_false()
	assert_bool(PlanetState.create(P.schema(), {"temperature": INF}).is_ok()).is_false()


func test_override_with_non_numeric_value_fails() -> void:
	assert_bool(PlanetState.create(P.schema(), {"temperature": "hot"}).is_ok()).is_false()


func test_values_copy_is_independent() -> void:
	var state: PlanetState = PlanetState.create(P.schema()).value
	var copy := state.values_copy()
	copy[0] = 99.0
	assert_float(state.get_value_at(0)).is_equal(35.0)


func test_snapshot_reads_values_and_carries_tick() -> void:
	var state: PlanetState = PlanetState.create(P.schema()).value
	var snapshot := state.snapshot(17)
	assert_int(snapshot.tick()).is_equal(17)
	assert_float(snapshot.get_value(&"temperature")).is_equal(35.0)
	assert_float(snapshot.get_value_at(1)).is_equal(0.0)
	assert_int(snapshot.size()).is_equal(2)


func test_snapshot_does_not_change_when_state_changes() -> void:
	var state: PlanetState = PlanetState.create(P.schema()).value
	var snapshot := state.snapshot(0)
	StateWriter.new(state).apply([Delta.new(&"temperature", 5.0, &"test", &"warming")])
	assert_float(state.get_value(&"temperature")).is_equal(40.0)
	assert_float(snapshot.get_value(&"temperature")).is_equal(35.0)
