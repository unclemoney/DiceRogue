# BUILD_CONSUMABLE.md - Complete Guide to Building New Consumables

## Overview
This guide covers the complete process for creating new consumables in DiceRogue, including all required files, setup steps, and integration points.

## File Structure
New consumables require 4 core files:
1. **Script file** - The consumable logic (`Scripts/Consumable/[name]_consumable.gd`)
2. **Scene file** - Node structure (`Scenes/Consumable/[Name]Consumable.tscn`)
3. **Data resource** - Configuration (`Scripts/Consumable/[Name]Consumable.tres`)
4. **Icon texture** - Visual representation (`Resources/Art/Powerups/[name]_icon.png`)

## Step-by-Step Build Process

### Step 1: Create the Consumable Script
Location: `Scripts/Consumable/[consumable_name]_consumable.gd`

Template:
```gdscript
extends Consumable
class_name [ConsumableName]Consumable

# Optional signals for consumable events
signal [consumable_event](args...)

func _ready() -> void:
	add_to_group("consumables")
	print("[[ConsumableName]Consumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[[ConsumableName]Consumable] Invalid target passed to apply()")
		return
	
	# TODO: Implement consumable logic here
	# Common patterns:
	# - Access game systems: game_controller.scorecard, game_controller.turn_tracker
	# - Modify game state
	# - Emit signals for UI updates
	
	print("[[ConsumableName]Consumable] Applied successfully")
```

**Key Guidelines:**
- Always extend `Consumable` base class
- Add `class_name` declaration 
- Validate `target` parameter is GameController
- Use descriptive print statements for debugging
- Follow existing naming patterns

### Step 2: Create the Scene File
Location: `Scenes/Consumable/[Name]Consumable.tscn`

Process:
1. Create new scene in Godot
2. Add root Node (type: Node)
3. Name the root node: `[Name]Consumable`
4. Attach the script created in Step 1
5. Save to the Scenes/Consumable folder

Scene structure:
```
[Name]Consumable (Node) [script: [name]_consumable.gd]
```

### Step 3: Create the Data Resource
Location: `Scripts/Consumable/[Name]Consumable.tres`

Template:
```gdresource
[gd_resource type="Resource" script_class="ConsumableData" load_steps=4 format=3]

[ext_resource type="Texture2D" path="res://Resources/Art/Powerups/[icon_file].png" id="1_icon"]
[ext_resource type="Script" path="res://Scripts/Consumable/ConsumableData.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://Scenes/Consumable/[Name]Consumable.tscn" id="2_scene"]

[resource]
script = ExtResource("1_script")
id = "[consumable_id]"
display_name = "[Display Name]"
description = "[Description for UI]"
icon = ExtResource("1_icon")
scene = ExtResource("2_scene")
price = 100
```

**Required Fields:**
- `id`: Unique identifier (snake_case)
- `display_name`: Human-readable name  
- `description`: Brief explanation of effect
- `icon`: Texture2D for UI display
- `scene`: Reference to the .tscn file
- `price`: Cost in shop (default: 100)

### Step 4: Add Icon Asset
Location: `Resources/Art/Powerups/[name]_icon.png`

Requirements:
- PNG format
- Recommended size: 64x64 pixels or larger
- Clear, readable design at small sizes
- Consistent art style with existing consumables

### Step 5: Register in ConsumableManager
Location: `Scenes/Controller/game_controller.tscn`

Process:
1. Open game_controller.tscn
2. Select the ConsumableManager node
3. In the Inspector, find the "Consumable Defs" array
4. Add new element to the array
5. Drag your .tres file from FileSystem to the new array slot
6. Save the scene

Alternative (Script method):
1. Open `Scripts/Managers/ConsumableManager.gd`
2. Add preload line: `const [NAME]_DEF = preload("res://Scripts/Consumable/[Name]Consumable.tres")`
3. Add to `_ready()`: `_defs_by_id["[id]"] = [NAME]_DEF`

### Step 6: Add to Game Controller Logic
Location: `Scripts/Core/game_controller.gd`

Find the `_on_consumable_used()` method and add your case:

```gdscript
func _on_consumable_used(consumable_id: String) -> void:
	var consumable = active_consumables.get(consumable_id)
	if not consumable:
		push_error("No consumable found with id: %s" % consumable_id)
		return

	print("[GameController] Using consumable:", consumable_id)
	
	# Add your new consumable case here
	match consumable_id:
		# ... existing cases ...
		"[your_consumable_id]":
			consumable.apply(self)
			active_consumables.erase(consumable_id)
		_:
			push_error("Unknown consumable type: %s" % consumable_id)
```

