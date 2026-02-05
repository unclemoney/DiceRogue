extends Node2D
class_name DiceHand

const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")
const DiceAreaContainerClass = preload("res://Scripts/UI/dice_area_container.gd")

signal roll_started
signal roll_complete
signal dice_spawned
signal die_locked(die)
signal all_dice_exited

@export var roll_delay: float = 0.1
@export var roll_duration: float = 0.5
@export var dice_scene:      PackedScene
@export var dice_count:      int     = 5
@export var spacing:         float   = 80.0
@export var row_spacing:     float   = 90.0
@export var max_dice_per_row: int    = 8

## Area configuration - dice will be centered in this area
@export var dice_area_center: Vector2 = Vector2(640, 200)
@export var dice_area_size:   Vector2 = Vector2(680, 200)

## Legacy start_position - still used as fallback
@export var start_position:  Vector2 = Vector2(100, 200)

## Animation configuration
@export var entry_duration:  float = 0.4
@export var exit_duration:   float = 0.3
@export var animation_stagger: float = 0.05
@export var exit_distance:   float = 500.0

@export var default_dice_data: DiceData
@export var d6_dice_data: DiceData = preload("res://Scripts/Dice/d6_dice.tres")
@export var d4_dice_data: DiceData = preload("res://Scripts/Dice/d4_dice.tres")
@export var roll_sound: AudioStreamWAV

# Add debug state tracking
var current_dice_type: String = "d6"

var dice_list: Array[Dice] = []
var _pending_exit_count: int = 0

# Roll tracking for audio pitch progression (resets after scoring)
var current_roll_number: int = 0

@onready var roll_audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

## _ready()
##
## Initialize the DiceHand scene, validate DiceData assets, and prepare audio player.
func _ready() -> void:
	print("\n=== DiceHand Initializing ===")
	print("[DiceHand] dice_area_center:", dice_area_center)
	print("[DiceHand] dice_area_size:", dice_area_size)
	print("[DiceHand] start_position (legacy):", start_position)
	
	# Add to group for easy finding
	add_to_group("dice_hand")
	print("[DiceHand] Added to 'dice_hand' group")

	if not d6_dice_data:
		push_error("[DiceHand] D6 dice data not assigned!")
		return

	if not d4_dice_data:
		push_error("[DiceHand] D4 dice data not assigned!")
		return

	if d6_dice_data.sides != 6:
		push_error("[DiceHand] D6 data has incorrect number of sides:", d6_dice_data.sides)
		return

	if d4_dice_data.sides != 4:
		push_error("[DiceHand] D4 data has incorrect number of sides:", d4_dice_data.sides)
		return

	## Add AudioStreamPlayer as a child if not already present
	if not has_node("RollAudioPlayer"):
		roll_audio_player.name = "RollAudioPlayer"
		add_child(roll_audio_player)

	# Update visual reference rectangle to match dice_area settings
	_update_dice_area_visual()

	# Start with D6 dice by default
	switch_dice_type("d6")


## spawn_dice()
##
## Spawns the configured number of dice with centered positioning and varied entry animations.
## Honors any active lock debuff by disabling input after spawn.
func spawn_dice() -> void:
	if not default_dice_data:
		push_error("[DiceHand] Cannot spawn dice - no default DiceData assigned!")
		return

	# Clear existing dice first
	print("[DiceHand] Clearing existing dice before spawn. Current count:", dice_list.size())
	clear_dice()
	await get_tree().process_frame  # Wait for dice to be fully removed

	print("[DiceHand] Spawning", dice_count, "dice of type:", current_dice_type)
	print("[DiceHand] max_dice_per_row:", max_dice_per_row)
	print("[DiceHand] dice_area_center:", dice_area_center)
	print("[DiceHand] dice_area_size:", dice_area_size)

	# Calculate centered positions for all dice
	var positions = _calculate_centered_positions(dice_count)
	print("[DiceHand] Calculated", positions.size(), "positions for", dice_count, "dice")
	if positions.size() > 0:
		print("[DiceHand] First position:", positions[0], "Last position:", positions[positions.size()-1])

	for i in range(dice_count):
		var die = dice_scene.instantiate() as Dice
		if die:
			die.dice_data = default_dice_data
			add_child(die)
			# Connect die's lock signal to re-emit at DiceHand level
			if not die.is_connected("die_locked", Callable(self, "_on_child_die_locked")):
				die.die_locked.connect(Callable(self, "_on_child_die_locked"))
			
			# Use centered position from calculated array
			die.home_position = positions[i]
			
			# Get varied entry animation starting position
			var entry_offset = _get_entry_offset(i, dice_count)
			var start_pos = die.home_position + entry_offset
			
			die.position = start_pos
			die.reset_visual_for_spawn()
			
			# Stagger the animations
			var stagger_delay = i * animation_stagger
			_animate_die_entry_delayed(die, start_pos, stagger_delay)
			
			dice_list.append(die)
			print("[DiceHand] Spawned die", i + 1, "- home_position:", die.home_position, "start_pos:", start_pos, "current position:", die.position)

	print("[DiceHand] Spawn complete. Total dice in scene:", get_child_count(), "Total dice in dice_list:", dice_list.size())
	emit_signal("dice_spawned")

	# Set all dice to ROLLABLE state initially
	set_all_dice_rollable()

	# Re-emit child's die_locked as DiceHand-level die_locked signal
	# (some power-ups listen on DiceHand for lock events)

	# Only disable dice if lock debuff is active
	var lock_debuff = get_tree().get_first_node_in_group("debuffs") as LockDiceDebuff
	if lock_debuff and lock_debuff.is_active:
		print("[DiceHand] Found active lock debuff - disabling all dice input")
		disable_all_dice()
	else:
		print("[DiceHand] No active lock debuff - enabling all dice input")
		enable_all_dice()


