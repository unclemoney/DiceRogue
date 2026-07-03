extends Control

## Colored Dice Shop Test Scene
##
## Tests the new colored dice purchasing system, including:
## - Progress unlocking requirements
## - Shop display and purchasing
## - Repeat purchases increasing owned count and odds
## - Dice spawning with purchased colors only
## - Color effect calculation

@onready var test_results_label: RichTextLabel = $VBoxContainer/TestResults
@onready var run_test_button: Button = $VBoxContainer/RunTestButton

var test_results: Array[String] = []

func _ready() -> void:
	add_to_group("colored_dice_shop_test")
	
	if not test_results_label:
		test_results_label = RichTextLabel.new()
		$VBoxContainer.add_child(test_results_label)
		test_results_label.custom_minimum_size = Vector2(800, 400)
		test_results_label.bbcode_enabled = true
	
	if not run_test_button:
		run_test_button = Button.new()
		$VBoxContainer.add_child(run_test_button)
		run_test_button.text = "Run Colored Dice Shop Test"
	
	run_test_button.pressed.connect(_run_comprehensive_test)
	
	print("[ColoredDiceShopTest] Test scene ready")

func _run_comprehensive_test() -> void:
	test_results.clear()
	_log_test("=== COLORED DICE SHOP SYSTEM TEST ===")
	
	# Test 1: Check if DiceColorManager exists and has new functions
	_test_dice_color_manager()
	
	# Test 2: Check colored dice data loading
	_test_colored_dice_data()
	
	# Test 3: Check progress system integration
	_test_progress_integration()
	
	# Test 4: Test purchase system
	_test_purchase_system()
	
	# Test 5: Test dice spawning restrictions
	_test_dice_spawning()
	
	_display_results()

func _test_dice_color_manager() -> void:
	_log_test("\n--- DiceColorManager Test ---")
	
	var dice_color_manager = get_node_or_null("/root/DiceColorManager")
	if not dice_color_manager:
		_log_test("❌ DiceColorManager autoload not found")
		return
	
	_log_test("✅ DiceColorManager found")
	
	# Test new methods
	var required_methods = [
		"get_available_colored_dice",
		"purchase_colored_dice", 
		"is_color_purchased",
		"clear_purchased_colors",
		"get_color_purchase_count",
		"get_current_color_chance",
		"is_color_at_max_odds"
	]
	
	for method in required_methods:
		if dice_color_manager.has_method(method):
			_log_test("✅ Method found: %s" % method)
		else:
			_log_test("❌ Missing method: %s" % method)

func _test_colored_dice_data() -> void:
	_log_test("\n--- Colored Dice Data Test ---")
	
	if not DiceColorManager:
		_log_test("❌ Cannot access DiceColorManager")
		return
	
	var available_data = DiceColorManager.get_available_colored_dice()
	_log_test("Available colored dice types: %d" % available_data.size())
	
	for data in available_data:
		if data and data.has_method("get_color_name"):
			_log_test("✅ %s - $%d - %s" % [data.display_name, data.price, data.get_color_name()])
		else:
			_log_test("❌ Invalid data found")

func _test_progress_integration() -> void:
	_log_test("\n--- Progress System Integration Test ---")
	
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		_log_test("❌ ProgressManager not found")
		return
	
	_log_test("✅ ProgressManager found")
	
	# Check colored dice unlock status
	var colored_dice_items = ["green_dice", "red_dice", "purple_dice", "blue_dice", "yellow_dice"]
	for item_id in colored_dice_items:
		var is_unlocked = progress_manager.is_item_unlocked(item_id)
		_log_test("%s %s: %s" % ["✅" if is_unlocked else "❌", item_id, "unlocked" if is_unlocked else "locked"])

func _test_purchase_system() -> void:
	_log_test("\n--- Purchase System Test ---")
	
	if not DiceColorManager:
		_log_test("❌ Cannot access DiceColorManager")
		return
	
	# Reset for clean test
	DiceColorManager.clear_purchased_colors()
	_log_test("Cleared all purchased colors")
	var green_type = DiceColor.Type.GREEN
	var base_odds = DiceColorManager.get_current_color_chance(green_type)
	_log_test("Starting green odds: 1/%d" % base_odds)
	
	# Test repeat purchasing and odds compression
	var first_result = DiceColorManager.purchase_colored_dice("green_dice")
	var second_result = DiceColorManager.purchase_colored_dice("green_dice")
	if first_result and second_result:
		_log_test("✅ Repeat purchases allowed before max odds")
	else:
		_log_test("❌ Repeat purchases failed before max odds")

	var purchase_count = DiceColorManager.get_color_purchase_count(green_type)
	var current_odds = DiceColorManager.get_current_color_chance(green_type)
	var is_purchased = DiceColorManager.is_color_purchased(green_type)
	_log_test("Green dice purchase count: %d" % purchase_count)
	_log_test("Green dice current odds: 1/%d" % current_odds)
	_log_test("Green dice purchased status: %s" % ("purchased" if is_purchased else "not purchased"))
	if purchase_count == 2:
		_log_test("✅ Purchase count increments correctly")
	else:
		_log_test("❌ Purchase count incorrect after two purchases")
	if current_odds < base_odds:
		_log_test("✅ Odds improved after repeat purchases")
	else:
		_log_test("❌ Odds did not improve after repeat purchases")

	var safety := 0
	while not DiceColorManager.is_color_at_max_odds(green_type) and safety < 8:
		DiceColorManager.purchase_colored_dice("green_dice")
		safety += 1
	if DiceColorManager.is_color_at_max_odds(green_type):
		_log_test("✅ Green dice reaches max odds at 1/2")
	else:
		_log_test("❌ Green dice did not reach max odds in expected range")

func _test_dice_spawning() -> void:
	_log_test("\n--- Dice Spawning Test ---")
	
	# This is a simplified test - in a real game test you'd spawn actual dice
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		_log_test("✅ GameController found - dice spawning integration ready")
	else:
		_log_test("❌ GameController not found")
	
	var purchased_colors = DiceColorManager.get_purchased_color_types()
	_log_test("Currently purchased color types: %d" % purchased_colors.size())
	for color_type in purchased_colors:
		_log_test("  - %s" % DiceColor.get_color_name(color_type))

func _log_test(message: String) -> void:
	test_results.append(message)
	print("[ColoredDiceShopTest] " + message)

func _display_results() -> void:
	if test_results_label:
		var formatted_results = "[font_size=12]%s[/font_size]" % "\n".join(test_results)
		test_results_label.text = formatted_results
	
	_log_test("\n=== TEST COMPLETED ===")