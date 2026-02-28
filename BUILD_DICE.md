# BUILD_DICE.md

## How to Add New Dice Types to DiceRogue

This guide covers the technical implementation of new dice types (d4, d6, d8, d10, d12, d20) and documents the design rules for scoring, debuffs, and balance considerations when using non-standard dice.

---

## Overview

DiceRogue supports multiple dice types through the `DiceData` resource system. Each dice type is defined by:
- **id** — Unique string identifier (`"d4"`, `"d6"`, `"d8"`, etc.)
- **display_name** — Human-readable name (`"D4"`, `"D6"`, `"D8"`, etc.)
- **sides** — Number of faces (4, 6, 8, 10, 12, 20)
- **textures** — Array of `Texture2D` for each face value (1 through N)

Dice types are assigned per-round via `ChallengeData.dice_type` and applied through `DiceHand.switch_dice_type()`.

### Currently Implemented Dice

| Type | Sides | Status | Resource File |
|------|-------|--------|---------------|
| d4   | 4     | Active | `Scripts/Dice/d4_dice.tres` |
| d6   | 6     | Active (default) | `Scripts/Dice/d6_dice.tres` |
| d8   | 8     | Scoring active | `Scripts/Dice/d8_dice.tres` |
| d10  | 10    | Scoring active | `Scripts/Dice/d10_dice.tres` |
| d12  | 12    | Scoring active | `Scripts/Dice/d12_dice.tres` |
| d20  | 20    | Scoring active | `Scripts/Dice/d20_dice.tres` |

### Art Assets

Face textures are stored in `Resources/Art/Dice/`:
- **Values 1–6**: `dieWhite_border1.png` – `dieWhite_border6.png` (pip style, original art)
- **Values 7–20**: `dieWhite_border7.png` – `dieWhite_border20.png` (numeral style, generated)

All textures are 68×68 RGBA PNGs with transparent corners and a white die body with black border.

---

## Creating a New Dice Resource

### Step 1: Art Assets

Ensure face textures exist in `Resources/Art/Dice/` for every value from 1 to N. Follow the naming convention: `dieWhite_border{value}.png`.

For new values, use the generation script at `Scripts/Editor/generate_dice_faces.py` or create custom pixel art.

### Step 2: Resource File (.tres)

Create a `.tres` file in `Scripts/Dice/` following this template:

```gdresource
[gd_resource type="Resource" script_class="DiceData" load_steps=N format=3]

[ext_resource type="Script" uid="uid://cfvqx1x72koke" path="res://Scripts/Dice/DiceData.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://Resources/Art/Dice/dieWhite_border1.png" id="2_tex1"]
... (one ext_resource per face texture)

[resource]
script = ExtResource("1_script")
id = "dN"
display_name = "DN"
sides = N
textures = Array[Texture2D]([ExtResource("2_tex1"), ...])
metadata/_custom_type_script = "uid://cfvqx1x72koke"
```

Set `load_steps` = 1 (script) + number of textures.

### Step 3: Register in DiceHand

In `Scripts/Core/dice_hand.gd`:

1. Add an `@export var` with a `preload()` default:
   ```gdscript
   @export var dN_dice_data: DiceData = preload("res://Scripts/Dice/dN_dice.tres")
   ```

2. Add a match arm in `switch_dice_type()`:
   ```gdscript
   "dN":
       if not dN_dice_data:
           push_error("[DiceHand] DN dice data not assigned!")
           return
       new_dice_data = dN_dice_data
   ```

### Step 4: Use in Challenges

Set `dice_type = "dN"` on any `ChallengeData` resource. The `RoundManager` will call `dice_hand.switch_dice_type()` at round start.

---

## Scoring Rules for Non-Standard Dice

### Current System (d6 Baseline)

The standard Yahtzee scorecard has 13 categories:

**Upper Section** (6 categories): Ones, Twos, Threes, Fours, Fives, Sixes
- Score = `count(N) × N` where N is the target number
- Upper bonus: 63 points threshold → 35 point bonus (scales +10% per round)