## _update_dice_area_visual()
##
## Updates the DiceAreaVisual ReferenceRect to match dice_area_center and dice_area_size.
## This provides visual feedback for positioning adjustments.
func _update_dice_area_visual() -> void:
	var visual = get_node_or_null("DiceAreaVisual")
	if visual and visual is ReferenceRect:
		var half_width = dice_area_size.x / 2.0
		var half_height = dice_area_size.y / 2.0
		
		visual.offset_left = dice_area_center.x - half_width
		visual.offset_top = dice_area_center.y - half_height
		visual.offset_right = dice_area_center.x + half_width
		visual.offset_bottom = dice_area_center.y + half_height
		
		print("[DiceHand] Updated DiceAreaVisual to bounds: (", visual.offset_left, ",", visual.offset_top, ") to (", visual.offset_right, ",", visual.offset_bottom, ")")


## _animate_die_entry_delayed(die: Dice, from_pos: Vector2, delay: float)
##
## Animates die entry with a staggered delay.
func _animate_die_entry_delayed(die: Dice, from_pos: Vector2, delay: float) -> void:
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	# Check if die is still valid after delay
	if not is_instance_valid(die):
		return
	die.animate_entry(from_pos, entry_duration)


## _calculate_centered_positions(count: int) -> Array[Vector2]
##
## Calculates centered positions for dice based on count.
## Supports up to 16 dice in 2 rows, with balanced distribution (9 → 5 top, 4 bottom).
func _calculate_centered_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	if count <= 0:
		return positions
	
	var clamped_count = mini(count, max_dice_per_row * 2)
	
	# Calculate row distribution (balanced: 9 dice → 5 top, 4 bottom)
	var top_row_count: int = 0
	var bottom_row_count: int = 0
	
	if clamped_count <= max_dice_per_row:
		top_row_count = clamped_count
		bottom_row_count = 0
		print("[DiceHand] Single row layout:", top_row_count, "dice")
	else:
		# Balanced distribution: larger half on top
		top_row_count = ceili(clamped_count / 2.0)
		bottom_row_count = clamped_count - top_row_count
		print("[DiceHand] Multi-row layout:", top_row_count, "top,", bottom_row_count, "bottom")
	
	var center_x = dice_area_center.x
	var center_y = dice_area_center.y
	
	# Calculate vertical offset for multi-row
	var total_height = row_spacing if bottom_row_count > 0 else 0.0
	var start_y = center_y - (total_height / 2.0)
	
	# Generate top row positions (centered)
	var top_row_width = (top_row_count - 1) * spacing
	var top_start_x = center_x - (top_row_width / 2.0)
	
	for i in range(top_row_count):
		var pos = Vector2(top_start_x + i * spacing, start_y)
		positions.append(pos)
	
	# Generate bottom row positions (centered)
	if bottom_row_count > 0:
		var bottom_row_width = (bottom_row_count - 1) * spacing
		var bottom_start_x = center_x - (bottom_row_width / 2.0)
		
		for i in range(bottom_row_count):
			var pos = Vector2(bottom_start_x + i * spacing, start_y + row_spacing)
			positions.append(pos)
	
	return positions


