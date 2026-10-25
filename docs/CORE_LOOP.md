# CORE_LOOP.md

# Genesis Error Core Loop

Version: 2.0 (new core, 2026-10-06)

Source: `docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md`
(chapters 2, 3, 5, 9).

Purpose:
Define the primary player experience.

If a feature does not improve this loop,
it should not be implemented.

---

# NORTH STAR

The player is the Creator's Apprentice.

Humanity doubts that life can be created on purpose.
The Creator gives the Apprentice an empty planet and 200 years.

The objective is lush life:
many species, wide spread, surviving every Trial.

The core experience is:

Collect Sparks.
Buy a perk.
Watch life spread.
Avert the next Trial.
Play again.

---

# THE PRIMARY LOOP

The loop runs on four levels at once.

| Level | What the player does | Plague Inc analogue |
|---|---|---|
| Seconds | collects bubbles on the globe and gets **Sparks of Life** | DNA bubbles |
| 1-2 minutes | buys perks, uses divine powers, reacts to a Trial warning | evolution, events |
| 5 minutes | picks a direction (tree) and a growth pace, because fast growth angers the Creator | stealth vs. lethality |
| game (15-25 min) | 200 years: from an empty planet to the Final Trial | one playthrough |
| meta | Legacy unlocks planets, starting perks, difficulty | genes, scenarios |

Time scale: 1 year = 360 ticks, a game = 72 000 ticks.
Speeds: x1, x5, x10, x25, x50, x100.

The loop is live: the simulation runs while the player acts.
Pause is not required for decisions. Only a Trial warning may auto-pause.

---

# LEVEL 1: SECONDS (BUBBLES)

Bubbles appear on reached continents:

- Bloom: a species crossed a population threshold.
- Mutation: a random event with a cause in the planet state.
- Discovery: a species appears for the first time, a continent is
  settled for the first time.

A bubble disappears after 15 real seconds, so the game rewards attention.

Targets (to be measured with a bot and testers):

- 4-6 bubbles per minute,
- the first perk bought within 30 seconds of the start,
- about 20 perks bought per game.

---

# LEVEL 2: 1-2 MINUTES (PERKS AND POWERS)

Four perk trees:

| Tree | Content |
|---|---|
| Environment | divine powers: mirrors, dust, cloud seeding, groundwater, volcanoes |
| Life | species traits: drought and frost resistance, faster growth, lower flammability |
| Dispersal | spores, wind-borne seeds, crossing the ocean (extends reach) |
| Ecosystem | decomposers, pollinators, insects, amphibians, mammals (later stage) |

Every perk has a price in Sparks, requirements, a **side effect**,
and can be refunded for part of the cost.
Divine powers keep their cooldowns: the player buys access, not a resource.

---

# LEVEL 3: 5 MINUTES (DIRECTION AND PACE)

The Creator's Wrath (0-100) is derived from the planet state:
the growth rate of biomass over a window. The faster life grows,
the higher the Wrath. Slower growth lowers it over time.

A Trial (cataclysm) is a world event:

- **Pending = warning.** The condition must hold for `for_ticks`
  (about 20-40 seconds at game pace). The player sees the warning
  and can avert the Trial by slowing growth or buying the matching perk.
- **Escalation.** Later Trials have higher biomass thresholds
  and stronger modifiers. The better the player does, the faster
  the Creator moves.
- Every Trial has a counter in the trees (ice age: mirrors and frost
  resistance; oxygen catastrophe: anaerobic niche; fires: low flammability).

The only scripted element is the Final Trial in year 200
(meteor impact plus volcanic winter).

---

# LEVEL 4: THE GAME (200 YEARS)

Life Index (0-100): the sum over species of
`weight * min(1, population / threshold)` plus a bonus
for the number of species living at once.

- **Win:** after the Final Trial the Life Index is at least 60
  and at least 4 species live.
- **Loss:** biomass stays below 2 for 5 game years, or after the Final
  Trial the Life Index is below 60.

---

# REWARD

The primary reward is growth in power and expansion:
more Sparks, stronger species, more of the map filled with life.

The secondary reward is transformation of the globe:
desert, moss, wetlands, forests, a complex biosphere.
Coverage fills the map with species colors, like a plague
spreading in Plague Inc.

The tertiary reward is stories:
the Trial that was averted at the last second,
the mutation that saved the planet,
the headline from humanity after a win.

---

# FAILURE AND LEGACY

A loss ends the game, but it always pays out.

```text
Game ends
↓
Legacy points (Life Index, Trials survived, speed)
↓
Unlocks: planets, starting perks, difficulty levels
↓
Next game
```

Legacy is the meta loop: failure moves the player forward.

---

# CORE LOOP VALIDATION TEST

Every feature must pass this test.

Question 1:

Does it give the player a reason to click once more
(bubble, perk, power)?

Question 2:

Does it make a decision clearer or a crisis more readable?

Question 3:

Does it carry a price or a side effect?

Question 4:

Does it change PlanetState in a measurable way?

Question 5:

Does it make the next game more interesting?

If at least three answers are NO,
the feature should be rejected.

---

# SYSTEM CONTRIBUTION MATRIX

Perk shop

✓ Click once more

✓ Price and side effect

✓ Changes PlanetState

Keep.

---

Inventory System

✗ Clarity of decisions

✗ Changes PlanetState

✗ Next game

Reject unless proven necessary.

---

# DESIGN WARNING SIGNS

The game is going wrong if:

Players buy perks without reading them.

One perk path wins every game.

Players stop clicking bubbles.

Trials arrive without a warning, or have no counter.

Players do not start a second game.

If this happens:

Return to the loop: bubbles, perks, Trials.

---

# THE 15-25 MINUTE TEST

Play one full game (200 years).

Questions:

Did the game last 15-25 minutes?

Did the tester click bubbles without hints (4-6 per minute)?

Was every Trial announced, and could it be countered?

Did the tester feel stronger over time?

Could the tester tell a story afterward?

Did the tester start a second game without being asked?

At least 3 of 5 testers should start the second game unprompted.

If most answers are NO:

Do not add more content.

Fix the loop.

---

# FINAL DESIGN RULE

Players should leave the game saying:

"One more game, I know what to do differently."

Not:

"I completed the optimal strategy."

That sentence defines Genesis Error.
