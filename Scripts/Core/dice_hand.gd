extends Node2D
class_name DiceHand

signal roll_complete

@export var roll_delay: float = 0.1
@export var roll_duration: float = 0.5
@export var dice_scene:      PackedScene
@export var dice_count:      int     = 5
@export var spacing:         float   = 80.0
@export var start_position:  Vector2 = Vector2(100, 200)

var dice_list: Array[Dice] = []

func spawn_dice() -> void:
	clear_dice()
	update_dice_count()
	
	# Only disable dice if lock debuff is active
	var lock_debuff = get_tree().get_first_node_in_group("debuffs") as LockDiceDebuff
	if lock_debuff and lock_debuff.is_active:
		print("[DiceHand] Found active lock debuff - disabling all dice input")
		disable_all_dice()
	else:
		print("[DiceHand] No active lock debuff - enabling all dice input")
		enable_all_dice()


func roll_all() -> void:
	if dice_list.size() == 0:
		return
	for die in dice_list:
		die.roll()
	_update_results()
	#await get_tree().create_timer(roll_duration).timeout
	emit_signal("roll_complete")

func _update_results() -> void:
	# Direct call to the autoloaded singleton
	DiceResults.update_from_dice(dice_list)

func clear_dice() -> void:
	for die in dice_list:
		die.queue_free()
	dice_list.clear()

# DiceHand.gd
func get_current_dice_values() -> Array[int]:
	var arr: Array[int] = []
	for die in dice_list:
		arr.append(die.value)
	return arr

func update_dice_count() -> void:
	var current_count = dice_list.size()
	
	if current_count == dice_count:
		return
	
	if current_count < dice_count:
		# Add more dice
		for i in range(current_count, dice_count):
			var die = dice_scene.instantiate() as Dice
			add_child(die)
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
			print("[DiceHand] Enabled die:", die.name)

func disable_all_dice() -> void:
	print("[DiceHand] Disabling all dice")
	for die in get_children():
		if die is Dice:
			die.unlock()  # Force unlock
			die.set_dice_input_enabled(false)
			if die.has_method("set_lock_shader_enabled"):
				die.set_lock_shader_enabled(false)

func roll_unlocked_dice() -> void:
	var unlocked = get_unlocked_dice()
	if unlocked.is_empty():
		print("No unlocked dice to roll")
		return
		
	print("Rolling", unlocked.size(), "unlocked dice")
	
	for die in unlocked:
		die.roll()
		await get_tree().create_timer(roll_delay).timeout
	
	# After all dice have finished rolling
	await get_tree().create_timer(roll_duration).timeout
	emit_signal("roll_complete")  # Changed to match original signal name



# Add this function
func get_unlocked_dice() -> Array[Dice]:
	var unlocked: Array[Dice] = []
	for die in dice_list:
		if die is Dice and not die.is_locked:
			unlocked.append(die)
	return unlocked
