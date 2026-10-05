---
name: genesis-fun-detector
description: Fun Detector for Genesis Error — asks "is this actually fun?" about any feature, system, species, event, climate mechanic, roadmap or balance change, scores it (fun, clarity, story potential, replayability, complexity, development and maintenance cost) and gives a verdict KEEP / SIMPLIFY / POSTPONE / REMOVE. Use this whenever the user designs or expands a system, adds simulation depth or complexity, proposes a new species, event or mechanic, evaluates a roadmap or reviews a feature, and before implementing any large feature — even when the idea is technically elegant or realistic. Highest design priority; may challenge every other Genesis skill.
---

# Fun Detector (skill 13)

## Purpose

Protect Genesis Error from becoming an engineering project disguised as a game.

This skill answers one question: **"Is this actually fun?"**

Not "Is it realistic?". Not "Is it technically impressive?".
Not "Is it scientifically accurate?". Only: "Will players enjoy interacting with it?"

Read first: `docs/CORE_LOOP.md`, `docs/DESIGN_PRINCIPLES.md`, `docs/vision.md`
and the CLAUDE.md section FUN DETECTOR.

## Priority and scope

HIGHEST design priority. This skill may challenge decisions made by every
other skill: `genesis-architect`, `genesis-climate`, `genesis-balance`,
`genesis-review` and the planned biosphere and personality designers.
Fun always outranks elegance.

The veto applies to **features** (what exists and how deep it goes), not to
**engineering invariants**. Determinism, the snapshot + delta model, tests and
the build order are not traded for fun: they are what keeps the simulation
trustworthy enough to be fun. When fun and an invariant collide, propose a
different feature, never a broken rule.

## Genesis Error now: who is the "player"?

The current stage is console simulation first (CLAUDE.md CURRENT PROJECT
GOAL). Until the gameplay layer exists, the player is the **observer reading
the logs**. Judge features by what that observer experiences:

- Does the log show a surprise, a story, a cause worth understanding?
- Would the observer ask "I wonder what happens if..."?
- Would they notice if the feature were gone?

Also ask what the feature will enable once player interventions exist
(phase 9): which decisions and experiments it prepares. A simulation feature
that will never become a decision or a visible story is a red flag even now.

## Core mission

Identify features that sound interesting and are technically impressive but
do not improve the player experience.

- Detect complexity without value.
- Detect simulation without gameplay.
- Detect mechanics that players will ignore.

## Questions to ask

For every proposed feature:

- Why should the player care?
- What decisions does this create?
- What stories does this generate?
- What emotions does this create?
- What happens if this feature is removed? Would players notice? Would they miss it?

## Mandatory evaluation framework

For every feature assign:

| Score | Range |
|---|---|
| Fun Score | 0-10 |
| Clarity Score | 0-10 |
| Story Potential | 0-10 |
| Replayability | 0-10 |
| Complexity Cost | 0-10 |
| Development Cost | 0-10 |
| Maintenance Cost | 0-10 |
| **Net Value** | Positive / Neutral / Negative |

Give one line of reasoning per score, based on evidence where it exists:
logs, `planet_report.gd` runs, measured event frequencies, test outcomes.
A score without a reason is not an evaluation.

## Red flag detector

Immediately flag features that:

- require explanation longer than their gameplay value,
- increase system complexity without generating new decisions,
- exist only because they are realistic,
- exist only because they are technically cool,
- exist only because another game used them,
- create optimization instead of curiosity,
- increase micromanagement,
- reduce experimentation,
- reduce emergent outcomes.

## Green flag detector

Promote features that:

- create stories,
- create surprises,
- generate experiments,
- create dilemmas,
- produce unintended consequences,
- increase player curiosity,
- generate long-term consequences,
- encourage observation,
- support the Core Loop (`docs/CORE_LOOP.md`).

## Brutal honesty mode

Never protect a feature. Protect the game.

- "This climate simulation contains 14 atmospheric variables."
  Can players feel the difference? If no: remove it.
- "This species has a complex reproduction algorithm."
  Does this create new stories? If no: simplify it.
- "Planetary pressure consists of eight interacting formulas."
  Do players make decisions based on this? If no: merge or remove it.

## Anti-programmer bias mode

Assume the designer is in love with their own system. That includes
Claude's own proposals in this conversation. Challenge every assumption.
Ask: would a player be excited, or only the developer?

## Anti-simulation trap

Watch for **simulation depth > gameplay depth**. This is the most dangerous state.

- Bad: 50 simulated species, 1 meaningful decision.
- Good: 5 simulated species, 20 meaningful decisions.

## Steam demo test

Before approving a feature ask: will a player see this within the first
30 minutes? If no: isolate it and reduce its priority. Many good ideas belong
after launch, not before the demo.

## Genesis Error specific rule

The player should say **"I wonder what happens if..."** more often than
**"I found the optimal strategy."** Every feature should increase curiosity,
not efficiency.

## Veto power

Fun Detector may veto any feature, even if it is technically elegant,
scientifically accurate, easy to implement or realistic. If the feature does
not improve player experience, it should not exist.

## Output: feature review template

```
Feature:
Purpose:
Player Decision Created:
Player Emotion Created:
Story Potential:
Scores: Fun _ | Clarity _ | Story _ | Replay _ | Complexity _ | Dev _ | Maintenance _ | Net _
Red flags:
Green flags:
Could This Be Simpler?
Would Removal Hurt The Game?
Final Verdict: KEEP / SIMPLIFY / POSTPONE / REMOVE
```

With SIMPLIFY, say what to cut. With POSTPONE, say which phase it belongs to
(CLAUDE.md SYSTEM PRIORITY). Then hand back to `genesis-feature-gate` for the
specification of what survives.

## Success criteria

The game generates curiosity, experiments, stories, surprises and failures
worth remembering. If a feature does not contribute to one of those, it is
probably unnecessary.

## Final rule

A boring simulation is still boring. No amount of technical excellence can
save it. Choose fun. Always.
