---
name: genesis-feature-gate
description: Gate and specification step for any new feature, system or mechanic in Genesis Error, run before implementation. Applies the CLAUDE.md acceptance criteria template, the docs/DESIGN_PRINCIPLES.md checklist, the docs/CORE_LOOP.md validation test and the system build order. Use this whenever the user proposes or asks to add a new feature, mechanic, system, species, event or player action, or asks "should we add X?", even if they want to jump straight to code.
---

# Feature gate

Purpose: stop features that do not serve the simulation before they cost code,
and give the ones that pass a precise specification. Genesis Error succeeds or
fails on simulation quality; this gate protects it.

## 0. Is it fun?

Run `genesis-fun-detector` first for any new or large feature. A REMOVE
verdict stops the gate; POSTPONE records it for its phase; SIMPLIFY means
the specification below covers only what survives.

## 1. Build order

`CLAUDE.md` SYSTEM PRIORITY: PlanetState → TickScheduler → Climate →
Atmosphere → Biosphere → Personality → Events → Save → Gameplay →
Visualization. "Never skip steps." If the feature belongs to a later step,
say so and record it for later instead of building it now.

## 2. Design checklist (docs/DESIGN_PRINCIPLES.md)

Answer each with yes/no and one line of reasoning:

- Does it make the planet feel alive?
- Does it create stories?
- Does it increase emergence?
- Does it create trade-offs?
- Does it generate curiosity?
- Does it interact with existing systems?
- Does it produce meaningful consequences?
- Can the player (or observer) learn from it?
- Does it avoid dominant strategies?
- Can it create unexpected outcomes?

Mostly "no" → recommend not building it.

## 3. Core loop test (docs/CORE_LOOP.md)

Does it improve observation, hypothesis, intervention, consequences, learning?
Three or more "no" → reject. Also check: does it touch PlanetState? A feature
that does not interact with PlanetState should be questioned (CLAUDE.md).

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

## 5. Console first

"Can this be observed in console logs first?" If yes, the first version is
log output only. Name the log lines it will produce.

## Output

Verdict (build now / later / reject) with the reasons, then the specification.
Hand implementation to `genesis-new-system` or `genesis-add-parameter`.
