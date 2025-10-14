# AnyScore Consumable - Testing Workflow

## Quick Test Instructions

1. **Open Project**: Launch DiceRogue in Godot 4.4+
2. **Run Main Scene**: Press F5 to start the game
3. **Open Debug Panel**: Press F12 to access debug tools
4. **Register AnyScore**: Click "Register AnyScore" button first
5. **Grant AnyScore**: Click "Grant AnyScore" button 
6. **Test Setup**: Use "Roll All 6s" to get good dice values
7. **Use Consumable**: 
   - Click consumable spine to fan out
   - Click AnyScore consumable (should have green background if usable)
   - Notice green highlights on open scorecard categories
   - Click any open category to score 30 points (sum of five 6s)

## Expected Behavior

### AnyScore Activation:
- [x] Consumable can be granted via debug panel
- [x] Appears in consumable UI as a spine
- [x] Shows as usable when dice are available and categories are open
- [x] When clicked, highlights open categories in green
- [x] Allows scoring in any open category regardless of dice configuration

### Scoring Logic:
- [x] Calculates best possible score for current dice
- [x] Applies this score to selected category
- [x] Example: Large straight (1,2,3,4,5 = 30) can be scored in "Ones" category
- [x] Consumable is consumed after use
- [x] UI returns to normal state

### Error Handling:
- [x] Cannot use when no dice are rolled
- [x] Cannot use when all categories are filled
- [x] Cannot use on already scored categories
- [x] Proper cleanup after consumable use

## Architecture Verification

### Files Created:
- ✅ `Scripts/Consumable/any_score_consumable.gd` - Main consumable logic
- ✅ `Scripts/Consumable/any_score_consumable.gd.uid` - Godot UID file
- ✅ `Scenes/Consumable/AnyScoreConsumable.tscn` - Scene structure
- ✅ `Scripts/Consumable/AnyScoreConsumable.tres` - Data resource
- ✅ `BUILD_CONSUMABLE.md` - Complete build guide
- ✅ `SETUP_ANYSCORE.md` - Setup instructions

### Integration Points:
- ✅ GameController: Added "any_score" case to `_on_consumable_used()`
- ✅ ScoreCardUI: Added `any_score_active` mode and `activate_any_score_mode()`
- ✅ ConsumableUI: Added specific usability logic for AnyScore
- ✅ DebugPanel: Added "Grant AnyScore" and "Register AnyScore" commands
- ✅ ConsumableManager: Added `register_consumable_def()` method
- ✅ README.md: Updated with new feature documentation

## Test Results Template

Date: ___________
Tester: ___________

| Test Case | Expected | Actual | Pass/Fail |
|-----------|----------|--------|-----------|
| Debug registration | AnyScore can be registered | | |
| Debug granting | AnyScore can be granted | | |
| UI appearance | Shows in spine system | | |
| Usability check | Usable with dice + open categories | | |
| Activation visual | Green highlights on open categories | | |
| Score calculation | Best score calculated correctly | | |
| Score application | Score applied to selected category | | |
| Cleanup | Consumable removed after use | | |
| Error handling | Graceful handling of invalid states | | |

## Success Criteria

The AnyScore consumable is working correctly if:
1. It can be registered and granted through debug panel
2. It appears in the consumable UI spine system
3. It correctly detects usability (dice + open categories)
4. It highlights open categories in green when activated
5. It calculates the best possible score for current dice
6. It allows scoring this value in any open category
7. It properly cleans up and removes itself after use
8. It handles edge cases gracefully (no dice, no open categories, etc.)

## Integration Complete ✅

The AnyScore consumable is fully implemented and ready for testing!