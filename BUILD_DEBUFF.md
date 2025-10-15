# BUILD_DEBUFF.md

## How to Create New Debuffs in DiceRogue

This guide provides step-by-step instructions for creating new debuffs in the DiceRogue game. Debuffs are negative effects that hinder the player's progress and add challenge to the gameplay.

### Overview

A complete debuff implementation requires three main components:
1. **Script** - The debuff logic and behavior
2. **Scene** - The Godot scene file containing the debuff node
3. **Resource** - The DebuffData resource that defines the debuff's metadata

### Step 1: Create the Debuff Script

Create a new script in `Scripts/Debuff/` that extends the base `Debuff` class:

```gdscript
extends Debuff
class_name YourDebuffName

## Your Debuff Description
##
## Detailed explanation of what this debuff does and how it affects gameplay

var additional_properties: type = default_value

## apply(_target)
##
## Called when the debuff is applied to the target.
## This is where you implement the debuff's negative effect.
func apply(_target) -> void:
	print("[YourDebuffName] Applied - Description of effect")
	
	# Store the target for cleanup
	self.target = _target
	
	# Implement your debuff logic here
	# Examples:
	# - Connect to signals
	# - Modify game state
	# - Intercept game mechanics
	# - Apply penalties

## remove()
##
## Called when the debuff is removed or expires.
## This must cleanly undo all effects applied in apply().
func remove() -> void:
	print("[YourDebuffName] Removed - Undoing effects")
	
	# Clean up all effects applied in apply()
	# Examples:
	# - Disconnect signals
	# - Restore original state
	# - Remove penalties
	# - Free resources
```

#### Key Guidelines for Debuff Scripts:

- **Always use `_target` parameter**: The base class has a `target` property, so use `_target` parameter to avoid shadowing
- **Store target reference**: Always set `self.target = _target` for proper cleanup
- **Implement both methods**: Both `apply()` and `remove()` must be implemented
- **Clean up properly**: `remove()` must undo everything that `apply()` did
- **Use appropriate class_name**: Follow PascalCase naming convention
- **Add comprehensive documentation**: Use GDScript doc comments for methods

#### Common Debuff Patterns:

1. **Signal-based debuffs**: Connect to game signals and apply penalties
2. **State modification debuffs**: Directly modify game state or properties
3. **Interception debuffs**: Replace or modify existing game methods
4. **Continuous effect debuffs**: Apply ongoing penalties during gameplay

### Step 2: Create the Debuff Scene

Create a new scene file in `Scenes/Debuff/` with the following structure:

1. Create new scene in Godot Editor
2. Add a Node as the root (name it after your debuff)
3. Attach your debuff script to the root node
4. Save the scene as `YourDebuffName.tscn`

**Alternative: Manual .tscn file creation** (for consistency with existing files):

```gdscene
[gd_scene load_steps=2 format=3 uid="uid://your_unique_id"]

[ext_resource type="Script" uid="uid://script_uid" path="res://Scripts/Debuff/your_debuff_script.gd" id="1_bequk"]

[node name="YourDebuffName" type="Node"]
script = ExtResource("1_bequk")
```

### Step 3: Create the DebuffData Resource

Create a new resource file in `Scripts/Debuff/` that defines the debuff's metadata:

```gdresource
[gd_resource type="Resource" script_class="DebuffData" load_steps=4 format=3 uid="uid://your_unique_id"]

[ext_resource type="Texture2D" uid="uid://icon_uid" path="res://Resources/Art/Powerups/your_icon.png" id="1_j54ng"]
[ext_resource type="Script" uid="uid://uiuqwtxbh7m0" path="res://Scripts/Debuff/DebuffData.gd" id="1_oh0j2"]
[ext_resource type="PackedScene" uid="uid://scene_uid" path="res://Scenes/Debuff/YourDebuffName.tscn" id="2_ta17l"]

[resource]
script = ExtResource("1_oh0j2")
id = "your_debuff_id"
display_name = "Your Debuff Display Name"
description = "Brief description shown in UI"
icon = ExtResource("1_j54ng")
scene = ExtResource("2_ta17l")
metadata/_custom_type_script = "uid://uiuqwtxbh7m0"
```

#### DebuffData Properties:

- **id**: Unique string identifier (snake_case)
- **display_name**: Human-readable name shown in UI
- **description**: Brief explanation of the debuff's effect
- **icon**: Texture2D resource for the UI icon
- **scene**: PackedScene reference to your debuff scene

### Step 4: Register the Debuff

Add your debuff resource to the DebuffManager in the main game scene:

1. Open the main game scene in Godot Editor
2. Find the DebuffManager node
3. In the Inspector, add your DebuffData resource to the `debuff_defs` array
4. Save the scene

### Step 5: Integration with GameController

Add support for your debuff in `GameController.gd`:

```gdscript
# In the apply_debuff() method, add your case:
match id:
	"your_debuff_id":
		debuff.target = appropriate_target  # self, dice_hand, scorecard, etc.
		debuff.start()
	# ... existing cases
```

