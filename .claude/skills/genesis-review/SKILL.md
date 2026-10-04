---
name: genesis-review
description: Project-specific technical review for Genesis Error code and design documents. Use this whenever the user asks to review, check, evaluate or audit code, a diff, a commit, a pull request, a system design or a doc in this repository, or asks "is this ok?" about simulation work — and use it as the default when unsure which Genesis skill applies. Brutally honest, protects the simulation, reports severity, reason, solution and priority for every issue.
---

# Genesis Error technical review

Review mode: honest and specific. Protect the project, not feelings. Every
finding must be real and traceable to a line, rule or document; do not pad the
list. If something is good, say it in one line and move on.

## Read first

The diff or files under review, then the relevant parts of `CLAUDE.md`,
`docs/architecture.md`, `docs/simulation.md`, `DESIGN_PRINCIPLES.md` and
`CORE_LOOP.md`. Run the test suite if code changed (`genesis-qa`).

## Checklist

**Architecture**
- Systems read `PlanetSnapshot` and return deltas; nothing outside
  `StateWriter` writes `PlanetState`; no system references another system.
- EventBus carries facts, not commands; no Godot signals in `simulation/`.
- No duplicated state (single source of truth); no god objects; dependencies
  point downward only.

**Determinism**
- Only `SimMath` and `SeededRng` for math and randomness.
- Ordered iteration, total-order sorting, `StringName` compared as `String`.
- Ints above 2^53 not stored as JSON numbers; RNG and internal state saved.

**Data over code**
- Coefficients, thresholds and limits in JSON, validated, all errors reported.
- No magic numbers in systems except mathematical constants.

**Simulation quality**
- Every delta has a meaningful `cause`; important changes are logged.
- Events emerge from state (trigger, active phase, end conditions, measurable
  effects); no random-chance events without a state cause.
- Trade-offs exist; no dominant strategy or unbounded growth.

**Godot / code**
- Static types everywhere; packed arrays duplicated at boundaries;
  `SimResult` instead of asserts for data errors; small classes and methods.

**Tests and docs**
- Unit, integration and simulation coverage for new behavior; guard tests
  proven to fail; golden trace changes explained.
- Docs and CLAUDE.md updated when contracts, files or rules changed.

## Output format

Start with a one-paragraph verdict (ship / fix first / redesign). Then a table,
most severe first:

| # | Severity | Location | Issue | Reason | Solution | Priority |
|---|---|---|---|---|---|---|

Severity: Critical (breaks determinism, state integrity or architecture rules),
High (bug or missing tests for core behavior), Medium (maintainability, data
in code, unclear causes), Low (naming, style).
Priority: Now / Before next system / Later.

End with what was verified (tests run, result) and what was not.
