extends Consumable
class_name LoadedDiceConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[LoadedDiceConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[LoadedDiceConsumable] Invalid target passed to apply()")
		return
	
	if not game_controller.dice_hand:
		push_error("[LoadedDiceConsumable] No dice_hand found on game_controller")
		return
	
	# Get all current dice from the dice_list
	var dice = game_controller.dice_hand.dice_list
	if dice.is_empty():
		print("[LoadedDiceConsumable] No dice available to modify")
		return
	
	# Pick a random die and set it to a random value 1-6
	var random_die = dice[randi() % dice.size()]
	var random_value = randi_range(1, 6)
	random_die.value = random_value
	random_die.update_visual()
	
	print("[LoadedDiceConsumable] Set a die to value: %d" % random_value)
