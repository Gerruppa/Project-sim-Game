---
name: genesis-architect
description: Simulation architecture for Genesis Error — designing new systems, modules, parameters, dependencies and communication between them before any code. Use this whenever the user asks how to structure, design or architect something in the simulation, proposes a new mechanic that changes system relationships, introduces a dependency, or asks for a diagram, module split or tradeoff analysis. Not for graphics or UI.
---

# Planet Simulation Architect

Purpose: design scalable simulation systems, protect system boundaries and
prevent technical debt. The planet is the protagonist; design from climate,
biosphere and ecosystems, never from buildings or progression.

Read `docs/architecture.md` first. It is the source of truth; a proposal that
contradicts it must say so explicitly and propose the doc change.

## Fixed decisions (do not re-litigate without new evidence)

- Four channels: State (snapshot read), Change (deltas with cause through
  StateWriter), Notification (EventBus FIFO, facts only), Control (CommandQueue).
- Feedback loops are broken in time: all systems read the snapshot of tick N-1.
- Events act only through modifiers; Personality outputs modifiers only.
- One dynamics owner per parameter; others contribute flows.
- Data in JSON; deterministic math policy; normalized 0..100 scale with anchors.
- Order of the tick lives only in TickPipeline.

## How to answer

Follow the CLAUDE.md order: architecture, tradeoffs, risks, then (only if asked)
code and tests, then acceptance criteria. Deliver:

1. **Diagram** (ASCII) showing where the new piece sits and which channel each
   arrow uses.
2. **Contract**: reads, writes (deltas and which parameters), causes, events,
   data, internal state.
3. **Dependencies**: confirm they point downward only and no system references
   another system.
4. **Tradeoffs** table (gain / cost) for each real decision.
5. **Scalability**: what happens with 10× parameters, more systems, future
   regions; what stays unchanged.
6. **Risks** with concrete mitigations (instability, boring output, determinism,
   save compatibility).
7. **Decisions needed** as short numbered questions, recommendation first.
8. **Acceptance criteria** (CLAUDE.md template).

## Forbidden

Graphics and UI focus; premature optimization; designing regions or features
not yet needed; adding a system that skips SYSTEM PRIORITY in CLAUDE.md.
Prefer three deeply interacting systems over ten independent ones.
