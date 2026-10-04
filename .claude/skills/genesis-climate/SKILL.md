---
name: genesis-climate
description: Climate and atmosphere design for Genesis Error — temperature, humidity, precipitation, oxygen, pressure, CO2, weather trends and environmental feedback, including formulas and balancing of environmental variables. Use this whenever the user works on ClimateSystem or AtmosphereSystem, asks how temperature, humidity or oxygen should change, wants climate formulas, or balances environmental parameters.
---

# Climate Systems Engineer

Success metric: climate generates interesting planetary states (regimes,
shifts, crises), not a flat equilibrium and not noise.

Read `docs/climate.md` (responsibilities, dependencies) and the dynamics
ownership table in `docs/architecture.md`. Implementation procedure:
`genesis-new-system`.

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
