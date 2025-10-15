# Dice Color System Implementation

## Overview
This document details the implementation of the Dice Color System for DiceRogue, which adds strategic depth through randomly colored dice that provide different bonuses during scoring.

## Feature Summary
- **Green Dice**: Award money bonuses equal to dice value when scored
- **Red Dice**: Add bonus points equal to dice value to final score  
- **Purple Dice**: Multiply final score by dice value
- **5+ Same Color Bonus**: Doubles all bonuses when 5 or more dice of same color are scored
- **Toggle System**: Colors can be enabled/disabled globally
- **Visual Effects**: Shader-based color radiating from dice edges

## New Files Created

### Core System Files
1. **`Scripts/Core/dice_color.gd`** - DiceColor enum and utility functions
   - Defines color types: NONE, GREEN, RED, PURPLE
   - Color chance constants (1:10, 1:15, 1:50)
   - Helper functions for names, chances, validation

2. **`Scripts/Managers/dice_color_manager.gd`** - Autoload manager
   - Global color enable/disable functionality
   - Color effect calculations for scoring
   - Integration with scoring system
   - Debug support functions

### Test Files
3. **`Tests/dice_color_test.gd`** - Comprehensive test script
   - Color assignment testing
   - Effect calculation verification
   - Same color bonus testing
   - Toggle system testing
   - Scoring integration testing

4. **`Tests/DiceColorTest.tscn`** - Test scene file
   - Interactive UI for testing
   - Button-driven test execution
   - Results display area

## Modified Files

### Core Game Components

#### `Scripts/Core/dice.gd`
**Changes Made:**
- Added `color` property of type `DiceColor.Type`
- Added `color_changed` signal
- Added color assignment in `roll()` function
- Added `_assign_random_color()` method
- Added `_set_color()` and `_update_color_shader()` methods
- Added `get_color()`, `force_color()`, `clear_color()` methods
- Added shader parameter updates for color effects

**New Methods:**
```gdscript
func _assign_random_color() -> void
func _set_color(new_color: DiceColor.Type) -> void
func _update_color_shader() -> void
func get_color() -> DiceColor.Type
func force_color(new_color: DiceColor.Type) -> void
func clear_color() -> void
```

#### `Scripts/Core/dice_hand.gd`
**Changes Made:**
- Added color tracking and analysis methods
- Added integration with DiceColorManager
- Added debug support for color manipulation

**New Methods:**
```gdscript
func get_dice_by_color(color_type: DiceColor.Type) -> Array[Dice]
func get_color_counts() -> Dictionary
func has_same_color_bonus() -> bool
func get_color_effects() -> Dictionary
func debug_force_all_colors(color_type: DiceColor.Type) -> void
func debug_clear_all_colors() -> void
```

#### `Scenes/ScoreCard/score_card.gd`
**Changes Made:**
- Modified `calculate_score()` to integrate dice color effects
- Added color effect calculation and application
- Added money bonus distribution to PlayerEconomy
- Enhanced logging for color effects

**Modified Method:**
```gdscript
func calculate_score(category: String, dice_values: Array) -> int:
    # Now includes:
    # - Dice color effect calculation
    # - Red dice additive bonuses
    # - Purple dice multiplier bonuses  
    # - Green dice money distribution
    # - Enhanced calculation order
```

### Visual Effects

#### `Scripts/Shaders/dice_combined_effects.gdshader`
**Changes Made:**
- Added color strength uniforms:
  - `uniform float green_color_strength = 0.0`
  - `uniform float red_color_strength = 0.0`
  - `uniform float purple_color_strength = 0.0`
- Added edge-radiating color effects in fragment shader
- Added pulsing animation for each color type
- Maintained compatibility with existing glow and lock effects

### Debug System

#### `Scripts/UI/debug_panel.gd`
**Changes Made:**
- Added 6 new debug commands for dice colors:
  - "Toggle Dice Colors"
  - "Force All Green"
  - "Force All Red" 
  - "Force All Purple"
  - "Clear All Colors"
  - "Show Color Effects"

**New Methods:**
```gdscript
func _debug_toggle_dice_colors() -> void
func _debug_force_all_green() -> void
func _debug_force_all_red() -> void
func _debug_force_all_purple() -> void
func _debug_clear_all_colors() -> void
func _debug_show_color_effects() -> void
func _get_dice_hand()
```

### Project Configuration

