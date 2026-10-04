# ARCHITECTURE.md

# Genesis Error Technical Architecture

Version: 1.1

Engine: Godot 4.7.2 stable (pinned, see docs/simulation.md)

Language: GDScript

Architecture Style:
Data Driven + Event Driven + Deterministic Simulation

---

# PURPOSE

This document describes the technical architecture of Genesis Error.

It defines:

- system boundaries
- communication patterns
- data ownership
- update order
- scalability rules
- testing requirements

This document is the source of truth for all technical decisions.

Related documents:

- `docs/simulation.md` - tick model, determinism, logging
- `docs/climate.md` - ClimateSystem and AtmosphereSystem
- `docs/biosphere.md` - BiosphereSystem and species
- `docs/events.md` - EventSystem, modifiers, personality

---

# HIGH LEVEL OVERVIEW

Genesis Error is a planetary evolution simulation.

The simulation layer is the foundation of the project.

All other layers depend on simulation.

Core hierarchy:

Simulation
↓
Gameplay
↓
Visualization
↓
UI

Never invert this dependency chain.

---

# CORE ARCHITECTURE

```text
┌──────────────────────────────────────────────────────────────┐
│ Observers (future: UI, Visualization, Narrative, Audio)      │
└───────────────▲──────────────────────────────┬───────────────┘
                │ events (read-only)           │ commands
┌───────────────┴──────────────────────────────▼───────────────┐
│ Gameplay Layer (future): player interventions → commands     │
└───────────────▲──────────────────────────────┬───────────────┘
                │                              │
╔═══════════════╧══════════════════════════════▼═══════════════╗
║                     SIMULATION LAYER                         ║
║                                                              ║
║  ORCHESTRATION                                               ║
║    SimulationManager ─► TickScheduler ─► TickPipeline        ║
║                                                              ║
║  DOMAIN SYSTEMS (never reference each other)                 ║
║    ClimateSystem  AtmosphereSystem  BiosphereSystem          ║
║                                                              ║
║  MODIFIERS AND EVENTS                                        ║
║    ModifierRegistry  PersonalitySystem  EventSystem          ║
║                                                              ║
║  CORE (no upward dependencies)                               ║
║    PlanetState  StateWriter  EventBus  SeededRng             ║
║    CommandQueue  SimulationLog  SaveSystem                   ║
╚═════════════════════════════▲════════════════════════════════╝
                              │
┌─────────────────────────────┴────────────────────────────────┐
│ Data Layer: ParameterDefs, SpeciesData, EventDefs,           │
│ PersonalityDefs, SimConfig (Resources / JSON, no logic)      │
└──────────────────────────────────────────────────────────────┘
```

Dependency rule:

Dependencies point downward only.

Domain systems depend on Core and Data.

Domain systems do not depend on each other,
on EventSystem or on PersonalitySystem.

The simulation does not know that UI, Visualization
or Gameplay exist.

---

# SIMULATION LAYER

The simulation layer is independent.

It must run without:

- UI
- graphics
- player input
- audio

The simulation must be executable in a console application.

If a system requires visualization to function,
the architecture is wrong.

---

# COMMUNICATION MODEL

Four channels exist.
They must never be mixed.

| Channel | Direction | Mechanism | Purpose |
|---|---|---|---|
| State | system ← Core | read-only snapshot | read the world |
| Change | system → Core | deltas with cause | propose changes |
| Notification | system → observers | EventBus | report facts after they happened |
| Control | outside → simulation | CommandQueue | player, tests, debug |

## Rules

1. Systems read PlanetState only through a snapshot.
2. Systems never write PlanetState directly.
   They return deltas. StateWriter is the only writer.
3. EventBus carries facts that already happened.
   It never drives the order of computation.
4. EventBus delivery is a FIFO queue flushed in a fixed phase.
   No re-entrant dispatch.
5. Anything that comes from outside enters through CommandQueue
   and is executed on a tick boundary.

## Why not "everything through events"

Event-driven control flow makes execution order depend on
subscription order. That breaks determinism and debugging.

Order of computation is explicit (TickPipeline).
Events inform. They do not command.

## Breaking circular feedback

