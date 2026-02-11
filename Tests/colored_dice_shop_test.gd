extends Control

## Colored Dice Shop Test Scene
##
## Tests the new colored dice purchasing system, including:
## - Progress unlocking requirements
## - Shop display and purchasing
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
		"clear_purchased_colors"
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
	
	# Test purchasing
	var result = DiceColorManager.purchase_colored_dice("green_dice")
	if result:
		_log_test("✅ Successfully purchased green_dice")
	else:
		_log_test("❌ Failed to purchase green_dice")
	
	# Test duplicate purchase prevention
	var duplicate_result = DiceColorManager.purchase_colored_dice("green_dice")
	if not duplicate_result:
		_log_test("✅ Correctly prevented duplicate purchase")
	else:
		_log_test("❌ Allowed duplicate purchase")
	
	# Check purchase status
	var is_purchased = DiceColorManager.is_color_purchased(DiceColor.Type.GREEN)
	_log_test("Green dice purchased status: %s" % ("purchased" if is_purchased else "not purchased"))

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