extends Node
class_name WildDotsPowerUpTest

func _ready() -> void:
	print("\n=== WildDotsPowerUp Test Starting ===")
	await get_tree().create_timer(0.2).timeout
	_test_bias_application()

func _test_bias_application() -> void:
	print("--- Testing bias application ---")
	var dice_hand = get_tree().get_first_node_in_group("dice_hand")
	if not dice_hand:
		push_error("No DiceHand found in scene")
		return
	
	# Grant power-up via GameController
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		push_error("No GameController found in scene")
		return
	
	game_controller.grant_power_up("wild_dots")
	# Simulate a lock of two sixes
	var unlocked = dice_hand.get_unlocked_dice()
	if unlocked.size() >= 2:
		# Force two dice to be six and lock them
		unlocked[0].value = 6
		unlocked[0].lock()
		unlocked[1].value = 6
		unlocked[1].lock()
		# Trigger roll_started to let WildDots set bias
		dice_hand.emit_signal("roll_started")
		# Check that unlocked dice have wild_dots_bias meta set
		for die in dice_hand.get_unlocked_dice():
			assert(die.has_meta("wild_dots_bias"), "Die missing wild_dots_bias meta")
			print("Die bias:", die.get_meta("wild_dots_bias"))
		print("WildDots bias applied successfully")
	else:
		push_error("Not enough dice to perform test")
	
	print("WildDotsPowerUpTest: ✓ bias application")
