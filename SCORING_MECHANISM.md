# SCORING MECHANISM - DiceRogue

## Overview
This document defines the authoritative scoring mechanism for DiceRogue, ensuring consistent behavior across all scoring paths (manual, auto, consumables, etc.).

## Core Scoring Flow

### 1. Trigger Phase
- **Manual Selection**: Player clicks a category in ScoreCardUI
- **Auto Selection**: Game automatically selects best category when turn ends
- **Consumable Trigger**: Consumables like "Score Reroll" or "Any Score" trigger scoring

### 2. Pre-Scoring Signal Phase
**Signal: `about_to_score(section, category, dice_values)`**
- Emitted BEFORE any score calculation begins
- Allows PowerUps to register multipliers with ScoreModifierManager
- Allows Debuffs to register penalties
- Must be emitted for ALL scoring paths

### 3. Base Score Calculation
```gdscript
base_score = ScoreEvaluator.calculate_score_for_category(category, dice_values)
```
- Uses ScoreEvaluator to determine raw score for category
- No modifiers applied yet
- Example: Small straight = 30 points

### 4. Additive Phase
```gdscript
total_additives = regular_additives + dice_color_additives
score_after_additives = base_score + total_additives
```
- **Regular Additives**: From PowerUps via ScoreModifierManager
- **Dice Color Additives**: Red dice add their face value
- Applied before multipliers

### 5. Multiplicative Phase
```gdscript
total_multiplier = regular_multipliers * dice_color_multipliers
final_score = ceil(score_after_additives * total_multiplier)
```
- **Regular Multipliers**: From PowerUps (PinHead, etc.) via ScoreModifierManager
- **Dice Color Multipliers**: Purple dice multiply
- **Division Mode**: If active, multipliers become dividers (1/multiplier)

### 6. Money Effects Phase
```gdscript
if apply_money_effects:
    PlayerEconomy.add_money(green_dice_bonus)
```
- **Green Dice**: Add money equal to face value
- Only applied during actual scoring, not previews

### 7. Score Assignment Phase
```gdscript
scorecard.set_score(section, category, final_score)
```
- Updates scorecard data structure with FINAL calculated score
- **NO further multiplication** - score is already fully calculated
- Triggers UI updates
- Emits `score_assigned` signal for statistics

### 8. Post-Scoring Cleanup
- PowerUps unregister temporary multipliers
- Debuffs clean up temporary effects
- UI updates to reflect new scores

## Scoring Paths

### Path 1: Manual Scoring (ScoreCardUI)
```
Player clicks category
└── ScoreCardUI.on_category_selected()
    ├── Emit about_to_score signal
    ├── Call scorecard.on_category_selected()
    └── scorecard follows standard flow
```

### Path 2: Auto Scoring (Scorecard)
```
Turn ends or auto-trigger
└── scorecard.auto_score_best()
    ├── Find best category
    ├── Emit about_to_score signal (through ScoreCardUI)
    ├── Defer to next frame: _complete_auto_scoring()
    └── Follow standard scoring flow
```

### Path 3: Consumable Scoring
```
Consumable triggers scoring
└── Various consumable methods
    ├── Emit about_to_score signal
    ├── Call appropriate scoring method
    └── Follow standard scoring flow
```

## Critical Rules

### 1. Signal Timing
- `about_to_score` MUST be emitted before any score calculation
- Must wait one frame after signal before calculating final score
- This allows PowerUps to register multipliers synchronously

### 2. Single Calculation Principle
- Base score calculated ONCE per scoring event
- Modifiers applied in order: additives → multipliers  
- No double multiplication
- **CRITICAL**: set_score() must NOT apply multipliers - they are already applied in calculate_score_internal()

### 3. Modifier Registration
- PowerUps register multipliers during `about_to_score` signal
- ScoreModifierManager handles all modifier math
- Multipliers auto-cleared after scoring

### 4. UI Update Timing
- ScoreCardUI updates immediately after score assignment
- TurnTracker shows current multipliers for debugging
- Statistics updated in post-scoring phase
- **CRITICAL**: Autoscoring must NOT emit hand_scored signal (would disable roll button)

## Expected Math Examples

### Example 1: Small Straight + PinHead PowerUp
```
Base Score: 30 (small straight)
Dice Values: [1,2,3,4,5]
PinHead picks: 3
Additives: 0
Multipliers: 3.0 (from PinHead)
Final Score: ceil(30 * 3.0) = 90
```

### Example 2: Chance + Dice Colors + PowerUp
```
Base Score: 25 (sum of dice)
Dice: [5(red), 4, 3, 6(purple), 2]
Red Additive: +5
Purple Multiplier: ×6
PowerUp Multiplier: ×2
Calculation: ceil((25 + 5) × 6 × 2) = ceil(360) = 360
```

### Example 3: With Division Debuff
```
Base Score: 30
PowerUp wants ×4 multiplier
Division mode active: 4 becomes ÷4 = ×0.25
Final Score: ceil(30 × 0.25) = 8
```

## Debugging Requirements

### TurnTracker Display
- Current base score
- Active additives (by source)
- Active multipliers (by source)
- Final calculated score

### Console Logging
- Each phase must log its calculations
- Show before/after values for each step
- Track multiplier registration/unregistration

### Validation Checks
- Verify signal emission before calculation
- Confirm single base score calculation per event
- Validate modifier cleanup after scoring

## Implementation Checklist

- [x] ScoreCardUI emits about_to_score for manual scoring
- [x] auto_score_best emits about_to_score with proper timing
- [ ] All consumables emit about_to_score before scoring
- [x] ScoreModifierManager properly tracks all modifiers
- [x] PinHeadPowerUp registers multipliers during about_to_score
- [x] Multipliers cleared after score_assigned
- [ ] TurnTracker shows current modifier state
- [x] UI updates immediately after score assignment
- [x] No double multiplication occurs
- [x] Base score calculated only once per event
- [x] Eliminated duplicate signal emissions
- [x] Reduced excessive debug logging
- [x] Fixed roll button disable after autoscoring