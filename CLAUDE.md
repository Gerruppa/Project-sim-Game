# CLAUDE.md

# Genesis Error

Version: 1.0
Project Type: Planetary Evolution Simulation
Engine: Godot 4.7.2 stable (pinned, see docs/simulation.md)
Language: GDScript
Architecture: Data Driven + Event Driven
Development Stage: Console Simulation First

---

# PROJECT VISION

Genesis Error is not a city builder.

Genesis Error is not a colony simulator.

Genesis Error is not a survival game.

Genesis Error is a simulation game about guiding the evolution of a living planet.

The planet is the main character.

The player is a catalyst.

The core fantasy is:

"Observe, influence, and understand an evolving world."

Every system must contribute to that fantasy.

---

# DEVELOPMENT PHILOSOPHY

Always prioritize:

1. Simulation
2. System interactions
3. Emergent gameplay
4. Gameplay decisions
5. Visualization
6. Graphics

Never reverse this order.

---

# CURRENT PROJECT GOAL

The simulation has proven it can generate surprises, instability,
adaptation, evolution and stories (steps 1-8).

The current goal is a console prototype that proves
the player's decisions are interesting:
decision points, interventions, hints and goals
(`./godot/play.sh`, player guide: docs/jak_grac.md).

No visual layer is required yet.
Visualization (step 10) comes after playtests in the console.

Every new mechanic must first show in the console
(chronicle, logs, decision screen)
that it creates decisions worth making.

Next stages and all ideas: docs/plan_rozwoju.md.

---

# FUN DETECTOR

Genesis Error must not become
an engineering project disguised as a game.

Every feature answers one question:

"Is this actually fun?"

Not "is it realistic?".
Not "is it technically impressive?".

Fun Detector is the highest design priority.
It may challenge every other skill and veto any feature.
Skill: `genesis-fun-detector` (docs/skills.md).

Use it before:

- designing or expanding a system
- adding simulation depth or complexity
- new species, events, climate mechanics
- roadmap decisions
- any large feature

Every evaluated feature gets scores
(fun, clarity, story potential, replayability,
complexity, development and maintenance cost)
and a verdict:

KEEP / SIMPLIFY / POSTPONE / REMOVE

Scope:

The veto applies to features,
not to engineering rules.

Determinism, snapshot + deltas, tests and the build order
are never traded for fun.
They keep the simulation trustworthy enough to be fun.

Current stage:

The player plays in the console (`./godot/play.sh`)
and reads the planet's chronicle.

A feature is fun now if the decision screens and the chronicle show
surprises, stories and causes worth understanding,
and if the player gets a decision worth making.
Measure it (tools in godot/simulation/tests/tools/) before keeping it.

Most dangerous state:

simulation depth > gameplay depth

Bad: 50 simulated species, 1 meaningful decision.

Good: 5 simulated species, 20 meaningful decisions.

The observer should say:

"I wonder what happens if..."

more often than:

"I found the optimal strategy."

A boring simulation is still boring.
No amount of technical excellence can save it.

---

# CORE DESIGN PRINCIPLES

## Principle 1

The planet is the protagonist.

Never design systems from the perspective of:

- buildings
- vehicles
- technology trees
- progression systems

Always design from the perspective of:

- climate
- biosphere
- ecosystems
- planetary evolution

---

## Principle 2

Everything affects PlanetState.

Any feature that does not interact with PlanetState should be questioned.

Examples:

GOOD

- climate changes
- extinction events
- species growth

BAD

- inventory systems
- cosmetic gameplay
- disconnected mechanics

---

## Principle 3

Systems over content.

Prefer:

one good system
over
twenty handcrafted events

---

## Principle 4

Emergence over scripting.

Prefer:

system interaction

instead of:

hardcoded gameplay sequences

---

## Principle 5

Data over code.

Configuration should live in:

- Resources
- Data Assets
- JSON files

Avoid hardcoded values.

---

# SIMULATION FIRST RULE

Before implementing ANY visual feature ask:

Can this be observed in console logs first?

If yes:

implement console version first.

Examples:

GOOD ORDER

simulation
↓
logs
↓
debug visualization
↓
final visualization

BAD ORDER

visual effect
↓
shader
↓
animation
↓
simulation

---

# ARCHITECTURE RULES

## Preferred Patterns

Use:

- Composition
- Observer Pattern
- Event Bus
- Data Driven Design
- ECS-style thinking

Avoid:

- deep inheritance
- god objects
- hard dependencies
- circular references

---

# SINGLE SOURCE OF TRUTH

PlanetState is the only source of truth.

No duplicated state.

Example:

GOOD

PlanetState.temperature

BAD

ClimateManager.temperature
AtmosphereManager.temperature
WorldManager.temperature

---

# EVENT BUS RULE

Systems must communicate through events.

Avoid direct system dependencies.

Example:

BAD

ClimateSystem directly modifies UI.

GOOD

ClimateSystem emits event.

UI reacts.

Simulation reacts.