**Lower Section** (7 categories): Three of a Kind, Four of a Kind, Full House, Small Straight, Large Straight, Yahtzee, Chance

### Dynamic 6th Slot Rule

**Design Decision**: The upper section always has exactly 6 category rows. The first 5 rows (Ones through Fives) remain fixed. The **6th row dynamically changes** to match the active dice type's maximum value.

| Dice Type | Upper Section Categories | 6th Slot |
|-----------|-------------------------|----------|
| d4        | Ones, Twos, Threes, Fours, —, — | **Fours** (Fives/Sixes impossible) |
| d6        | Ones, Twos, Threes, Fours, Fives, Sixes | **Sixes** (standard) |
| d8        | Ones, Twos, Threes, Fours, Fives, Eights | **Eights** |
| d10       | Ones, Twos, Threes, Fours, Fives, Tens | **Tens** |
| d12       | Ones, Twos, Threes, Fours, Fives, Twelves | **Twelves** |
| d20       | Ones, Twos, Threes, Fours, Fives, Twenties | **Twenties** |

#### d4 Special Case

With a d4, values 5 and 6 are impossible to roll. The 6th slot becomes Fours (already covered by the 4th row). Effectively only 4 upper categories are usable — the Fives and Sixes rows would need to be **disabled or hidden**. This makes d4 rounds significantly harder for upper section scoring.

**Open question**: Should d4 disable the 5th and 6th rows entirely, or should they remain as scratch-only (-0) rows that the player must waste?

#### Higher Dice (d8–d20) Risk/Reward

When using d8+, values 6–19 are **dead weight** for Ones through Fives categories. Only the 6th slot benefits from high rolls. This creates natural strategic tension:

- **d8**: Rolling a 7 or 8 is usable only for the Eights category, Three/Four of a Kind, straights (future), or Chance.
- **d20**: Rolling 6–19 is dead for *all* upper categories except Twenties. Extremely volatile.

The risk/reward increases with dice size — higher ceiling on the 6th slot, but harder to accumulate points in Ones through Fives.

#### Implementation Notes

**IMPLEMENTED** — Dynamic 6th slot scoring is now active:

1. **`Scenes/ScoreCard/score_card.gd`**:
   - Added `current_dice_sides`, `sixth_slot_target` variables
   - Added `set_dice_type(sides)` to update the 6th slot target at runtime
   - Added `get_sixth_slot_display_name()` for UI text ("Sixes", "Eights", etc.)
   - Added `calculate_upper_bonus_base_threshold()` for dice-type-aware bonus threshold
   - `_get_used_dice_for_category()` uses `sixth_slot_target` for the "sixes" category
   - `_format_category_display_name()` returns the dynamic name
   - The key remains `"sixes"` internally to avoid breaking node path references

2. **`Scripts/Core/score_evaluator.gd`**:
   - Added `current_dice_sides` property and `set_dice_sides()` method
   - `evaluate_normal()` uses `current_dice_sides` for the 6th upper category
   - `is_small_straight()` generalized to check all 4-consecutive sequences up to `current_dice_sides`
   - `generate_wildcard_combinations()` uses `current_dice_sides` instead of hardcoded 6

3. **`Scripts/UI/score_card_ui.gd`**:
   - Added `update_sixth_slot_display()` — updates SixesButton text dynamically
   - Called from `bind_scorecard()` and by RoundManager after dice type changes

4. **`Scripts/Managers/round_manager.gd`**:
   - After `switch_dice_type()`, propagates dice sides to Scorecard and ScoreEvaluator
   - Also triggers `update_sixth_slot_display()` on the UI

### Upper Bonus Threshold Rebalancing

The current upper bonus threshold is **63** (the sum of scoring 3 of each value: 3×1 + 3×2 + 3×3 + 3×4 + 3×5 + 3×6 = 63).

For different dice types, the threshold should scale:

| Dice Type | "3 of each" Sum | Proposed Threshold | Notes |
|-----------|------------------|--------------------|-------|
| d4        | 3×(1+2+3+4) = 30 | ~30 | Only 4 usable categories |
| d6        | 3×(1+2+3+4+5+6) = 63 | 63 (current) | Standard |
| d8        | 3×(1+2+3+4+5+8) = 69 | ~69 | 6th slot is 8s |
| d10       | 3×(1+2+3+4+5+10) = 75 | ~75 | 6th slot is 10s |
| d12       | 3×(1+2+3+4+5+12) = 81 | ~81 | 6th slot is 12s |
| d20       | 3×(1+2+3+4+5+20) = 105 | ~105 | High ceiling, very hard to fill lower slots |

**Formula**: `threshold = 3 × (1 + 2 + 3 + 4 + 5 + sides)` when sides ≥ 6, or `3 × sum(1..sides)` when sides < 6.

**IMPLEMENTED** as `calculate_upper_bonus_base_threshold()` in `score_card.gd`:
```gdscript
func calculate_upper_bonus_base_threshold() -> int:
    if current_dice_sides <= 5:
        var total := 0
        for i in range(1, current_dice_sides + 1):
            total += i
        return total * 3
    else:
        return (1 + 2 + 3 + 4 + 5 + sixth_slot_target) * 3
```

`get_scaled_upper_bonus_threshold()` now calls this instead of using the hardcoded UPPER_BONUS_THRESHOLD constant.

### Lower Section Considerations

#### Straights

Current straight detection is **hardcoded for d6**:
- Small straight: `[1,2,3,4]`, `[2,3,4,5]`, `[3,4,5,6]`
- Large straight: any 5 consecutive values via sliding window

**For higher dice**: The sliding window logic in `is_straight()` already works generically (checks `sequence[4] == sequence[0] + 4`). However, `is_small_straight()` hardcodes three specific sequences.

**Proposed fix**: Generalize small straight to check all possible 4-consecutive sequences from 1 to `sides`:
```gdscript
func is_small_straight(values: Array[int], sides: int) -> bool:
    var unique := get_unique(values)
    for start in range(1, sides - 2):  # 1 to sides-3
        var seq_valid := true
        for offset in range(4):
            if not unique.has(start + offset):
                seq_valid = false
                break
        if seq_valid:
            return true
    return false
```

**For d4**: Small and large straights are more constrained (only one possible small straight: `[1,2,3,4]`, and large straight is impossible with 5 dice from 4 values).

#### Of-a-Kind and Full House

These work generically — they count die values regardless of range. No changes needed for higher dice.

#### Chance

`Chance = sum(all_dice)`. Works generically. Higher dice naturally produce higher Chance scores.

#### Wildcards

`generate_wildcard_combinations(wildcard_count, sides)` already accepts a `sides` parameter. Ensure the correct value is passed based on active dice type.

---

## Debuff Designs for Dice Types

### Mixed Dice Pool ("Mixed Bag")

**Concept**: Replace some dice in the player's hand with lower dice types, creating an uneven pool (e.g., 3×d6 + 2×d4).

**Effect**: The player rolls a mix of dice types simultaneously. Each die retains its own `DiceData` (affecting its value range and display).

**How it works**:
- The `Dice` class already has an individual `dice_data` property
- `DiceHand.switch_dice_type()` sets all dice to the same type, but the debuff would override individual dice after the switch
- The debuff's `apply()` method would directly assign `die.dice_data = d4_dice_data` (or other types) to specific dice in the hand

**Architecture**:
```gdscript
extends Debuff
class_name MixedBagDebuff

## Mixed Bag Debuff
##
## Replaces some dice with smaller dice types, creating an uneven hand.

var original_dice_data: Array[DiceData] = []  # For cleanup

func apply(_target) -> void:
    self.target = _target
    var dice_hand = _get_dice_hand()
    if not dice_hand:
        return
    
    # Store originals for removal
    for die in dice_hand.dice_list:
        original_dice_data.append(die.dice_data)
    
    # Replace last 2 dice with d4s (intensity could control count)
    var d4_data = preload("res://Scripts/Dice/d4_dice.tres")
    var count_to_replace = mini(intensity, dice_hand.dice_list.size())
    for i in range(dice_hand.dice_list.size() - count_to_replace, dice_hand.dice_list.size()):
        dice_hand.dice_list[i].dice_data = d4_data
        dice_hand.dice_list[i].value = 1
        dice_hand.dice_list[i].update_visual()

func remove() -> void:
    var dice_hand = _get_dice_hand()
    if dice_hand and original_dice_data.size() > 0:
        for i in range(mini(original_dice_data.size(), dice_hand.dice_list.size())):
            dice_hand.dice_list[i].dice_data = original_dice_data[i]
            dice_hand.dice_list[i].value = 1
            dice_hand.dice_list[i].update_visual()
    original_dice_data.clear()
```

