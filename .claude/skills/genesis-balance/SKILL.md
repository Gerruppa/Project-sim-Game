---
name: genesis-balance
description: Simulation balance analysis for Genesis Error — growth curves, soft caps, runaway growth, dead or exploding trajectories, parameters stuck at 0 or 100, dominant strategies, and multi-seed batch runs with metrics. Use this whenever the user tunes coefficients, says the simulation is boring, flat, chaotic or unstable, sees values saturating, or asks whether a system is balanced.
---

# Simulation Balance Analyst

Perfect balance is not required. Interesting balance is required: the planet
should move through regimes, surprise the observer and recover or transform
after crises, without collapsing into a flat line or bouncing off the limits.

## Measure before tuning

Never tune from a single run. Use many seeds:

- Simulation tests already run 20 seeds × 2000 ticks for validity
  (`tests/simulation/stability_test.gd`).
- The planet already has a report tool:
  `godot/simulation/tests/tools/planet_report.gd` (climate + atmosphere + biosphere; `--personality <id>` (default none), `--lifeless`, `--climate-only`; seeds × ticks, per-seed
  temperature, time in ice, ice ages, CO2 and O2 ranges, oxygenation tick, biomass, first trees, forest time, species alive, extinctions). Use it as the
  pattern for other systems (`extends SceneTree`, run with `--headless -s`);
  bigger batches can write CSV to `logs/simulation_runs/` (ignored by git).
- Gameplay measurement tools in the same folder (all compare a run with an
  otherwise identical run, so the difference is only what is measured):
  `intervention_report.gd` (price and gain of actions; `--at decision|
  extinction|event:<id>`, `--actions a,b`), `intervention_trace.gd` (peak
  and duration of an action's effect), `event_impact.gd` (one world event's
  effect, `--event id`), `goal_report.gd` (goals without a player),
  `goal_bot.gd` (a bot playing by the hints). Results go to docs/gameplay.md.
- `planet_report.gd --limits` adds each parameter's range and time at the
  edges of the scale.
- Every run also writes `logs/simulation_runs/*.jsonl`, one record per tick
  with all changes and causes, ready for offline analysis.

Metrics per run, per 1000 ticks (from `docs/simulation.md`):
- min, max, mean, variance per parameter
- ticks spent saturated (`ApplyReport.saturations()`)
- threshold crossings and regime changes
- extinctions and events started (once those systems exist)

Classify trajectories: **dead** (variance near zero), **exploding** (most time
at a limit), **oscillating** (regular period, often from one-tick feedback
with too high gain), **interesting** (regime changes with recovery).

## Tools for shaping behavior (deterministic only)

- Logistic growth: `r * b * (1 - b / K)` — pure arithmetic.
- Soft cap: `x / (x + k)` or `SimMath.smoothstep` near the limit, so
  clamping is a last resort, not the mechanism.
- Damping: lower relaxation rates; one-tick delay plus gain > 1 oscillates.
- Thresholds with hysteresis for events (enter and exit at different values).
- Data thresholds instead of `== 0`; floats approach zero forever.

## Deliverables

1. **Diagnosis** from metrics (which trajectories, which parameters, which
   loop causes it). Point at the cause via delta causes, not guesses.
2. **Risks**: runaway loops, dominant strategies, exploits once players act.
3. **Soft caps** proposed per issue, with formula and data coefficient.
4. **Failure analysis**: what a collapse looks like and whether it is
   transformative (good) or a dead end (bad).
5. **Recommendations** as data changes (coefficient old → new) with the
   expected metric shift, then re-measure on the same seeds.

While the golden trace is driven by `TestFixtureDynamics`, tuning real system
coefficients does not change it. If the golden scenario is later switched to
real systems, every balance change will require a deliberate regeneration
(`genesis-determinism-debug`).
