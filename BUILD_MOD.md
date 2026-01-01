# BUILD_MOD.md

## How to Create a New Mod for DiceRogue

This guide provides step-by-step instructions for creating a new mod in the DiceRogue game. Mods are special effects that can be applied to dice to change their behavior, such as forcing specific values or providing bonus effects.

## Overview

A mod in DiceRogue consists of three main components:
1. **Script File** (`Scripts/Mods/[mod_name]_mod.gd`) - Contains the mod's logic
2. **Scene File** (`Scenes/Mods/[ModName].tscn`) - Godot scene that instantiates the mod
3. **Resource File** (`Scripts/Mods/[ModName].tres`) - ModData resource with metadata

## Step-by-Step Guide

### 1. Create the Mod Script

Create a new GDScript file in `Scripts/Mods/` with the naming convention `[mod_name]_mod.gd`.

**Template:**
```gdscript
extends Mod
class_name [ModName]Mod

var _attached_die: Dice = null

func _ready() -> void:
	add_to_group("mods")
	print("[YourModName] Ready")

## apply(dice_target)
##
## Applies the mod to a dice. This is where you implement your mod's logic.
func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		print("[YourModName] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target  # Store in base class target variable
		
		# Connect to the dice signals you need
		_attached_die.rolled.connect(_on_die_roll_completed)
		emit_signal("mod_applied")
	else:
		push_error("[YourModName] Invalid target passed to apply()")

## remove()
##
## Removes the mod from the attached dice.
func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	emit_signal("mod_removed")

## _on_die_roll_completed(value)
##
## Callback when the attached die completes a roll. Implement your mod's effect here.
func _on_die_roll_completed(value: int) -> void:
	# Implement your mod's behavior here
	# Example: Force a specific value
	# _attached_die.value = 3
	
	# Example: Grant money to player
	# PlayerEconomy.add_money(10)
	
	print("[YourModName] Effect applied")
```

**Key Points:**
- Always extend `Mod` base class
- Use `dice_target` parameter instead of `target` to avoid shadowing
- Store the target in the base class `target` variable
- Connect to `_attached_die.rolled` signal for roll-based effects
- Use `PlayerEconomy.add_money(amount)` to grant money
- Remember to emit `mod_applied` and `mod_removed` signals

### 2. Create the Scene File

Create a new scene file in `Scenes/Mods/` with the naming convention `[ModName].tscn`.

**Template:**
```gdscene
[gd_scene load_steps=2 format=3 uid="uid://[unique_id]"]

[ext_resource type="Script" path="res://Scripts/Mods/[mod_name]_mod.gd" id="1_script"]

[node name="[ModName]" type="Node"]
script = ExtResource("1_script")
```

**Important:**
- The scene root should be a simple `Node`
- Attach your mod script to the root node
- Use a descriptive name matching your mod

### 3. Create the ModData Resource

Create a new resource file in `Scripts/Mods/` with the naming convention `[ModName].tres`.

**Template:**
```gdresource
[gd_resource type="Resource" script_class="ModData" load_steps=4 format=3 uid="uid://[unique_id]"]

[ext_resource type="Texture2D" uid="uid://[icon_uid]" path="res://Resources/Art/Dice/[icon_file].png" id="1_icon"]
[ext_resource type="Script" uid="uid://47gl3by4wwht" path="res://Scripts/Mods/ModData.gd" id="1_moddata"]
[ext_resource type="PackedScene" uid="uid://[scene_uid]" path="res://Scenes/Mods/[ModName].tscn" id="2_scene"]

[resource]
script = ExtResource("1_moddata")
id = "[mod_id]"
display_name = "[Display Name]"
description = "[Short Description]"
icon = ExtResource("1_icon")
scene = ExtResource("2_scene")
price = [price_in_dollars]
metadata/_custom_type_script = "uid://47gl3by4wwht"
```

**Configuration:**
- **id**: Unique identifier (lowercase, underscores)
- **display_name**: User-friendly name shown in UI
- **description**: Brief description of the mod's effect
- **icon**: Choose an appropriate dice icon from `Resources/Art/Dice/`
- **price**: Cost in the shop (typical range: 100-200)

