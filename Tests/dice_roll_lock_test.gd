extends Node2D

## Dice Roll Lock Test
##
## Tests that locked dice are properly excluded from rolling

var dice_hand: DiceHand
var test_label: Label
var roll_button: Button

func _ready():
	# Create UI elements
	test_label = Label.new()
	test_label.position = Vector2(50, 50)
	test_label.text = "Testing dice rolling with locks"
	add_child(test_label)
	
	roll_button = Button.new()
	roll_button.text = "Roll All Dice"
	roll_button.position = Vector2(50, 400)
	roll_button.size = Vector2(120, 40)
	roll_button.pressed.connect(_on_roll_button_pressed)
	add_child(roll_button)
	
	# Create a dice hand with 3 dice for easier testing
	dice_hand = DiceHand.new()
	add_child(dice_hand)
	
	# Set up dice hand properties
	dice_hand.dice_count = 3
	dice_hand.position = Vector2(100, 200)
	dice_hand.spacing = 100
	dice_hand.start_position = Vector2(0, 0)
	
	# Load dice scene and data
	dice_hand.dice_scene = preload("res://Scenes/Dice/dice.tscn")
	dice_hand.default_dice_data = preload("res://Scripts/Dice/d6_dice.tres")
	dice_hand.d6_dice_data = preload("res://Scripts/Dice/d6_dice.tres")
	dice_hand.d4_dice_data = preload("res://Scripts/Dice/d4_dice.tres")
	
	# Connect signals
	dice_hand.dice_spawned.connect(_on_dice_spawned)
	dice_hand.roll_complete.connect(_on_roll_complete)
	
	# Spawn the dice
	dice_hand.spawn_dice()

func _on_dice_spawned():
	print("[Test] Dice spawned, setting up test")
	
	# Wait a frame for dice to be properly initialized
	await get_tree().process_frame
	
	# Set all dice to ROLLED state initially
	dice_hand.set_all_dice_rollable()
	for die in dice_hand.dice_list:
		die.roll()
	
	_update_display()

func _on_roll_button_pressed():
	print("\n[Test] === ROLL BUTTON PRESSED ===")
	print("[Test] Pre-roll dice states:")
	_print_dice_states()
	
	# Store pre-roll values to check if locked dice changed
	var pre_roll_values = []
	var pre_roll_states = []
	for die in dice_hand.dice_list:
		pre_roll_values.append(die.value)
		pre_roll_states.append(die.get_state_name())
	
	# Use the new method that preserves locks
	dice_hand.prepare_dice_for_roll()
	print("[Test] After prepare_dice_for_roll:")
	_print_dice_states()
	
	# Roll all dice
	dice_hand.roll_all()
	
	print("[Test] Post-roll dice states:")
	_print_dice_states()
	
	# Check if any locked dice changed values (they shouldn't)
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		if pre_roll_states[i] == "LOCKED":
			if pre_roll_values[i] != die.value:
				print("[Test] ERROR: Locked die", i + 1, "changed from", pre_roll_values[i], "to", die.value)
			else:
				print("[Test] GOOD: Locked die", i + 1, "value preserved:", die.value)
		else:
			print("[Test] Die", i + 1, "was", pre_roll_states[i], "- checking for proper roll behavior")

func _on_roll_complete():
	print("[Test] Roll complete, updating display")
	_update_display()

func _print_dice_states():
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		print("[Test] Die", i + 1, "- State:", die.get_state_name(), "Value:", die.value, "Can Roll:", die.can_roll())

func _update_display():
	var status_text = "Dice States:\n"
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		status_text += "Die " + str(i + 1) + ": " + die.get_state_name() + " (Value: " + str(die.value) + ")\n"
	
	status_text += "\nInstructions:\n"
	status_text += "- Click dice to lock/unlock them\n"
	status_text += "- Press Roll button to test rolling\n"
	status_text += "- Locked dice should NOT change value"
	
	test_label.text = status_text

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				if dice_hand.dice_list.size() > 0:
					var die = dice_hand.dice_list[0]
					print("[Test] Manually locking die 1")
					die.set_state(Dice.DiceState.LOCKED)
					_update_display()
			KEY_2:
				if dice_hand.dice_list.size() > 1:
					var die = dice_hand.dice_list[1]
					print("[Test] Manually locking die 2")
					die.set_state(Dice.DiceState.LOCKED)
					_update_display()
			KEY_3:
				if dice_hand.dice_list.size() > 2:
					var die = dice_hand.dice_list[2]
					print("[Test] Manually locking die 3")
					die.set_state(Dice.DiceState.LOCKED)
					_update_display()
			KEY_R:
				print("[Test] Setting all dice to ROLLABLE")
				dice_hand.set_all_dice_rollable()
				_update_display()
			KEY_SPACE:
				_on_roll_button_pressed()