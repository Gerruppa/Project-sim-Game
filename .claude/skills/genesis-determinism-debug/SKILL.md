---
name: genesis-determinism-debug
description: Diagnose and fix determinism problems in the Genesis Error simulation — golden trace mismatches, determinism_test or save_load_continuity_test failures, different results between Windows, Linux and macOS CI jobs, or "same seed gives different result". Also covers when and how to regenerate the golden trace and the deterministic math policy. Use this before touching any failing determinism test and before any golden trace regeneration.
---

# Determinism debugging

Policy and levels (L1 same machine, L2 Windows vs Linux, L3 macOS ARM) are in
`docs/simulation.md`. The golden trace is
`godot/simulation/tests/golden/fixture_trace.txt` (seed 42, 10 000 ticks,
SHA-256 of the exact state every 100 ticks).

## First question: intended change or bug?

A golden mismatch is expected after: adding/removing a parameter, changing
`TestFixtureDynamics`, changing `SimMath`, `SeededRng`, delta ordering, the
codec's hash input, or upgrading Godot. In that case regenerate:

```bash
"$GODOT_BIN" --headless --path godot -s res://simulation/tests/tools/write_golden_trace.gd
```

Commit the new trace alone, with the reason in the message. Never regenerate to
make an unexplained failure go away; that deletes the evidence.

## Locating an unexpected divergence

1. The test reports the first diverging checkpoint. Divergence started within
   the 100 ticks before it.
2. Narrow to the exact tick: run `TestFixtureScenario` with
   `run_with_checkpoints(ticks, 1)` on both sides (or both platforms) and diff.
3. At that tick, dump the deltas: `StateWriter.apply()` returns
   `ApplyReport.applied_deltas` (canonical order, with source and cause) and
   `changes`. The first differing delta names the system and cause.
4. Compare values bitwise (`var_to_bytes` or Base64 of
   `PackedFloat64Array.to_byte_array()`), not with printed decimals.

## Known causes, most likely first

| Symptom | Cause | Fix |
|---|---|---|
| Differs only across platforms | Engine math (`sin`, `exp`, `pow`, `lerp`, `randfn`...) | Replace with `SimMath`; extend the architecture test list if a new function slipped through |
| Differs between runs on one machine | Iteration over unordered input, unstable sort, `StringName` `<` comparison | Iterate in schema order; total-order comparators; compare as `String` |
| Differs after save/load | RNG state or other int > 2^53 stored as a JSON number; missing state in the save | Save as string; add the missing field |
| Differs only on ARM (L3) | Possible FMA contraction in engine C++ code | Avoid engine helpers in the hot path; record the finding in docs/simulation.md |
| Sum differs by 1 ulp | Deltas summed in a different order | Must go through `StateWriter` canonical order |
| Readable save values differ | Decimal formatting | Expected; `values_exact` is the source of truth |

## Plan B

If L2 cannot be achieved with the math policy, the documented fallback is
fixed-point storage inside PlanetState (API by id stays). Propose it with
measurements; do not switch silently.

## After the fix

Add a regression test that reproduces the divergence (small, fast), then run
the full suite (`genesis-qa`). Update `docs/simulation.md` if a new rule or
measurement came out of it.
