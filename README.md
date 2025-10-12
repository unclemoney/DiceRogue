# DiceRogue — Project Overview

A pixel-art, roguelite dice-roller (Yahtzee-inspired) built for Godot 4.4. This README summarizes the repository layout, key systems, known issues, refactor targets, feature ideas, and deprecated/redundant code to consider removing.

## Repo layout (important files & nodes)
- Scenes
  - [Scenes/ScoreCard/score_card.gd](Scenes/ScoreCard/score_card.gd) — score handling (`Scorecard`)
  - Scorecard scene(s) live under `Scenes/ScoreCard/`
- Core systems
  - [Scripts/Core/game_controller.gd](Scripts/Core/game_controller.gd) — central game flow (`GameController`)
  - [Scripts/Core/dice.gd](Scripts/Core/dice.gd) — die logic (`Dice`)
  - [Scripts/Core/dice_hand.gd](Scripts/Core/dice_hand.gd) — dice collection (`DiceHand`)
  - [Scripts/Core/turn_tracker.gd](Scripts/Core/turn_tracker.gd) — turn/roll tracking (`TurnTracker`)
  - [Scripts/Managers/MultiplierManager.gd](Scripts/Managers/MultiplierManager.gd) — score modifiers manager (referred to as `ScoreModifierManager` in code)
  - [Scripts/Managers/PlayerEconomy.gd](Scripts/Managers/PlayerEconomy.gd) — player money & events (`PlayerEconomy`)
  - [Scripts/Managers/ModManager.gd](Scripts/Managers/ModManager.gd) — mod definitions & spawn
  - [Scripts/Managers/ConsumableManager.gd](Scripts/Managers/ConsumableManager.gd) — consumable definitions & spawn
  - [Scripts/Managers/round_manager.gd](Scripts/Managers/round_manager.gd) — round/level flow (`RoundManager`)
- UI
  - [Scripts/UI/power_up_ui.gd](Scripts/UI/power_up_ui.gd) — power-up spine/fanned UI (`PowerUpUI`)
  - [Scripts/UI/consumable_ui.gd](Scripts/UI/consumable_ui.gd) — consumable spine/fanned UI (`ConsumableUI`)
  - [Scripts/UI/power_up_icon.gd](Scripts/UI/power_up_icon.gd) — card/fanned icon visuals
  - [Scripts/Consumable/consumable_icon.gd](Scripts/Consumable/consumable_icon.gd) — consumable card visuals
  - [Scripts/Mods/mod_icon.gd](Scripts/Mods/mod_icon.gd) — mod icon visuals (`ModIcon`)
  - [Scripts/UI/shop_ui.gd](Scripts/UI/shop_ui.gd) — in-game shop
- PowerUps (examples)
  - [Scripts/PowerUps/chance520_power_up.gd](Scripts/PowerUps/chance520_power_up.gd) — Chance ≥20 additive stacking
  - [Scripts/PowerUps/evens_no_odds_power_up.gd](Scripts/PowerUps/evens_no_odds_power_up.gd)
  - [Scripts/PowerUps/yahtzee_bonus_mult_power_up.gd](Scripts/PowerUps/yahtzee_bonus_mult_power_up.gd)
  - [Scripts/PowerUps/randomizer_power_up.gd](Scripts/PowerUps/randomizer_power_up.gd)
  - [Scripts/PowerUps/consumable_cash_power_up.gd](Scripts/PowerUps/consumable_cash_power_up.gd)
- Consumables (examples)
  - [Scripts/Consumable/score_reroll_consumable.gd](Scripts/Consumable/score_reroll_consumable.gd)
  - [Scripts/Consumable/double_existing_consumable.gd](Scripts/Consumable/double_existing_consumable.gd)
  - [Scripts/Consumable/three_more_rolls_consumable.gd](Scripts/Consumable/three_more_rolls_consumable.gd)
  - [Scripts/Consumable/quick_cash_consumable.gd](Scripts/Consumable/quick_cash_consumable.gd)
  - [Scripts/Consumable/add_max_power_up_consumable.gd](Scripts/Consumable/add_max_power_up_consumable.gd)
  - [Scripts/Consumable/power_up_shop_num_consumable.gd](Scripts/Consumable/power_up_shop_num_consumable.gd)
