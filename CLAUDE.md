# CLAUDE.md

# Genesis Error

Version: 1.0
Project Type: Planetary Evolution Simulation
Engine: Godot 4.x
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

The current goal is NOT to create a game.

The current goal is to create a simulation that produces interesting outcomes.

No visual layer is required.

No UI is required.

No player interaction is required.

The simulation must first prove that it can generate:

- surprises
- instability
- adaptation
- evolution
- interesting stories

Only then can gameplay systems be added.

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

Future parameters:

- pressure
- co2
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

Simulation must support:

- pause
- resume
- speed x1
- speed x10
- speed x100

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

---

# TESTING PHILOSOPHY

Every system must support:

- unit tests
- integration tests
- simulation tests

No system is complete without tests.

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

res://

addons/

simulation/

simulation/core/

simulation/planet/

simulation/climate/

simulation/biosphere/

simulation/events/

simulation/personality/

simulation/tests/

resources/

docs/

logs/

---

# AI REQUEST RULES

Whenever helping with implementation:

1. Explain architecture first.
2. Explain tradeoffs.
3. Explain risks.
4. Then generate code.
5. Then generate tests.
6. Then generate acceptance criteria.

Never provide code only.

Always explain