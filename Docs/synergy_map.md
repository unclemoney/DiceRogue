# Synergy Map

How DiceRogue's items feed each other. Read each node as a channel: something
produces a resource (even dice, fixed faces, colored dice, consumable uses,
debuffs, zero scores), and something else pays off for having it.

- `feeds →` — what this item makes stronger or enables downstream.
- `fed by ←` — what this item needs upstream to reach full value.

Sources: `Scripts/PowerUps/*.tres`, `Scripts/Consumable/*.tres`,
`Scripts/Mods/*.tres`, `Scripts/Managers/SynergyManager.gd`,
`Scripts/Managers/dice_color_manager.gd`, `Scripts/Core/dice_color.gd`.

---

## The Core Web (existing map)

### Parity
- EvenOnly / OddOnly mods force a die's parity every roll.
- `feeds →` **EvensNoOdds** (even +1 / odd -1 additive), **Even Higher** (+1
  cumulative additive per even die scored), **Tango & Cash** (+$10 per odd die
  scored at round end).
- `fed by ←` nothing upstream; parity mods are the root of the channel.

### FixedFace
- Three But Three (always 3s, +$3/roll) and Five By One (always 5, +1/roll)
  fix a die to one face.
- `feeds →` **Yahtzeed Dice** (+1 die per Yahtzee), **Yahtzee Mult** (+1x per
  Yahtzee Bonus), and the upper section (Threes/Fives fill on demand, feeding
  the 63-point upper bonus).

### Sixes
- Gold Six ($6 per 6 rolled) + Wild Dots (locked dice raise odds of matching
  faces) push the board toward sixes.
- `feeds →` **Snake Eyes**… indirectly — see anti-synergies. Sixes stacking is
  the payoff itself via the Sixes category and Yahtzee attempts.
- **Hail Satan** (debuff: 3 sixes in a turn = instant 0 in a random category)
  punishes the channel.

### Mods
- Any mod on any die.
- `feeds →` **Mod Money** ($8 per modded die scored), **Modded Dice Mastery**
  (+10 per modded die scored).
- `fed by ←` **One Free Mod** (consumable: grants 1 free random mod).

