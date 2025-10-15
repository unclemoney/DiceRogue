extends Control

## DiceColorTest
##
## Test scene for verifying dice color system functionality including:
## - Color assignment on roll
## - Visual effects (shader integration)
## - Score calculation with color effects
## - Bonus calculations for 5+ same color

@onready var test_results: TextEdit
@onready var button_container: VBoxContainer

const DiceColor = preload("res://Scripts/Core/dice_color.gd")

var test_dice_hand: DiceHand

func _ready() -> void:
	setup_ui()
	setup_test_components()
	log_test("=== DICE COLOR SYSTEM TEST ===")
	log_test("Ready to test dice color functionality")

func setup_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	var title = Label.new()
	title.text = "Dice Color System Test"
	title.add_theme_font_size_override("font_size", 24)
	main_vbox.add_child(title)
	
	# Test results area
	test_results = TextEdit.new()
	test_results.custom_minimum_size = Vector2(800, 400)
	test_results.editable = false
	main_vbox.add_child(test_results)
	
	# Button container
	button_container = VBoxContainer.new()
	main_vbox.add_child(button_container)
	
	create_test_buttons()

func create_test_buttons() -> void:
	var buttons = [
		{"text": "Test Color Assignment", "method": "_test_color_assignment"},
		{"text": "Test Color Effects", "method": "_test_color_effects"},
		{"text": "Test Same Color Bonus", "method": "_test_same_color_bonus"},
		{"text": "Test Toggle System", "method": "_test_toggle_system"},
		{"text": "Test Scoring Integration", "method": "_test_scoring_integration"},
		{"text": "Clear Results", "method": "_clear_results"},
	]
	
	for button_data in buttons:
		var button = Button.new()
		button.text = button_data["text"]
		button.custom_minimum_size = Vector2(200, 40)
		button.pressed.connect(Callable(self, button_data["method"]))
		button_container.add_child(button)

func setup_test_components() -> void:
	# Create test dice hand
	var dice_hand_scene = preload("res://Scenes/Dice/dice_hand.tscn")
	if dice_hand_scene:
		test_dice_hand = dice_hand_scene.instantiate()
		add_child(test_dice_hand)
		test_dice_hand.position = Vector2(100, 500)
	else:
		log_test("ERROR: Could not load dice hand scene")

func log_test(message: String) -> void:
	var timestamp = Time.get_ticks_msec() / 1000.0
	var formatted_message = "[%.2fs] %s\n" % [timestamp, message]
	test_results.text += formatted_message
	test_results.scroll_vertical = test_results.get_line_count()
	print("[DiceColorTest] " + message)

func _test_color_assignment() -> void:
	log_test("\n=== Testing Color Assignment ===")
	
	if not test_dice_hand:
		log_test("ERROR: No dice hand available")
		return
	
	# Enable colors
	var color_manager = _get_dice_color_manager()
	if color_manager:
		color_manager.set_colors_enabled(true)
		log_test("Enabled dice color system")
	else:
		log_test("ERROR: Could not find DiceColorManager")
		return
	
	# Test multiple rolls to see color assignment
	for i in range(5):
		log_test("Roll #" + str(i + 1) + ":")
		test_dice_hand.roll_all()
		await get_tree().create_timer(0.5).timeout
		
		var counts = test_dice_hand.get_color_counts()
		log_test("  Green: " + str(counts.green) + ", Red: " + str(counts.red) + 
				", Purple: " + str(counts.purple) + ", None: " + str(counts.none))

func _test_color_effects() -> void:
	log_test("\n=== Testing Color Effects ===")
	
	if not test_dice_hand:
		log_test("ERROR: No dice hand available")
		return
	
	# Test each color type
	var test_cases = [
		{"color": DiceColor.Type.GREEN, "name": "Green", "expected": "money bonus"},
		{"color": DiceColor.Type.RED, "name": "Red", "expected": "additive bonus"},
		{"color": DiceColor.Type.PURPLE, "name": "Purple", "expected": "multiplier bonus"}
	]
	
	for test_case in test_cases:
		log_test("Testing " + test_case.name + " dice effects:")
		
		# Force all dice to specific color
		test_dice_hand.debug_force_all_colors(test_case.color)
		
		# Set some test values
		for i in range(test_dice_hand.dice_list.size()):
			var die = test_dice_hand.dice_list[i]
			die.value = i + 1  # Values 1,2,3,4,5
		
		var effects = test_dice_hand.get_color_effects()
		log_test("  Effects: " + str(effects))
		log_test("  Expected: " + test_case.expected)