## _get_entry_offset(index: int, total_count: int) -> Vector2
##
## Returns a varied entry offset for the die at the given index.
## Creates visual variety with dice entering from different directions.
func _get_entry_offset(index: int, total_count: int) -> Vector2:
	var distance = 400.0
	
	# For small counts, use simpler patterns
	if total_count <= 4:
		match index % 4:
			0: return Vector2(-distance * 0.707, -distance * 0.707)  # Top-left
			1: return Vector2(distance * 0.707, -distance * 0.707)   # Top-right
			2: return Vector2(-distance * 0.707, distance * 0.707)   # Bottom-left
			3: return Vector2(distance * 0.707, distance * 0.707)    # Bottom-right
	elif total_count <= 8:
		# Single row: alternate directions
		match index % 4:
			0: return Vector2(-distance, 0)      # Left
			1: return Vector2(distance, 0)       # Right
			2: return Vector2(0, -distance)      # Top
			3: return Vector2(0, distance)       # Bottom
	else:
		# Two rows: top row from top, bottom row from bottom
		var top_row_count = ceili(total_count / 2.0)
		if index < top_row_count:
			# Top row dice - come from top
			if index % 2 == 0:
				return Vector2(-distance * 0.707, -distance * 0.707)  # Top-left
			else:
				return Vector2(distance * 0.707, -distance * 0.707)   # Top-right
		else:
			# Bottom row dice - come from bottom
			if index % 2 == 0:
				return Vector2(-distance * 0.707, distance * 0.707)   # Bottom-left
			else:
				return Vector2(distance * 0.707, distance * 0.707)    # Bottom-right
	
	return Vector2(-distance, 0)


## _get_exit_offset(index: int, total_count: int) -> Vector2
##
## Returns exit offset (opposite of entry direction).
func _get_exit_offset(index: int, total_count: int) -> Vector2:
	# Exit in opposite direction of entry
	var entry = _get_entry_offset(index, total_count)
	return -entry * (exit_distance / 400.0)


## animate_all_dice_exit()
##
## Animates all dice exiting the screen with varied directions.
## Emits all_dice_exited when complete.
func animate_all_dice_exit() -> void:
	if dice_list.is_empty():
		emit_signal("all_dice_exited")
		return
	
	_pending_exit_count = dice_list.size()
	print("[DiceHand] Starting exit animation for", _pending_exit_count, "dice")
	
	for i in range(dice_list.size()):
		var die = dice_list[i]
		var exit_offset = _get_exit_offset(i, dice_list.size())
		var exit_pos = die.position + exit_offset
		
		# Connect to exit complete signal
		if not die.is_connected("exit_complete", _on_die_exit_complete):
			die.exit_complete.connect(_on_die_exit_complete)
		
		# Stagger exit animations
		var stagger_delay = i * animation_stagger
		_animate_die_exit_delayed(die, exit_pos, stagger_delay)


## _animate_die_exit_delayed(die: Dice, to_pos: Vector2, delay: float)
##
## Animates die exit with a staggered delay.
func _animate_die_exit_delayed(die: Dice, to_pos: Vector2, delay: float) -> void:
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	
	# Check if die still exists before animating
	if is_instance_valid(die) and not die.is_queued_for_deletion():
		die.animate_exit(to_pos, exit_duration)
	else:
		print("[DiceHand] Skipping exit animation for freed die")
		_pending_exit_count -= 1


## _on_die_exit_complete(_die: Dice)
##
## Called when a die finishes its exit animation.
func _on_die_exit_complete(_die: Dice) -> void:
	_pending_exit_count -= 1
	if _pending_exit_count <= 0:
		print("[DiceHand] All dice exit animations complete")
		# Clear the dice after exit animation so they can be respawned
		clear_dice()
		print("[DiceHand] Cleared dice after exit animation")
		emit_signal("all_dice_exited")



