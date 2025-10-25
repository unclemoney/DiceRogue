# Building PowerUps in DiceRogue

This document provides a comprehensive guide for creating new PowerUps in the DiceRogue game. PowerUps are persistent effects that modify gameplay mechanics, provide bonuses, or alter game behavior throughout the game session.

## Overview

A PowerUp in DiceRogue consists of four main components:
1. **Script (.gd)** - The logic and behavior
2. **Scene (.tscn)** - The node structure
3. **Resource (.tres)** - The data definition
4. **Integration** - Adding to game systems

## Step-by-Step Process

### 1. Create the PowerUp Script

**Location:** `Scripts/PowerUps/[powerup_name]_power_up.gd`

**Template Structure:**
```gdscript
extends PowerUp
class_name [PowerUpName]PowerUp

# PowerUp-specific variables
var [relevant_variables]: [type] = [default_value]

# Reference to target (usually scorecard, dice_hand, or turn_tracker)
var [target]_ref: [TargetType] = null

# Signal for dynamic description updates (optional)
signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[%s] Added to 'power_ups' group" % get_class())

func apply(target) -> void:
	print("=== Applying %s ===" % get_class())
	var [target_var] = target as [TargetType]
	if not [target_var]:
		push_error("[%s] Target is not a [TargetType]" % get_class())
		return
	
	# Store reference
	[target]_ref = [target_var]
	
	# Connect to relevant signals
	if not [target_var].is_connected("[signal_name]", _on_[signal_handler]):
		[target_var].[signal_name].connect(_on_[signal_handler])
		print("[%s] Connected to [signal_name] signal" % get_class())
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(target) -> void:
	print("=== Removing %s ===" % get_class())
	
	var [target_var]: [TargetType] = null
	if target is [TargetType]:
		[target_var] = target
	elif target == self:
		[target_var] = [target]_ref
	
	if [target_var]:
		# Disconnect signals
		if [target_var].is_connected("[signal_name]", _on_[signal_handler]):
			[target_var].[signal_name].disconnect(_on_[signal_handler])
	
	[target]_ref = null

func _on_[signal_handler]([parameters]) -> void:
	# Handle the signal and implement PowerUp logic
	pass

func get_current_description() -> String:
	# Return dynamic description based on current state
	return "[Base description]"

func _update_power_up_icons() -> void:
	# Update UI icons if description changes
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("[powerup_id]")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if [target]_ref:
		# Disconnect signals
		pass
```

**Key Requirements:**
- Extend `PowerUp` base class
- Implement `apply(target)` and `remove(target)` methods
- Add to "power_ups" group in `_ready()`
- Handle signal connections and cleanup properly
- Support dynamic descriptions if needed

### 2. Create the PowerUp Scene

**Location:** `Scenes/PowerUp/[PowerUpName].tscn`

**Content:**
```gdscene
[gd_scene load_steps=2 format=3 uid="uid://[unique_id]"]

[ext_resource type="Script" path="res://Scripts/PowerUps/[powerup_name]_power_up.gd" id="1_[reference]"]

[node name="[PowerUpName]" type="Node2D"]
script = ExtResource("1_[reference]")
id = "[powerup_id]"
```

**Requirements:**
- Root node should be Node2D
- Attach the PowerUp script
- Set the `id` property to the PowerUp's identifier

### 3. Create the PowerUp Resource

**Location:** `Scripts/PowerUps/[PowerUpName].tres`

**Content:**
```gdresource
[gd_resource type="Resource" script_class="PowerUpData" load_steps=4 format=3 uid="uid://[unique_id]"]

[ext_resource type="Texture2D" uid="uid://[icon_uid]" path="res://Resources/Art/Powerups/[icon_file].png" id="1_[icon_ref]"]
[ext_resource type="Script" uid="uid://b4upm4dbvhukm" path="res://Scripts/PowerUps/PowerUpData.gd" id="1_powerup_data"]
[ext_resource type="PackedScene" uid="uid://[scene_uid]" path="res://Scenes/PowerUp/[PowerUpName].tscn" id="2_[scene_ref]"]

[resource]
script = ExtResource("1_powerup_data")
id = "[powerup_id]"
display_name = "[Display Name]"
description = "[Description text]"
icon = ExtResource("1_[icon_ref]")
scene = ExtResource("2_[scene_ref]")
price = [price_value]
rarity = "[rarity_level]"
metadata/_custom_type_script = "uid://b4upm4dbvhukm"
```

**Rarity Options:**
- "common" (60% weight)
- "uncommon" (25% weight)  
- "rare" (10% weight)
- "epic" (4% weight)
- "legendary" (1% weight)

**Price Guidelines:**
- Common: 50-100
- Uncommon: 100-200
- Rare: 200-350
- Epic: 350-500
- Legendary: 500+

### 4. Integration with Game Systems

#### 4.1 Update GameController

**File:** `Scripts/Core/game_controller.gd`

**Required Changes:**

