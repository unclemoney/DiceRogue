# Dice Color System Implementation Guide

## Overview
The Dice Color System adds strategic depth to DiceRogue by giving dice special properties based on their color. Each colored die provides unique effects that can dramatically alter scoring and strategy.

## Color Types and Effects

### None (Default)
- **Color**: White/Default
- **Effect**: No special properties
- **Probability**: Base probability after all colored dice are assigned

### Green Dice
- **Color**: Green
- **Effect**: Provides money bonus equal to the die value
- **Example**: Green die showing 4 = +$4 money bonus
- **Probability**: Standard colored die probability

### Red Dice  
- **Color**: Red
- **Effect**: Adds die value to the score (additive bonus)
- **Example**: Base score 20 + Red die showing 3 = 23 total score
- **Probability**: Standard colored die probability

### Purple Dice
- **Color**: Purple  
- **Effect**: Multiplies score by die value (multiplicative bonus)
- **Example**: Base score 20 × Purple die showing 2 = 40 total score
- **Probability**: Standard colored die probability

### Blue Dice (NEW)
- **Color**: Blue
- **Effect**: **Conditional multiplier/divisor based on usage**
  - **If the blue die is USED in scoring**: Multiply final score by die value
  - **If the blue die is NOT USED in scoring**: Divide final score by die value (rounded down)
- **Probability**: 1:100 (very rare)

#### Blue Dice Examples

**Example 1 - Blue Die NOT Used (Penalty)**
- Roll: 4, 4, 4, 4, 5 (where 5 is Blue)
- Score in: Fours category (upper section)
- Scoring dice: 4, 4, 4, 4 (total = 16 points)
- Blue die effect: 5 is NOT used → 16 ÷ 5 = 3 points (rounded down)

**Example 2 - Blue Die Used (Bonus)**
- Roll: 1, 2, 3, 4, 5 (where 3 is Blue)
- Score in: Large Straight (40 points)
- Scoring dice: All dice used for straight
- Blue die effect: 3 IS used → 40 × 3 = 120 points

## Same Color Bonus
When 5 or more dice of the same color are rolled:
- Green: Money bonus doubled
- Red: Additive bonus doubled  
- Purple: Multiplier bonus doubled
- Blue: Effect doubled (2× multiplier when used, 2× divisor when not used)

## Implementation Architecture

### Core Classes

#### DiceColor (Scripts/Core/dice_color.gd)
```gdscript
enum Type {
    NONE,
    GREEN,    # Money bonus
    RED,      # Additive bonus
    PURPLE,   # Multiplicative bonus
    BLUE      # Conditional multiplier/divisor
}
```

#### Dice Class
- Each die has a `color` property of type `DiceColor.Type`
- Color assignment happens during roll with appropriate probabilities
- Blue dice have 1:100 probability vs other colors

#### DiceColorManager (Scripts/Managers/dice_color_manager.gd)
- Calculates all color effects from dice arrays
- Handles Blue dice conditional logic
- Integrates with scoring system
- Emits signals for UI updates

### Scoring Integration

The scoring flow for Blue dice:
1. Determine which dice are used in the selected scoring category
2. Check if any Blue dice are in the "used" set
3. Apply Blue dice effects:
   - Used Blue dice: Multiply final score by die value
   - Unused Blue dice: Divide final score by die value
4. Handle same color bonus if applicable

### Statistical Tracking

#### StatisticsManager Updates
- Track Blue dice in `dice_rolled_by_color["blue"]`
- Track Blue dice scoring in `dice_scored_by_color["blue"]`
- Separate tracking for Blue dice penalties vs bonuses

#### StatisticsPanel Display
- Blue dice roll count
- Blue dice bonus applications (when used)
- Blue dice penalty applications (when not used)
- Average Blue dice impact on scoring

## Probability System

### Base Probabilities
- Green: Standard rate
- Red: Standard rate  
- Purple: Standard rate
- Blue: 1:100 (1% chance)
- None: Remaining probability

### Color Assignment Process
1. Roll base die value (1-6)
2. Generate random number for color assignment
3. Check Blue dice probability first (1:100)
4. If not Blue, assign other colors based on standard rates
5. Remaining dice get NONE color

## Debug Features

### Debug Panel Integration
- **Force Blue Dice**: Button to make all dice Blue for testing
- **Test Blue Scenarios**: Pre-configured test cases
- **Blue Dice Logger**: Track Blue dice effects in console

### Test Scenarios
1. **Penalty Test**: Blue die not used in scoring
2. **Bonus Test**: Blue die used in scoring  
3. **Same Color Bonus**: 5+ Blue dice effects
4. **Mixed Effects**: Multiple Blue dice, some used, some not

## UI Integration

### Visual Indicators
- Blue dice display with distinct blue coloring
- Score calculation tooltips showing Blue dice effects
- Statistics panel showing Blue dice impact

### Score Display
- Show base score calculation
- Display Blue dice modifications
- Final score with all effects applied

## Testing Strategy

### Unit Tests
- Blue dice probability validation
- Conditional logic verification (used vs not used)
- Same color bonus calculations
- Edge cases (all Blue dice, no Blue dice)

### Integration Tests  
- Full scoring flow with Blue dice
- Statistics tracking accuracy
- UI display correctness

### Manual Test Scenarios
Create test scenes for:
1. Single Blue die penalty scenario
2. Single Blue die bonus scenario
3. Multiple Blue dice mixed scenarios
4. Same color bonus with Blue dice

## Performance Considerations

### Optimization Notes
- Color effects calculated once per scoring action
- Blue dice usage determination cached during scoring
- Minimal impact on existing color system performance