- Mods (examples)
  - [Scripts/Mods/wild_card_mod.gd](Scripts/Mods/wild_card_mod.gd)
  - [Scripts/Mods/gold_six_mod.gd](Scripts/Mods/gold_six_mod.gd)
- Tests
  - [Tests/multiplier_manager_test.gd](Tests/multiplier_manager_test.gd)
  - [Tests/power_up_test.gd](Tests/power_up_test.gd)
  - [Tests/dice_test.gd](Tests/dice_test.gd)
  - [Tests/game_buttons_test.gd](Tests/game_buttons_test.gd)

## High-level responsibilities
- `GameController` ([Scripts/Core/game_controller.gd](Scripts/Core/game_controller.gd)) coordinates granting/revoking power-ups/consumables, hooking UI, and round flow (`RoundManager`).
- `Scorecard` ([Scenes/ScoreCard/score_card.gd](Scenes/ScoreCard/score_card.gd)) handles raw scoring. Score modifiers are applied via the manager ([Scripts/Managers/MultiplierManager.gd](Scripts/Managers/MultiplierManager.gd)).
- `ScoreModifierManager` (file: [Scripts/Managers/MultiplierManager.gd](Scripts/Managers/MultiplierManager.gd)) centralizes additive and multiplier modifiers and emits change signals consumed by PowerUps (e.g., `Chance520PowerUp`, `EvensNoOddsPowerUp`, `YahtzeeBonusMultPowerUp`).
- UI spines/fanned system: `PowerUpUI` and `ConsumableUI` manage spine and fanned-card interaction patterns.

## Immediate issues spotted (from code excerpts)
- Naming inconsistency: the manager file is [Scripts/Managers/MultiplierManager.gd](Scripts/Managers/MultiplierManager.gd) but the project uses `ScoreModifierManager` in many places. Recommend unifying to a single filename/class: [`ScoreModifierManager`](Scripts/Managers/MultiplierManager.gd).
- Typo / syntax bug: [Scripts/Managers/PlayerEconomy.gd](Scripts/Managers/PlayerEconomy.gd) shows `var money: int = 500:` (trailing colon). Fix to `var money: int = 500`.
- Mutating constants: [Scripts/Core/turn_tracker.gd](Scripts/Core/turn_tracker.gd) `add_rolls()` mutates `MAX_ROLLS` (looks like a constant). Consider using a mutable property (e.g., `max_rolls`) or separate `rolls_left` logic.
- Duplicate "create card structure" code exists across many icon scripts: `ConsumableIcon`, `PowerUpIcon`, `ChallengeIcon`, `ConsumableSpine`, `PowerUpSpine`. These can be consolidated into shared helper or scene templates.
- Some files keep legacy methods / deprecation comments:
  - [`Scenes/ScoreCard/score_card.gd`](Scenes/ScoreCard/score_card.gd): `clear_score_multiplier()` marked DEPRECATED — remove or migrate callers.
  - Multiple files refer to old groups/names for backward compatibility (e.g., adding `multiplier_manager` group). Consolidate group naming.

## Deprecated / candidates for removal
- `Scorecard.clear_score_multiplier()` — marked DEPRECATED. Replace callers with [`ScoreModifierManager.unregister_multiplier`](Scripts/Managers/MultiplierManager.gd).
- `_score_multiplier_func` and `score_multiplier` in [Scenes/ScoreCard/score_card.gd](Scenes/ScoreCard/score_card.gd) — legacy approach superseded by the manager.
- Any "get_consumable_icon" wrappers that only exist for backward compatibility; prefer `get_consumable_spine()` / `get_fanned_icon()` in [Scripts/UI/consumable_ui.gd](Scripts/UI/consumable_ui.gd).
- Redundant score modifier registration in power-ups that both manage internal state and call the global manager in overlapping ways — consolidate to single source-of-truth behavior per power-up.

