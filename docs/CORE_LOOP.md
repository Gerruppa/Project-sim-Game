# CORE_LOOP.md

# Genesis Error Core Loop

Version: 1.0

Purpose:
Define the primary player experience.

If a feature does not improve this loop,
it should not be implemented.

---

# NORTH STAR

The player is not building a planet.

The player is discovering how a planet works.

The objective is not control.

The objective is understanding.

The core experience is:

Observe a world.
Change something.
Watch the consequences.
Learn.
Repeat.

---

# THE PRIMARY LOOP

```text
Observe
↓
Hypothesize
↓
Intervene
↓
Simulate
↓
Observe Consequences
↓
Learn
↓
Form New Hypothesis
```

This loop defines the entire game.

Every feature must support it.

---

# LOOP STAGE 1

# OBSERVE

Player studies the world.

Objectives:

- understand current climate
- understand species distribution
- identify opportunities
- identify risks

Player asks:

What is happening?

Why is it happening?

What could happen next?

---

# Player Emotions

Curiosity

Wonder

Interest

---

# Success Criteria

Player can identify:

- major environmental trends
- dominant species
- ecosystem state

Without requiring external tools.

---

# Questions Produced

Examples:

Why is oxygen rising?

Why are forests dying?

Why is humidity collapsing?

Why are algae spreading?

Good gameplay begins with questions.

---

# LOOP STAGE 2

# HYPOTHESIZE

The player develops a theory.

Examples:

I believe adding moss
will increase humidity.

I believe lower temperatures
will stabilize the ecosystem.

I believe algae growth
will improve oxygen levels.

---

# Purpose

Create player agency through knowledge.

Not through power.

---

# Success Criteria

Player can make informed predictions.

Predictions do not need
to be correct.

Only reasonable.

---

# LOOP STAGE 3

# INTERVENE

Player performs an action.

Examples:

Introduce species.

Remove species.

Alter climate.

Deploy technology.

Influence atmosphere.

Modify water cycle.

Create ecological pressure.

---

# Design Rule

Every action must change
the simulation.

Avoid cosmetic actions.

Avoid meaningless interactions.

---

# Questions Produced

What happens now?

What side effects exist?

What did I miss?

---

# LOOP STAGE 4

# SIMULATE

The world processes changes.

This is the most important phase.

The player should feel:

The planet is alive.

Not:

The planet is following scripts.

---

# Design Goals

System interactions

Delayed consequences

Unexpected outcomes

Nonlinear effects

Tradeoffs

---

# Examples

Player introduces algae.

↓

Oxygen increases.

↓

Humidity changes.

↓

Moss expands.

↓

Forest appears.

↓

Wildfires increase.

↓

Atmosphere destabilizes.

A single action created
multiple outcomes.

This is desirable.

---

# LOOP STAGE 5

# OBSERVE CONSEQUENCES

Player investigates outcomes.

This stage provides reward.

Not currency.

Not experience points.

Not unlocks.

Knowledge.

---

# Questions Produced

Was my theory correct?

Why did this happen?

What caused this chain reaction?

Can I repeat it?

Can I stop it?

---

# Design Goal

Generate stories.

Examples:

I accidentally caused
a planetary drought.

I created a forest ecosystem.

My species became invasive.

These stories are progression.

---

# LOOP STAGE 6

# LEARN

Player builds mental models.

This is the true progression system.

Player progression should be:

KnowledgeBasedProgression

Not:

NumericProgression

---

# Bad Progression

Unlock stronger algae.

Unlock larger buildings.

Unlock bigger numbers.

---

# Good Progression

Understand ecosystems.

Understand feedback loops.

Understand weather systems.

Understand ecological pressures.

---

# LOOP STAGE 7

# NEW HYPOTHESIS

Player's new knowledge creates
new experiments.

The loop restarts.

---

# SECONDARY LOOP

Planet Discovery Loop

```text
Observe Anomaly
↓
Investigate
↓
Gather Evidence
↓
Understand Cause
↓
Gain Knowledge
```

Purpose:

Support exploration.

---

# TERTIARY LOOP

Ecological Management Loop

```text
Problem
↓
Diagnosis
↓
Intervention
↓
Monitoring
↓
Resolution
```

Purpose:

Create long-term engagement.

---

# EMOTIONAL CURVE

Early Game

Curiosity

↓

Experimentation

↓

Discovery

Mid Game

Mastery

↓

Unexpected Crisis

↓

Adaptation

Late Game

Stewardship

↓

Responsibility

↓

Planetary Transformation

---

# WHAT IS THE PLAYER ACTUALLY DOING?

A common design mistake is
misunderstanding the player activity.

The player is NOT:

Building

Mining

Crafting

Collecting

Grinding

The player IS:

Observing

Predicting

Experimenting

Learning

Adapting

---

# PRIMARY REWARD

The primary reward is:

Understanding.

---

# SECONDARY REWARD

Planetary transformation.

Examples:

Desert

↓

Moss

↓

Wetlands

↓

Forests

↓

Complex Ecosystem

The visual change reflects learning.

---

# TERTIARY REWARD

Emergent stories.

Examples:

The oxygen crisis.

The fungal takeover.

The great extinction.

The endless storm age.

These stories create memory.

---

# FAILURE LOOP

Failure is not game over.

Failure produces knowledge.

```text
Failure
↓
Analysis
↓
Understanding
↓
New Strategy
```

A failed ecosystem is content.

Not punishment.

---

# CORE LOOP VALIDATION TEST

Every feature must pass this test.

Question 1:

Does it improve observation?

Question 2:

Does it improve hypothesis creation?

Question 3:

Does it improve intervention?

Question 4:

Does it create consequences?

Question 5:

Does it create learning?

If at least three answers are NO,
the feature should be rejected.

---

# SYSTEM CONTRIBUTION MATRIX

Climate System

✓ Observation

✓ Hypothesis

✓ Consequences

✓ Learning

Keep.

---

Inventory System

✗ Observation

✗ Consequences

✗ Learning

Reject unless proven necessary.

---

# PLAYER QUESTIONS TEST

A healthy game constantly generates
player questions.

Examples:

Why is that happening?

What if I change this?

What caused that event?

Can I stabilize the ecosystem?

Can I reproduce this outcome?

If a feature creates questions,
it is valuable.

If a feature only creates clicks,
it is dangerous.

---

# DESIGN WARNING SIGNS

The game is becoming a city builder if:

Players optimize layouts.

Players focus on production.

Players solve build orders.

Players repeat identical strategies.

Players stop observing the planet.

If this happens:

Return focus to simulation.

---

# THE 30-MINUTE TEST

Observe a simulation.

Allow intervention.

Play for 30 minutes.

Questions:

Did interesting things happen?

Did unexpected things happen?

Did the planet surprise the player?

Did the player form hypotheses?

Did the player learn anything?

Could the player tell a story afterward?

If most answers are NO:

Do not add more content.

Fix the simulation.

---

# FINAL DESIGN RULE

Players should leave the game saying:

"I wonder what would happen if..."

Not:

"I completed the optimal strategy."

That sentence defines Genesis Error.