Climate, Atmosphere and Biosphere form a natural feedback loop.

temperature → humidity → biomass → oxygen → life → temperature

The loop is not removed. It is broken in time.

All systems in tick N read the snapshot from the end of tick N-1.
Their deltas are applied together at the end of the compute phase.

Consequences:

- the result does not depend on system call order
- every reaction has a natural one-tick delay
- no system holds a reference to another system

---

# CORE MODULES

## PlanetState

Single source of truth.

Stores complete planetary state.

Owns (schema v3):

- temperature
- humidity
- oxygen
- biomass
- cloud_cover
- precipitation
- co2
- crust_oxidation

Future:

- pressure
- radiation
- toxicity
- ocean_level
- geology

Responsibilities:

- hold parameter values
- enforce limits (from ParameterDefs)
- validate values
- serialize and deserialize
- produce an immutable snapshot

Rules:

No system may duplicate values stored here.

Contains no simulation logic.

Parameters are accessed by identifier, not by hardcoded fields,
so a future change from global values to regional values
does not break systems.

## Implementation

| Class | Base | File | Role |
|---|---|---|---|
| ParameterDef | RefCounted | `simulation/planet/parameter_def.gd` | immutable definition: id, display name, unit, min, max, initial, anchors |
| ParameterSchema | RefCounted | `simulation/planet/parameter_schema.gd` | ordered definitions, id → index, validation of data |
| Param | RefCounted | `simulation/planet/param.gd` | id constants (`Param.TEMPERATURE`) |
| PlanetState | RefCounted | `simulation/core/planet_state.gd` | values in `PackedFloat64Array` ordered by schema |
| PlanetSnapshot | RefCounted | `simulation/planet/planet_snapshot.gd` | read-only copy with tick |
| PlanetStateCodec | RefCounted | `simulation/core/planet_state_codec.gd` | save/load, exact values, state hash |
| SimResult | RefCounted | `simulation/core/sim_result.gd` | value + errors + warnings |

Rules:

- State is RefCounted, not Node: it runs headless and without the scene tree.
- PlanetState is created by SimulationManager and injected. It is never an autoload.
- Packed arrays are passed by reference in Godot 4. Every copy that leaves
  PlanetState (snapshot, values_copy) is duplicated explicitly.
- Validation returns SimResult instead of asserting:
  GDScript has no exceptions and assert() is stripped from release builds.
- Unknown ids return NAN, so a typo is rejected by StateWriter
  instead of silently reading zero.
- Static typing is required: `untyped_declaration` is an error in project settings.

## Normalized scale

Every parameter uses the scale 0..100.
The simulation computes only in normalized units.
Physical units exist only in presentation.

Each parameter defines anchors (meaning of 0, 50 and 100) in data:

| Parameter | 0 | 50 | 100 |
|---|---|---|---|
| temperature | frozen, no life possible | optimum for Earth-like life | boiling, no life possible |
| humidity | absolute desert | temperate climate | saturation, constant rain |
| oxygen | no oxygen | Earth level | toxic, extreme fire risk |
| biomass | dead planet | forests and shrubs | dense biosphere |
| cloud_cover | clear sky | moderate cloud cover | full cloud cover |
| precipitation | no precipitation | regular rain, temperate climate | downpours, constant monsoon |
| co2 | no CO2, no greenhouse, plants starve | dense young atmosphere, strong greenhouse | suffocating, Venus-like |
| crust_oxidation | fresh reduced crust absorbs oxygen | half oxidized | fully oxidized, oxygen can accumulate |

Thresholds (extinction, events) are defined in data,
never as comparisons with exact zero.

---

## StateWriter

The only write path into PlanetState.

Responsibilities:

- collect deltas from the compute phase
- sum deltas per parameter
- clamp to limits
- validate result
- apply atomically
- report every applied delta with its source and cause

Does not decide what a sensible change is.

Rules (`simulation/core/state_writer.gd`):

- any invalid delta (unknown parameter, NaN, INF, missing source or cause)
  rejects the whole batch; NaN is a model bug, never clamped
- deltas are summed in canonical order (parameter, source, cause, amount)
  because float addition is not associative