Narrative reacts.

Events report facts that already happened.
Events never drive the order of computation.

Simulation systems read PlanetState through a snapshot
and change it only by returning deltas to StateWriter.

Details: docs/architecture.md (COMMUNICATION MODEL)

---

# SYSTEM PRIORITY

Current development order:

1. PlanetState
2. TickScheduler
3. ClimateSystem
4. AtmosphereSystem
5. BiosphereSystem
6. PersonalitySystem
7. EventSystem
8. SaveSystem
9. Gameplay Layer
10. Visualization Layer

Never skip steps.

---

# PLANET STATE

Current planetary parameters:

- temperature
- humidity
- oxygen
- biomass
- cloud cover
- precipitation
- co2
- crust oxidation

Future parameters:

- pressure
- toxicity
- radiation
- ocean level
- geological activity

All parameters must:

- have limits
- have validation
- support serialization
- support testing

---

# TICK SYSTEM

Simulation must not depend on FPS.

Simulation uses one fixed tick size.

Speed is the number of ticks per real second.
It never changes the size of a tick.

Simulation must support:

- pause
- resume
- speed x1
- speed x10
- speed x100

Details: docs/simulation.md

Simulation should be deterministic.

Same seed.

Same result.

---

# BIOSPHERE PHILOSOPHY

Never simulate individual organisms.

Simulate populations.

Each species contains:

- population
- growth rate
- mortality rate
- environmental requirements
- environmental effects

Goal:

Large-scale ecosystem simulation.

Not creature simulation.

---

# SPECIES DESIGN RULES

Each species must answer:

What does it consume?

What does it produce?

What environment does it need?

What happens if it disappears?

What happens if it dominates?

If these answers do not exist,
the species design is incomplete.

---

# EVENT SYSTEM RULES

Events should emerge from simulation.

Prefer:

"Drought occurs because humidity collapsed."

Not:

"5% random chance of drought."

Every event must have:

- trigger conditions
- active phase
- ending conditions
- measurable effects

---

# PLANET PERSONALITY RULES

Planet personality exists to create variety.

The planet is NOT truly intelligent.

The player should feel it is intelligent.

Current archetypes:

- Harmonious
- Chaotic
- Guardian

Each archetype modifies:

- event generation
- ecosystem growth
- climate stability

---

# PERFORMANCE PHILOSOPHY

Never optimize blindly.

Measure first.

Optimize second.

Rules:

1. Working system first.
2. Profiling second.
3. Optimization third.

Avoid premature optimization.

---

# LOGGING RULES

Every simulation tick must be observable.

Important events must be logged.

Examples:

[Tick 100]
Temperature +2

[Tick 500]
Species Moss expanded

[Tick 1200]
Oxygen reached critical threshold

Logs are part of gameplay design.

Logs are not temporary.

Every run writes text and JSON Lines to logs/simulation_runs/.
Run: GODOT_BIN=<godot console binary> ./godot/run_simulation.sh (formats in docs/simulation.md)

---

# TESTING PHILOSOPHY

Every system must support:

- unit tests
- integration tests
- simulation tests

No system is complete without tests.

Framework: gdUnit4. Run: GODOT_BIN=<godot console binary> ./godot/run_tests.sh

Simulation code must follow the deterministic math policy
(docs/simulation.md). Architecture tests enforce it.

---

# ACCEPTANCE CRITERIA TEMPLATE

Every feature must define:

## Goal

Why the feature exists.

## Inputs

What data it receives.

## Outputs

What data it modifies.

## Constraints

What limits exist.

## Acceptance Criteria

What determines completion.

## Test Cases

How completion is verified.

---

# CODE STYLE

Prefer:

small classes

small methods

single responsibility

clear names

Examples:

PlanetState
ClimateSystem
SpeciesPopulation
EventManager

Avoid:

ManagerManager
GlobalSystemHandler
MegaController

---

# FILE STRUCTURE

res:// (the Godot project lives in godot/)

addons/

simulation/

simulation/core/

simulation/scheduling/

simulation/planet/

simulation/climate/

simulation/atmosphere/

simulation/biosphere/

simulation/modifiers/

simulation/events/

simulation/personality/

simulation/narrative/

simulation/interventions/

simulation/tests/

game/ (game layer above the simulation: SimulationRunner,
PlaySession, GoalTracker, DecisionWatcher, HintAdvisor, saves)

tools/ (entry points only: run_simulation.gd, play.gd)

resources/

Outside res:// (repository root):

docs/ (design, player guide, plan: docs/plan_rozwoju.md)

logs/ and saves/ (generated, not in git)

---

# AI REQUEST RULES

Whenever helping with implementation:

0. For a new or large feature, ask first whether it is fun
   (genesis-fun-detector). A feature that fails is not built.
1. Explain architecture first.
2. Explain tradeoffs.
3. Explain risks.
4. Then generate code.
5. Then generate tests.
6. Then generate acceptance criteria.

Never provide code only.

Always explain