extends Control

## BlueDiceDebugTest
## Quick test to verify Blue dice implementation works correctly

@onready var test_output: RichTextLabel = $VBoxContainer/TestOutput
@onready var force_blue_button: Button = $VBoxContainer/ForceBlueButton
@onready var test_probability_button: Button = $VBoxContainer/TestProbabilityButton
@onready var roll_dice_button: Button = $VBoxContainer/RollDiceButton

var game_controller: GameController

func _ready() -> void:
	force_blue_button.pressed.connect(_test_force_blue)
	test_probability_button.pressed.connect(_test_blue_probability)
	roll_dice_button.pressed.connect(_test_roll_dice)
	
	# Try to find game controller
	game_controller = get_tree().get_first_node_in_group("game_controller")
	
	add_log("Blue Dice Debug Test Ready")
	add_log("Game Controller Found: %s" % ("Yes" if game_controller else "No"))

func _test_force_blue() -> void:
	add_log("\n[color=yellow]Testing Force All Blue...[/color]")
	
	var dice_hand = _get_dice_hand()
	if not dice_hand:
		add_log("[color=red]ERROR: No dice hand found[/color]")
		return
	
	add_log("Dice Hand Found: %s" % dice_hand.name)
	add_log("Dice Count: %d" % dice_hand.dice_list.size())
	
	# Force all dice to blue
	dice_hand.debug_force_all_colors(preload("res://Scripts/Core/dice_color.gd").Type.BLUE)
	add_log("Forced all dice to BLUE")
	
	# Check if colors were actually set
	var blue_count = 0
	for die in dice_hand.dice_list:
		if die.get_color() == preload("res://Scripts/Core/dice_color.gd").Type.BLUE:
			blue_count += 1
	
	add_log("Blue dice after forcing: %d/%d" % [blue_count, dice_hand.dice_list.size()])
	
	if blue_count == dice_hand.dice_list.size():
		add_log("[color=green]SUCCESS: All dice are now blue![/color]")
	else:
		add_log("[color=red]FAILED: Not all dice are blue[/color]")

func _test_blue_probability() -> void:
	add_log("\n[color=yellow]Testing Blue Dice Probability...[/color]")
	
	var dice_color_class = preload("res://Scripts/Core/dice_color.gd")
	var blue_chance = dice_color_class.get_color_chance(dice_color_class.Type.BLUE)
	add_log("Blue dice chance: 1 in %d" % blue_chance)
	
	# Test color assignment multiple times
	var test_runs = 100
	var blue_hits = 0
	
	for i in range(test_runs):
		# Simulate the dice color assignment logic
		for color_type in dice_color_class.get_all_colors():
			var chance = dice_color_class.get_color_chance(color_type)
			if chance > 0:
				var color_roll = randi() % chance
				if color_roll == 0 and color_type == dice_color_class.Type.BLUE:
					blue_hits += 1
					break
	
	add_log("Blue dice hits in %d tests: %d (%.1f%%)" % [test_runs, blue_hits, (float(blue_hits) / test_runs) * 100])
	add_log("Expected: ~%.1f%%" % (100.0 / blue_chance))

func _test_roll_dice() -> void:
	add_log("\n[color=yellow]Testing Dice Roll...[/color]")
	
	if not game_controller:
		add_log("[color=red]ERROR: No game controller found[/color]")
		return
	
	var dice_hand = _get_dice_hand()
	if not dice_hand:
		add_log("[color=red]ERROR: No dice hand found[/color]")
		return
	
	# Roll dice and check colors
	add_log("Rolling dice...")
	dice_hand.roll_all_dice()
	
	await get_tree().process_frame  # Wait a frame for roll to complete
	
	var color_counts = {}
	for die in dice_hand.dice_list:
		var color_name = preload("res://Scripts/Core/dice_color.gd").get_color_name(die.get_color())
		if not color_counts.has(color_name):
			color_counts[color_name] = 0
		color_counts[color_name] += 1
	
	add_log("Color distribution:")
	for color in color_counts.keys():
		add_log("  %s: %d" % [color, color_counts[color]])

func _get_dice_hand():
	return get_tree().get_first_node_in_group("dice_hand")

func add_log(message: String) -> void:
	test_output.append_text(message + "\n")
	print("[BlueDiceDebugTest] " + message)