## Areas to refactor
- Unify the score modifier manager naming & API:
  - File: [Scripts/Managers/MultiplierManager.gd](Scripts/Managers/MultiplierManager.gd) → consider renaming to `ScoreModifierManager.gd` and expose class_name `ScoreModifierManager`.
  - Ensure all power-ups call `ScoreModifierManager.register_additive` / `unregister_additive` consistently (see `Chance520PowerUp`, `EvensNoOddsPowerUp`, `YahtzeeBonusMultPowerUp`).
- Extract UI card construction:
  - Move repeated UI creation into shared scenes or factories used by `ConsumableIcon`, `PowerUpIcon`, `ChallengeIcon`, etc.
- Spine/fanned UI duplication:
  - `PowerUpUI` and `ConsumableUI` share a spine/fan system. Consider abstracting common spine/fan controller.
- Signal connect/disconnect patterns:
  - Many power-ups call `is_connected` before `connect` and perform cleanup on `tree_exiting`. Make a small helper mixin or base class `PowerUp` utilities to centralize connect/disconnect lifecycle.
- Improve autoloads vs class_name usage:
  - Per project instruction: autoload scripts should not have `class_name`. Review autoloaded singletons and remove `class_name` where appropriate.
- Tests: expand unit tests for modifier manager, score application order (additive → multiplier), and consumable usability logic.

## Suggested TODO (short-term → long-term)
- Short-term
  - ✅ **COMPLETED** - Fix `PlayerEconomy` colon typo (was already correct)
  - ✅ **NO ACTION NEEDED** - Unify `ScoreModifierManager` naming: Current design is optimal
  - ✅ **COMPLETED** - Remove class_name from autoloaded scripts: Fixed DiceResults and ScoreEvaluator  
  - ✅ **BASE CLASS CREATED** - Consolidate UI card construction: [Scripts/UI/card_icon_base.gd](Scripts/UI/card_icon_base.gd) available for new cards
  - Add activation code registration for any new power-ups to [`GameController`](Scripts/Core/game_controller.gd) (see copilot instructions)
- Mid-term
  - Extract spine/fan logic into a shared controller used by `PowerUpUI` and `ConsumableUI` (identified as complex refactor)
  - Add unit tests: ensure additive bonuses apply before multipliers (see [Scenes/ScoreCard/score_card.gd](Scenes/ScoreCard/score_card.gd) score logic)
  - Harden signal lifecycle: create base PowerUp that connects/disconnects safely (identified as complex refactor)
  - Fix `turn_tracker.add_rolls()` implementation (`MAX_ROLLS` mutation)
- Long-term / polish
  - Implement mod sell UI and persistence mechanics
  - Implement mod rarity/weight balancing in `ModManager` and shop (`ShopUI`)
  - Build analytics-friendly debug logging toggles

## Recent Refactor Activity (October 2025)
**Comprehensive refactor assessment completed** - See [REFACTOR_TODO.md](REFACTOR_TODO.md) for detailed analysis.

**Key Findings:**
- Most suggested refactors were already well-implemented or not needed
- Fixed autoload class_name violations in DiceResults and ScoreEvaluator  
- Created CardIconBase class for future use (existing icons work well, migration optional)
- Identified complex UI duplication that requires careful approach

**Outcome:** Codebase is in excellent shape with minimal violations found and fixed.

## Game design ideas / feature wishlist
- Selling mods:
  - Allow players to sell mods for partial refund. Add `sell_mod(mod_id)` plumbing in `GameController` and UI through `ShopUI`.
- Additional mods
  - Persistent passive mods applied to dice at spawn (e.g., `ExplosiveSixMod`, `LockedHighMod`, `LuckyEvenMod`).
  - One-shot mods (consumable-like) that can be applied to a single die and then removed.
