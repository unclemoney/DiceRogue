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

## Code Examples

### Basic Blue Dice Usage Check
```gdscript
func is_blue_die_used_in_scoring(blue_die: Dice, used_dice: Array) -> bool:
    return blue_die in used_dice
```

### Blue Dice Effect Calculation
```gdscript
func apply_blue_dice_effects(base_score: int, blue_dice: Array, used_dice: Array) -> int:
    var final_score = base_score
    for blue_die in blue_dice:
        if blue_die in used_dice:
            # Used: multiply
            final_score *= blue_die.value
        else:
            # Not used: divide (rounded down)
            final_score = int(final_score / blue_die.value)
    return final_score
```

## References
- See DICE_COLOR_IMPLEMENTATION.md for original color system details
- See STATISTICS.md for tracking system architecture
- See SIGNALS.md for color system signal documentation