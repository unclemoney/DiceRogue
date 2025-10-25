extends Control
class_name BlueDiceIntegrationTest

## Blue Dice Integration Test
##
## Comprehensive test for Blue dice functionality including:
## - Visual effects
## - Scoring multiplier logic (multiply if used, divide if not used)
## - Logbook recording
## - Statistics tracking

@onready var test_label: Label = $VBoxContainer/TestLabel
@onready var debug_button: Button = $VBoxContainer/DebugButton
@onready var manual_test_button: Button = $VBoxContainer/ManualTestButton
@onready var multiplier_debug_button: Button = $VBoxContainer/MultiplierDebugButton
@onready var results_label: Label = $VBoxContainer/ResultsLabel

var test_results: Array[String] = []

func _ready() -> void:
	if test_label:
		test_label.text = "Blue Dice Integration Test\nPress Debug to force blue dice, then test scoring."
	
	if debug_button:
		debug_button.text = "Force All Blue Dice"
		debug_button.pressed.connect(_on_debug_pressed)
	
	if manual_test_button:
		manual_test_button.text = "Run Integration Test"
		manual_test_button.pressed.connect(_on_manual_test_pressed)
	
	if multiplier_debug_button:
		multiplier_debug_button.text = "Show MultiplierManager State"
		multiplier_debug_button.pressed.connect(_on_multiplier_debug_pressed)
	
	if results_label:
		results_label.text = "Ready to test Blue dice functionality..."

func _on_debug_pressed() -> void:
	print("[BlueDiceTest] Forcing all dice to blue...")
	if DiceColorManager:
		# Use the debug panel approach instead
		var debug_panel = get_node_or_null("/root/GameController/DebugPanel")
		if debug_panel and debug_panel.has_method("_debug_force_all_blue"):
			debug_panel._debug_force_all_blue()
			_add_result("✓ Forced all dice to blue via debug panel")
		else:
			_add_result("⚠️ Debug panel not available - check visual effects manually")
	else:
		_add_result("✗ DiceColorManager not available")

func _on_multiplier_debug_pressed() -> void:
	print("[BlueDiceTest] Showing MultiplierManager state...")
	
	if ScoreModifierManager:
		ScoreModifierManager.debug_print_state()
		_add_result("✓ MultiplierManager state printed to console")
		
		# Show active sources in test results
		var active_sources = ScoreModifierManager.get_active_sources()
		var active_additives = ScoreModifierManager.get_active_additive_sources()
		
		_add_result("Active multipliers: " + str(active_sources))
		_add_result("Active additives: " + str(active_additives))
		
		# Check specifically for dice color effects
		if ScoreModifierManager.has_multiplier("blue_dice"):
			var blue_mult = ScoreModifierManager.get_multiplier("blue_dice")
			_add_result("✓ Blue dice multiplier found: ×" + str(blue_mult))
		else:
			_add_result("⚠️ No blue dice multiplier registered")
			
		if ScoreModifierManager.has_multiplier("purple_dice"):
			var purple_mult = ScoreModifierManager.get_multiplier("purple_dice")
			_add_result("✓ Purple dice multiplier found: ×" + str(purple_mult))
		else:
			_add_result("⚠️ No purple dice multiplier registered")
			
		if ScoreModifierManager.has_additive("red_dice"):
			var red_add = ScoreModifierManager.get_additive("red_dice")
			_add_result("✓ Red dice additive found: +" + str(red_add))
		else:
			_add_result("⚠️ No red dice additive registered")
	else:
		_add_result("✗ ScoreModifierManager not available")

func _on_manual_test_pressed() -> void:
	print("[BlueDiceTest] Running comprehensive Blue dice integration test...")
	test_results.clear()
	
	# Test 1: Check DiceColorManager blue logic
	_test_blue_scoring_logic()
	
	# Test 2: Check logbook integration
	_test_logbook_integration()
	
	# Test 3: Check statistics tracking
	_test_statistics_tracking()
	
	_display_results()

func _test_blue_scoring_logic() -> void:
	print("[BlueDiceTest] Testing Blue dice scoring logic...")
	
	if not DiceColorManager:
		_add_result("✗ DiceColorManager not available")
		return
	
	# Test scenario 1: Blue dice used in scoring
	var used_dice = [0, 1, 2]  # First 3 dice used
	var color_effects_used = DiceColorManager.calculate_color_effects(used_dice)
	
	if color_effects_used.has("blue_score_multiplier"):
		var multiplier_used = color_effects_used["blue_score_multiplier"]
		if multiplier_used > 1.0:
			_add_result("✓ Blue dice multiply when used (×%.1f)" % multiplier_used)
		else:
			_add_result("✗ Blue dice should multiply when used, got ×%.1f" % multiplier_used)
	else:
		_add_result("✗ Blue score multiplier not found in used dice effects")
	
	# Test scenario 2: Blue dice not used in scoring
	var unused_dice = []  # No dice used
	var color_effects_unused = DiceColorManager.calculate_color_effects(unused_dice)
	
	if color_effects_unused.has("blue_score_multiplier"):
		var multiplier_unused = color_effects_unused["blue_score_multiplier"]
		if multiplier_unused < 1.0:
			_add_result("✓ Blue dice divide when not used (×%.1f)" % multiplier_unused)
		else:
			_add_result("✗ Blue dice should divide when not used, got ×%.1f" % multiplier_unused)
	else:
		_add_result("✗ Blue score multiplier not found in unused dice effects")

func _test_logbook_integration() -> void:
	print("[BlueDiceTest] Testing logbook integration...")
	
	if not Statistics:
		_add_result("✗ Statistics Manager not available")
		return
	
	# Clear any existing logbook entries for clean test
	var initial_entries = Statistics.get_logbook_entries().size()
	
	# Simulate a scoring event with blue dice
	if DiceColorManager:
		DiceColorManager.force_all_blue()
		_add_result("✓ Logbook integration ready (initial entries: %d)" % initial_entries)
		_add_result("ℹ️ Now manually score to test logbook recording")
	else:
		_add_result("✗ Cannot test logbook - DiceColorManager unavailable")

func _test_statistics_tracking() -> void:
	print("[BlueDiceTest] Testing statistics tracking...")
	
	if not Statistics:
		_add_result("✗ Statistics Manager not available")
		return
	
	# Check if blue dice stats are being tracked
	var _stats_data = Statistics._get_current_stats()
	_add_result("✓ Statistics Manager available")
	_add_result("ℹ️ Stats will be tracked when blue dice are used in scoring")

func _add_result(message: String) -> void:
	test_results.append(message)
	print("[BlueDiceTest] " + message)

func _display_results() -> void:
	if results_label:
		var results_text = "Test Results:\n"
		for result in test_results:
			results_text += result + "\n"
		results_label.text = results_text
	
	print("[BlueDiceTest] Test completed. %d results recorded." % test_results.size())

## Manual test instructions
func get_manual_test_instructions() -> String:
	return """
BLUE DICE MANUAL TEST PROCEDURE:

1. Press 'Force All Blue Dice' button
2. Roll dice and verify blue visual effects appear
3. Score a hand and check:
   - Score multiplier applied correctly
   - Logbook entry includes blue dice effects
   - Statistics panel shows blue effects
4. Try scoring with different dice combinations:
   - Used blue dice: should multiply score
   - Unused blue dice: should divide score

EXPECTED RESULTS:
- Visual: Blue pulsing effect on dice
- Scoring: Multiplier effects applied based on usage
- Logbook: "blue×X.X" entries in effects list
- Debug: Console shows blue dice calculations
"""