- New power-ups
  - Score category-specific modifiers (e.g., double `large_straight`): implement via `ScoreModifierManager.register_multiplier("id", factor)` and add UI descriptions.
  - Round-based passives (e.g., +X chance to reroll a die per turn)
- Consumable ideas
  - "Sell a mod" coupon: consumes to remove a mod and grant coins
  - "Force reroll all dice once" (affects `DiceHand`)
  - "Instant shop refresh" consumable for better shop RNG
- UI/UX
  - Visual indicator on `Scorecard` showing active additives (from `ScoreModifierManager`) and total multiplier
  - Contextual tooltips from `PowerUpUI` and `ConsumableUI` showing applied totals
- Challenges & progression
  - Unlock power-ups/consumables through challenge completion (`ChallengeManager` / `RoundManager` integration)
  - Balance reward economy (see `PlayerEconomy` usages)

## Important behavioral notes / recommendations
- Score calculation order is additive → multiplier. Confirm via tests: see `Tests/multiplier_manager_test.gd` and score application in [Scenes/ScoreCard/score_card.gd](Scenes/ScoreCard/score_card.gd).
- Consumable UI now returns `ConsumableSpine` on add (`GameController._grant_consumable`), and usability is applied only when cards are fanned via `ConsumableUI.update_consumable_usability()`; follow that flow when adding new consumables.
- When adding new features that affect scoring, update `GameController` activation points (see copilot instructions) and hook into `ScoreModifierManager` signals.

## Deprecated / redundant code to audit
- [`Scenes/ScoreCard/score_card.gd` → clear_score_multiplier(), _score_multiplier_func, score_multiplier] — legacy, remove after migration
  - File: [Scenes/ScoreCard/score_card.gd](Scenes/ScoreCard/score_card.gd)
- Old UI-helper wrappers:
  - `get_consumable_icon` in [Scripts/UI/consumable_ui.gd](Scripts/UI/consumable_ui.gd) — logs DEPRECATED, prefer spines/fanned icons
- Any ad-hoc additive/multiplier bookkeeping inside power-ups that both update their own state and call manager in inconsistent ways (examples: [Scripts/PowerUps/chance520_power_up.gd](Scripts/PowerUps/chance520_power_up.gd), [Scripts/PowerUps/evens_no_odds_power_up.gd](Scripts/PowerUps/evens_no_odds_power_up.gd), [Scripts/PowerUps/yahtzee_bonus_mult_power_up.gd](Scripts/PowerUps/yahtzee_bonus_mult_power_up.gd)). Standardize responsibility: power-up computes its contribution and registers it with the manager; the manager owns totals.
- Duplicate "create_card_structure()" implementations in:
  - [Scripts/Consumable/consumable_icon.gd](Scripts/Consumable/consumable_icon.gd)
  - [Scripts/UI/power_up_icon.gd](Scripts/UI/power_up_icon.gd)
  - [Scripts/Challenge/challenge_icon.gd](Scripts/Challenge/challenge_icon.gd)

## Tests & validation
- Existing tests:
  - [Tests/multiplier_manager_test.gd](Tests/multiplier_manager_test.gd) — validates modifier manager basics
  - Add tests covering:
    - Score ordering (additive then multiplier)
    - Consumable usability rules via `ConsumableUI.update_consumable_usability()` ([Scripts/UI/consumable_ui.gd](Scripts/UI/consumable_ui.gd))
    - Mod persistence across rounds (`GameController` mod persistence logic)

## Quick fixes to prioritize
1. Fix `PlayerEconomy` colon typo: [Scripts/Managers/PlayerEconomy.gd](Scripts/Managers/PlayerEconomy.gd)
2. Unify `ScoreModifierManager` naming: [Scripts/Managers/MultiplierManager.gd](Scripts/Managers/MultiplierManager.gd) and everywhere it's referenced.
3. Remove or migrate DEPRECATED API usage in [Scenes/ScoreCard/score_card.gd](Scenes/ScoreCard/score_card.gd).
4. Consolidate repeated UI construction code into reusable scenes/helpers.