- clamping happens after summing, never per delta
- the result is an ApplyReport (changes, saturations, applied deltas);
  the pipeline turns it into events, so Core never depends on EventBus
- saturation is a balance signal and is logged

---

## Delta

A proposed change.

Fields:

- parameter
- amount
- source (which system)
- cause (why, as a short identifier)

The cause is mandatory.

It is the basis of the cause chain in logs
and of the player's ability to learn why something happened.

---

## SimulationManager

Central orchestrator.

Responsibilities:

- initialize systems from SimConfig
- register simulation modules
- own the TickPipeline
- run deterministic ticks

Must not contain business logic.

Responsibilities stop at orchestration.

Implementation (`simulation/scheduling/simulation_manager.gd`):

- `create(config, schema, overrides)` → SimResult; owns PlanetState,
  TickScheduler, TickPipeline, EventBus
- `register_system(system, interval)`, `attach_log(log)`
- `step()`, `run_ticks(n)` (batch), `advance(real_seconds)` (real time)
- tick 0 is the initial state; tick N reads the snapshot of tick N-1
- a rejected batch halts the simulation: state unchanged, tick not advanced,
  errors kept, further steps refused
- keeps references to attached logs, because EventBus subscriptions
  do not keep objects alive

Settings come from `godot/resources/simulation/sim_config.json`
(SimConfig): seed, `base_ticks_per_second` = 1, speeds [1, 10, 100],
`max_catch_up_ticks`, log flags and directory.

---

## TickScheduler

Controls simulation timing.

Responsibilities:

- fixed simulation step
- pause and resume
- speed control (x1, x10, x100)
- system intervals ("run every N ticks")

Rules:

Speed is the number of ticks per real second.
The tick itself never changes size.

Must not depend on FPS.

Must be deterministic.

Implementation (`simulation/scheduling/tick_scheduler.gd`):

- x1 = 1 tick per real second
- `advance(real_seconds)` returns the number of ticks due; fractions
  accumulate (a small epsilon absorbs float error such as 10 × 0.1 s)
- one advance never returns more than `max_catch_up_ticks`;
  the excess is dropped and counted, so a long stall slows the
  simulation instead of freezing it
- pause keeps partial progress; resume keeps the selected speed
- `is_due(tick, interval)`: a system with interval K runs on ticks K, 2K, ...

See `docs/simulation.md`.

---

## TickPipeline

The single place that defines the order of a tick.

```text
1. Begin       commands from CommandQueue, RNG advance
2. Modifiers   ModifierRegistry resolves effective coefficients
3. Compute     Climate, Atmosphere, Biosphere read snapshot, return deltas
4. Apply       StateWriter sums, clamps, validates, applies
5. Detect      EventSystem evaluates conditions on the new state
6. Dispatch    EventBus flushes queue (log, observers)
7. End         metrics, optional snapshot
```

No other module may define or change this order.

Implemented now (`simulation/scheduling/tick_pipeline.gd`):
Compute, Apply, Dispatch (publishes `tick_applied` or `batch_rejected`
with the ApplyReport, then flushes the EventBus). Begin, Modifiers and
Detect are documented placeholders, filled in with CommandQueue,
ModifierRegistry and EventSystem.

Every system extends `SimulationSystem` (`simulation/core/simulation_system.gd`):
`system_id()` and `compute(snapshot) -> Array[Delta]`. Systems with a
coefficient file also implement `coefficients()`, `coefficient_spec()` and
`apply_coefficients(effective)` so modifiers can reach them. Duplicate ids and
intervals below 1 are rejected at registration.

Systems report facts with `emit_event(type, data)` during compute. The
pipeline collects them (`take_events(tick)`) and publishes them in Dispatch,
after the tick event, in registration order. If the batch is rejected the
tick never happened, so its system events are dropped.

---

## EventBus

Global notification layer.

Responsibilities:

- publish events
- subscribe listeners
- decouple systems

Rules:

Events describe what happened.
They never carry commands.

Delivery is FIFO and happens in the Dispatch phase.

Handlers must not publish events that change simulation state.
State changes go through deltas or commands.

Implementation (`simulation/core/event_bus.gd`, `sim_event.gd`):

