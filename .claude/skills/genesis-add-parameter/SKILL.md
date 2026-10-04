---
name: genesis-add-parameter
description: Checklist for adding, renaming or removing a planetary parameter in Genesis Error (pressure, co2, radiation, toxicity, ocean_level, geological activity or anything stored in PlanetState). Use this whenever a change touches godot/resources/planet/parameters.json, the Param constants, or the list of planet values, because a parameter change ripples into saves, the golden trace, tests and docs.
---

# Adding a planetary parameter

Parameters are data: PlanetState code does not change. What does change is
everything that depends on the set of parameters. Skipping a step here causes
silent save incompatibility or a golden trace failure that looks like a
determinism bug.

## Before adding

- Does a system need it now? `CLAUDE.md` lists future parameters, but add one
  only when a system reads or writes it. Unused parameters dilute the model.
- Decide the **dynamics owner** (one system) and **contributors**.
- Define the meaning of the normalized scale. Every parameter is 0..100 and
  needs anchors for 0, 50 and 100. Propose them to the user if not given;
  without anchors the number means different things in different systems.

## Steps

1. `godot/resources/planet/parameters.json`: add the entry (`id`,
   `display_name`, `unit` = `"normalized 0-100"`, `min` 0, `max` 100,
   `initial`, `anchors` with keys `"0"`, `"50"`, `"100"`). Order matters: it is
   the storage order and the save `parameter_order`.
2. Bump `schema_version` when parameters are added, removed or renamed.
3. `godot/simulation/planet/param.gd`: add the constant.
4. `godot/simulation/tests/integration/project_parameters_test.gd`: update the
   expected id list and the `Param` constants check.
5. `docs/architecture.md`: add to the dynamics ownership table and the anchors
   table; move it out of "Future" in the PlanetState section.
6. `CLAUDE.md` PLANET STATE section: move it from future to current.

## Consequences to handle

- **Saves**: old saves decode with the new parameter at its initial value plus a
  warning (`PlanetStateCodec.decode`). A rename is a remove + add; old values
  would be lost and the old id becomes an error. Ask before renaming.
- **Golden trace**: the state hash includes every parameter id and value, so
  the trace changes. This is expected, not a determinism bug. Regenerate it in
  a separate commit and say why in the message (`genesis-determinism-debug`).
- **Test fixtures**: `tests/support/fixture_dynamics.gd` ignores unknown
  parameters, so it keeps working; add the parameter there only if the fixture
  should exercise it.

## Verify

Run the full suite (`genesis-qa`). Expected: everything green after the golden
trace regeneration; `project_parameters_test` proves the data loads.
