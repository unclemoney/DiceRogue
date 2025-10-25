extends Node2D
class_name DiceHand

const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")

# Add the missing signal
signal roll_started
signal roll_complete
signal dice_spawned
# Signal for when a die is locked
signal die_locked(die)

@export var roll_delay: float = 0.1
@export var roll_duration: float = 0.5
@export var dice_scene:      PackedScene
@export var dice_count:      int     = 5
@export var spacing:         float   = 80.0
@export var start_position:  Vector2 = Vector2(100, 200)

@export var default_dice_data: DiceData
@export var d6_dice_data: DiceData = preload("res://Scripts/Dice/d6_dice.tres")
@export var d4_dice_data: DiceData = preload("res://Scripts/Dice/d4_dice.tres")
@export var roll_sound: AudioStreamWAV

# Add debug state tracking
var current_dice_type: String = "d6"

var dice_list: Array[Dice] = []

@onready var roll_audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

## _ready()
##
## Initialize the DiceHand scene, validate DiceData assets, and prepare audio player.
func _ready() -> void:
	print("\n=== DiceHand Initializing ===")
	
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

	# Start with D6 dice by default
	switch_dice_type("d6")


## spawn_dice()
##
## Spawns the configured number of dice, initializes their data, and emits `dice_spawned`.
## Honors any active lock debuff by disabling input after spawn.
func spawn_dice() -> void:
	if not default_dice_data:
		push_error("[DiceHand] Cannot spawn dice - no default DiceData assigned!")
		return

	# Clear existing dice first
	clear_dice()

	print("[DiceHand] Spawning", dice_count, "dice of type:", current_dice_type)

	for i in range(dice_count):
		var die = dice_scene.instantiate() as Dice
		if die:
			die.dice_data = default_dice_data
			add_child(die)
			# Connect die's lock signal to re-emit at DiceHand level
			if not die.is_connected("die_locked", Callable(self, "_on_child_die_locked")):
				die.die_locked.connect(Callable(self, "_on_child_die_locked"))
			die.home_position = start_position + Vector2(i * spacing, 0)
			die.position = Vector2(-200, die.home_position.y)
			die.animate_entry(die.position)
			dice_list.append(die)
			print("[DiceHand] Spawned die", i + 1, "with", default_dice_data.sides, "sides")

	emit_signal("dice_spawned")

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



## roll_all()
##
## Rolls every die in `dice_list`. Plays roll sound and emits `roll_complete` when finished.
func roll_all() -> void:
	if dice_list.size() == 0:
		return

	# Play roll sound effect
	if roll_sound:
		roll_audio_player.stream = roll_sound
		roll_audio_player.play()

	print("\n=== Rolling All Dice ===")
	print("[DiceHand] Current dice type:", current_dice_type.to_upper())
	print("[DiceHand] Number of dice:", dice_list.size())

	for i in range(dice_list.size()):
		var die = dice_list[i]
		die.roll()
		print("[DiceHand] Die", i + 1, "rolled:", die.value)

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
func update_dice_count() -> void:
	var current_count = dice_list.size()

	if current_count == dice_count:
		return

	if current_count < dice_count:
		# Add more dice
		for i in range(current_count, dice_count):
			var die = dice_scene.instantiate() as Dice
			add_child(die)
			# Connect die lock signal
			if not die.is_connected("die_locked", Callable(self, "_on_child_die_locked")):
				die.die_locked.connect(Callable(self, "_on_child_die_locked"))
			die.home_position = start_position + Vector2(i * spacing, 0)
			die.position = Vector2(-200, die.home_position.y)
			die.animate_entry(die.position)
			dice_list.append(die)
	else:
		# Remove excess dice
		for i in range(dice_count, current_count):
			var die = dice_list.pop_back()
			die.queue_free()

func enable_all_dice() -> void:
	print("[DiceHand] Enabling all dice")
	for die in get_children():
		if die is Dice:
			die.set_dice_input_enabled(true)
			die.set_lock_shader_enabled(true)
			#print("[DiceHand] Enabled die:", die.name)


func disable_all_dice() -> void:
	print("[DiceHand] Disabling all dice")
	for die in get_children():
		if die is Dice:
			die.unlock()  # Force unlock
			die.set_dice_input_enabled(false)
			if die.has_method("set_lock_shader_enabled"):
				die.set_lock_shader_enabled(false)

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

# Add this function
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
	
	# Rest of your existing roll_dice function...

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
		return color_manager.calculate_color_effects(dice_list)
	else:
		# Return empty effects if manager not found
		return {
			"green_money": 0,
			"red_additive": 0,
			"purple_multiplier": 1.0,
			"same_color_bonus": false,
			"green_count": 0,
			"red_count": 0,
			"purple_count": 0
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
