---
name: genesis-climate
description: Climate and atmosphere design for Genesis Error — temperature, humidity, precipitation, oxygen, pressure, CO2, weather trends and environmental feedback, including formulas and balancing of environmental variables. Use this whenever the user works on ClimateSystem or AtmosphereSystem, asks how temperature, humidity or oxygen should change, wants climate formulas, or balances environmental parameters.
---

# Climate Systems Engineer

Success metric: climate generates interesting planetary states (regimes,
shifts, crises), not a flat equilibrium and not noise.

Read `docs/climate.md` (formulas, coefficients, balance results, tuning
history) and the dynamics ownership table in `docs/architecture.md`.
Implementation procedure: `genesis-new-system`.

ClimateSystem exists (`godot/simulation/climate/`, data in
`godot/resources/climate/climate.json`). Before changing a coefficient, run
the balance report and compare before/after:

```bash
"$GODOT_BIN" --headless --path godot -s res://simulation/tests/tools/planet_report.gd -- --seeds 8 --ticks 20000
```

Design properties to preserve (tests guard them): two stable climates
(`ice_strength` ≥ 22 with the current base), a soft floor so temperature never
sits at 0 (`cold_floor`), responses ≤ 1 so relaxation never overshoots.

AtmosphereSystem also exists (`godot/simulation/atmosphere/`, data in
`godot/resources/atmosphere/atmosphere.json`): carbon cycle (volcanoes vs
weathering) whose CO2 greenhouse ends ice ages, and oxygen sinks (crust
oxidation, volcanic gases). Properties to preserve: a frozen planet thaws via
volcanic CO2 without drift or seasons; CO2 never pinned at a limit; lifeless
oxygen stays prebiotic. Coefficient files share `CoefficientLoader`
(`simulation/core/`) for validation; new systems should reuse it.
Planets of a different character are separate JSON files
(`run_simulation.sh --climate <file>`), not code changes.

## Ground rules

- ClimateSystem owns temperature and humidity dynamics; AtmosphereSystem owns
  oxygen (later pressure, CO2). Biosphere contributes flows, never copies.
- All values are normalized 0..100. Use the anchors: temperature 50 = optimum
  for Earth-like life, humidity 50 = temperate, oxygen 50 = Earth level,
  biomass 50 = forests and shrubs.
- Formulas use only `+ - * /`, comparisons and `SimMath` (`lerp`,
  `smoothstep`, `int_pow`). No `exp`, `pow`, `sin`. Useful deterministic shapes:
  - relaxation toward a target: `(target - value) * rate`
  - smooth threshold: `SimMath.smoothstep(a, b, x)`
  - saturating response: `x / (x + k)`
  - seasonal or cyclic signals: a triangle wave from integer tick arithmetic
    instead of `sin`
- Every coefficient lives in the system's JSON file; every effect is a delta
  with a named cause (`greenhouse`, `evaporation`, `cooling`, `oxidation`).
- Noise comes from the system's `SeededRng` and should modulate, not drive.
  Events must still be explainable from state.

## Deliverables for any climate change

1. **Formulas** with each term explained and its coefficient named.
2. **Simulation effects**: which parameters move, in which direction, with
   what delay (one tick per hop through the snapshot model).
3. **Feedback loops**: label each loop positive (runaway) or negative
   (stabilizing); every positive loop needs a limiting mechanism.
4. **Balance implications**: equilibrium points, how fast it gets there,
   which trade-offs it creates (more oxygen = more fire risk, more rain =
   more mutation, more biomass = less stability).
5. **Edge cases**: values at 0 and 100, saturation (clamping reported by
   `ApplyReport.saturations()`), interaction when biomass is 0.
6. **Tests**: chain-reaction integration test and a many-seed run;
   see `genesis-qa`. Balance tuning: `genesis-balance`.
