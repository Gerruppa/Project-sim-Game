extends GdUnitTestSuite
## PersonalitySystem in the real SimulationManager with all domain systems.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")
const Q := preload("res://simulation/tests/support/personality_fixtures.gd")

const TICKS := 2000


func _manager(choice: StringName, with_personality: bool = true) -> SimulationManager:
	var config: SimConfig = SimConfig.load_json(SimConfig.DEFAULT_PATH).value
	var manager: SimulationManager = SimulationManager.create(config, P.project_schema()).value
	manager.register_system(ClimateSystem.new(ClimateConfig.load_json(ClimateConfig.DEFAULT_PATH).value, 42))
	manager.register_system(AtmosphereSystem.new(AtmosphereConfig.load_json(AtmosphereConfig.DEFAULT_PATH).value))
	manager.register_system(BiosphereSystem.new(BiosphereConfig.load_json(BiosphereConfig.DEFAULT_PATH).value,
			SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value, 42))
	if with_personality:
		manager.register_system(PersonalitySystem.create(Q.project_catalog(), choice, 42).value)
	return manager


func test_no_personality_is_bit_identical_to_the_planet_without_it() -> void:
	var without := _manager(&"", false)
	var none := _manager(PersonalityCatalog.NONE)
	without.run_ticks(TICKS)
	none.run_ticks(TICKS)
	assert_str(none.state_hash()).is_equal(without.state_hash())


func test_an_archetype_changes_the_planet() -> void:
	var none := _manager(PersonalityCatalog.NONE)
	var chaotic := _manager(&"chaotic")
	none.run_ticks(TICKS)
	chaotic.run_ticks(TICKS)
	assert_str(chaotic.state_hash()).is_not_equal(none.state_hash())


func test_modifiers_reach_the_systems() -> void:
	var manager := _manager(&"chaotic")
	manager.run_ticks(1)
	var targets := manager.modifier_registry().modifiers().map(func(m: Modifier) -> String: return String(m.target))
	assert_array(targets).contains(["climate.drift_noise", "atmosphere.volcanic_co2", "biosphere.fire_rate"])


func test_personality_is_written_to_the_log() -> void:
	var manager := _manager(&"guardian")
	var text := MemoryLogSink.new()
	manager.attach_log(SimulationLog.new([text], [], true))
	manager.run_ticks(1)
	var personality_lines := Array(text.lines).filter(func(line: String) -> bool: return line.contains("planet_personality"))
	assert_int(personality_lines.size()).is_equal(1)
	assert_str(personality_lines[0]).starts_with("[Tick 1] EVENT planet_personality from personality")
	assert_str(personality_lines[0]).contains("guardian")