1. **Add to description_updated signal connection (if needed):**
```gdscript
# Connect to description_updated signal if the power-up has one
if power_up_id == "upper_bonus_mult" or power_up_id == "consumable_cash" or power_up_id == "evens_no_odds" or power_up_id == "[powerup_id]":
```

2. **Add to _activate_power_up match statement:**
```gdscript
"[powerup_id]":
	if [target]:
		pu.apply([target])
		print("[GameController] Applied [PowerUpName] to [target]")
	else:
		push_error("[GameController] No [target] available for [PowerUpName]")
```

3. **Add to _deactivate_power_up match statement:**
```gdscript
"[powerup_id]":
	print("[GameController] Removing [powerup_id] PowerUp")
	pu.remove([target])
```

4. **Add to revoke_power_up match statement:**
```gdscript
"[powerup_id]":
	pu.remove([target])
```

#### 4.2 Register with PowerUpManager

**File:** `Tests/DebuffTest.tscn` (main scene)

1. **Add external resource:**
```gdscene
[ext_resource type="Resource" uid="uid://[unique_id]" path="res://Scripts/PowerUps/[PowerUpName].tres" id="[next_id]_[reference]"]
```

2. **Add to power_up_defs array:**
```gdscene
power_up_defs = Array[ExtResource("17_2uvn1")]([..., ExtResource("[id]_[reference]"), ...])
```

### 5. Testing

#### 5.1 Debug Console Testing
1. Start the game
2. Open debug console
3. Use "Grant Random PowerUp" to test the PowerUp appears
4. Grant specific PowerUp by ID if needed

#### 5.2 Create Unit Tests (Optional)
**Location:** `Tests/[powerup_name]_test.gd`

**Template:**
```gdscript
extends Node
class_name [PowerUpName]Test

func _ready() -> void:
	print("\n=== [PowerUpName] Test Starting ===")
	await get_tree().create_timer(0.5).timeout
	_test_[functionality]()

func _test_[functionality]() -> void:
	print("\n--- Testing [functionality] ---")
	# Test implementation
	assert([condition], "[test description]")
	print("[PowerUpName]Test: ✓ [test passed]")
```

## Example Implementation: BonusMoneyPowerUp

The BonusMoneyPowerUp demonstrates a complete implementation:

**Features:**
- Grants $50 for each bonus achieved (Upper Section Bonus or Yahtzee Bonus)
- Connects to scorecard signals (`upper_bonus_achieved`, `yahtzee_bonus_achieved`)
- Updates description dynamically to show progress
- Properly manages PlayerEconomy integration

**Key Implementation Details:**
- Uses `PlayerEconomy.add_money(amount)` for money grants
- Tracks `total_bonuses_earned` for description updates
- Emits `description_updated` signal for UI updates
- Proper signal cleanup in `_on_tree_exiting()` and `remove()`

## Common Patterns

### 1. Scorecard-based PowerUps
**Target:** `scorecard`
**Common Signals:** `score_assigned`, `upper_bonus_achieved`, `yahtzee_bonus_achieved`

### 2. Dice-based PowerUps  
**Target:** `dice_hand`
**Common Signals:** `dice_rolled`, `dice_locked`

### 3. Turn-based PowerUps
**Target:** `turn_tracker`
**Common Signals:** `rolls_changed`, `turn_completed`

### 4. Economy PowerUps
**Target:** `self` (GameController)
**Integration:** `PlayerEconomy` singleton

## Checklist for New PowerUps

- [ ] Create PowerUp script with proper inheritance
- [ ] Implement apply() and remove() methods
- [ ] Create scene file with correct node structure
- [ ] Create resource file with all required properties
- [ ] Add to GameController activation system
- [ ] Add to main scene power_up_defs array
- [ ] Test via debug console
- [ ] Verify proper cleanup and signal disconnection
- [ ] Test description updates (if applicable)
- [ ] Verify integration with target systems
- [ ] Update documentation

## Troubleshooting

### PowerUp Not Appearing in Debug
- Check PowerUpManager.power_up_defs array includes your resource
- Verify resource file has correct id and scene reference
- Ensure scene file has proper script attachment

### PowerUp Not Activating
- Verify apply() method implementation
- Check GameController match statement includes your PowerUp ID
- Ensure target object is available and correct type

### Signals Not Working
- Verify signal connections in apply() method
- Check signal names match exactly
- Ensure proper cleanup in remove() method

### Description Not Updating
- Implement description_updated signal emission
- Add PowerUp ID to GameController signal connection list
- Verify _update_power_up_icons() implementation

### PowerUp Triggering Multiple Times
- Check if target signal is being emitted multiple times
- Add tracking variables to prevent duplicate execution
- Example: Use a flag like `bonus_awarded` to ensure single execution

### Debug Console Errors
- Ensure debug panel references use proper property access (e.g., `game_controller.dice_hand` not `game_controller.get("dice_hand")`)
- Verify all manager references are updated to use @onready variables

## ScoreModifierManager Integration & Logbook Visibility

**CRITICAL:** PowerUps that modify scores MUST use ScoreModifierManager to appear in the logbook's statistics panel.

### When to Use ScoreModifierManager

