# ARCHITECTURE.md

# Genesis Error Technical Architecture

Version: 1.0

Engine: Godot 4.x

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
┌─────────────────────────────┐
│           UI Layer          │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│      Visualization Layer    │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│       Gameplay Layer        │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│      Simulation Layer       │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│          Data Layer         │
└─────────────────────────────┘
```

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

# CORE MODULES

## PlanetState

Single source of truth.

Stores complete planetary state.

Owns:

- temperature
- humidity
- oxygen
- biomass

Future:

- pressure
- co2
- radiation
- toxicity
- ocean_level
- geology

Rules:

No system may duplicate values stored here.

---

## SimulationManager

Central orchestrator.

Responsibilities:

- initialize systems
- execute update loop
- register simulation modules
- run deterministic ticks

Must not contain business logic.

Responsibilities stop at orchestration.

---

## TickScheduler

Controls simulation frequency.

Responsibilities:

- simulation timing
- tick dispatching
- pause
- speed control

Supported rates:

1 second
10 seconds
30 seconds
60 seconds

Must be deterministic.

---

## EventBus

Global communication layer.

Responsibilities:

- publish events
- subscribe listeners
- decouple systems

All major systems communicate
through EventBus.

Avoid direct dependencies.

---

# SYSTEM COMMUNICATION

Allowed:

```text
System A
   │
   ▼
EventBus
   │
   ▼
System B
```

Avoid:

```text
ClimateSystem
   │
   ▼
BiosphereSystem
   │
   ▼
ClimateSystem
```

This creates circular dependencies.

---

# CLIMATE SYSTEM

Responsibilities:

- temperature
- humidity
- precipitation
- weather trends

Inputs:

PlanetState

Outputs:

Updated PlanetState

Events:

TemperatureChanged

HumidityChanged

ClimateShift

---

# ATMOSPHERE SYSTEM

Responsibilities:

- oxygen generation
- atmospheric stability
- pressure calculations

Inputs:

PlanetState

Biosphere output

Outputs:

PlanetState

Events:

OxygenChanged

PressureChanged

AtmosphereCrisis

---

# BIOSPHERE SYSTEM

Most important gameplay system.

Responsibilities:

- species simulation
- population growth
- extinction
- environmental impact

Inputs:

Climate data

PlanetState

Outputs:

PlanetState modifications

Events:

SpeciesExpanded

SpeciesCollapsed

EcologicalShift

---

# PERSONALITY SYSTEM

Purpose:

Create planetary identity.

Planet is not actually intelligent.

Planet appears intelligent.

Responsibilities:

- modify simulations
- alter event probabilities
- adjust environmental stability

Archetypes:

Harmonious
Chaotic
Guardian

Outputs:

Modifiers only.

Never directly manipulate world state.

---

# EVENT SYSTEM

Purpose:

Convert simulation state 