### 4. Register the Mod in the Main Scene

Add your new mod to the main game scene so it can be used:

1. Open `Tests/DebuffTest.tscn` (current main scene)
2. Add an external resource reference for your mod:
   ```gdscene
   [ext_resource type="Resource" path="res://Scripts/Mods/[ModName].tres" id="[next_id]"]
   ```
3. Add it to the ModManager's `mod_defs` array:
   ```gdscene
   mod_defs = Array[ExtResource("60_moddata")]([..., ExtResource("[your_ext_id]")])
   ```

**Important Notes:**
- The ModData script reference should be `ExtResource("60_moddata")` (this references `Scripts/Mods/ModData.gd`)
- Ensure the external resource ID follows the numbering sequence in the file
- All mod `.tres` files should be in `Scripts/Mods/`, not `Resources/Data/`

### 5. Available Dice Icons

Choose from these available icons in `Resources/Art/Dice/`:
- `dieWhite_border1.png` through `dieWhite_border6.png` - Specific numbers
- `dieWhite_borderEvenonly.png` - Even numbers theme
- `dieWhite_borderOddonly.png` - Odd numbers theme
- `dieWhite_borderWild.png` - Wild card theme
- `dieWhite_borderGoldsix.png` - Gold/money theme
- `dieWhite_borderBlank.png` - Blank/neutral theme

### Score Integration

For mods that affect scoring, use the `ScoreModifierManager` autoload:

```gdscript
# Add bonus points to all scores
ScoreModifierManager.register_additive("your_mod_id", bonus_amount)

# Remove bonus when mod is removed/sold
ScoreModifierManager.unregister_additive("your_mod_id")

# Check if additive exists
if ScoreModifierManager.has_additive("your_mod_id"):
    var current_bonus = ScoreModifierManager.get_additive("your_mod_id")
```

The ScoreModifierManager automatically applies all registered additives to scores when they are calculated.

### Value Forcing Mods
```gdscript
func _on_die_roll_completed(value: int) -> void:
	_attached_die.value = 3  # Force specific value
```

### Money-Granting Mods
```gdscript
func _on_die_roll_completed(value: int) -> void:
	PlayerEconomy.add_money(5)  # Grant money per roll
```

### Conditional Effects
```gdscript
func _on_die_roll_completed(value: int) -> void:
	if value == 6:  # Only trigger on 6s
		PlayerEconomy.add_money(10)
```

### Range Restrictions
```gdscript
func _on_die_roll_completed(value: int) -> void:
	if value < 3:  # Force minimum value
		_attached_die.value = 3
```

### Reset on Sale/Removal
```gdscript
func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	
	# Clean up score modifiers
	if ScoreModifierManager.has_additive("your_mod_id"):
		ScoreModifierManager.unregister_additive("your_mod_id")
	
	# Reset any persistent state
	roll_count = 0
	
	emit_signal("mod_removed")
```

## Testing Your Mod

1. **In-Game Testing:**
   - Run the game
   - Open the debug panel (if available)
   - Look for your mod in the available mods list
   - Apply it to a die and test its behavior

2. **Console Output:**
   - Check the console for your mod's debug messages
   - Verify the mod applies and removes correctly
   - Ensure no error messages appear

## Integration Points

### GameController
Mods are automatically handled by the `ModManager` and don't require specific integration in `GameController.gd` unless you need special lifecycle management.

### Debug Panel
The debug panel automatically detects available mods through `ModManager.get_available_mods()`.

### Shop System
Mods can be made purchasable in the shop by setting an appropriate `price` in the ModData resource.

## Example: ThreeButThreeMod

Here's a complete example of a mod that forces dice to always roll 3 and grants $3 per roll:

