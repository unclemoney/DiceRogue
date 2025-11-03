extends Node2D

## Dice State Flow Test
##
## Tests the complete flow: roll -> lock -> score -> disabled -> roll again

var dice_hand: DiceHand
var test_label: Label
var roll_button: Button
var score_button: Button
var step: int = 0

func _ready():
	# Create UI elements
	test_label = Label.new()
	test_label.position = Vector2(50, 50)
	test_label.text = "Testing complete dice flow"
	add_child(test_label)
	
	roll_button = Button.new()
	roll_button.text = "Roll Dice"
	roll_button.position = Vector2(50, 400)
	roll_button.size = Vector2(120, 40)
	roll_button.pressed.connect(_on_roll_button_pressed)
	add_child(roll_button)
	
	score_button = Button.new()
	score_button.text = "Score (Disable)"
	score_button.position = Vector2(180, 400)
	score_button.size = Vector2(120, 40)
	score_button.pressed.connect(_on_score_button_pressed)
	add_child(score_button)
	
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
	print("[Test] Dice spawned")
	step = 1
	_update_display()

func _on_roll_button_pressed():
	print("\n[Test] === STEP", step, ": ROLL BUTTON PRESSED ===")
	_print_dice_states_before("roll")
	
	dice_hand.prepare_dice_for_roll()
	print("[Test] After prepare_dice_for_roll:")
	_print_dice_states_after("prepare")
	
	dice_hand.roll_all()
	step += 1

func _on_score_button_pressed():
	print("\n[Test] === STEP", step, ": SCORE BUTTON PRESSED (Simulating score) ===")
	_print_dice_states_before("score")
	
	# Simulate scoring by disabling all dice
	dice_hand.set_all_dice_disabled()
	
	print("[Test] After set_all_dice_disabled:")
	_print_dice_states_after("disable")
	step += 1
	_update_display()

func _on_roll_complete():
	print("[Test] Roll complete")
	_print_dice_states_after("roll_complete")
	_update_display()

func _print_dice_states_before(action: String):
	print("[Test] BEFORE", action.to_upper(), ":")
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		print("  Die", i + 1, "- State:", die.get_state_name(), "Value:", die.value)

func _print_dice_states_after(action: String):
	print("[Test] AFTER", action.to_upper(), ":")
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		print("  Die", i + 1, "- State:", die.get_state_name(), "Value:", die.value)

func _update_display():
	var status_text = "Step " + str(step) + " - Dice States:\n"
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		status_text += "Die " + str(i + 1) + ": " + die.get_state_name() + " (Value: " + str(die.value) + ")\n"
	
	status_text += "\nFlow Test Instructions:\n"
	status_text += "1. Roll dice\n"
	status_text += "2. Click some dice to lock them\n"
	status_text += "3. Score (simulates disabled state)\n"
	status_text += "4. Roll again (should preserve locks)\n"
	
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
			KEY_SPACE:
				_on_roll_button_pressed()
			KEY_S:
				_on_score_button_pressed()