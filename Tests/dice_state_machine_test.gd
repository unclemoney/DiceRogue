extends Node2D

## Dice State Machine Test
##
## Tests the new dice state machine functionality to ensure proper state transitions
## and validation logic work correctly throughout the game flow.

var dice_hand: DiceHand
var test_label: Label

func _ready():
	test_label = $Label
	
	# Create a test dice hand
	var dice_hand_scene = preload("res://Scenes/Dice/dice_hand.tscn")
	dice_hand = dice_hand_scene.instantiate()
	add_child(dice_hand)
	
	# Position the dice hand
	dice_hand.position = Vector2(100, 300)
	
	# Wait for dice to spawn, then start tests
	dice_hand.dice_spawned.connect(_on_dice_spawned)
	dice_hand.spawn_dice()
	
	print("[DiceStateMachineTest] Test scene initialized")

func _on_dice_spawned():
	print("[DiceStateMachineTest] Dice spawned, ready for testing")
	_update_display()

func _input(event):
	if not event is InputEventKey:
		return
	if not event.pressed:
		return
		
	match event.keycode:
			KEY_1:
				_test_rollable_to_rolled()
			KEY_2:
				_test_rolled_to_locked()
			KEY_3:
				_test_locked_to_rolled()
			KEY_4:
				_test_to_disabled()
			KEY_5:
				_test_disabled_to_rollable()
			KEY_6:
				_test_full_game_flow()
			KEY_R:
				_reset_all_dice()
			KEY_ESCAPE:
				get_tree().quit()

func _test_rollable_to_rolled():
	print("\n=== Testing ROLLABLE to ROLLED ===")
	_reset_all_dice()
	
	for die in dice_hand.dice_list:
		if die.get_state() == Dice.DiceState.ROLLABLE:
			print("Rolling die with value:", die.value)
			die.roll()
			print("Die state after roll:", die.get_state_name())
			break
	
	_update_display()

func _test_rolled_to_locked():
	print("\n=== Testing ROLLED to LOCKED ===")
	
	for die in dice_hand.dice_list:
		if die.get_state() == Dice.DiceState.ROLLED:
			print("Locking die with value:", die.value)
			die.lock()
			print("Die state after lock:", die.get_state_name())
			break
	
	_update_display()

func _test_locked_to_rolled():
	print("\n=== Testing LOCKED to ROLLED ===")
	
	for die in dice_hand.dice_list:
		if die.get_state() == Dice.DiceState.LOCKED:
			print("Unlocking die with value:", die.value)
			die.unlock()
			print("Die state after unlock:", die.get_state_name())
			break
	
	_update_display()

func _test_to_disabled():
	print("\n=== Testing to DISABLED ===")
	
	for die in dice_hand.dice_list:
		print("Disabling die with value:", die.value, "from state:", die.get_state_name())
		die.make_disabled()
		print("Die state after disable:", die.get_state_name())
		break
	
	_update_display()

func _test_disabled_to_rollable():
	print("\n=== Testing DISABLED to ROLLABLE ===")
	
	for die in dice_hand.dice_list:
		if die.get_state() == Dice.DiceState.DISABLED:
			print("Making die rollable with value:", die.value)
			die.make_rollable()
			print("Die state after making rollable:", die.get_state_name())
			break
	
	_update_display()

func _test_full_game_flow():
	print("\n=== Testing Full Game Flow ===")
	
	# 1. Start turn - all dice ROLLABLE
	dice_hand.set_all_dice_rollable()
	print("1. Turn start: All dice set to ROLLABLE")
	_update_display()
	await get_tree().create_timer(1.0).timeout
	
	# 2. Roll dice - transition to ROLLED
	dice_hand.roll_all()
	print("2. Rolling dice: Dice transition to ROLLED")
	_update_display()
	await get_tree().create_timer(1.0).timeout
	
	# 3. Lock some dice
	var locked_count = 0
	for die in dice_hand.dice_list:
		if die.get_state() == Dice.DiceState.ROLLED and locked_count < 2:
			die.lock()
			locked_count += 1
	print("3. Locked 2 dice: Some dice now LOCKED")
	_update_display()
	await get_tree().create_timer(1.0).timeout
	
	# 4. Check scoring validation
	print("=== Debugging Dice States ===")
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		print("Die %d: state=%s, can_score=%s" % [i, die.get_state_name(), die.can_score()])
	
	var can_score = dice_hand.can_any_dice_score()
	print("4. Can score dice?", can_score)
	
	# 5. After scoring - all dice DISABLED
	dice_hand.set_all_dice_disabled()
	print("5. After scoring: All dice set to DISABLED")
	_update_display()
	await get_tree().create_timer(1.0).timeout
	
	# 6. Next turn - back to ROLLABLE
	dice_hand.set_all_dice_rollable()
	print("6. Next turn: All dice set to ROLLABLE")
	_update_display()
	
	print("=== Full Game Flow Test Complete ===")

func _reset_all_dice():
	print("\n=== Resetting all dice to ROLLABLE ===")
	dice_hand.set_all_dice_rollable()
	_update_display()

func _update_display():
	if not dice_hand or not test_label:
		return
		
	var display_text = "Dice State Machine Test\\n"
	display_text += "Press keys to trigger state changes:\\n"
	display_text += "1 - Test ROLLABLE to ROLLED transition\\n"
	display_text += "2 - Test ROLLED to LOCKED transition\\n"
	display_text += "3 - Test LOCKED to ROLLED transition\\n"
	display_text += "4 - Test any state to DISABLED transition\\n"
	display_text += "5 - Test DISABLED to ROLLABLE transition\\n"
	display_text += "6 - Run full game flow simulation\\n"
	display_text += "R - Reset all dice to ROLLABLE\\n"
	display_text += "ESC - Exit test\\n\\n"
	
	display_text += "=== Current Dice States ===\\n"
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		display_text += "Die %d: %s (value: %d)\\n" % [i + 1, die.get_state_name(), die.value]
	
	# Add validation checks
	display_text += "\\n=== Validation ===\\n"
	display_text += "Can roll any dice: %s\\n" % dice_hand.can_any_dice_roll()
	display_text += "Can score any dice: %s\\n" % dice_hand.can_any_dice_score()
	
	# Count dice in each state
	var rollable_count = dice_hand.get_dice_in_state(Dice.DiceState.ROLLABLE).size()
	var rolled_count = dice_hand.get_dice_in_state(Dice.DiceState.ROLLED).size()
	var locked_count = dice_hand.get_dice_in_state(Dice.DiceState.LOCKED).size()
	var disabled_count = dice_hand.get_dice_in_state(Dice.DiceState.DISABLED).size()
	
	display_text += "\\n=== State Counts ===\\n"
	display_text += "ROLLABLE: %d\\n" % rollable_count
	display_text += "ROLLED: %d\\n" % rolled_count
	display_text += "LOCKED: %d\\n" % locked_count
	display_text += "DISABLED: %d\\n" % disabled_count
	
	test_label.text = display_text