# SETUP_ANYSCORE.md - Manual Setup Instructions

## AnyScore Consumable Setup

The AnyScore consumable has been implemented with all required files:
- ✅ Script: `Scripts/Consumable/any_score_consumable.gd`
- ✅ Scene: `Scenes/Consumable/AnyScoreConsumable.tscn`
- ✅ Data Resource: `Scripts/Consumable/AnyScoreConsumable.tres`
- ✅ Game Controller Integration: Added to `_on_consumable_used()` method
- ✅ Debug Command: Added "Grant AnyScore" button to debug panel
- ✅ UI Integration: Added to `ScoreCardUI` with `activate_any_score_mode()`
- ✅ Usability Logic: Added to `ConsumableUI._can_use_consumable()`
- ✅ Documentation: Updated `README.md` and created `BUILD_CONSUMABLE.md`

## Required Manual Step

**IMPORTANT**: The consumable must be registered in the ConsumableManager to be available in-game:

1. Open `Scenes/Controller/game_controller.tscn` in Godot Editor
2. Select the `ConsumableManager` node
3. In the Inspector, find the "Consumable Defs" array property  
4. Add a new element to the array
5. Drag `Scripts/Consumable/AnyScoreConsumable.tres` from the FileSystem dock to the new array slot
6. Save the scene

## Testing Instructions

After completing the manual setup:

1. **Run the Game**: Press F5 to run the main scene
2. **Open Debug Panel**: Press F12 to open the debug panel
3. **Grant AnyScore**: Click "Grant AnyScore" button
4. **Test Functionality**:
   - Roll some dice (or use "Roll All 6s" debug command)
   - Click the consumable spine to fan out consumables
   - Click the AnyScore consumable to activate it
   - Notice that open scorecard categories are highlighted in green
   - Click any open category to score with the best possible value for your dice

## How AnyScore Works

1. **Activation**: When used, enables special scoring mode
2. **Category Selection**: Only open (unscored) categories are available
3. **Best Score Calculation**: Automatically calculates the highest possible score for current dice across all categories
4. **Application**: Assigns this best score to the selected category, regardless of normal category requirements

## Example Usage

Dice: [1, 2, 3, 4, 5] (Large Straight = 30 points)
- Normal: Can only score 30 in Large Straight category
- With AnyScore: Can score 30 points in ANY open category (e.g., in Four of a Kind category instead)

This allows strategic placement of good hands into categories that normally wouldn't support them!

## Verification

The consumable should:
- ✅ Appear in debug panel as "Grant AnyScore" button
- ✅ Be grantable via debug command
- ✅ Show in consumable UI spine system
- ✅ Be usable only when dice are rolled and categories are open
- ✅ Highlight open categories in green when activated
- ✅ Calculate and assign the best possible score regardless of category rules
- ✅ Clean up properly after use

## Troubleshooting

If the consumable doesn't appear:
1. Verify ConsumableManager registration (step above)
2. Check console for error messages
3. Use debug command to test registration: F12 → "Grant AnyScore"
4. Check that ConsumableData resource has correct references to script and scene

## Integration Complete

The AnyScore consumable is fully integrated following the BUILD_CONSUMABLE.md guide and is ready for use once the manual registration step is completed!