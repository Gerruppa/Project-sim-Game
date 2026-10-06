# SKILLS.md

# Genesis Error AI Skill Framework

Version: 1.2

Purpose:

This document lists the specialized expert roles used during
Genesis Error development and maps them to Claude Code skills.

---

# HOW SKILLS ACTIVATE

Claude Code skills live in `.claude/skills/<name>/SKILL.md`
(versioned with the repository).

A skill activates when the task matches its `description`,
or when invoked directly with `/<name>`.

This document is an index for humans.
It does not activate anything by itself.

Rules for every skill:

- Refer to project documents, do not copy them.
  `CLAUDE.md`, `docs/architecture.md`, `docs/simulation.md`,
  `docs/DESIGN_PRINCIPLES.md`, `docs/CORE_LOOP.md` stay the source of truth.
- Contain project-specific knowledge: procedures, checklists, pitfalls.
- Update the skill when the documents it relies on change.

---

# ACTIVE SKILLS

| Skill | Role | Activates on |
|---|---|---|
| `genesis-fun-detector` | Fun Detector (skill 13, highest design priority) | new or expanded systems, species, events, mechanics, roadmaps, feature reviews, before large features |
| `genesis-architect` | Planet Simulation Architect | new systems, dependencies, module design |
| `genesis-feature-gate` | Design gate | any new feature, mechanic, species, event, before code |
| `genesis-new-system` | Procedure | implementing a domain system |
| `genesis-add-parameter` | Procedure | adding, renaming or removing a planet parameter |
| `genesis-godot-dev` | Godot Senior Developer | writing or refactoring GDScript |
| `genesis-qa` | Simulation QA Engineer | writing or running tests, validating work |
| `genesis-determinism-debug` | Procedure | golden trace or determinism failures, regeneration |
| `genesis-review` | Technical Reviewer | reviewing code, diffs, designs, docs |
| `genesis-climate` | Climate Systems Engineer | ClimateSystem, AtmosphereSystem, climate formulas |
| `genesis-balance` | Simulation Balance Analyst | tuning, saturation, flat or chaotic runs |

---

# DEFAULT SKILL PRIORITY

| Question type | Skill |
|---|---|
| Is this fun? Is it worth building at all? | genesis-fun-detector |
| Should we build this? | genesis-feature-gate |
| Architecture | genesis-architect |
| Implement a system | genesis-new-system |
| New planet value | genesis-add-parameter |
| Code | genesis-godot-dev |
| Tests | genesis-qa |
| Determinism | genesis-determinism-debug |
| Review | genesis-review |
| Climate | genesis-climate |
| Balance | genesis-balance |

Fun Detector may challenge every other skill.
Its veto covers features, never engineering rules
(determinism, snapshot + deltas, tests, stage order).

When uncertain, use `genesis-review`.

When uncertain, choose simplicity.

When uncertain, protect the simulation.

---

# CHANGES FROM THE ORIGINAL ROLE LIST (v1.0)

1. "Skill activation rules" replaced by skill descriptions,
   because Claude Code triggers skills by description match.
2. Godot Senior Developer:
   - "Resources" replaced by JSON data with validating loaders
     (decision in `docs/architecture.md`).
   - "Signals" limited to visualization and UI.
     Signals call listeners immediately, which breaks the
     queued, phase-ordered EventBus used by the simulation.
3. Climate and Balance roles: formulas and soft caps must follow
   the deterministic math policy (`SimMath`, no `exp` or `pow`).
4. New procedural skills: new system, add parameter,
   determinism debugging, feature gate.
5. Document paths corrected (`docs/architecture.md`).

# CHANGES IN v1.2

1. Skill 13, Fun Detector (`genesis-fun-detector`), added as the highest
   design priority. Until the gameplay layer exists, its "player" is the
   observer of the simulation logs. It takes over the "Is the game fun?
   What should be removed or delayed?" questions of the deferred
   Steam Demo Evaluator for the current stage.

---

# PLANNED SKILLS

Created when the matching development phase starts.

## Biosphere Designer (`genesis-biosphere`)

Phase: 3, species simulation.

Purpose: design planetary life.

Expertise: ecosystems, food chains, species interaction,
extinction, adaptation.

Deliverables: ecological role, inputs, outputs, long term effects,
answers to the CLAUDE.md species questions.

Success metric: species create stories, not statistics.

## Planet Personality Architect (`genesis-personality`)

Phase: 4, planet personality.

Purpose: maintain the illusion of a living world.

Deliverables: player perception, simulation influence, variety impact.

Core rule: the planet appears intelligent.
The planet is not actually intelligent.
Personality outputs modifiers only.

## Scientific Plausibility Advisor (`genesis-science`)

Phase: with Biosphere.

Deliverables: realistic version, gameplay version, recommended version.

Core rule: gameplay wins. Believability supports gameplay.

## Emergent Gameplay Designer (`genesis-emergent-design`)

Phase: 9, gameplay layer.

Deliverables: positive outcomes, negative outcomes,
unintended outcomes, exploitation analysis.

Core rule: interesting systems beat complex systems.

---

# DEFERRED ROLES (NO SKILL YET)

Kept as reference for phase 10. Not created as skills now,
because the current goal is the simulation (CLAUDE.md)
and extra skills add noise to skill matching.

## Content Expansion Designer

Purpose: future features, expansions, replayability, endgame.

Core rule: never damage the Core Loop.

## Steam Demo Evaluator

Purpose: readiness for public testing.

Always answer:

- Is the game fun?
- Is the simulation interesting?
- What should be removed?
- What should be delayed?

---

# FINAL RULE

Genesis Error succeeds or fails
based on simulation quality.
