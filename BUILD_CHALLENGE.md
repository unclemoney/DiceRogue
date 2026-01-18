# BUILD_CHALLENGE.md

This guide provides step-by-step instructions for creating new challenges in DiceRogue. Challenges are gameplay objectives that players must complete under specific conditions, often with debuffs active.

## Overview

A challenge consists of:
- **Challenge Script**: GDScript extending `Challenge` class with the logic
- **Challenge Scene**: Godot .tscn file containing the challenge node
- **Challenge Resource**: .tres file with challenge configuration and metadata
- **Round Resource**: .tres file for round-based challenge loading (optional)
- **Manager Registration**: Adding the challenge to the ChallengeManager's definitions
- **Debug Integration**: Optional debug panel buttons for testing

## File Structure

New challenges should follow this naming convention:
```
Scripts/Challenge/
├── your_challenge_name.gd           # Challenge script
├── your_challenge_name.tres         # Challenge resource
Scripts/Round/
├── your_challenge_name.tres         # Round config (for round-based loading)
Scenes/Challenge/
├── YourChallengeName.tscn           # Challenge scene
```

## Step 1: Create the Challenge Script

Create a new GDScript file in `Scripts/Challenge/` that extends the `Challenge` class.

### Template Structure:
```gdscript
extends Challenge
class_name YourChallengeName

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_id: String = "your_debuff_id"  # Optional: if challenge applies a debuff

func _ready() -> void:
	add_to_group("challenges")
	print("[YourChallengeName] Ready")

## apply(_target)
##
## Sets up the challenge requirements and applies any necessary debuffs.
## Connects to scorecard signals to track progress.
func apply(_target) -> void:
	_game_controller = _target as GameController
	if _game_controller:
		print("[YourChallengeName] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[YourChallengeName] Failed to get scorecard reference")
			return
			
		# Connect to score change signals
		if _scorecard.has_signal("score_changed"):
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[YourChallengeName] Connected to score_changed signal")
		else:
			push_error("[YourChallengeName] Scorecard does not have signal score_changed")
		
		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[YourChallengeName] Connected to game_completed signal")
		else:
			push_error("[YourChallengeName] Scorecard does not have signal game_completed")
		
		# Apply debuff if needed
		if not _debuff_id.is_empty():
			_game_controller.apply_debuff(_debuff_id)
			print("[YourChallengeName] Applied debuff:", _debuff_id)
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[YourChallengeName] Invalid target - expected GameController")

## remove()
##
## Cleans up the challenge by removing debuffs and disconnecting signals.
func remove() -> void:
	if _game_controller:
		# Remove debuff if applied
		if not _debuff_id.is_empty() and _game_controller.is_debuff_active(_debuff_id):
			_game_controller.disable_debuff(_debuff_id)
			print("[YourChallengeName] Disabled debuff:", _debuff_id)
		
		# Disconnect signals
		if _scorecard:
			if _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.disconnect("score_changed", _on_score_changed)
			if _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.disconnect("game_completed", _on_game_completed)

## get_progress()
##
## Returns the current progress as a float between 0.0 and 1.0.
func get_progress() -> float:
	if not _scorecard:
		return 0.0
		
	var current_score = _scorecard.get_total_score()
	return float(current_score) / float(_target_score)

## _update_progress()
##
## Updates and emits the current progress.
func _update_progress() -> void:
	var progress = get_progress()
	update_progress(progress)
	print("[YourChallengeName] Progress updated:", progress)

## _on_score_changed(total_score)
##
## Handles score change events to track progress and check for completion.
func _on_score_changed(total_score: int) -> void:
	print("[YourChallengeName] Score changed! New total:", total_score)
	_update_progress()
	
	# Check if target is reached
	if total_score >= _target_score:
		print("[YourChallengeName] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

## _on_game_completed()
##
## Handles game completion to determine if the challenge was successful.
func _on_game_completed() -> void:
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[YourChallengeName] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[YourChallengeName] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()


## set_target_score_from_resource(resource, _round_number)
##
## CRITICAL: Sets the target score from the ChallengeData resource.
## This method MUST be implemented or the challenge will have a target score of 0.
func set_target_score_from_resource(resource: ChallengeData, _round_number: int) -> void:
	if resource:
		_target_score = resource.target_score
		print("[YourChallengeName] Target score set from resource:", _target_score)
```

### Key Implementation Notes:
- Always use `_target` parameter in `apply()` to avoid shadowing the base class variable
- Use proper signal connection checks to avoid duplicate connections
- Include comprehensive logging for debugging
- **CRITICAL**: Always implement `set_target_score_from_resource()` or the challenge will have a target score of 0
- Clean up all connections and debuffs in `remove()`
- Track progress using scorecard signals