## roll_all()
##
## Rolls every die in `dice_list` that can be rolled (not locked). 
## Plays per-die roll sounds via AudioManager with pitch progression.
## Emits `roll_complete` when finished.
func roll_all() -> void:
	if dice_list.size() == 0:
		return

	# Increment roll number for audio pitch progression
	current_roll_number += 1

	print("\n=== Rolling All Dice (Roll #%d) ===" % current_roll_number)
	print("[DiceHand] Current dice type:", current_dice_type.to_upper())
	print("[DiceHand] Number of dice:", dice_list.size())

	var rolled_count = 0
	for i in range(dice_list.size()):
		var die = dice_list[i]
		if die.can_roll():
			# Play per-die roll sound via AudioManager with slight stagger
			if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
				var audio_mgr = get_node_or_null("/root/AudioManager")
				if audio_mgr:
					# Stagger sound by roll_delay * die index for natural feel
					var delay = rolled_count * roll_delay * 0.3
					if delay > 0:
						get_tree().create_timer(delay).timeout.connect(
							func(): audio_mgr.play_dice_roll(i, current_roll_number)
						)
					else:
						audio_mgr.play_dice_roll(i, current_roll_number)
			die.roll()
			rolled_count += 1
			print("[DiceHand] Die", i + 1, "rolled:", die.value, "- now in state:", die.get_state_name())
		else:
			print("[DiceHand] Die", i + 1, "skipped (state:", die.get_state_name(), ")")

	print("[DiceHand] Rolled", rolled_count, "out of", dice_list.size(), "dice")
	_update_results()
	emit_signal("roll_complete")

func _on_child_die_locked(die: Dice) -> void:
	emit_signal("die_locked", die)


## _update_results()
##
## Updates the global DiceResults singleton using the current dice_list.
func _update_results() -> void:
	# Direct call to the autoloaded singleton
	DiceResults.update_from_dice(dice_list)


## clear_dice()
##
## Frees all child dice nodes and clears the internal dice_list.
func clear_dice() -> void:
	for die in dice_list:
		die.queue_free()
	dice_list.clear()


## get_current_dice_values() -> Array[int]
##
## Returns an array of current face values for each die in `dice_list`.
func get_current_dice_values() -> Array[int]:
	var arr: Array[int] = []
	for die in dice_list:
		arr.append(die.value)
	return arr


## update_dice_count()
##
## Ensures that the number of active dice in the scene matches the exported `dice_count`.
## Uses centered positioning for any new dice added.
func update_dice_count() -> void:
	var current_count = dice_list.size()

	if current_count == dice_count:
		return

	# Recalculate all positions for the new count
	var new_positions = _calculate_centered_positions(dice_count)

	if current_count < dice_count:
		# Update positions for existing dice first
		for i in range(current_count):
			dice_list[i].home_position = new_positions[i]
			# Animate to new position
			var tween = get_tree().create_tween()
			tween.tween_property(dice_list[i], "position", new_positions[i], 0.3)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_OUT)
		
		# Add more dice
		for i in range(current_count, dice_count):
			var die = dice_scene.instantiate() as Dice
			add_child(die)
			# Connect die lock signal
			if not die.is_connected("die_locked", Callable(self, "_on_child_die_locked")):
				die.die_locked.connect(Callable(self, "_on_child_die_locked"))
			die.home_position = new_positions[i]
			
			# Get varied entry position
			var entry_offset = _get_entry_offset(i, dice_count)
			var start_pos = die.home_position + entry_offset
			
			die.position = start_pos
			die.reset_visual_for_spawn()
			
			# Stagger animation
			var stagger_delay = (i - current_count) * animation_stagger
			_animate_die_entry_delayed(die, start_pos, stagger_delay)
			
			dice_list.append(die)
	else:
		# Remove excess dice
		for i in range(dice_count, current_count):
			var die = dice_list.pop_back()
			die.queue_free()
		
		# Update positions for remaining dice
		for i in range(dice_count):
			dice_list[i].home_position = new_positions[i]
			var tween = get_tree().create_tween()
			tween.tween_property(dice_list[i], "position", new_positions[i], 0.3)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_OUT)

func enable_all_dice() -> void:
	print("[DiceHand] Enabling all dice (legacy method - state machine should handle this)")
	# Note: With state machine, dice input is controlled by their state
	# This function is kept for compatibility with debuffs, but should not override state machine
	for die in get_children():
		if die is Dice:
			# Only enable input if the dice is not in DISABLED state
			if die.get_state() != Dice.DiceState.DISABLED:
				die.set_dice_input_enabled(true)
			die.set_lock_shader_enabled(true)


## disable_locking_only()
##
## Disables lock/unlock input without changing dice states.
## Dice remain scoreable in ROLLED/LOCKED states. Used by Lock Dice Debuff.
func disable_locking_only() -> void:
	print("[DiceHand] Disabling locking only (dice remain scoreable)")
	for die in dice_list:
		if die is Dice:
			die.set_lock_shader_enabled(false)
			die.set_dice_input_enabled(false)