#### `project.godot`
**Changes Made:**
- Added DiceColorManager to autoloads section:
  ```
  DiceColorManager="*res://Scripts/Managers/dice_color_manager.gd"
  ```

## Implementation Details

### Color Assignment Logic
When a die is rolled:
1. Check if color system is enabled via DiceColorManager
2. If disabled, set color to NONE
3. If enabled, iterate through color types (GREEN, RED, PURPLE)
4. For each color, check random chance (1 in X)
5. First color that hits wins (GREEN has priority, then RED, then PURPLE)
6. Update shader parameters based on assigned color

### Scoring Integration
When a category is scored:
1. Get base score from ScoreEvaluator
2. Calculate dice color effects via DiceColorManager
3. Extract color bonuses:
   - Green money: Sum of green dice values
   - Red additive: Sum of red dice values  
   - Purple multiplier: Product of purple dice values
4. Apply 5+ same color bonus (doubles all bonuses of that color)
5. Calculate final score: `(base + regular_additive + red_additive) * (regular_multiplier * purple_multiplier)`
6. Award green money to PlayerEconomy

### Visual Effects
Each colored die shows:
- Edge-radiating color effect (green/red/purple)
- Pulsing animation with different frequencies per color
- Maintains compatibility with existing hover, lock, and disabled effects
- Shader parameters: `*_color_strength` controls intensity (0.0 to 1.0)

### Same Color Bonus Rules
- Triggered when 5 or more dice of the same color are scored
- Applies 2x multiplier to ALL bonuses of that color type
- Examples:
  - 5 green dice (values 2,3,4,5,6): Money = (2+3+4+5+6) × 2 = $40
  - 5 red dice (values 1,1,1,1,1): Additive = (1+1+1+1+1) × 2 = +10
  - 5 purple dice (values 2,2,2,2,2): Multiplier = (2×2×2×2×2) × 2 = ×64

## Editor Setup Instructions

### Scene Configuration
1. **DiceHand Scene**: No changes needed - color functionality is code-based
2. **Dice Scene**: Ensure dice use the updated dice_combined_effects.gdshader
3. **GameController**: No changes needed - integration is automatic via autoloads

### Material Setup
1. Open any dice scene (e.g., `Scenes/Dice/Die.tscn`)
2. Ensure Sprite2D uses ShaderMaterial with `dice_combined_effects.gdshader`
3. Verify shader parameters include new color strength uniforms
4. Test in-editor by setting color strength values manually

### Testing Setup
1. Open `Tests/DiceColorTest.tscn` in editor
2. Run scene to access interactive testing interface
3. Use debug panel (F12) in main game for quick color testing
4. Verify autoloads are loaded in correct order (DiceColorManager should load before gameplay systems)

## Backward Compatibility

### Existing Save Data
- No save data format changes required
- Dice colors are assigned per-roll, not stored
- Existing power-ups and systems work unchanged

### API Compatibility
- All existing Dice and DiceHand methods remain functional
- New methods are additive, no breaking changes
- ScoreModifierManager integration preserves existing multiplier system

### Visual Compatibility
- Existing shader effects (glow, lock, disabled) work unchanged
- Color effects layer properly with existing visual systems
- Performance impact minimal (3 additional shader uniforms)

## Known Limitations

### Current Constraints
1. Colors are not persistent between saves (design choice)
2. Color chances are fixed constants (not player-configurable)
3. Shader effects require OpenGL-compatible rendering
4. Color effects only apply during scoring, not during rolling

### Future Enhancement Opportunities
1. Color persistence options
2. Configurable color chances via game settings
3. Additional color types (orange, blue, etc.)
4. Color-specific sound effects
5. Color combination bonuses (rainbow effects)

## Performance Notes

### Memory Usage
- Minimal impact: Single enum per die + 3 shader floats
- No additional texture resources required
- Manager uses lightweight calculation methods

### Rendering Performance  
- Shader adds ~10 lines to fragment shader
- Edge calculation computed per-pixel but optimized
- Pulsing animation uses built-in TIME uniform
- Compatible with existing mobile rendering pipeline

### Debug Impact
- Debug commands add ~50 lines to debug panel
- Test scene is standalone, doesn't affect main game performance
- Color effect calculations cached per frame during scoring

This implementation provides a solid foundation for the dice color system while maintaining compatibility with existing DiceRogue systems and following the project's coding standards.