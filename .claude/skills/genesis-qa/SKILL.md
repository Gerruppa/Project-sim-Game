---
name: genesis-qa
description: Testing workflow for Genesis Error with gdUnit4 — running the suite headless, writing unit/integration/simulation/architecture tests, proving tests can fail, and reporting results. Use this whenever writing or changing tests, running tests, validating an implementation, checking CI results, or before claiming any simulation work is done. Assume the system is broken until the suite proves otherwise.
---

# Simulation QA

## Running

```bash
GODOT_BIN="<Godot 4.7.2 console binary>" ./godot/run_tests.sh            # all
GODOT_BIN=... ./godot/run_tests.sh -a res://simulation/tests/unit/x_test.gd   # one suite
```

- Exit code 0 = pass, 100 = failures, 101 = warnings. Anything else than 0 is
  a failure, including 101.
- Output is colored; strip ANSI codes before grepping
  (`sed 's/\x1b\[[0-9;]*m//g'`). Lines about `Remote Debugger` and port 0 are
  expected noise.
- A parse error in one test file makes that suite fail to load; look for
  `SCRIPT ERROR` lines, not only the summary.
- Reports: `godot/reports/` (ignored by git). CI:
  `.github/workflows/simulation-tests.yml` on Linux, Windows (required) and
  macOS ARM (measured, allowed to fail).

## Test levels and where they go

| Level | Folder | Checks |
|---|---|---|
| Unit | `simulation/tests/unit/` | one class, hand-built inputs, edge values 0/100, NaN/INF, empty input |
| Integration | `simulation/tests/integration/` | several classes or real project data |
| Simulation | `simulation/tests/simulation/` | many seeds, long runs, determinism, save/load continuity, golden trace |
| Architecture | `simulation/tests/architecture/` | source scans for forbidden calls and write access |

## Writing tests

- TDD: write the test, run it, see it fail for the right reason, then implement.
- Name tests after behavior (`test_clamps_after_summing_not_per_delta`).
- Before trusting a new guard test, prove it can fail: temporarily break the
  code (remove a sort, store a value wrongly, plant a violation file), run,
  see red, restore, see green. This project found two real traps this way.
- Floats: exact expectations with exact values (`assert_float(x).is_equal(15.0)`
  when the math is exact); bit-level checks via `a == b` in `assert_bool` or
  Base64 of bytes; approximate checks with `is_equal_approx`.
- `override_failure_message(...)` goes before the final assertion call.
- Shared helpers: `tests/support/schema_fixtures.gd` (preload as `P`),
  `TestFixtureScenario`, `TestFixtureDynamics`, `golden_trace.gd`.
- Files written by tests go to `user://`, never into `res://`.
- Keep simulation tests fast (whole suite runs in seconds); prefer more seeds
  over longer single runs.

## Failure scenarios to always consider

NaN or INF entering through data or deltas; values at 0 and 100; empty lists;
duplicate ids; unknown ids; old save formats; JSON int→float conversion;
order of inputs reversed; two systems writing the same parameter; long runs
drifting into saturation.

## Reporting

Report the exact summary line (`N test cases | E errors | F failures`) and the
exit code. Name every failing test, including ones you did not cause. Do not
say "done" without a full-suite run.