**Script** (`Scripts/Mods/three_but_three_mod.gd`):
```gdscript
extends Mod
class_name ThreeButThreeMod

var _attached_die: Dice = null

func _ready() -> void:
	add_to_group("mods")
	print("[ThreeButThreeMod] Ready")

func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		print("[ThreeButThreeMod] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target
		_attached_die.rolled.connect(_on_die_roll_completed)
		emit_signal("mod_applied")
	else:
		push_error("[ThreeButThreeMod] Invalid target passed to apply()")

func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	emit_signal("mod_removed")

func _on_die_roll_completed(value: int) -> void:
	_attached_die.value = 3
	print("[ThreeButThreeMod] Forced roll to 3 and granting $3")
	PlayerEconomy.add_money(3)
```

**Resource** (`Scripts/Mods/ThreeButThreeMod.tres`):
```gdresource
[resource]
script = ExtResource("1_moddata")
id = "three_but_three"
display_name = "Three But Three"
description = "Always Roll 3, Earn $3 Per Roll"
icon = ExtResource("1_border3")  # dieWhite_border3.png
scene = ExtResource("2_scene")
price = 150
```

## Troubleshooting

### Common Issues

1. **Mod not appearing in debug panel:**
   - Check that the resource is added to ModManager's `mod_defs`
   - Verify the resource file is properly formatted
   - Ensure the scene reference is correct

2. **Script errors:**
   - Check for typos in class names and method signatures
   - Ensure you're not shadowing the `target` variable
   - Verify all required signals are properly connected/disconnected

3. **Scene instantiation fails:**
   - Verify the scene file path in the resource is correct
   - Check that the script is properly attached to the scene root
   - Ensure UIDs are unique and properly referenced

4. **Icon not displaying:**
   - Check that the icon path is correct
   - Verify the texture resource exists
   - Ensure the icon file is properly imported in Godot

### Debug Tips

- Use `print()` statements liberally for debugging mod behavior
- Check the console output when applying/removing mods
- Test with different dice to ensure compatibility
- Verify money changes in the debug panel's game state display

## Unlock Conditions

All Mods in DiceRogue are locked by default and must be unlocked through gameplay achievements. Configure unlock conditions in `Scripts/Managers/progress_manager.gd`.

### Adding Unlock Condition

In `_create_default_unlockable_items()`, add your Mod using `_add_default_mod()`:

```gdscript
_add_default_mod("your_mod_id", "Display Name", "Description text", 
    UnlockConditionClass.ConditionType.CONDITION_TYPE, target_value)
```

### Available Condition Types

| Condition Type | Description | Target Value |
|---------------|-------------|--------------|
| `SCORE_POINTS` | Score X points in a single category | Points (e.g., 200) |
| `ROLL_YAHTZEE` | Roll X yahtzees in a single game | Count (e.g., 2) |
| `ROLL_STRAIGHT` | Roll X straights in a single game | Count (e.g., 4) |
| `USE_CONSUMABLES` | Use X consumables in one game | Count (e.g., 10) |
| `CUMULATIVE_YAHTZEES` | Roll X yahtzees across all games | Yahtzees (e.g., 12) |
| `COMPLETE_CHANNEL` | Complete channel X | Channel (e.g., 5) |

### Example Unlock Configurations

```gdscript
# Basic mod - unlock with score achievement
_add_default_mod("even_only", "Even Only", "Forces die to only roll even numbers", 
    UnlockConditionClass.ConditionType.SCORE_POINTS, 200)

# Advanced mod - unlock with cumulative yahtzees
_add_default_mod("five_by_one", "Five by One", "All dice show 1 or 5", 
    UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 12)

# Channel-based mod - unlock by completing channel 5
_add_default_mod("channel_veteran", "Channel Veteran", "Start with +$25 per channel completed", 
    UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 5)
```

## File Structure Summary

After creating a mod, your file structure should include:

```
Scripts/Mods/
├── [mod_name]_mod.gd          # Main script
├── [ModName].tres             # Resource definition
└── ...

Scenes/Mods/
├── [ModName].tscn             # Scene file
└── ...

Tests/
└── DebuffTest.tscn            # Updated main scene with mod registration
```

## Conclusion

Following this guide ensures your mod integrates properly with the DiceRogue mod system and maintains consistency with existing code standards. Remember to test thoroughly and follow the established naming conventions for the best development experience.