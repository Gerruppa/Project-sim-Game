# DESIGN_PRINCIPLES.md

# Genesis Error Design Principles

Version: 2.0 (new core, 2026-10-06)

Project Type:
Strategy game, Plague Inc-style, goal: create lush life

Audience:
Designers
Programmers
AI Assistants
Future Team Members

Purpose:
Protect the core identity of the game.

Whenever a design decision is questionable,
this document wins.

Source: `docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md`.

---

# GAME IDENTITY

Genesis Error is a strategy game about creating
a living planet in 200 years.

The player is the Creator's Apprentice.
Humanity doubts that life can be created on purpose.
The Creator gives the Apprentice an empty planet,
and speeds up the cataclysms when the Apprentice does well.

It is not a city builder.

It is not a colony simulator.

It is not a survival game.

The focus is:

Spreading life, spending Sparks on perks,
surviving the Creator's Trials.

---

# CORE PLAYER FANTASY

The player fantasy is:

"I grow life across a planet and survive everything the Creator throws at me."

Not:

"I optimize production chains."

Not:

"I watch numbers go up."

The player acts as:

- the Creator's Apprentice
- a gardener of a whole planet
- a strategist who chooses a direction and a pace

---

# EVERY PERK HAS A PRICE AND A SIDE EFFECT

This replaces "the player is not an economy".
Sparks of Life are a currency, and that is fine,
as long as spending them is a real decision.

A perk:

- costs Sparks,
- has requirements (a planet parameter threshold or another perk),
- has a side effect,
- can be refunded for part of the cost.

Example:

Faster growth
=
higher Creator's Wrath

The concrete side effect of each perk is decided
per perk in its data file and measured before it ships.

If a perk has no downside, it is a bug in the design.
If one perk beats every other, the game is broken.

---

# EVERY TRIAL IS ANNOUNCED AND HAS A COUNTER

A Trial (cataclysm) is a world event with a Pending phase.

- The player sees the warning (the condition must hold for `for_ticks`).
- The player can avert the Trial: slow growth, or buy the matching perk.
- Later Trials are stronger: when the player does well,
  the Creator speeds up.

Bad:

A random catastrophe with no warning.

Good:

"Ice age in 30 seconds. Mirrors or frost resistance will help."

The only scripted element is the Final Trial in year 200.
Scripting is justified by the story deadline.

---

# THE LOOP IS LIVE

The simulation runs while the player acts.

- Bubbles on the globe appear and disappear in 15 real seconds.
- The player can always spend Sparks.
- Pause is not required for decisions.

The game must reward attention, not patience.

---

# EXPANSION MUST BE VISIBLE

The strongest reward is the map filling with life.

Coverage appears on reached continents, in species colors,
like a plague in Plague Inc.

Desert
↓
Moss
↓
Wetlands
↓
Forests
↓
Complex biosphere

The world changing is more important
than graphical fidelity.

---

# THE SIMULATION STAYS GLOBAL

No regions. Reach is modeled by continents and species capacity:
effective capacity = `capacity * reach`.

Consequence we accept: climate effects are global,
so there are no local decisions ("drought only on continent A").
If testers show this is missing, regions become a separate stage.

---

# EMERGENCE OVER SCRIPTING

Good:

A species expands.

Humidity increases.

Forests grow.

Wildfires appear.

Atmosphere changes.

All systems interact naturally.

Bad:

At minute 15,
trigger forest fire cutscene.

Events originate from the planet state
(biomass growth, oxygen, humidity),
not from a random roll.

---

# EVERY SYSTEM MUST CREATE STORIES

A system without stories is dead.

When designing a new mechanic ask:

Can a player tell a story about this later?

Good:

"I averted the ice age with 5 seconds to spare."

Bad:

"I increased biomass from 48 to 52."

---

# NO PERFECT STRATEGY

If one strategy always wins,
the game is broken.

Every decision should involve trade-offs.

Examples:

More oxygen
=
higher wildfire risk

More biomass
=
greater Wrath of the Creator

Every gain should create new risks.

---

# CAUSE AND EFFECT

The player must understand
why something happened.

Every major outcome should have
traceable causes.

Avoid:

Random unexplained punishment.

Prefer:

Understandable consequences.

Mystery is acceptable.

Arbitrariness is not.

---

# COMPLEXITY THROUGH INTERACTION

Avoid adding complexity through
more systems.

Bad:

10 independent systems.

Good:

3 systems interacting deeply.

Depth beats quantity.

Most dangerous state:

simulation depth > gameplay depth.

---

# DATA OVER CODE

Perks, bubbles, Trials, continents, species
and scenarios live in data files (JSON, Resources).

Code stays small and general.

---

# DETERMINISM IS A TESTING TOOL

Same seed, same result.

Determinism is not a goal for the player.
It is how we test, balance with bots and reproduce bugs.
It is never traded for speed or fun.

---

# FAILURE PAYS OUT

A lost game ends the run, but always gives Legacy points.

Legacy unlocks planets, starting perks and difficulty levels.
The player should want to start the next game.

---

# SCIENCE FICTION RULE

Science fiction exists
to support gameplay.

Not the opposite.

Never add a mechanic only because
it sounds scientifically accurate.

Ask:

Does it improve the player experience?

If not:

Remove it.

---

# DESIGN CHECKLIST

Before adding a new feature:

□ Does the player want to click once more?

□ Does it have a price and a side effect?

□ Does it create stories?

□ Does it create trade-offs?

□ Does it interact with PlanetState?

□ Does it produce meaningful consequences?

□ Is a crisis it creates announced, with a counter?

□ Does it avoid dominant strategies?

□ Is it visible on the map or in a decision?

□ Does it make the next game more interesting?

If most answers are "no",
the feature should not exist.

---

# FEATURES WE WANT

Bubbles and Sparks of Life

Perk trees with side effects

Visible spread of life across continents

Trials with a warning and a counter

Creator's Wrath derived from planet state

Mutations with a cause in the planet state

Scenarios (planets) and Legacy

Humanity's reactions as a story layer

---

# FEATURES WE DO NOT WANT

Artificial grind

Production chain obsession

Inventory management focus

Busy work

Daily quests

Perks without downsides

Trials without a warning

Excessive micro-management

Multiplayer, combat, crafting

---

# DEFINITIONS OF SUCCESS

A player says:

"One more game."

A player says:

"I averted the Trial just in time."

A player says:

"I tried a different perk path this time."

A player says:

"I filled the whole map."

These are success signals.

---

# DEFINITIONS OF FAILURE

A player says:

"I solved the optimal perk order."

A player says:

"I stopped clicking the bubbles."

A player says:

"Every game feels the same."

A player says:

"The Trial came out of nowhere."

These are warning signs.

---

# NORTH STAR

The goal of Genesis Error is to let players
prove that life can be created,
one game at a time.

Everything else is secondary.