### Colors
- Slimes (Green/Red/Purple/Blue/Yellow) double the roll chance of their color
  → colored dice on the board → color PowerUps (Green Monster, Red Power
  Ranger, Purple Payout, Blue Safety Net, Azure Perfection, Extra Rainbow)
  → **Rainbow Surge** (2x at 5 unique colors of the 6) and same-color bonuses
  (5+ of one color triggers each color's overdrive).

### Consumable
- Every consumable use.
- `feeds →` **The Consumer Is Always Right** (+0.25x per consumable used this
  session), **Cash Flow** (+$1 per turn per consumable used).
- `fed by ←` **Yellow dice** — scoring yellow dice grant consumables, so a
  yellow investment is a self-refueling consumable engine.

### Ratings
- POG ratings (G / PG / PG-13 / R / NC-17) on owned PowerUps, tracked by
  `SynergyManager` and registered with `ScoreModifierManager`.
- 5+ PowerUps sharing one rating: **+50 additive per set of 5**
  (`synergy_<rating>_sets`).
- One of each rating: **5x multiplier** (`synergy_rainbow`).

### PawnShop
- Liquidation channel.
- **The Pawn Shop** (sell ALL PowerUps at 1.25x) → leaves every PowerUp slot
  empty → **Empty Shelves** (next score × empty PowerUp slots) spikes hardest
  right after a Pawn Shop fire sale.
- **The Piggy Bank** ($3 saved per roll, sell to cash out) is the slow-burn
  half of the same "sell for value" fantasy.

---

## New Content in the Web

### Orange Dice (colored dice, $175 base, 1-in-150 roll chance)
Scoring orange dice grants +1 roll per orange die scored (doubled to +2 each
on a 5+ orange same-color bonus). Rolls are the game's core tempo resource:
more rolls → more scoring chances → higher expected score per turn.
- `feeds →` roll-hungry builds: **Roll Efficiency** (+N where N = rolls used),
  **Lock & Load** (more rolls = more lock cycles), **Wild Dots** (more chances
  to land the matching face), **The Piggy Bank** ($3 per roll fills faster),
  **One-Roll Wonder** stays a fork — extra rolls devalue first-roll scoring.
- `fed by ←` **Extra Rolls**, **Three More Rolls**, **The Great Exchange**
  (+2 dice, -1 roll — orange dice buy the lost roll back and then some).
- Note: with orange in the pool there are 6 dice colors; **Rainbow Surge** now
  means 5 unique of 6.

### Yellow Slime (PowerUp, $300 legendary)
Yellow base chance is 1-in-120; Yellow Slime doubles it to 1-in-60.
- `feeds →` the yellow engine: more yellow dice → more granted consumables →
  **Extreme Couponing**, **The Consumer Is Always Right**, **Cash Flow**.
- `fed by ←` yellow dice unlock (USE_CONSUMABLES 8) and any consumable-slot
  capacity (**Extra Coupons** fixes slots at 4).

### Extreme Couponing (PowerUp, $140 uncommon)
+5 additive per consumable *granted* this run — grants, not uses, so it stacks
even on consumables you hold or sell.
- `feeds →` raw additive floor for any build willing to run yellow dice.
- `fed by ←` **yellow dice** (each scored yellow grants a consumable = +5),
  **Yellow Slime** (1/60), **Extra Coupons** (more slots = more grants held),
  **Random Uncommon Power-Up** and other granting consumables.

### Defiance (PowerUp, $400 epic)
+0.25x score multiplier per active debuff. Mom-granted buffs (rebellion,
teacher_pet) ride the debuff pipeline but are **excluded** — Defiance only
pays for real debuffs.
- `feeds →` debuff-tolerant score builds; converts bad rounds into multiplier
  fuel.
- `fed by ←` debuff-heavy Mall Zones/channels; pairs with **Spite** (stack
  both before scoring) and **Antidote** (cleanse after the value is banked).
- Hard fork vs **Immunity** — see anti-synergies.

### Spite (Consumable, $50)
Next scored category gets ×(1.0 + 0.5 per active debuff). Requires at least
one active debuff; fizzles otherwise.
- `feeds →` one huge scored category mid-debuff-storm.
- `fed by ←` active debuffs; same pipeline as Defiance. Sequence: let debuffs
  accumulate → Spite + Defiance score → Antidote the worst one.

### Antidote (Consumable, $40)
Cleanses the highest-intensity active debuff.
- `feeds →` tempo: the exit ramp after Defiance/Spite value is extracted, so
  the debuff doesn't keep taxing future scores.
- `fed by ←` debuff-heavy rounds; dead draw in clean rounds.

### Immunity (Consumable, $50)
No debuffs are assigned next round.
- `feeds →` safety for fragile builds (Lock & Load windows, Cursed Six
  economy protection from Hail Satan).
- `fed by ←` nothing — and it **starves** Defiance/Spite. This is a
  deliberate fork: you are either a debuff-farming build or a
  debuff-avoiding build, not both.

### Mulligan (Consumable, $25)
Reroll your worst placed score using your current dice.
- `feeds →` scorecard repair; converts a forced 0 into a second chance.
- `fed by ←` the zero-score archetype: **Scratch Ticket** (0-score → next
  score 2x) and **Comeback Kid** (+5 per category sitting at 0). Mulligan
  decides *when* to cash the zero out; Scratch Ticket and Comeback Kid pay
  you for having suffered it.

### Comeback Kid (PowerUp, $150 rare)
+5 score for each category sitting at 0.
- `feeds →` additive floor that grows as the scorecard fills with scars.
- `fed by ←` zero scores — accidental or deliberate. Natural partner of
  **Scratch Ticket** and **Mulligan**.

### Upper Crust (PowerUp, $250 rare) + Bonus Sprint (Consumable, $65)
Upper Crust: upper section scores ×1.5. Bonus Sprint: this round, upper
section scores count double toward the 63-point upper bonus threshold.
- `feeds →` the upper-section archetype: **Step By Step** (+6 upper),
  **Bonus Mult** (+1x per upper bonus achieved), **Bonus Collector** ($150 if
  upper total ≥ 63), **Upper Section Boost** (all 6 upper categories +1
  level).
- `fed by ←` fixed-face mods (Three But Three, Five By One) that fill
  Threes/Fives on demand. The archetype now rivals LowerTen builds
  (**Lower Ten**, **Lower Section Boost**) as a section-focusing path.

### Four-Kind Yahtzee (PowerUp, $450 epic) + Two Pair House (PowerUp, $300 rare)
Four-Kind Yahtzee: four-of-a-kind scores as a 25-point Yahtzee (no Yahtzee
bonus). Two Pair House: two pair scores as a 25-point Full House. Both are
category-score-only by design.
- `feeds →` reliable mid-tier category value; rescues near-miss hands.
- `fed by ←` fixed-face mods (Three But Three, Five By One) and parity mods
  (EvenOnly/OddOnly) — bending the dice pool makes bent categories reliable.

### Painted Die (Mod, $100)
This die is permanently painted a random color; it always counts as that
color.
- `feeds →` color PowerUps (a guaranteed colored die every roll), rainbow
  fixing (one known color toward Rainbow Surge's 5-of-6), same-color pushes
  (paint matching an existing slime investment).
- `fed by ←` slime investments (paint into your doubled color) and
  **Paint Job** for splash-color turns.

### Cursed Six (Mod, $25)
Always rolls a 6, but costs $5 per roll. Sells for $0.
- `feeds →` the sixes archetype: **Gold Six** ($6 per 6 — nets +$1/roll on
  this die alone), Sixes category, Yahtzee attempts with **Wild Dots**.
- `fed by ←` Gold Six and money engines (Tango & Cash, Plus A Dollar) that
  subsidize the $5/roll upkeep.
- **Hail Satan** anti-synergy: a guaranteed 6 every roll means every third
  roll risks the instant-0 punishment — see anti-synergies.

### Loaded Dice (Consumable, $75)
Pick one die and set it to an exact value (1 to its side count).
- `feeds →` precision category filling; completes straights, forces the fifth
  of a Yahtzee.
- `fed by ←` **Wild Dots** is the best synergy: lock the loaded value, and
  Wild Dots pushes the remaining dice to match it. Also feeds fixed-face
  channels (set the face your mods can't produce).

### Paint Job (Consumable, $60)
All dice gain a random color for the next roll, then revert.
- `feeds →` **Rainbow Surge** (one-roll rainbow fishing), **Extra Rainbow**
  (+10 per colored die scored), any slime-invested color lucky enough to land.
- `fed by ←` slime investments (raise the odds the random colors hit your
  payoff color) and **Painted Die** (one slot already fixed).

---

## Discovered Anti-Synergies & Friction

| Pair | Friction | Notes |
|---|---|---|
| Lock & Load ↔ High Roller | **Hard conflict.** High Roller dice cannot be locked; Lock & Load pays per locked die and its unlock constraint caps locks. | Now surfaced as a warning in the shop. |
| Immunity ↔ Defiance / Spite | **Deliberate fork.** Immunity skips a round of debuffs, zeroing Defiance's multiplier and making Spite unusable. | Documented as intended design: pick a side per run. |
| Cursed Six ↔ Hail Satan | **Dangerous.** A guaranteed 6 per roll accelerates Hail Satan's "3 sixes = instant 0" trigger. | The $5/roll upkeep already taxes the channel; the debuff makes it a liability in Hail Satan rounds. |
| Scratch Ticket ↔ Comeback Kid | **Soft tension.** Scratch Ticket wants you to *leave* the zero and double the next score; Mulligan/Comeback Kid pressure you to *fix* or *farm* zeros. Deliberately bricking a category for +5/zero can cost more than it pays. | Watch whether zero-farming becomes a dominant line. |
| Orange dice ↔ One-Roll Wonder | **Soft tension.** Extra rolls raise the expected value of later rolls, diluting the first-roll bonus fantasy. | Acceptable; both stay pickable. |
| Immunity / Ungrounded ↔ Antidote | Dead draw. No debuffs = nothing to cleanse. | Minor; Antidote is cheap ($40). |

---

## Proposed Synergy-Creating Tweaks

1. **Piggy Bank ↔ Orange dice** — count orange-granted rolls toward Piggy
   Bank's $3/roll savings (verify: if they already do, document it; if not,
   include them). *Why:* welds the new roll economy to the PawnShop channel,
   giving orange builds a cash-out fantasy.
2. **Painted Die** — let the player pick the color in the shop (or reroll the
   color for $25) instead of pure random. *Why:* agency converts it from a
   lottery ticket into the anchor piece of a chosen color channel, feeding
   slimes, color PowerUps, and Rainbow Surge on purpose.
3. **Cursed Six ↔ Gold Six** — make Gold Six's $6 payout exempt from Cursed
   Six's $5/roll upkeep on the cursed die itself. *Why:* turns a net +$1/roll
   treadmill into a real combo worth building around, without touching the
   Hail Satan risk that prices it.
4. **Debuff Destroyer ↔ Defiance** — when Debuff Destroyer's sell-effect
   removes a debuff, Defiance keeps that debuff's +0.25x for one more score.
   *Why:* right now cleansing always hurts a Defiance build; a one-score
   memory turns "sell to cleanse" from anti-synergy into a tempo decision
   like Antidote.
5. **Insurance Policy ↔ Scratch Ticket** — if Insurance Policy pays its $75
   consolation while Scratch Ticket is armed, also add +10 additive to the
   doubled score. *Why:* the two zero-payoff consumables currently compete
   for the same event; a small bridge makes the zero-score archetype feel
   like a deck, not a coincidence.
6. **Extreme Couponing ↔ Extra Coupons** — while Extra Coupons is owned,
   yellow-dice consumable grants count double for Extreme Couponing's +5.
   *Why:* both already live in the consumable engine; this gives the
   slot-cap item a scoring identity beyond utility.
7. **Bonus Sprint ↔ Upper Section Boost** — using both in one round also
   extends Bonus Sprint by one round. *Why:* the upper-section archetype has
   multipliers (Upper Crust) and thresholds (Bonus Sprint) but no duration
   play; a small combo reward mirrors how Lower Section Boost + Lower Ten
   stack passively.

---

## Edges of the Web (unmapped items)

Roster items with no strong channel yet — candidates for future tweaks or
watchlist entries rather than the current map:

- **Chore economy:** Chore Champion, Chore Sprint, Free Chores, All Chores,
  Allowance — feed Mom/goof-off, not other items.
- **Shop economy:** Half Price, Loss Leader, Clearance Rack, Shop Rerolls,
  Shop Expansion, Quick Cash, Add Power Up Slot, Visit The Shop — utility,
  no scoring channel.
- **Volatility/RNG:** Chaos Dice (randomizer), Perfect Strangers, Pin Head,
  Foursome, Lucky Upgrade, Random Card Level, Melting Dice, Daring Dice —
  self-contained gambles.
- **Tempo/streaks:** Hot Streak, Score Streak, One-Roll Wonder,
  Sweet Sixteen, Highlighted Score — turn-timing payoffs with no feeder.
- **Meta-scaling:** Power Surge, The Replicator — scale with owned PowerUps;
  adjacent to the Ratings channel but not wired into it.
