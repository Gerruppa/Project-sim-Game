---
name: genesis-feature-gate
description: Gate and specification step for any new feature, system or mechanic in Genesis Error, run before implementation. Applies the CLAUDE.md acceptance criteria template, the docs/DESIGN_PRINCIPLES.md checklist, the docs/CORE_LOOP.md validation test and the stage order. Use this whenever the user proposes or asks to add a new feature, mechanic, system, species, event or player action, or asks "should we add X?", even if they want to jump straight to code.
---

# Feature gate

Purpose: stop features that do not serve the game loop before they cost code,
and give the ones that pass a precise specification. Genesis Error succeeds or
fails on whether the player wants to click once more; this gate protects it.

## 0. Is it fun?

Run `genesis-fun-detector` first for any new or large feature. A REMOVE
verdict stops the gate; POSTPONE records it for its stage; SIMPLIFY means
the specification below covers only what survives.

## 1. Stage order

`CLAUDE.md` CURRENT PROJECT GOAL (spec
`docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md`, chapter 8):
Stage 0 documents → 1 bubbles, Sparks, perk shop → 2 reach → 3 Creator
(Wrath, Trials, Life Index) → 4 meta (mutations, Legacy, scenarios) →
5 fauna → 6 Steam. Each stage ends with a playable version. If the feature
belongs to a later stage, say so and record it for later instead of
building it now. The engineering rules (determinism, snapshot + deltas,
tests, single source of truth) always apply.

## 2. Design checklist (docs/DESIGN_PRINCIPLES.md)

Answer each with yes/no and one line of reasoning:

- Does the player want to click once more?
- Does it have a price and a side effect (perks)?
- Does it create stories?
- Does it create trade-offs?
- Does it interact with PlanetState?
- Does it produce meaningful consequences?
- Is a crisis it creates announced, with a counter (Trials)?
- Does it avoid dominant strategies?
- Is it visible on the map or in a decision?
- Does it make the next game more interesting?

Mostly "no" → recommend not building it.

## 3. Core loop test (docs/CORE_LOOP.md)

Does it give a reason to click once more, make a decision or crisis clearer,
carry a price or side effect, change PlanetState measurably, make the next
game more interesting? Three or more "no" → reject. A feature that does not
interact with PlanetState should be questioned (CLAUDE.md).

## 4. Specification (CLAUDE.md template)

```
## Goal          why the feature exists
## Inputs        data it receives (snapshot fields, data files, commands)
## Outputs       data it modifies (deltas, modifiers, events, logs)
## Constraints   limits, determinism, performance budget
## Acceptance Criteria   observable conditions for "done"
## Test Cases    unit / integration / simulation tests that prove it
```

For systems and events, also answer the CLAUDE.md design questions:
species → consumes, produces, environment, if it disappears, if it dominates;
events → trigger conditions, active phase, ending conditions, measurable effects.

## 5. Measure first

How will we know it works? Name the measure (bubble clicks per minute,
perks bought per game, a bot win rate, a `planet_report.gd` run) and the log
lines the simulation will produce so the effect can be checked without the
window.

## Output

Verdict (build now / later / reject) with the reasons, then the specification.
Hand implementation to `genesis-new-system` or `genesis-add-parameter`.