- `publish()` only queues; `flush()` delivers in publish order to
  subscribers in subscription order
- events published during a flush wait for the next flush
  (no re-entrant delivery, no infinite loops)
- a Callable does not keep its object alive; subscribers whose object
  was freed are dropped
- SimEvent: `type`, `tick`, `source`, `data` (plain values)
- Godot signals are forbidden in `simulation/` (architecture test)

---

## SeededRng

Deterministic randomness.

Rules:

- one global seed
- one independent stream per system
- adding a system must not change streams of other systems
- stream state is saved and restored
- global random functions are forbidden in simulation code

---

## CommandQueue

The only entry point from outside the simulation.

Examples:

- add species
- change a coefficient
- set seed

Commands run on a tick boundary.
Commands never bypass StateWriter.

---

## SimulationLog

Subscribes to EventBus and to applied deltas.

Responsibilities:

- structured log per tick
- cause chains
- log levels and aggregation for high speeds

Does not affect the simulation.

Logs are part of gameplay design.
They are not temporary.

Implementation (`simulation/core/simulation_log.gd`):

- writes to LogSinks: FileLogSink, PrintLogSink (console), MemoryLogSink (tests)
- two formats from the same events: text and JSON Lines
  (formats in `docs/simulation.md`)
- same seed → byte-identical logs (sorted keys, full float precision,
  no timestamps inside the logs)
- `log.deltas` in SimConfig switches per-delta causes on or off

---

## Console runner

`godot/tools/run_simulation.gd` (SceneTree entry) and
`godot/tools/simulation_runner.gd` (options, log files; testable).
Kept outside `simulation/` because it does file and process work.

```bash
GODOT_BIN=... ./godot/run_simulation.sh                  # batch, 3600 ticks
GODOT_BIN=... ./godot/run_simulation.sh --realtime --speed 10 --seconds 60
```

Domain systems are registered in `run_simulation.gd` as they are built.

---

## SaveSystem

Saves and restores:

- PlanetState
- current tick
- RNG stream states
- species populations
- active events
- active modifiers

The state format is designed for it from the beginning.
Implementation comes later (see system priority in CLAUDE.md).

---

# DOMAIN SYSTEMS

All domain systems follow one contract:

- read a snapshot
- read effective coefficients from ModifierRegistry
- return deltas
- hold no copy of planet parameters

A system may hold internal state
only if it is not a planet parameter
(for example species populations).

## Dynamics ownership

Every parameter has one system that owns its dynamics
(regulation, decay, equilibrium).

Other systems may contribute flows to it as deltas.

| Parameter | Dynamics owner | Contributors |
|---|---|---|
| temperature | ClimateSystem | AtmosphereSystem, BiosphereSystem |
| humidity | ClimateSystem | BiosphereSystem |
| oxygen | AtmosphereSystem | BiosphereSystem |
| biomass | BiosphereSystem (weighted sum of species populations) | none |
| cloud_cover | ClimateSystem | none |
| precipitation | ClimateSystem | none |
| co2 | AtmosphereSystem | BiosphereSystem (future: photosynthesis, respiration) |
| crust_oxidation | AtmosphereSystem | none |

Example:

A species produces oxygen.
BiosphereSystem returns an oxygen delta caused by that species.
AtmosphereSystem owns regulation and decay of oxygen.
Oxygen exists once, in PlanetState.

---

## ClimateSystem

Responsibilities:

- temperature
- humidity
- cloud cover
- precipitation
- seasons and slow climate drift

Status: implemented (`simulation/climate/`, data in `resources/climate/climate.json`).

Inputs:

Snapshot (temperature, humidity, cloud_cover, precipitation, biomass),
tick (season), own SeededRng stream; effective coefficients once
ModifierRegistry exists

Outputs:

Deltas for temperature, humidity, cloud_cover and precipitation,
one per named cause (radiative_balance, season, ice_albedo, greenhouse,
evaporation, rainfall, ...)

Internal state: climate drift (to be saved by SaveSystem)

Events (planned, emitted through the event queue once EventSystem exists):

TemperatureChanged

HumidityChanged

ClimateShift (e.g. entering or leaving an ice age)

See `docs/climate.md`.

