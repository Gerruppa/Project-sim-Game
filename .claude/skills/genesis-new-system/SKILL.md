---
name: genesis-new-system
description: Step-by-step procedure for adding a new simulation system to Genesis Error (ClimateSystem, AtmosphereSystem, BiosphereSystem, EventSystem, PersonalitySystem, GeologySystem or any future domain system). Use this whenever the user wants to create, scaffold or implement a system that reads planet state and changes it, even if they just say "let's start the climate" or "implement the next step from the plan".
---

# Adding a simulation system

A domain system is a pure function of the world: snapshot and coefficients in,
deltas out. Keeping that shape is what makes the simulation deterministic,
testable and free of circular dependencies. Read `docs/architecture.md`
(DOMAIN SYSTEMS, COMMUNICATION MODEL) and the system's own doc
(`docs/climate.md`, `docs/biosphere.md`, `docs/events.md`) first.

## 0. Check the build order

`CLAUDE.md` defines SYSTEM PRIORITY (PlanetState → TickScheduler → Climate →
Atmosphere → Biosphere → Personality → Events → Save → Gameplay → Visualization).
If the requested system skips an unfinished earlier step, say so and propose
building the missing step first. Run `genesis-feature-gate` for the spec.

## 1. Define the contract before code

Write down (in the response and later in the system's doc):

- **Reads**: which parameters from `PlanetSnapshot`, which coefficients.
- **Writes**: which parameters it proposes deltas for. Check the dynamics
  ownership table in `docs/architecture.md`: one owner per parameter, others
  only contribute flows. Update the table if ownership changes.
- **Causes**: the list of `cause` ids it will emit (short snake_case, e.g.
  `greenhouse`, `evaporation`). Players learn through causes, so name them for
  meaning, not implementation.
- **Data**: coefficients it needs, all in a JSON file.
- **Events**: notifications it publishes (facts after the fact).

## 2. Files

```
godot/simulation/<area>/<area>_system.gd     class_name <Area>System
godot/simulation/<area>/<area>_config.gd     loader -> SimResult (if it has data)
godot/resources/<area>/<area>.json           coefficients
godot/simulation/tests/unit/<area>_system_test.gd
godot/simulation/tests/integration/<area>_*_test.gd
```

## 3. Shape of the system

- `extends RefCounted`, constructed with its config and its own
  `SeededRng.new(global_seed, "<area>")` (stream id = system id).
- One public compute method: takes `PlanetSnapshot` (and resolved coefficients
  once ModifierRegistry exists), returns `Array[Delta]`.
- Every delta: `Delta.new(Param.X, amount, &"<area>", &"<cause>")`.
- No reference to `PlanetState`, other systems, EventBus internals or Nodes.
- Math only through `SimMath`; randomness only through its `SeededRng`.
- Persistent internal state (e.g. species populations) is allowed only if it is
  not a planet parameter, and it must be serializable (plan it for SaveSystem;
  ints above 2^53 as strings).

## 4. Registration

If `godot/simulation/scheduling/` exists, register the system in the pipeline's
Compute phase and add its interval (ticks) to SimConfig. If the pipeline does
not exist yet, do not invent a partial one inside the system; drive it in tests
the way `tests/support/fixture_scenario.gd` does and note the missing step.

## 5. Tests (write first)

- Unit: each cause produces the expected sign and magnitude for a hand-built
  snapshot; edge values 0 and 100; no deltas for parameters it must not touch.
- Unit: same seed → same deltas; different seed → different noise.
- Integration: system + StateWriter over N ticks shows the intended chain
  reaction (e.g. temperature change moves humidity within K ticks).
- Simulation: many seeds, long runs, no rejected batches, values stay finite.
- Architecture tests already scan the new folder; keep them green.

## 6. Finish

- Update the system doc and `docs/architecture.md` (ownership, events).
- If the golden trace changes, regenerate it in a separate commit
  (`genesis-determinism-debug`).
- Run the full suite and report the result honestly (`genesis-qa`).
- End with the CLAUDE.md acceptance criteria block (Goal, Inputs, Outputs,
  Constraints, Acceptance Criteria, Test Cases).