### Step 6: Testing and Debug Integration

Add debug support by updating `debug_panel.gd`:

```gdscript
# In _create_debug_buttons(), add a new button:
{"text": "Apply Your Debuff", "method": "_debug_apply_your_debuff"},

# Add the debug method:
func _debug_apply_your_debuff() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	game_controller.apply_debuff("your_debuff_id")
	log_debug("Applied your debuff for testing")
```

## Complete Example: TheDivisionDebuff

Here's a complete example of the newly created TheDivisionDebuff:

### Script (`Scripts/Debuff/the_division_debuff.gd`):
```gdscript
extends Debuff
class_name TheDivisionDebuff

## TheDivisionDebuff
##
## Converts all multiplier power-ups to work as dividers instead.
## When active, any power-up that would normally multiply scores will instead divide them.
## Example: A 2.0 multiplier becomes 1/2.0 = 0.5 (dividing score by 2)

var score_modifier_manager: Node
var original_get_total_multiplier_method: Callable
var is_intercepting: bool = false

func apply(_target) -> void:
	print("[TheDivisionDebuff] Applied - Converting multipliers to dividers")
	self.target = _target
	
	# Find and intercept ScoreModifierManager
	score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if score_modifier_manager:
		original_get_total_multiplier_method = score_modifier_manager.get_total_multiplier
		score_modifier_manager.get_total_multiplier = _get_total_divider_instead
		is_intercepting = true

func remove() -> void:
	print("[TheDivisionDebuff] Removed - Restoring normal multiplier behavior")
	if score_modifier_manager and is_intercepting:
		score_modifier_manager.get_total_multiplier = original_get_total_multiplier_method
		is_intercepting = false

func _get_total_divider_instead() -> float:
	# Custom logic to convert multipliers to dividers
	# Implementation details...
```

### Resource (`Scripts/Debuff/TheDivisionDebuff.tres`):
```gdresource
[gd_resource type="Resource" script_class="DebuffData" load_steps=4 format=3]

[resource]
script = ExtResource("DebuffData.gd")
id = "the_division"
display_name = "The Division"
description = "All multiplier powerups now divide scores instead"
icon = ExtResource("chore_chart.png")
scene = ExtResource("TheDivisionDebuff.tscn")
```

## Best Practices

### Code Quality:
- Follow the project's coding standards (tabs, snake_case, etc.)
- Add comprehensive documentation with GDScript doc comments
- Use descriptive variable and method names
- Handle edge cases and error conditions

### Game Design:
- Ensure debuffs are challenging but not frustrating
- Balance negative effects appropriately
- Consider how debuffs interact with existing systems
- Test debuffs with various power-up combinations

### Technical Implementation:
- Always implement proper cleanup in `remove()`
- Avoid memory leaks by disconnecting signals
- Use appropriate target types (self, dice_hand, scorecard)
- Test debuff activation and deactivation thoroughly

### UI/UX Considerations:
- Choose appropriate icons that communicate the debuff's effect
- Write clear, concise descriptions
- Ensure debuff effects are visible to the player
- Consider animation or visual feedback for debuff application

## Testing Checklist

Before considering a debuff complete, verify:

- [ ] Script compiles without errors
- [ ] Scene file loads correctly
- [ ] Resource file is properly configured
- [ ] DebuffManager can spawn the debuff
- [ ] GameController can apply and remove the debuff
- [ ] `apply()` method works as intended
- [ ] `remove()` method properly cleans up
- [ ] No memory leaks or orphaned connections
- [ ] UI displays debuff correctly
- [ ] Debug panel integration works
- [ ] Debuff interacts properly with other systems
- [ ] Edge cases are handled gracefully

## Common Issues and Solutions

### Issue: "Failed to spawn Debuff"
**Solution**: Check that the scene path in the resource is correct and the scene file exists.

### Issue: Debuff effects don't apply
**Solution**: Verify the target is correct and the `apply()` method is properly implemented.

### Issue: Debuff effects persist after removal
**Solution**: Ensure `remove()` method undoes all changes made in `apply()`.

### Issue: Missing from DebuffManager
**Solution**: Add the DebuffData resource to the DebuffManager's `debuff_defs` array.

### Issue: GameController doesn't recognize debuff
**Solution**: Add a case for your debuff ID in the `apply_debuff()` method.

## File Structure Summary

```
DiceRogue/
├── Scripts/
│   └── Debuff/
│       ├── your_debuff_script.gd          # Main debuff logic
│       └── YourDebuffData.tres            # Debuff metadata resource
├── Scenes/
│   └── Debuff/
│       └── YourDebuffScene.tscn           # Debuff scene file
└── Resources/
    └── Art/
        └── Powerups/
            └── your_debuff_icon.png       # Icon for UI (optional new icon)
```

This guide ensures consistent, maintainable debuff implementation that integrates seamlessly with the existing DiceRogue codebase.