---

## AtmosphereSystem

Responsibilities:

- carbon cycle: volcanic outgassing vs silicate weathering (a slow thermostat
  that also ends ice ages: no weathering under ice)
- oxygen sources and sinks: photolysis, crust oxidation, volcanic gases
- CO2 greenhouse contribution to temperature
- pressure calculations (future)

Status: implemented (`simulation/atmosphere/`, data in
`resources/atmosphere/atmosphere.json`). Pure function of the snapshot:
no randomness, no internal state.

Inputs:

Snapshot (temperature, humidity, precipitation, oxygen, co2,
crust_oxidation); effective coefficients once ModifierRegistry exists

Outputs:

Deltas for oxygen, co2, crust_oxidation and a temperature contribution,
one per named cause (volcanic_outgassing, silicate_weathering,
co2_greenhouse, photolysis, crust_oxidation, volcanic_gases)

Events (planned):

OxygenChanged

PressureChanged

AtmosphereCrisis

See `docs/climate.md`.

---

## BiosphereSystem

Most important gameplay system.

Responsibilities:

- species simulation
- population growth
- extinction
- environmental impact

Never simulates individual organisms.
Simulates populations.

Status: implemented (`simulation/biosphere/`, data in
`resources/biosphere/species.json` and `biosphere.json`).

Species populations are internal state (decision: not planet parameters);
biomass, owned by BiosphereSystem, is their weighted sum. A "census" delta
corrects biomass if it ever drifts from that sum.

Inputs:

Snapshot (temperature, humidity, precipitation, oxygen, co2, biomass),
species catalog, biosphere coefficients, own SeededRng stream

Outputs:

Deltas for biomass (per species growth/dieback) and flows to oxygen, co2
and humidity, with species-named causes (algae_photosynthesis,
tree_respiration, moss_transpiration, shrub_wildfire)

Events (emitted now through `emit_event`):

species_emerged

species_extinct

Planned: EcologicalShift (with EventSystem)

See `docs/biosphere.md`.

---

# MODIFIERS, PERSONALITY AND EVENTS

## ModifierRegistry

Holds active modifiers.

Modifier fields:

- target (coefficient identifier)
- operation (add, multiply)
- value
- source
- lifetime

Responsibilities:

- register and expire modifiers
- resolve effective coefficients once per tick

Operation order is defined in one place:

base value → add → multiply → clamp

Registration order must not change the result.

Implementation (`simulation/modifiers/`):

- `Modifier`: target `<system_id>.<coefficient>`, operation add|multiply,
  value, source, `expires_at` (last active tick, -1 permanent)
- `ModifierRegistry`: targets validated against each system's coefficient
  spec; modifiers folded in canonical order (float multiplication is not
  associative); result clamped to the spec range, integers stay integers;
  `version()` changes only when the set changes
- `ModifierProvider` (extends SimulationSystem): `provide_modifiers(snapshot,
  tick, registry)`, called in phase 2 for every provider, in registration order
- TickPipeline phase 2: providers run, expired modifiers drop
  (`expire(tick - 1)`), then, only if the set changed, every system with
  coefficients receives an effective copy via `apply_coefficients()`.
  Base coefficients (returned by `coefficients()` at registration) are never
  changed. With no modifiers nothing happens, so a planet without
  personality is bit-identical to one with personality "none".

---

## PersonalitySystem

Purpose:

Create planetary identity.

Planet is not actually intelligent.

Planet appears intelligent.

Responsibilities:

- select an archetype at start
- register constant modifiers

Archetypes:

Harmonious
Chaotic
Guardian

Outputs:

Modifiers only.

Never directly manipulate world state.

Status: implemented (`simulation/personality/`, data in
`resources/personality/personality.json`).

- archetype: forced id, "random" (weighted draw from its own SeededRng
  stream) or "none"; chosen in `sim_config.json` or with `--personality`
- modifiers registered once on tick 1 with source `personality:<id>`;
  modifiers for systems the planet does not run are skipped
- event `planet_personality` on tick 1 (archetype, description)
- reactions of the planet (healing, restlessness) are planned for
  EventSystem (step 7); see `docs/events.md`

---

## EventSystem

