# ARCHITECTURE.md

# How Genesis Error is built

A one-page answer to "how is this project built?".
Details and rules: `docs/architecture.md`. Time, determinism, logs: `docs/simulation.md`.

---

# In one sentence

A deterministic planet simulation in Godot 4.7.2 (GDScript) that runs headless
in the console: every tick, independent systems read a frozen copy of the
planet, propose changes with a cause, and one writer applies them.

---

# Layers

```text
UI              (future)
Visualization   (future)
Gameplay        (future)   player actions enter as commands
─────────────────────────────────────────────────────────
Simulation      runs alone, no UI, no graphics, no player
Data            JSON files with numbers, no logic
```

Dependencies point down only. The simulation does not know the upper layers exist.

---

# What happens in one tick

```text
            ┌─────────────────────────────────────────────┐
 tick N     │ 1. snapshot of the planet after tick N-1    │
            │ 2. every due system: snapshot -> deltas      │
            │    (delta = parameter, amount, source, cause)│
            │ 3. StateWriter: validate, sort, sum, clamp,  │
            │    apply all at once                         │
            │ 4. events queued, delivered in fixed order   │
            │ 5. log: text + JSON Lines                    │
            └─────────────────────────────────────────────┘
```

- Systems never talk to each other and never write the planet directly.
- Feedback loops (temperature → humidity → biomass → oxygen → ...) work through
  the snapshot, one tick later. No circular dependencies.
- Same seed + same inputs = bit-identical result (checked by a golden trace in CI).

---

# Repository layout

```text
CLAUDE.md, DESIGN_PRINCIPLES.md, CORE_LOOP.md   vision and rules
ARCHITECTURE.md                                 this page
docs/                                           detailed design
godot/                                          the Godot project (res://)
  project.godot
  resources/                                    data (JSON)
  simulation/
    core/          PlanetState, StateWriter, Delta, EventBus, log, RNG, math
    planet/        parameter schema, snapshot
    climate/       ClimateSystem, ClimateConfig
    atmosphere/    AtmosphereSystem, AtmosphereConfig
    biosphere/     BiosphereSystem, species catalog
    modifiers/     ModifierRegistry, Modifier, ModifierProvider
    personality/   PersonalitySystem, archetype catalog
    scheduling/    TickScheduler, TickPipeline, SimulationManager
    tests/         gdUnit4: unit, integration, simulation, architecture
  tools/           console entry points
  addons/gdUnit4/  test framework
logs/simulation_runs/                           run logs (not in git)
.claude/skills/                                 project skills for Claude Code
.github/workflows/                              CI on Linux, Windows, macOS
```

---

# Key building blocks

| Block | Responsibility |
|---|---|
| PlanetState | the only source of truth: temperature, humidity, oxygen, biomass, cloud cover, precipitation, co2, crust oxidation (0..100) |
| ParameterSchema | which parameters exist, their limits and meaning, loaded from JSON |
| PlanetSnapshot | read-only copy given to systems |
| Delta | one proposed change with source and cause |
| StateWriter | the only code allowed to change PlanetState |
| TickScheduler | fixed tick, 1 tick/s at x1, pause, x10, x100 |
| TickPipeline | the fixed order of a tick |
| SimulationManager | wires everything together, runs ticks |
| EventBus | queued notifications about facts that already happened |
| SimulationLog | every tick written as text and JSON Lines |
| SimMath, SeededRng | math and randomness that give the same bits on every platform |
| ClimateSystem | seasons, climate drift, ice-albedo tipping point, water cycle, clouds, rain |
| AtmosphereSystem | carbon cycle (volcanoes vs weathering), CO2 greenhouse, oxygen sources and sinks |
| BiosphereSystem | species populations: growth, competition by height, succession, fires; emits species events |
| ModifierRegistry | coefficient modifiers (add, multiply, clamp) applied before systems compute |
| PersonalitySystem | planet archetype: permanent modifiers, never deltas |

---

# Status

| Step (CLAUDE.md order) | State |
|---|---|
| 1. PlanetState | done |
| 2. TickScheduler and simulation skeleton | done |
| 3. ClimateSystem | done: seasons, ice ages, water cycle, clouds, rain |
| 4. AtmosphereSystem | done: carbon thermostat, volcanic thaw of ice ages, oxygen sinks |
| 5. BiosphereSystem | done: succession, oxygenation, forests and fires, anaerobe refuge |
| 6. PersonalitySystem | done: Harmonious, Chaotic, Guardian via ModifierRegistry |
| 7. EventSystem | next (includes planet reactions per archetype) |
| 8–10. Save, Gameplay, Visualization | planned |

---

# How to run

```bash
export GODOT_BIN=<Godot 4.7.2 console binary>
./godot/run_tests.sh                                      # all tests
./godot/run_simulation.sh                                 # 3600 ticks (1 h at x1), batch
./godot/run_simulation.sh --realtime --speed 10 --seconds 60
./godot/run_simulation.sh --personality guardian          # harmonious, chaotic, guardian, random, none
```

Each run writes `logs/simulation_runs/<run id>.log` (text) and `.jsonl` (JSON Lines).