## restore_locking()
##
## Restores lock/unlock input after debuff expires.
## Re-enables input and lock shader for dice that are still scoreable.
func restore_locking() -> void:
	print("[DiceHand] Restoring locking ability")
	for die in dice_list:
		if die is Dice:
			# Only restore input for dice that aren't disabled
			if die.get_state() != Dice.DiceState.DISABLED:
				die.set_dice_input_enabled(true)
			die.set_lock_shader_enabled(true)


func disable_all_dice() -> void:
	print("[DiceHand] Disabling all dice (legacy method)")
	# Note: With state machine, this should call set_all_dice_disabled() instead
	for die in get_children():
		if die is Dice:
			# Transition to DISABLED state instead of manual input disabling
			die.make_disabled()

## State Machine Management Methods

## set_all_dice_rollable()
##
## Sets all dice to ROLLABLE state for the start of a new turn.
func set_all_dice_rollable() -> void:
	print("[DiceHand] Setting all dice to ROLLABLE state")
	for die in dice_list:
		if die is Dice:
			die.make_rollable()


## reset_roll_count()
##
## Resets the roll counter after scoring. Called when a category is scored
## to ensure pitch progression restarts for the next turn.
func reset_roll_count() -> void:
	current_roll_number = 0
	print("[DiceHand] Roll count reset to 0")


## set_all_dice_disabled()
##
## Sets all dice to DISABLED state after scoring.
func set_all_dice_disabled() -> void:
	print("[DiceHand] Setting all dice to DISABLED state")
	for die in dice_list:
		if die is Dice:
			die.make_disabled()

## prepare_dice_for_roll()
##
## Sets ROLLED and DISABLED dice back to ROLLABLE for subsequent rolls, preserving LOCKED dice.
## Use this before each roll within a turn (not set_all_dice_rollable).
func prepare_dice_for_roll() -> void:
	print("[DiceHand] Preparing dice for roll - preserving locks")
	for die in dice_list:
		if die is Dice:
			if die.current_state == Dice.DiceState.ROLLED:
				die.make_rollable()
				print("[DiceHand] Set die to rollable (was ROLLED)")
			elif die.current_state == Dice.DiceState.DISABLED:
				die.make_rollable()
				print("[DiceHand] Set die to rollable (was DISABLED)")
			elif die.current_state == Dice.DiceState.LOCKED:
				print("[DiceHand] Preserving locked die")
			else:
				print("[DiceHand] Die already in state:", die.get_state_name())

## can_any_dice_roll() -> bool
##
## Returns true if any dice can be rolled (are in ROLLABLE state).
func can_any_dice_roll() -> bool:
	for die in dice_list:
		if die is Dice and die.can_roll():
			return true
	return false

## can_any_dice_score() -> bool
##
## Returns true if any dice can be used for scoring (ROLLED or LOCKED states).
func can_any_dice_score() -> bool:
	for die in dice_list:
		if die is Dice and die.can_score():
			return true
	return false

## get_dice_in_state(state: Dice.DiceState) -> Array[Dice]
##
## Returns all dice currently in the specified state.
func get_dice_in_state(state: Dice.DiceState) -> Array[Dice]:
	var result: Array[Dice] = []
	for die in dice_list:
		if die is Dice and die.get_state() == state:
			result.append(die)
	return result

## print_dice_states()
##
## Debug function to print the current state of all dice.
func print_dice_states() -> void:
	print("[DiceHand] Current dice states:")
	for i in range(dice_list.size()):
		var die = dice_list[i]
		if die is Dice:
			print("  Die ", i, ": ", die.get_state_name(), " (value: ", die.value, ")")

## Lock a specific die and emit die_locked signal
func lock_die(die: Dice) -> void:
	if die is Dice and not die.is_locked:
		die.lock()
		emit_signal("die_locked", die)

func roll_unlocked_dice() -> void:
	var unlocked = get_unlocked_dice()
	if unlocked.is_empty():
		print("[DiceHand] No unlocked dice to roll")
		return
		
	print("\n=== Rolling Unlocked Dice ===")
	print("[DiceHand] Current dice type:", current_dice_type.to_upper())
	print("[DiceHand] Unlocked dice count:", unlocked.size())
	
	for i in range(unlocked.size()):
		var die = unlocked[i]
		die.roll()
		print("[DiceHand] Unlocked die", i + 1, "rolled:", die.value)
		await get_tree().create_timer(roll_delay).timeout
	
	await get_tree().create_timer(roll_duration).timeout
	emit_signal("roll_complete")

