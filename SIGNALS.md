# SIGNALS.md - DiceRogue Signal Documentation

## Overview
This document lists all signals in the DiceRogue codebase and explains their purpose, usage, and data flow.

## Core Game Signals

### Scorecard Signals (`Scenes/ScoreCard/score_card.gd`)
- `signal upper_bonus_achieved(bonus: int)` - Emitted when upper section bonus is earned (63+ points)
- `signal upper_section_completed` - Emitted when all upper section categories are filled
- `signal lower_section_completed` - Emitted when all lower section categories are filled
- `signal score_auto_assigned(section: Section, category: String, score: int)` - Emitted specifically when autoscoring assigns a score
- `signal score_assigned(section: Section, category: String, score: int)` - Emitted for ALL score assignments (manual + auto)
- `signal yahtzee_bonus_achieved(points: int)` - Emitted when bonus Yahtzee is scored (100 points)
- `signal score_changed(total_score: int)` - Emitted whenever total score changes
- `signal game_completed(final_score: int)` - Emitted when game ends (UNUSED)

### ScoreCardUI Signals (`Scripts/UI/score_card_ui.gd`)
- `signal hand_scored` - Emitted when player manually scores a hand
- `signal score_rerolled(section: Scorecard.Section, category: String, score: int)` - Used by Score Reroll consumable
- `signal score_doubled(section: Scorecard.Section, category: String, new_score: int)` - Used by Double Existing consumable
- `signal about_to_score(section: Scorecard.Section, category: String, dice_values: Array[int])` - **CRITICAL**: Allows PowerUps to register modifiers before scoring

### Game Controller Signals (`Scripts/Core/game_controller.gd`)
- `signal power_up_granted(id: String, power_up: PowerUp)` - Emitted when PowerUp is given to player
- `signal power_up_revoked(id: String)` - Emitted when PowerUp is removed from player
- `signal consumable_used(id: String, consumable: Consumable)` - Emitted when Consumable is activated

## UI Component Signals

### GameButtonUI Signals (`Scripts/UI/game_button_ui.gd`)
- `signal shop_button_pressed` - Opens/closes shop
- `signal next_round_pressed` - Advances to next round
- `signal dice_rolled(dice_values: Array)` - Emitted after dice roll completes

### PowerUpUI Signals (`Scripts/UI/power_up_ui.gd`)
- `signal power_up_selected(power_up_id: String)` - PowerUp clicked for activation
- `signal power_up_deselected(power_up_id: String)` - PowerUp deactivated
- `signal power_up_sold(power_up_id: String)` - PowerUp sold back
- `signal max_power_ups_reached` - Player hit PowerUp limit

### ConsumableUI Signals (`Scripts/UI/consumable_ui.gd`)
- `signal consumable_used(consumable_id: String)` - Consumable activated
- `signal consumable_sold(consumable_id: String)` - Consumable sold back
- `signal max_consumables_reached` - Player hit Consumable limit

### ShopUI Signals (`Scripts/UI/shop_ui.gd`)
- `signal item_purchased(item_id: String, item_type: String)` - Item bought from shop
- `signal shop_button_opened` - Shop UI opened

### Individual Item Signals
- `signal spine_clicked(item_id: String)` - Spine-based UI item clicked
- `signal spine_hovered(item_id: String, mouse_pos: Vector2)` - Spine item hovered
- `signal spine_unhovered(item_id: String)` - Spine item unhovered

## Manager Signals

### ScoreModifierManager Signals (`Scripts/Managers/MultiplierManager.gd`)
- `signal multiplier_changed(total_multiplier: float)` - Total multiplier value changed
- `signal multiplier_registered(source_name: String, multiplier: float)` - New multiplier added
- `signal multiplier_unregistered(source_name: String)` - Multiplier removed
- `signal additive_changed(total_additive: int)` - Total additive value changed
- `signal additive_registered(source_name: String, additive: int)` - New additive added
- `signal additive_unregistered(source_name: String)` - Additive removed

### Statistics Manager Signals (`Scripts/Managers/statistics_manager.gd`)
- `signal milestone_reached(milestone_name: String, value: int)` - Player reached achievement
- `signal new_record_set(statistic_name: String, new_value)` - New personal best
- `signal logbook_entry_added(entry: LogEntry)` - New logbook entry created

### Round Manager Signals (`Scripts/Managers/round_manager.gd`)
- `signal round_started(round_number: int)` - New round begins
- `signal round_completed(round_number: int)` - Round completed successfully
- `signal all_rounds_completed` - All rounds finished
- `signal round_failed(round_number: int)` - Round failed

