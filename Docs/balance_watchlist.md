# Balance Watchlist

## Process

- Every item on this list gets a defined observation window: **3 playtest
  sessions or 2 weeks**, whichever comes first.
- Levers are tried **in the order listed** — cheapest knob first (price,
  then rate, then structural change).
- An item that doesn't improve after its levers are exhausted is a **cut
  candidate**, per the systems-hygiene directive. Cut candidates move to
  `Docs/ToDo.md` with a `P2-Minor` removal task.
- Verdicts: `keep` (ship as-is), `tweak` (adjust a lever, re-observe),
  `cut` (remove), `watch` (window still open), `audit` (needs code
  investigation before any verdict).

## Watchlist

| Item | Concern | Lever (specific buff/nerf knob) | Check after | Verdict |
|---|---|---|---|---|
| TheConsumerIsAlwaysRight | Sell-leak fixed: the multiplier now unregisters on sell, which was a stealth buff before. Post-fix power level unmeasured. | 1) Price $550 → $600. 2) Rate +0.25x → +0.2x per consumable. | 3 sessions | watch |
| ConsumableCollector | **Removed** this session (deduplicated into TheConsumerIsAlwaysRight). Watch for consumable-build weakness without it. | If consumable builds sag: buff Extreme Couponing per-grant value before re-adding anything. | 3 sessions | watch |
| Orange dice ($175, 1/150) | Infinite-rolls bug FIXED: rolls now apply to the next turn only (temporary, carry across rounds, wiped on Mall Zone change) instead of permanently stacking MAX_ROLLS. Keep watching the roll economy — a boosted turn can still compound with Extra Rolls / The Great Exchange / Three More Rolls. | 1) Price $175 → $200. 2) Chance denominator 150 → 175. 3) Roll cap per turn. | 3 sessions | watch |
| Defiance ($400 epic) | +0.25x per active debuff; rebellion/teacher_pet excluded. Could be trivially farmed in debuff-heavy channels where debuffs are always up. | 1) Per-debuff value 0.25x → 0.2x. 2) Rarity/price bump. 3) Cap stacked debuff count. | 3 sessions | watch |
| Cursed Six ($25 mod) | $5/roll upkeep vs sixes-archetype payoff (Gold Six nets +$1/roll on the cursed die). Economy may never break even outside Gold Six. | 1) Cost $5 → $4 per roll. 2) Sell lock (sells for $0) — reconsider if it feels punishing. | 3 sessions | watch |
| Scratch Ticket / Mulligan | Comeback-floor pair. Watch for feel-bad (rewarding failure) or mandatory-pick status (every run wants the insurance). | 1) Price ($50 / $25). 2) Scratch Ticket multiplier 2x → 1.5x. | 3 sessions | watch |
| Comeback Kid ($150 rare) | +5 per 0-category could reward sandbagging zeros early instead of playing to score. | 1) Per-zero value +5 → +3. 2) Cap (e.g. max 4 zero categories count). | 3 sessions | watch |
| Four-Kind Yahtzee / Two Pair House | Category-score-only by design (no Yahtzee/FH bonus chaining). Watch whether the 25pt bend is pick-on-sight vs fixed-face mods. | 1) Payout value 25 → 20. 2) Price ($450 / $300). | 3 sessions | watch |
| Upper Crust + Bonus Sprint | Upper-section archetype power level vs the established LowerTen line. 1.5x upper + double-count toward 63 may overtake lower builds. | 1) Upper Crust multiplier 1.5x → 1.25x. 2) Bonus Sprint price $65 → $85. | 3 sessions | watch |
| WildCardMod | Semantics fixed this session (substitutes exclude current face; `is_yahtzee` tightened). Post-fix strength unknown. | 1) Price $300 → $350 if it dominates fixed-face mods. | 3 sessions | watch |
| Extreme Couponing ($140 uncommon) | +5 additive per consumable *granted*; with the yellow engine (1/60 via Yellow Slime) grants can snowball. | 1) Per-grant value +5 → +3. 2) Rarity uncommon → rare. | 3 sessions | watch |
| OneShotDebuff | Snapshots/restores `MAX_ROLLS` absolutely; selling The Great Exchange mid-debuff corrupts the roll count. Known, deferred from the stacking fix. | Convert to delta-based add/remove instead of snapshot/restore. | Next debuff-system pass | tweak |
| MoneyWellSpent | Signal-driven now; `reset_to_starting_money()` emits a negative money change that counts as "spending". Known edge. | Re-read `Statistics.total_money_spent` on signal instead of accumulating deltas. | Next economy pass | tweak |
| Deprecated Challenge system + ChallengeEaserPowerUp | Challenge machinery is deprecated but still feeds `challenge_score_modifier`; Challenge Easer ($450 epic) modifies a dead system. | Audit all `challenge_score_modifier` readers; remove item + wiring if nothing live consumes it. | Before next content pass | audit → cut |
| Stale `Scenes/Managers/*_manager_full.tscn` | Duplicate full-manager scenes partially deleted; `mod_manager_full.tscn` remains. | Audit references; delete remaining stale scene if unreferenced. | Before next content pass | audit → cut |
| PRE-EXISTING: bonus-Yahtzee tests fail on HEAD | `Tests/YahtzeeScenarioTest.tscn` and `Tests/ComprehensiveYahtzeeBonusTest.tscn` fail on HEAD (bonus-Yahtzee logic). Unrelated to this session's work. | Investigate and fix before any scoring-content pass lands on top. | Before next content pass | audit |
| Icon collisions | `paint_job` shares a coupon atlas cell with `even_odd_full_house_upgrade`; `bonus_sprint` shares with `three_of_a_kind_upgrade`; `yellow_slime` / `extreme_couponing` icons are placeholders. | Art pass: assign unique cells / new icons (see `_pog_work/` and `_coupon_work/` pipelines). | Next art pass | tweak |
| BonusCollectorConsumable | Description fixed to $150 behavior this session — verify $150 is still the right amount for the current economy. | 1) Payout $150 → $100 if upper bonus is now easy via Upper Crust + Bonus Sprint. | 3 sessions | watch |