### Step 7: Add Debug Commands (Optional but Recommended)
Location: `Scripts/UI/debug_panel.gd`

Add to `_create_debug_buttons()` array:
```gdscript
["Grant [Name]", "_debug_grant_[name]"],
```

Add the debug method:
```gdscript
func _debug_grant_[name]() -> void:
	if game_controller:
		game_controller.grant_consumable("[consumable_id]")
		log_debug("Granted [Display Name] consumable")
	else:
		log_debug("No GameController found")
```

### Step 8: Add Usability Logic (If Needed)
Location: `Scripts/UI/consumable_ui.gd`

If your consumable has specific usability conditions, modify `_can_use_consumable()`:

```gdscript
func _can_use_consumable(data: ConsumableData) -> bool:
	match data.id:
		"[your_consumable_id]":
			# Return true/false based on game state
			# Example: return game_controller.scorecard.has_any_scores()
			return true
		_:
			return true  # Default: all consumables are useable
```

### Step 9: Testing
1. **Debug Panel Testing**:
   - Press F12 to open debug panel
   - Use "Grant [Name]" button to add consumable
   - Test usability and effect

2. **Scene Testing**:
   - Create test scene in `Tests/` folder
   - Add GameController and UI components
   - Test consumable in isolation

3. **Integration Testing**:
   - Play full game loop
   - Purchase consumable in shop
   - Verify proper behavior in real gameplay

### Step 10: Documentation
Update `README.md` with:
- New consumable description
- Usage instructions
- Any special mechanics

## Common Patterns and Examples

### Pattern 1: Game State Modification
```gdscript
func apply(target) -> void:
	var game_controller = target as GameController
	var turn_tracker = game_controller.turn_tracker
	turn_tracker.rolls_left += 3
	turn_tracker.emit_signal("rolls_updated", turn_tracker.rolls_left)
```

### Pattern 2: Score Manipulation
```gdscript
func apply(target) -> void:
	var game_controller = target as GameController
	var scorecard = game_controller.scorecard
	# Modify scores or scoring rules
```

### Pattern 3: Economy Interaction
```gdscript
func apply(target) -> void:
	var player_economy = get_node("/root/PlayerEconomy")
	player_economy.add_money(100)
```

### Pattern 4: UI State Changes
```gdscript
func apply(target) -> void:
	var game_controller = target as GameController
	# Enable special UI modes or states
	game_controller.score_card_ui.activate_special_mode()
```

## Troubleshooting

### Common Issues:
1. **Consumable not appearing in game**: Check ConsumableManager registration
2. **Script errors**: Verify class_name and extends declarations
3. **Icon not showing**: Check file path and import settings
4. **Apply() not working**: Verify GameController cast and system access
5. **Usability issues**: Check _can_use_consumable() logic

### Debug Tips:
- Use F12 debug panel for rapid testing
- Check console output for error messages
- Use print statements liberally during development
- Test edge cases (no scores, max rolls, etc.)

## Integration Checklist

Before considering a consumable complete:

- [ ] Script created with proper class_name
- [ ] Scene file created and saved
- [ ] Data resource created with all fields
- [ ] Icon asset added and imported
- [ ] Registered in ConsumableManager
- [ ] Added to GameController logic
- [ ] Debug command created (optional)
- [ ] Usability logic implemented (if needed)
- [ ] Tested via debug panel
- [ ] Tested in full game
- [ ] Documentation updated

## Architecture Notes

### Consumable Lifecycle:
1. **Instantiation**: ConsumableManager creates instance from scene
2. **Registration**: GameController stores in active_consumables
3. **UI Creation**: ConsumableUI creates spine/icon display
4. **Usage**: Player clicks → ConsumableUI → GameController → apply()
5. **Cleanup**: Consumable removed from active list and UI

### Key Systems Integration:
- **ScoreModifierManager**: For score bonuses/multipliers
- **PlayerEconomy**: For money transactions
- **TurnTracker**: For roll modifications
- **Scorecard**: For score manipulation
- **UI Systems**: For state changes and feedback

### Signal Flow:
```
ConsumableIcon → ConsumableUI → GameController → Consumable.apply()
                    ↓
              System Modifications
                    ↓
              UI Updates via Signals
```

This guide should be sufficient to create any new consumable in the DiceRogue system!