## Step 2: Create the Challenge Scene

Create a new scene file in `Scenes/Challenge/` with the following structure:

```gdscene
[gd_scene load_steps=2 format=3 uid="uid://unique_scene_id"]

[ext_resource type="Script" path="res://Scripts/Challenge/your_challenge_name.gd" id="1_your_id"]

[node name="YourChallengeName" type="Node"]
script = ExtResource("1_your_id")
```

### Scene Guidelines:
- Use a descriptive node name in PascalCase
- Generate a unique UID for the scene
- Keep the scene structure simple (usually just a Node with the script)

## Step 3: Create the Challenge Resource

Create a new .tres resource file in `Scripts/Challenge/` with challenge metadata:

```gdresource
[gd_resource type="Resource" script_class="ChallengeData" load_steps=4 format=3 uid="uid://unique_resource_id"]

[ext_resource type="Texture2D" uid="uid://icon_texture_id" path="res://Resources/Art/Icons/your_icon.png" id="1_icon"]
[ext_resource type="Script" uid="uid://f8jnl4x2x0gr" path="res://Scripts/Challenge/ChallengeData.gd" id="1_data"]
[ext_resource type="PackedScene" uid="uid://unique_scene_id" path="res://Scenes/Challenge/YourChallengeName.tscn" id="2_scene"]

[resource]
script = ExtResource("1_data")
id = "your_challenge_id"
display_name = "Challenge Display Name"
description = "Brief challenge description"
icon = ExtResource("1_icon")
scene = ExtResource("2_scene")
debuff_ids = Array[String](["debuff_id_if_any"])
target_score = 150
reward_money = 100
dice_type = "d6"
metadata/_custom_type_script = "uid://f8jnl4x2x0gr"
```

### Resource Configuration:
- **id**: Unique identifier used in code (snake_case)
- **display_name**: Player-facing name
- **description**: Brief explanation of the challenge
- **icon**: UI icon texture
- **scene**: Reference to the challenge scene
- **debuff_ids**: Array of debuffs that apply during this challenge
- **target_score**: Score needed to complete the challenge
- **reward_money**: Money awarded upon completion
- **dice_type**: Type of dice used (usually "d6")

## Step 4: Create Round Resource (Optional)

If you want your challenge to be loadable through the round management system, create a round configuration resource.

Create a new .tres file in `Scripts/Round/` with the same name as your challenge:

```gdresource
[gd_resource type="Resource" script_class="RoundChallengeConfig" load_steps=2 format=3 uid="uid://unique_round_id"]

[ext_resource type="Script" uid="uid://b41v75rm14duq" path="res://Scripts/Round/round_challenge_config.gd" id="1_round"]

[resource]
script = ExtResource("1_round")
challenge_id = "your_challenge_id"
description = "Brief round description"
metadata/_custom_type_script = "uid://b41v75rm14duq"
```

### Round Resource Configuration:
- **challenge_id**: Must match exactly the ID from your challenge resource
- **description**: Brief description for round management UI
- **Generate unique UID**: Each round resource needs a unique identifier

### Usage in Round Manager:
The round manager can load challenges using these round resources:
```gdscript
# In round data or round manager configuration
var round_config = preload("res://Scripts/Round/your_challenge_name.tres")
if round_config:
    round_manager.load_challenge(round_config.challenge_id)
```

## Step 5: Register in ChallengeManager

Add the new challenge to the appropriate scene files that use ChallengeManager.

### For Test Scenes:
1. Open the test scene file (e.g., `Tests/DebuffTest.tscn`)
2. Add an ExtResource declaration for your challenge resource:
   ```gdscene
   [ext_resource type="Resource" uid="uid://your_resource_id" path="res://Scripts/Challenge/your_challenge_name.tres" id="XX_your_ref"]
   ```
3. Add the ExtResource reference to the ChallengeManager's `challenge_defs` array:
   ```gdscene
   [node name="ChallengeManager" parent="." instance=ExtResource("25_3vaha")]
   challenge_defs = Array[ExtResource("26_si81o")]([ExtResource("27_1jk2k"), ..., ExtResource("XX_your_ref")])
   ```

### For Production:
Add similar ExtResource declarations and array entries to the main game scene or any scene that needs access to challenges.

## Step 6: Integrate with Game Controller

The game controller can activate challenges in several ways:

### Manual Activation:
```gdscript
# In _on_game_start() or other initialization methods
activate_challenge("your_challenge_id")
```