### Challenge Manager Signals (`Scripts/Managers/ChallengeManager.gd`)
- `signal definitions_loaded` - Challenge definitions loaded from files
- `signal challenge_activated(id: String)` - Challenge started
- `signal challenge_completed(id: String)` - Challenge completed successfully
- `signal challenge_failed(id: String)` - Challenge failed

### Manager Loading Signals
- `signal definitions_loaded` - Used by PowerUpManager, ConsumableManager, ModManager when definitions load

### Player Economy Signals (`Scripts/Managers/PlayerEconomy.gd`)
- `signal money_changed(new_amount: int)` - Player money amount changed

### Dice Color Manager Signals (`Scripts/Managers/dice_color_manager.gd`)
- `signal colors_enabled_changed(enabled: bool)` - Dice color system toggled
- `signal color_effects_calculated(green_money: int, red_additive: int, purple_multiplier: float, same_color_bonus: bool)` - Color effects calculated

## PowerUp Signals

### Common PowerUp Signals
- `signal description_updated(power_up_id: String, new_description: String)` - PowerUp description changed (used by most PowerUps)
- `signal max_rolls_changed(new_max: int)` - PowerUp changes max rolls per turn

### Special PowerUp Signals
- `signal effect_updated(effect_type: String, value_text: String)` - Used by RandomizerPowerUp for effect display

## Consumable Signals

### Score Reroll Consumable (`Scripts/Consumable/score_reroll_consumable.gd`)
- `signal reroll_activated` - Reroll mode started
- `signal reroll_completed` - Reroll finished successfully
- `signal reroll_denied` - Reroll denied (no valid targets)

### Double Existing Consumable (`Scripts/Consumable/double_existing_consumable.gd`)
- `signal double_activated` - Double mode started
- `signal double_completed` - Double applied successfully
- `signal double_denied` - Double denied (no valid targets)

### Three More Rolls Consumable (`Scripts/Consumable/three_more_rolls_consumable.gd`)
- `signal rolls_increased(additional_rolls: int)` - Added rolls to turn

### Power Up Shop Num Consumable (`Scripts/Consumable/power_up_shop_num_consumable.gd`)
- `signal shop_size_increased(additional_items: int)` - Shop inventory expanded

### Poor House Consumable (`Scripts/Consumable/poor_house_consumable.gd`)
- `signal money_transferred_to_score(amount: int)` - Money converted to score

## Core System Signals

### Turn Tracker Signals (`Scripts/Core/turn_tracker.gd`)
- `signal turn_updated(turn: int)` - Turn number changed
- `signal rolls_updated(rolls_left: int)` - Rolls remaining changed
- `signal rolls_exhausted` - No rolls left in turn
- `signal turn_started` - New turn began
- `signal game_over` - Game ended
- `signal max_rolls_changed(new_max: int)` - Max rolls per turn changed

### Roll Stats Signals (`Scripts/Core/roll_stats.gd`)
- `signal stats_updated` - Statistics recalculated
- `signal yahtzee_rolled` - Yahtzee achieved
- `signal combination_achieved(combination_type: String)` - Specific combo achieved
- `signal bonus_achieved(bonus_type: String)` - Bonus earned

### Effects Signals
- `signal shake_finished` - Screen shake animation completed
- `signal crt_enabled` / `signal crt_disabled` - CRT effect toggled

### Mod Signals (`Scripts/Mods/Mod.gd`)
- `signal mod_applied` - Mod effect activated
- `signal mod_removed` - Mod effect deactivated

### Debug Signals (`Scripts/UI/debug_panel.gd`)
- `signal debug_command_executed(command: String, result: String)` - Debug command completed

## Signal Flow Analysis

### Critical Scoring Flow
1. **Manual Scoring**: `about_to_score` → PowerUps register modifiers → `score_assigned` → `score_changed`
2. **Auto Scoring**: `about_to_score` → PowerUps register modifiers → `score_auto_assigned` → `score_changed`

### **IDENTIFIED ISSUE**: 
The `_complete_auto_scoring()` method is called deferred, which means it can execute AFTER new dice are rolled, causing it to use wrong dice state for color effects calculation. This leads to incorrect scoring.

## Common Signal Patterns

### PowerUp Lifecycle
1. `power_up_granted` → PowerUp connects to `about_to_score`
2. `about_to_score` → PowerUp registers modifiers
3. `score_assigned` → PowerUp updates description/stats
4. `power_up_revoked` → PowerUp disconnects signals

### Consumable Lifecycle
1. `consumable_used` → Consumable activates effect
2. Effect-specific signals (`reroll_activated`, etc.)
3. Completion signals (`reroll_completed`, etc.)

### Manager Initialization
1. `definitions_loaded` → Manager ready for use
2. UI systems connect to manager signals
3. Game systems request data from managers