Purpose:

Convert simulation state into meaningful events.

Responsibilities:

- evaluate trigger conditions on the new state
- manage lifecycle: trigger → active phase → ending conditions
- register modifiers for the active phase
- publish lifecycle events

Rules:

Events have no private write path to PlanetState.

An active event only changes modifiers.
The state changes through the normal systems.

Example:

Drought does not set humidity.
Drought lowers the humidity recovery coefficient.
ClimateSystem produces the humidity decline.

This keeps events emergent.
They cannot become scripts.

See `docs/events.md`.

---

# DATA LAYER

Logic lives in code.
Numbers live in data.

Data assets:

- ParameterDefs: name, limits, initial value, unit, anchors
  (`godot/resources/planet/parameters.json`)
- SpeciesData: population, growth, mortality, requirements, effects
- EventDefs: triggers, duration, ending conditions, modifiers
- PersonalityDefs: modifier sets per archetype
- SimConfig: seed, speeds, system intervals

Rules:

Adding a species or an event must not require code changes.

Data is validated when loaded. All errors are reported at once.

Format decision: JSON instead of `.tres` Resources.
JSON is edited outside the Godot editor, diffs cleanly
and is validated explicitly by loaders. Loaded data is immutable,
which also avoids the shared-instance problem of cached Resources.

---

# FILE STRUCTURE

The Godot project lives in `godot/`, so `res://` is `godot/`.
Documentation stays in the repository root (`docs/`).

```text
res://  (godot/)
  addons/gdUnit4/   test framework
  simulation/
    core/           PlanetState, StateWriter, Delta, SimulationSystem, CoefficientLoader,
                    EventBus, SimEvent, SimulationLog, log sinks,
                    SeededRng, SimMath, CommandQueue, SaveSystem
    scheduling/     SimulationManager, TickScheduler, TickPipeline, SimConfig
    planet/         ParameterDefs, snapshot
    climate/        ClimateSystem
    atmosphere/     AtmosphereSystem, AtmosphereConfig
    biosphere/      BiosphereSystem, SpeciesData, SpeciesCatalog, BiosphereConfig
    modifiers/      Modifier, ModifierRegistry, ModifierProvider
    events/         EventSystem, EventDefs
    personality/    PersonalitySystem, PersonalityCatalog, PersonalityArchetype
    tests/          unit, integration, simulation, architecture,
                    support (test-only helpers), golden, tools
  resources/        data assets (planet/, simulation/)
  tools/            console runner (outside simulation/: file and process work)
```

---

# SCALABILITY RULES

1. A new domain system must not require edits to existing systems or Core.
2. Parameters are accessed by identifier.
3. Slow systems run on intervals, not every tick.
4. Regions and maps are not designed now.
   The architecture must only avoid blocking them.
5. Optimization happens after measurement.

---

# TESTING REQUIREMENTS

Every module requires:

- unit tests
- integration tests
- simulation tests

Required architecture-level tests:

- same seed, same commands → identical log
- result independent of system registration order
- save at tick N, load, continue M ticks = continuous run of N+M ticks
- speeds x1, x10, x100 → identical result after the same tick count
- direct write to PlanetState outside StateWriter is detected
- many seeds, long runs: no NaN, no permanent freeze, no divergence

Architecture tests (`simulation/tests/architecture/`) scan the source and fail when:

- simulation code calls forbidden math or global random functions
- RandomNumberGenerator is used outside SeededRng
- `_commit` is called outside PlanetState and StateWriter
- PlanetState is referenced outside core, scheduling and tests

---

# KNOWN RISKS

1. Model instability.
   One-tick feedback can oscillate or converge to a flat line.
   Needs statistical simulation tests over many seeds.

2. Boring or chaotic output.
   "Interesting" must be measured.
   Log regime changes, threshold crossings and extinctions
   per 1000 ticks.

3. Spatial scaling.
   Global scalars will become fields.
   Identifier-based access reduces the cost.

4. Modifier growth.
   Without a fixed operation order results depend
   on registration order.

5. Log volume at high speed.
   Use log levels and aggregation.
   Do not disable logs.

6. God object.
   SimulationManager must stay orchestration only.