**Difficulty Ratings**:
| Difficulty | Mix |
|-----------|------|
| 1 | 4×d6 + 1×d4 |
| 2 | 3×d6 + 2×d4 |
| 3 | 2×d6 + 3×d4 |
| 4 | 1×d6 + 2×d4 + 2×d8 (chaotic) |
| 5 | All different types (1×d4, 1×d6, 1×d8, 1×d10, 1×d12) |

**IMPLEMENTED**: Script at `Scripts/Debuff/mixed_bag_debuff.gd`, scene at `Scenes/Debuff/MixedBagDebuff.tscn`, resource at `Scripts/Debuff/MixedBagDebuff.tres`. Registered in `game_controller.gd` `apply_debuff()`. Add the `.tres` to DebuffManager's `debuff_defs` array via the Inspector to activate.

---

## Future Considerations

### Per-Die Dice Type Display

When using mixed dice pools, the UI should visually indicate each die's type (e.g., a small "d4" label above downgraded dice, or a different die shape/color).

### Shop Integration

New dice types could be purchasable:
- **Dice Upgrade**: Buy a d8/d10 to replace all d6s for one round
- **Specialty Die**: Buy a single specialty die that replaces one die in the hand
- Integrate with existing `ColoredDiceData` shop system

### Challenge Integration

`ChallengeData.dice_type` already supports arbitrary strings. New challenges can specify:
- `"d8"` for an 8-sided dice challenge
- `"d20"` for a high-variance challenge
- Mixed types could use a new `dice_config` array field (future)

### Score Card Upgrade Balancing

Category level multipliers (`upper_levels`, `lower_levels`) may need rebalancing for higher dice. A d20 "Twenties" category at level 3 would score `count(20) × 20 × 3 = 300` for five twenties — much higher than d6 "Sixes" at level 3 (`count(6) × 6 × 3 = 90`). Consider capping or scaling the level multiplier inversely with dice sides.

### Color Dice Interaction

The color system (Green, Red, Purple, Blue, Yellow) applies per-die effects based on the die's rolled value. Higher dice values amplify these effects:
- **Red d20 showing 18**: Adds +18 to score (very strong additive)
- **Purple d20 showing 15**: Multiplies score by ×15 (extremely powerful)
- **Blue d20 not used**: Divides score by rolled value (devastating penalty)

Balance consideration: Color effects may need to be capped or scaled for higher dice types.

---

## File Reference

| File | Purpose |
|------|---------|
| `Scripts/Dice/DiceData.gd` | Base resource class for dice types |
| `Scripts/Dice/d*.tres` | Dice resource definitions |
| `Scripts/Core/dice.gd` | Individual die logic (rolling, locking, visuals) |
| `Scripts/Core/dice_hand.gd` | Dice hand management, `switch_dice_type()` |
| `Scripts/Core/score_evaluator.gd` | Score calculation logic (needs generalization) |
| `Scenes/ScoreCard/score_card.gd` | Scorecard data model and scoring |
| `Scripts/UI/score_card_ui.gd` | Scorecard UI display |
| `Resources/Art/Dice/` | Face texture assets |
| `Scripts/Editor/generate_dice_faces.py` | Art generation utility |
| `Scripts/Managers/round_manager.gd` | Round/dice type assignment flow |
| `Scripts/Challenge/ChallengeData.gd` | Challenge definitions (dice_type field) |
| `BUILD_DEBUFF.md` | Debuff creation guide |
