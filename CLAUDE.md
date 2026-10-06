# CLAUDE.md

# Genesis Error

Version: 2.0 (new core, 2026-10-06)
Project Type: Strategy game, Plague Inc-style, goal: create lush life
Engine: Godot 4.7.2 stable (pinned, see docs/simulation.md)
Language: GDScript
Architecture: Data Driven + Event Driven
Platform: Steam
Development Stage: Stage 0 (documents) and Stage 1 (bubbles, Sparks, perk
shop) of the new core are done; next is Stage 2. Spec:
docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md

---

# PROJECT VISION

Genesis Error is a strategy game with the goal of Plague Inc reversed:
the player must create lush life, not destroy it.

Story: humanity doubts the Creator and claims that any fool with divine
powers could create life. The Creator names the player a temporary
Apprentice (Praktykant), gives them an empty planet and 200 years.
When the Apprentice does well, the Creator speeds up the cataclysms.

Genesis Error is not a city builder.

Genesis Error is not a colony simulator.

Genesis Error is not a survival game.

The player is the Creator's Apprentice.

The core fantasy is:

"Grow life across a planet, spend Sparks on perks,
and survive the Creator's Trials."

Every system must contribute to that fantasy.

The simulation stays global (no regions): life spreads over continents
and species capacity (spec chapter 4).

---

# DEVELOPMENT PHILOSOPHY

Always prioritize:

1. A playable loop on the map (bubbles, Sparks, perks)
2. Readable decisions and crises
3. The simulation engine
4. Presentation (graphics, audio)

Every stage ends with a playable version and a question to a tester.

The engineering rules below (determinism, snapshot + deltas, tests,
single source of truth) are not traded for speed.

---

# CURRENT PROJECT GOAL

The game is pivoting from "observe the planet" to a Plague Inc-style loop.
Spec: docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md
Plan: docs/superpowers/plans/2026-10-06-iskry-i-perki.md
Roadmap and history: docs/plan_rozwoju.md.

Stages:

- Stage 0: documents (this rewrite).
- Stage 1: bubbles, Sparks of Life, perk shop in the window,
  on the current planet; first 10 perks.
- Stage 2: reach: continents as data, `reach`, Dispersal tree,
  coverage drawn on the globe.
- Stage 3: Creator: Wrath, Trials with a warning, the Final Trial,
  Life Index, win and loss.
- Stage 4: meta: mutations, Legacy, three scenarios, humanity's faith,
  end screen.
- Stage 5: fauna (separate spec). Stage 6: Steam.

The simulation engine (climate, atmosphere, biosphere, modifiers, events)
stays. The window (`./godot/play_window.sh`) becomes the main interface.
The console (`./godot/play.sh`) is no longer the first interface;
`./godot/run_simulation.sh` stays as a balance tool.

Vertical slice (stages 1-3) success criteria:

- a game lasts 15-25 minutes,
- a tester clicks bubbles without hints (4-6 per minute),
- a bot with simple rules wins 40-60% of games on normal difficulty,
- at least 3 of 5 testers start a second game unprompted,
- every Trial is announced and has at least one counter.

---

# FUN DETECTOR

Genesis Error must not become
an engineering project disguised as a game.

Every feature answers one question:

"Does the player want to click once more?"

Not "is it realistic?".
Not "is it technically impressive?".

Fun Detector is the highest design priority.
It may challenge every other skill and veto any feature.
Skill: `genesis-fun-detector` (docs/skills.md).

Use it before:

- designing or expanding a system
- adding simulation depth or complexity
- new species, events, perks, climate mechanics
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

Determinism, snapshot + deltas, tests and the stage order
are never traded for fun.
They keep the simulation trustworthy enough to be fun.

Measures (tools in godot/simulation/tests/tools/, bot, testers):

- bubble clicks per minute (target 4-6),
- a second game started without prompting
  (at least 3 of 5 testers),
- first perk bought within 30 seconds of the start,
- about 20 perks bought per game.

Most dangerous state:

simulation depth > gameplay depth

Bad: 50 simulated species, 1 meaningful decision.

Good: 5 simulated species, 20 meaningful decisions.

The player should say:

"One more perk, one more game."

more often than:

"I found the optimal strategy."

A boring game is still boring.
No amount of technical excellence can save it.

---

# CORE DESIGN PRINCIPLES

## Principle 1

Every perk has a price and a side effect.

A perk costs Sparks, has requirements, can be refunded
for part of the cost, and always has a downside
(for example faster growth angers the Creator).

No perk is strictly better than the others.
No single strategy wins every game.

The player is not an observer: the player acts, grows stronger
and reacts to crises. Design from the perspective of:

- the loop on the map (bubbles, perks, Trials)
- climate
- biosphere
- ecosystems

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

Every Trial is announced and has a counter.

A Trial (cataclysm) is a world event with a Pending phase.
The player sees the warning and can avert the Trial
(slow growth or buy the matching perk).
The Creator speeds up when the player does well.
The only scripted element is the Final Trial in year 200.

---

## Principle 4

Systems over content.

Prefer:

one good system
over
twenty handcrafted events

Emergence over scripting:
events come from the state of the planet.

---

## Principle 5

Data over code.

Configuration should live in:

- Resources
- Data Assets
- JSON files

Avoid hardcoded values. Perks, bubbles, Trials, continents
and scenarios are data.

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

Trials (the Creator's cataclysms) are world events with a warning phase
(Pending) and a counter (Core Design Principle 3).

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

Archetypes become traits of planets in scenarios (Stage 4).

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

simulation/perks/ (PerkSystem, PerkCatalog)

simulation/tests/

game/ (game layer above the simulation: SimulationRunner,
PlaySession, GoalTracker, DecisionWatcher, HintAdvisor, BubbleField, saves)

ui/ (the window: GameView, PlanetView (3D globe + shaders), HistoryChart,
BubbleLayer, PerkPanel;
Godot nodes and signals only here)

tools/ (console entry points only: run_simulation.gd, play.gd)

resources/

resources/perks/ (perk data)

resources/bubbles/ (bubble data)

Outside res:// (repository root):

docs/ (design, player guide, plan: docs/plan_rozwoju.md;
spec and plans: docs/superpowers/)

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