# Get all unlocked dice and return as an array
func get_unlocked_dice() -> Array[Dice]:
	var unlocked: Array[Dice] = []
	for die in dice_list:
		if die is Dice and not die.is_locked:
			unlocked.append(die)
	return unlocked

# Replace both switch_to_d4() and switch_to_d6() with this single function
func switch_dice_type(type: String) -> void:
	print("\n=== Switching to", type.to_upper(), "Dice ===")
	
	# Get the appropriate dice data based on type
	var new_dice_data: DiceData
	match type.to_lower():
		"d4":
			if not d4_dice_data:
				push_error("[DiceHand] D4 dice data not assigned!")
				return
			new_dice_data = d4_dice_data
		"d6":
			if not d6_dice_data:
				push_error("[DiceHand] D6 dice data not assigned!")
				return
			new_dice_data = d6_dice_data
		_:
			push_error("[DiceHand] Unknown dice type:", type)
			return
	
	default_dice_data = new_dice_data
	current_dice_type = type.to_lower()
	
	for i in range(dice_list.size()):
		var die = dice_list[i]
		die.dice_data = new_dice_data
		die.value = 1  # Reset to first face
		die.update_visual()
		print("[DiceHand] Updated die", i + 1, "to", type.to_upper())
	
	print("[DiceHand] Successfully switched to", type.to_upper(), "dice")

func roll_dice() -> void:
	print("▶ Rolling dice...")
	emit_signal("roll_started")
	

## Get all dice with a specific color
## @param color_type: DiceColorClass.Type to filter by
## @return Array[Dice] of dice with the specified color
func get_dice_by_color(color_type: DiceColorClass.Type) -> Array[Dice]:
	var colored_dice: Array[Dice] = []
	for die in dice_list:
		if die is Dice and die.get_color() == color_type:
			colored_dice.append(die)
	return colored_dice

## Get count of dice for each color type
## @return Dictionary with color counts
func get_color_counts() -> Dictionary:
	var counts = {
		"green": 0,
		"red": 0,
		"purple": 0,
		"none": 0
	}
	
	for die in dice_list:
		if not die is Dice:
			continue
			
		match die.get_color():
			DiceColorClass.Type.GREEN:
				counts["green"] += 1
			DiceColorClass.Type.RED:
				counts["red"] += 1
			DiceColorClass.Type.PURPLE:
				counts["purple"] += 1
			DiceColorClass.Type.NONE:
				counts["none"] += 1
	
	return counts

## Check if hand has 5 or more dice of the same color (for bonus)
## @return bool true if 5+ same color bonus should apply
func has_same_color_bonus() -> bool:
	var counts = get_color_counts()
	return counts["green"] >= 5 or counts["red"] >= 5 or counts["purple"] >= 5

## Get dice color effects for scoring
## @return Dictionary with color effects from DiceColorManager
func get_color_effects() -> Dictionary:
	var color_manager = _get_dice_color_manager()
	if color_manager:
		return color_manager.calculate_color_effects(get_all_dice())
	else:
		# Return empty effects if manager not found
		return {
			"green_money": 0,
			"red_additive": 0,
			"purple_multiplier": 1.0,
			"blue_score_multiplier": 1.0,
			"same_color_bonus": false,
			"green_count": 0,
			"red_count": 0,
			"purple_count": 0,
			"blue_count": 0
		}

## Get DiceColorManager safely
## @return DiceColorManager node or null if not found
func _get_dice_color_manager():
	if get_tree():
		var manager = get_tree().get_first_node_in_group("dice_color_manager")
		if manager:
			return manager
		
		# Fallback: try to find autoload directly
		var autoload_node = get_node_or_null("/root/DiceColorManager")
		if autoload_node:
			return autoload_node
	
	return null

## Force all dice to specific color (debug function)
## @param color_type: DiceColorClass.Type to set all dice to
func debug_force_all_colors(color_type: DiceColorClass.Type) -> void:
	for die in dice_list:
		if die is Dice:
			die.force_color(color_type)
	print("[DiceHand] DEBUG: Set all dice to ", DiceColorClass.get_color_name(color_type))

## Clear all dice colors (debug function)
func debug_clear_all_colors() -> void:
	for die in dice_list:
		if die is Dice:
			die.clear_color()
	print("[DiceHand] DEBUG: Cleared all dice colors")

## Get all dice in the hand
## @return Array[Dice] all dice currently in the hand
func get_all_dice() -> Array[Dice]:
	return dice_list