### Round-Based Activation:
```gdscript
# In round manager or round data configuration
# Using the round resource created in Step 4
var round_config = preload("res://Scripts/Round/your_challenge_name.tres")
if round_config and round_data.challenge_id == round_config.challenge_id:
    activate_challenge(round_config.challenge_id)
```

## Step 7: Add Debug Panel Integration (Optional)

For easier testing, add debug buttons to activate your challenge:

### 1. Add Button Definition:
In `Scripts/UI/debug_panel.gd`, add to the buttons array:
```gdscript
# Challenge Testing  
{"text": "Activate Your Challenge", "method": "_debug_activate_your_challenge"},
```

### 2. Implement Debug Method:
Add the corresponding method at the end of the debug panel script:
```gdscript
## _debug_activate_your_challenge()
##
## Activates Your Challenge for testing
func _debug_activate_your_challenge() -> void:
	log_debug("=== ACTIVATING YOUR CHALLENGE ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	var challenge_id = "your_challenge_id"
	
	if game_controller.active_challenges.has(challenge_id):
		log_debug("Your Challenge is already active")
		return
	
	game_controller.activate_challenge(challenge_id)
	log_debug("✓ Your Challenge activated!")
	log_debug("Target: " + str(target_score) + " points with [conditions]")
```

## Testing Your Challenge

### Basic Testing Checklist:
1. **Activation**: Challenge activates without errors
2. **Debuff Application**: Any specified debuffs are applied correctly
3. **Progress Tracking**: Progress updates as scores change
4. **Completion Detection**: Challenge completes when target is reached
5. **Cleanup**: Debuffs are removed when challenge ends
6. **UI Integration**: Challenge appears in challenge UI with correct info
7. **Round Integration**: Round resource loads the challenge correctly (if applicable)

### Debug Testing:
1. Open the debug panel (F12)
2. Use "Activate Your Challenge" button
3. Use "Show Active Challenges" to verify status
4. Test scoring to verify progress tracking
5. Verify challenge completion/failure states

### Manual Testing:
1. Run the test scene containing your challenge
2. Activate the challenge through game flow
3. Play through a game to test the complete experience
4. Verify rewards are granted on completion

### Round-Based Testing (if using round resource):
1. Configure your round resource in the round manager
2. Start a round that should load your challenge
3. Verify the challenge activates automatically when the round begins
4. Test the complete round flow from start to completion

## Common Patterns

### Score-Based Challenges:
Most challenges track total score and complete when a target is reached.

### Debuff Challenges:
Challenges that apply debuffs to make scoring more difficult.

### Conditional Challenges:
Challenges with specific scoring requirements (e.g., only certain combinations count).

### Timed Challenges:
Challenges that must be completed within a certain number of rounds or turns.

## Troubleshooting

### Common Issues:
1. **Signal Connection Errors**: Ensure scorecard exists before connecting signals
2. **Debuff Not Applied**: Verify debuff ID matches exactly
3. **Progress Not Updating**: Check if score_changed signal is being emitted
4. **Challenge Not Loading**: Verify all ExtResource UIDs are correct
5. **Completion Not Detected**: Ensure target_score is set correctly

### Debug Logs:
Enable comprehensive logging in your challenge script to track:
- Challenge activation
- Signal connections  
- Score changes
- Progress updates
- Completion/failure states

## Best Practices

1. **Naming Conventions**: Use snake_case for IDs, PascalCase for class names
2. **Error Handling**: Always check for null references before using them
3. **Signal Management**: Connect/disconnect signals properly to avoid memory leaks
4. **Logging**: Include detailed debug output for easier troubleshooting
5. **Documentation**: Use Godot doc comments (##) for all public methods
6. **Testing**: Test both success and failure conditions thoroughly
7. **UI Integration**: Ensure challenge works with the existing UI system

## Example Implementation

See `Scripts/Challenge/the_crossing_challenge.gd` for a complete example implementation that:
- Requires 150 points to complete
- Applies the "the_division" debuff (converts multipliers to dividers)
- Tracks progress through scorecard signals
- Properly cleans up when the challenge ends

**Associated Files:**
- **Challenge Script**: `Scripts/Challenge/the_crossing_challenge.gd`
- **Challenge Scene**: `Scenes/Challenge/TheCrossingChallenge.tscn`
- **Challenge Resource**: `Scripts/Challenge/the_crossing_challenge.tres`
- **Round Resource**: `Scripts/Round/the_crossing_challenge.tres` (for round-based loading)

This example demonstrates all the key concepts and can serve as a template for new challenges.