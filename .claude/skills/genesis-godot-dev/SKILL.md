---
name: genesis-godot-dev
description: Godot 4.7 / GDScript implementation conventions for the Genesis Error simulation. Use this whenever writing, editing or refactoring any .gd file under godot/, adding a class, loader, data file or test helper, or deciding between RefCounted, Resource, Node, signals or autoloads in this project — even for small edits, because several Godot defaults (signals, Resources, StringName comparison, packed array references) silently break the project's determinism and encapsulation rules.
---

# Genesis Error: Godot developer conventions

The Godot project lives in `godot/` (`res://` = `godot/`). Engine is pinned to
Godot 4.7.2 stable. Read `docs/architecture.md` before adding a module and
`docs/simulation.md` before touching anything that computes simulation values.

Work order for any implementation: architecture first, then tests, then code
(the project follows TDD, see the `genesis-qa` skill).

## Choosing the base type

| Need | Use | Why |
|---|---|---|
| Simulation state, systems, value objects | `RefCounted` | Runs headless, no scene tree, freed automatically |
| Designer data (parameters, species, events) | JSON + a loader returning `SimResult` | Diffable, edited outside the editor, validated explicitly |
| Editor-only assets (future visuals) | `Resource` | Fine there; never for simulation data |
| Scene objects (future UI/visualization) | `Node` | Never inside `simulation/` |

`load()` returns a cached, shared Resource instance; mutating it changes it for
every user. That is one reason simulation data is JSON loaded into immutable objects.

## Communication

- Simulation systems never use Godot signals. Signals call listeners immediately,
  in connection order, which breaks the queued, phase-ordered EventBus model.
  Signals are allowed later in visualization and UI layers only.
- No autoload singletons for state. Create objects in SimulationManager and
  inject them (constructor arguments). Tests then build their own instances.
- Systems read `PlanetSnapshot`, return `Array[Delta]`. Only `StateWriter`
  writes `PlanetState` (via `_commit`). Architecture tests enforce this.

## Typing and errors

- `untyped_declaration` is an error in `project.godot`: every `var`, parameter
  and return needs a type (`:=` inference is fine).
- GDScript has no exceptions and `assert()` is stripped from release builds.
  Anything that can fail on data returns `SimResult` (`value`, `errors`,
  `warnings`); report all errors at once, not just the first.
- Unknown parameter ids return `NAN` so the bad value is rejected by
  `StateWriter` instead of silently reading 0.

## Pitfalls that already bit or nearly bit this project

- **Packed arrays are passed by reference** in Godot 4. Duplicate before
  storing or returning (`values.duplicate()`), or callers can mutate internals.
- **`StringName < StringName` is not guaranteed to compare text.** Convert with
  `String(name)` before sorting or ordering.
- **`Array.sort_custom` is not stable.** Give comparators a total order.
- **A `Callable` does not keep its `RefCounted` object alive.** Whoever
  subscribes an object to `EventBus` must hold a reference to it (the
  SimulationManager does); the bus drops subscribers whose object was freed.
- **JSON numbers are doubles.** Integers above 2^53 (RNG state, large ids) must
  be saved as strings. All JSON numbers come back as `float`.
- **`hash()` stability across engine versions is not documented.** Use
  `String.sha256_text()` for anything persisted or compared across runs.
- **Engine math (`sin`, `exp`, `pow`, built-in `lerp`, `randf`...) is forbidden
  in `simulation/`.** Use `SimMath` and `SeededRng`. See `genesis-determinism-debug`.

## Naming and layout

- `class_name` in PascalCase, files in snake_case, one class per file.
- Folders follow `docs/architecture.md` (`simulation/core`, `planet`,
  `scheduling`, `climate`, `atmosphere`, `biosphere`, `modifiers`, `events`,
  `personality`), data in `godot/resources/<area>/`.
- Parameter ids come from `Param` constants (`Param.TEMPERATURE`), never literals.
- Test-only helpers live in `simulation/tests/support/`. Load them with
  `preload()`; only give them a `class_name` (prefixed `Test`) when the script
  must reference its own type.
- Match the surrounding comment density: a `##` doc comment on each class
  explaining *why* it exists, short comments only where the reason is not obvious.

## After editing

Run the suite (see `genesis-qa`). New `class_name` scripts need the class cache;
`run_tests.sh` runs `--import` first. Commit generated `*.gd.uid` files.
