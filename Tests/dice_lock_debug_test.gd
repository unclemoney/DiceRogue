extends Node2D

## Dice Lock Debug Test
##
## Simple test to debug dice locking issues

var dice: Dice
var test_label: Label

func _ready():
	# Create label for status
	test_label = Label.new()
	test_label.position = Vector2(50, 50)
	test_label.text = "Click dice to test locking"
	add_child(test_label)
	
	# Create a single dice
	var dice_scene = preload("res://Scenes/Dice/dice.tscn")
	dice = dice_scene.instantiate()
	add_child(dice)
	
	# Position the dice
	dice.position = Vector2(200, 200)
	
	# Set up dice data
	var d6_data = preload("res://Scripts/Dice/d6_dice.tres")
	dice.dice_data = d6_data
	dice.value = 3  # Set a specific value
	
	# Set to ROLLED state initially (since that's when locking should work)
	dice.set_state(Dice.DiceState.ROLLED)
	
	# Connect signals
	dice.selected.connect(_on_dice_selected)
	dice.state_changed.connect(_on_state_changed)
	
	dice.update_visual()
	
	_update_label()

func _on_dice_selected(selected_dice: Dice):
	print("[Test] Dice selected, current state:", selected_dice.get_state_name())
	_update_label()

func _on_state_changed(_dice_ref: Dice, old_state: Dice.DiceState, new_state: Dice.DiceState):
	print("[Test] State changed from", Dice.DiceState.keys()[old_state], "to", Dice.DiceState.keys()[new_state])
	_update_label()

func _update_label():
	if dice:
		test_label.text = "Dice State: " + dice.get_state_name() + "\nValue: " + str(dice.value) + "\nClick to toggle lock"

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				print("[Test] Setting dice to ROLLED state")
				dice.set_state(Dice.DiceState.ROLLED)
				_update_label()
			KEY_L:
				print("[Test] Setting dice to LOCKED state")
				dice.set_state(Dice.DiceState.LOCKED)
				_update_label()
			KEY_U:
				print("[Test] Unlocking dice")
				dice.unlock()
				_update_label()
			KEY_SPACE:
				print("[Test] Rolling dice")
				dice.set_state(Dice.DiceState.ROLLABLE)
				dice.roll()
				_update_label()