### Memory Usage
- Additional enum value (negligible)
- Extended statistics tracking (minimal)
- No significant memory overhead

## Future Extensions

### Potential Enhancements
- Blue dice rarity modifiers (PowerUps that affect Blue dice probability)
- Blue dice interaction with other game systems
- Advanced Blue dice effects (different conditions)

### Balancing Considerations
- Monitor Blue dice impact on game economy
- Adjust probability if effects too powerful/weak
- Consider caps on Blue dice effects for extreme cases

## Migration Notes

### Existing Save Compatibility
- New Blue dice enum value backwards compatible
- Existing statistics remain valid
- Default handling for unknown color types

### Configuration Options
- Ability to disable Blue dice system
- Adjustable Blue dice probability
- Debug modes for testing different scenarios

## Yellow Dice

### Overview
- **Color**: Yellow
- **Effect**: **Grants a random consumable when the yellow die is scored (used in a scoring category)**
  - Only triggers if there is available consumable slot space
  - If slots are full, no consumable is granted (no error)
- **Probability**: 1:60 (moderate rarity, between Red 1:50 and Purple 1:88)
- **Base Cost**: $85 (exponential scaling with purchases)

### Yellow Dice Examples

**Example 1 - Yellow Die Used (Consumable Granted)**
- Roll: 3, 3, 3, 2, 5 (where 5 is Yellow)
- Score in: Three of a Kind (all dice used)
- Yellow die is USED → Random consumable granted to player
- If consumable slots are full → Nothing happens

**Example 2 - Yellow Die NOT Used (No Effect)**
- Roll: 4, 4, 4, 4, 2 (where 2 is Yellow)
- Score in: Fours category (upper section, only 4s count)
- Yellow die is NOT used → No consumable granted

### Same Color Bonus (5+ Yellow Dice)
- When 5+ Yellow dice are present and scored: 2 consumables are granted instead of 1

## Rainbow Bonus System

### Overview
When all 5 different dice colors are present in a single roll (Green, Red, Purple, Blue, Yellow):
- **All color effects are boosted by 50%**
  - Green money: ×1.5
  - Red additive: ×1.5
  - Purple multiplier: ×1.5
  - Blue score multiplier: ×1.5
  - Yellow: Grants an additional consumable (+1 on top of normal grant)

### Rainbow Bonus Example
- Roll: 3(Green), 4(Red), 2(Purple), 5(Blue), 6(Yellow)
- Green money: $3 → $4 (×1.5 rounded)
- Red additive: +4 → +6 (×1.5 rounded)
- Purple multiplier: ×2 → ×3.0 (×1.5)
- Blue multiplier: ×5 → ×7.5 (×1.5)
- Yellow: Grants 2 consumables (1 base + 1 rainbow bonus)

## Max Odds System

### Overview
- Dice colors can be purchased multiple times, each purchase halving the probability denominator
- **Maximum odds are now 1:2 (50% chance)**, changed from the previous 1:1 (guaranteed)
- This preserves some randomness even at max investment
- Once at max odds, no further purchases are allowed for that color

### Odds Progression Example (Green Dice)
| Purchases | Odds | Cost |
|---|---|---|
| 0 | N/A (not purchased) | $50 |
| 1 | 1:25 | $100 |
| 2 | 1:13 | $200 |
| 3 | 1:7 | $400 |
| 4 | 1:4 | $800 |
| 5 | 1:2 (MAX) | Cannot purchase |

## Same Color Bonus
When 5 or more dice of the same color are rolled:
- Green: Money bonus doubled
- Red: Additive bonus doubled  
- Purple: Multiplier bonus doubled
- Blue: Effect doubled (2× multiplier when used, 2× divisor when not used)
- Yellow: Grants 2 consumables instead of 1 when scored

## Implementation Architecture

### Core Classes

#### DiceColor (Scripts/Core/dice_color.gd)
```gdscript
enum Type {
    NONE,
    GREEN,    # Money bonus
    RED,      # Additive bonus
    PURPLE,   # Multiplicative bonus
    BLUE,     # Conditional multiplier/divisor
    YELLOW    # Consumable grant on score
}
```

#### DiceColorManager (Scripts/Managers/dice_color_manager.gd)
- Calculates all color effects from dice arrays
- Handles Yellow dice consumable granting logic
- Handles Blue dice conditional logic
- Detects rainbow bonus (all 5 colors present)
- Integrates with scoring system
- Emits signals for UI updates

#### Yellow Dice Consumable Flow
1. `calculate_color_effects()` detects yellow dice and checks if they are "used" in scoring
2. The `apply_side_effects` parameter controls whether consumables are actually granted (default: false)
3. When `apply_side_effects=true` and yellow is used, `_grant_yellow_dice_consumable()` is called
4. The method checks for available consumable space via CorkboardUI/ConsumableUI
5. If space is available, a random consumable is picked and granted via GameController

**Important:** The `apply_side_effects` parameter prevents duplicate consumable grants during score preview/breakdown calculations. Only the final scoring operation should pass `apply_side_effects=true`.

## Debug Panel Features

### Dice Color Debug Commands
- **Force All [Color]**: Sets all dice to a specific color
- **Force One [Color]**: Sets one uncolored dice to a specific color
- **Force Rainbow Set**: Sets dice 0-4 to Green, Red, Purple, Blue, Yellow
- **Toggle Dice Colors**: Enable/disable the color system
- **Show Color Effects**: Display full color effect breakdown
- **Test Color Scoring**: Run color scoring pipeline test

## References
- See DICE_COLOR_IMPLEMENTATION.md for original color system details
- See STATISTICS.md for tracking system architecture
- See SIGNALS.md for color system signal documentation