func _test_same_color_bonus() -> void:
	log_test("\n=== Testing Same Color Bonus (5+ dice) ===")
	
	if not test_dice_hand:
		log_test("ERROR: No dice hand available")
		return
	
	# Test with 5 green dice
	test_dice_hand.debug_force_all_colors(DiceColor.Type.GREEN)
	
	# Set dice values to 2 each for easy calculation
	for die in test_dice_hand.dice_list:
		die.value = 2
	
	var effects = test_dice_hand.get_color_effects()
	log_test("5 Green dice (value 2 each):")
	log_test("  Base money would be: 5 * 2 = 10")
	log_test("  With 5+ bonus: " + str(effects.green_money))
	log_test("  Same color bonus active: " + str(effects.same_color_bonus))
	
	# Test with 4 dice (should not get bonus)
	test_dice_hand.dice_list[0].clear_color()
	effects = test_dice_hand.get_color_effects()
	log_test("4 Green dice (value 2 each):")
	log_test("  Money bonus: " + str(effects.green_money))
	log_test("  Same color bonus active: " + str(effects.same_color_bonus))

func _test_toggle_system() -> void:
	log_test("\n=== Testing Toggle System ===")
	
	var color_manager = _get_dice_color_manager()
	if not color_manager:
		log_test("ERROR: Could not find DiceColorManager")
		return
	
	# Test enable/disable
	color_manager.set_colors_enabled(true)
	log_test("Colors enabled: " + str(color_manager.are_colors_enabled()))
	
	color_manager.set_colors_enabled(false)
	log_test("Colors disabled: " + str(color_manager.are_colors_enabled()))
	
	# Test dice assignment when disabled
	if test_dice_hand:
		test_dice_hand.roll_all()
		var counts = test_dice_hand.get_color_counts()
		log_test("Color counts when disabled: " + str(counts))
	
	# Re-enable for other tests
	color_manager.set_colors_enabled(true)
	log_test("Re-enabled colors for other tests")

func _test_scoring_integration() -> void:
	log_test("\n=== Testing Scoring Integration ===")
	
	if not test_dice_hand:
		log_test("ERROR: No dice hand available")
		return
	
	# Create a mock scenario
	test_dice_hand.debug_force_all_colors(DiceColor.Type.GREEN)
	for i in range(3):
		test_dice_hand.dice_list[i].force_color(DiceColor.Type.RED)
	test_dice_hand.dice_list[4].force_color(DiceColor.Type.PURPLE)
	
	# Set dice to make a full house (3 threes, 2 fives)
	for i in range(3):
		test_dice_hand.dice_list[i].value = 3
	for i in range(3, 5):
		test_dice_hand.dice_list[i].value = 5
	
	var effects = test_dice_hand.get_color_effects()
	log_test("Mixed colors Full House test:")
	log_test("  Dice: 3(R), 3(R), 3(R), 5(G), 5(P)")
	log_test("  Base Full House score: 25")
	log_test("  Green money bonus: $" + str(effects.green_money))
	log_test("  Red additive bonus: +" + str(effects.red_additive))
	log_test("  Purple multiplier: x" + str(effects.purple_multiplier))
	
	# Calculate what final score would be
	var base_score = 25
	var final_score = (base_score + effects.red_additive) * effects.purple_multiplier
	log_test("  Final score would be: (" + str(base_score) + " + " + str(effects.red_additive) + ") * " + str(effects.purple_multiplier) + " = " + str(final_score))

func _clear_results() -> void:
	test_results.text = ""
	log_test("=== DICE COLOR SYSTEM TEST ===")
	log_test("Test results cleared")

## Get DiceColorManager safely
## @return DiceColorManager node or null if not found
func _get_dice_color_manager():
	if get_tree():
		var manager = get_tree().get_first_node_in_group("dice_color_manager")
		if manager:
			return manager
		
		# Fallback: try to find autoload directly
		var autoload_node = get_node_or_null("/root/DiceColorManager")
		return autoload_node
	return null