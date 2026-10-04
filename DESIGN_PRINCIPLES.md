# DESIGN_PRINCIPLES.md

# Genesis Error Design Principles

Version: 1.0

Project Type:
Planetary Evolution Simulation

Audience:
Designers
Programmers
AI Assistants
Future Team Members

Purpose:
Protect the core identity of the game.

Whenever a design decision is questionable,
this document wins.

---

# GAME IDENTITY

Genesis Error is a simulation about creating,
guiding and understanding a living planet.

It is not a city builder.

It is not a colony simulator.

It is not a survival game.

It is not a resource management game.

Those elements may exist.

None of them are the focus.

The focus is:

Watching a world evolve.

---

# CORE PLAYER FANTASY

The player fantasy is:

"I influence planetary evolution and observe the consequences."

Not:

"I optimize production chains."

Not:

"I maximize resources."

Not:

"I build bigger structures."

The player acts as:

- scientist
- observer
- gardener
- experimenter

Never as:

- king
- general
- factory manager

---

# THE PLANET IS THE PROTAGONIST

Most games make the player
the main character.

Genesis Error makes the planet
the main character.

The player is secondary.

The player exists to interact with the planet.

Every design decision must ask:

"Does this make the planet feel more alive?"

If not:

Reject it.

---

# OBSERVATION FIRST

The primary activity is observation.

Gameplay loop:

Observe
↓
Understand
↓
Intervene
↓
Observe consequences

Not:

Click
↓
Reward
↓
Click
↓
Reward

The game must encourage patience.

Not constant action.

---

# CONSEQUENCES OVER REWARDS

The game should not focus on rewards.

The game should focus on consequences.

Player action:

Introduce algae.

Interesting response:

The algae unexpectedly reshapes
the ecosystem.

Boring response:

+10 oxygen.

Prefer systemic consequences.

Avoid isolated rewards.

---

# EMERGENCE OVER SCRIPTING

The most memorable moments should emerge.

Good example:

A species expands.

Humidity increases.

Forests grow.

Wildfires appear.

Atmosphere changes.

All systems interact naturally.

Bad example:

At minute 15,
trigger forest fire cutscene.

Emergence should dominate.

Scripts should support emergence,
not replace it.

---

# THE PLANET SHOULD SURPRISE THE PLAYER

The player should never have
complete control.

The planet should surprise them.

Healthy surprises:

Unexpected growth.

Unexpected collapse.

Rare mutations.

Environmental shifts.

Planetary crises.

The player must learn.

Not memorize.

---

# EVERY SYSTEM MUST CREATE STORIES

A system without stories is dead.

When designing a new mechanic ask:

Can a player tell a story about this later?

Example:

Good:

"I accidentally caused a global extinction."

Bad:

"I increased biomass from 48 to 52."

Stories are the real reward.

---

# INFORMATION SHOULD BE DISCOVERED

Avoid showing everything.

The player should discover:

- ecosystem behavior
- planetary tendencies
- long-term consequences
- hidden relationships

Knowledge becomes progression.

Not just numbers.

---

# KNOWLEDGE IS A RESOURCE

Traditional games reward:

gold
wood
stone
credits

Genesis Error rewards:

understanding

The player should become more powerful
because they know more.

Not because numbers increased.

---

# FAILURE MUST BE INTERESTING

Failure is content.

A collapse should reveal something.

Good failure:

An ecosystem crashes and teaches
the player a lesson.

Bad failure:

Game over.

Avoid hard failure states.

Prefer transformative failures.

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
greater ecological instability

More rain
=
higher mutation probability

Every gain should create new risks.

---

# SHORT-TERM VS LONG-TERM THINKING

Interesting decisions create tension.

The player should constantly choose between:

Immediate benefit

and

Future stability

Example:

Fast-growing species provide
quick ecosystem growth.

Later:

They become invasive.

---

# THE PLAYER IS AN ECOLOGIST

The player should think like:

an ecologist
a biologist
a climatologist

Not:

an accountant

Not:

an RTS player

Not:

a logistics optimizer

Design interfaces accordingly.

---

# CAUSE AND EFFECT

The player must understand
why something happened.

Every major outcome should have
traceable causes.

The player may not know them immediately.

But they must exist.

Avoid:

Random unexplained punishment.

Prefer:

Understandable consequences.

---

# TRANSPARENCY OF SYSTEMS

Never hide information
without a reason.

The player may not know everything.

But the simulation always knows.

There must be logic underneath.

Mystery is acceptable.

Arbitrariness is not.

---

# COMPLEXITY THROUGH INTERACTION

Avoid adding complexity through
more systems.

Prefer complexity through interaction.

Bad:

10 independent systems.

Good:

3 systems interacting deeply.

Depth beats quantity.

---

# SIMULATION BEFORE GAMEPLAY

The simulation must be enjoyable
before gameplay exists.

Required test:

Observe the simulation for 30 minutes.

Question:

Is it interesting?

If not:

Adding gameplay will not solve it.

---

# BEAUTY THROUGH TRANSFORMATION

The strongest visual reward
is transformation.

Players should witness:

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

Transformation creates emotion.

---

# SYSTEMIC EVENTS

Events should emerge naturally.

Good:

Drought occurs because
humidity collapsed.

Bad:

5% random drought chance.

All major events should originate from:

- environment
- ecology
- climate
- species interactions

---

# THE PLAYER SHOULD FEEL SMALL

The planet exists beyond the player.

The planet should feel ancient.

Powerful.

Independent.

Alive.

The player influences.

The player does not dominate.

---

# UNCERTAINTY CREATES CURIOSITY

The player should not know
every outcome in advance.

Questions are gameplay.

Examples:

Will this species survive?

Will the climate stabilize?

Will the ecosystem collapse?

Curiosity drives engagement.

---

# BEAUTIFUL PROBLEMS

The best moments happen when
the player creates a problem.

Then attempts to solve it.

The game should generate:

Interesting mistakes.

Not perfect plans.

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

□ Does it make the planet feel alive?

□ Does it create stories?

□ Does it increase emergence?

□ Does it create trade-offs?

□ Does it generate curiosity?

□ Does it interact with existing systems?

□ Does it produce meaningful consequences?

□ Can the player learn from it?

□ Does it avoid dominant strategies?

□ Can it create unexpected outcomes?

If most answers are "no",
the feature should not exist.

---

# FEATURES WE WANT

Emergent ecosystems

Planetary evolution

Species interaction

Environmental adaptation

Mutation

Climate response

Ecological collapse

Planet personality

Long-term consequences

Scientific discovery

Environmental storytelling

---

# FEATURES WE DO NOT WANT

Idle mechanics

Clicker gameplay

Artificial grind

Production chain obsession

Inventory management focus

Busy work

Daily quests

Meaningless upgrades

Constant notifications

Excessive micro-management

Instant gratification loops

---

# DEFINITIONS OF SUCCESS

A player says:

"I wanted to see what would happen next."

A player says:

"I accidentally created a disaster."

A player says:

"I spent an hour watching the ecosystem."

A player says:

"I did not expect that outcome."

These are success signals.

---

# DEFINITIONS OF FAILURE

A player says:

"I solved the optimal build order."

A player says:

"I only watched the numbers go up."

A player says:

"Every game feels the same."

A player says:

"I already know the best strategy."

These are warning signs.

---

# NORTH STAR

The goal of Genesis Error is not to let players build a planet.

The goal is to let players witness
the birth of a world.

Everything else is secondary.