PowerUps should register with ScoreModifierManager if they:
- **Add points to scores** (additive modifiers)
- **Multiply score values** (multiplier modifiers)
- **Need to appear in logbook's "powerups_applied" list**

PowerUps that DON'T need ScoreModifierManager:
- Give money or resources (e.g., bonus_money, full_house)
- Modify dice behavior (e.g., extra_dice)
- Change game mechanics without affecting score values

### Global vs Conditional Registration

#### Global Registration (Most PowerUps)
Register once during apply(), stays active until removed:

```gdscript
func apply(target) -> void:
	# ... other setup code ...
	
	# Register with ScoreModifierManager
	ScoreModifierManager.register_additive("powerup_source_name", bonus_amount)
	# OR
	ScoreModifierManager.register_multiplier("powerup_source_name", multiplier_value)

func remove(target) -> void:
	# ... cleanup code ...
	
	# Unregister from ScoreModifierManager
	ScoreModifierManager.unregister_additive("powerup_source_name")
	# OR
	ScoreModifierManager.unregister_multiplier("powerup_source_name")
```

#### Conditional Registration (Advanced)
For PowerUps that only affect specific score categories (like StepByStep affecting only upper section):

```gdscript
# PowerUp applies only to upper section scores
func apply(target) -> void:
	var scorecard = target as Scorecard
	scorecard_ref = scorecard
	
	# Connect to about_to_score signal for conditional registration
	var score_card_ui = scorecard.get_tree().get_first_node_in_group("score_card_ui")
	if score_card_ui:
		score_card_ui.about_to_score.connect(_on_about_to_score)
	
	# Connect to score_assigned for cleanup
	scorecard.score_assigned.connect(_on_score_assigned)

func _on_about_to_score(section: Scorecard.Section, category: String, _dice_values: Array[int]) -> void:
	# Only register for upper section categories
	if section == Scorecard.Section.UPPER:
		ScoreModifierManager.register_additive("powerup_source_name", bonus_amount)
		print("[PowerUp] Registered additive for upper section category: ", category)

func _on_score_assigned(section: Scorecard.Section, category: String, _score: int) -> void:
	# Clean up after scoring completes
	if section == Scorecard.Section.UPPER:
		if ScoreModifierManager.has_additive("powerup_source_name"):
			ScoreModifierManager.unregister_additive("powerup_source_name")
			print("[PowerUp] Cleaned up additive after upper section scoring")
```

### Source Name Guidelines

Use consistent, descriptive source names:
- Use snake_case: `"step_by_step"`, `"green_monster"`, `"evens_no_odds"`
- Match PowerUp class name pattern: Remove "PowerUp" suffix and convert to snake_case
- Add to scorecard categorization list (see below)

### Logbook Integration Checklist

1. **✅ Use ScoreModifierManager:** Register additive/multiplier
2. **✅ Use proper source name:** Consistent naming convention
3. **✅ Update scorecard categorization:** Add source name to `_categorize_modifier_source()`
4. **✅ Test visibility:** Verify PowerUp appears in logbook statistics

### Adding to Scorecard Categorization

Edit `Scripts/ScoreCard/score_card.gd` and add your PowerUp source name:

```gdscript
func _categorize_modifier_source(source: String) -> String:
	var powerup_sources = [
		"green_monster", "evens_no_odds", "chance520", "foursome", 
		"highlighted_score", "step_by_step", "your_new_powerup"  # Add here
	]
	
	if source in powerup_sources:
		return "powerup"
	# ... rest of function
```

### Common Issues & Solutions

#### PowerUp Not Appearing in Logbook
1. **Check ScoreModifierManager registration:** Use `register_additive()` or `register_multiplier()`
2. **Verify source name:** Must be added to scorecard's powerup_sources list
3. **Test with debug:** Check `ScoreModifierManager.get_active_additive_sources()`

#### Conditional PowerUp Always/Never Registering
1. **Check signal connections:** Verify about_to_score and score_assigned signals
2. **Debug conditional logic:** Add print statements to verify section/category filtering
3. **Test cleanup:** Ensure modifiers are unregistered after scoring

#### Multiplier/Additive Value Wrong
1. **Check calculation logic:** Verify bonus amounts and multiplier values
2. **Test incremental updates:** For growing bonuses, ensure proper tracking
3. **Debug ScoreModifierManager:** Use debug panel to view active modifiers

## Best Practices

1. **Always test PowerUp cleanup** - Use remove() and verify no memory leaks
2. **Use descriptive variable names** - Make code self-documenting
3. **Add debug prints sparingly** - Only for critical debugging, remove for production
4. **Follow naming conventions** - snake_case for variables, PascalCase for classes
5. **Document complex logic** - Use Godot doc comments (##)
6. **Handle edge cases** - Check for null references and invalid states
7. **Test with multiple instances** - Ensure PowerUp works when granted multiple times
8. **Consider performance** - Avoid expensive operations in frequently called methods
9. **Prevent duplicate execution** - Use flags or tracking variables for one-time effects
10. **Keep console output clean** - Remove excessive print statements that clutter terminal output