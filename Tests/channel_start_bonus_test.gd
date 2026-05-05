extends Node
class_name ChannelStartBonusTest

## ChannelStartBonusTest
##
## Verifies the channel starting bonus system.
## Tests bonus formula accuracy, item granting, and scorecard level boosts.
## Run this scene standalone in the Godot editor (F6).

const EXPECTED_BONUSES = {
	1: {"bonus_money": 0, "bonus_powerup_count": 0, "bonus_consumable_count": 0, "bonus_level_boost_count": 0},
	2: {"bonus_money": 150, "bonus_powerup_count": 0, "bonus_consumable_count": 0, "bonus_level_boost_count": 0},
	3: {"bonus_money": 300, "bonus_powerup_count": 1, "bonus_consumable_count": 0, "bonus_level_boost_count": 0},
	4: {"bonus_money": 450, "bonus_powerup_count": 1, "bonus_consumable_count": 1, "bonus_level_boost_count": 0},
	5: {"bonus_money": 600, "bonus_powerup_count": 2, "bonus_consumable_count": 1, "bonus_level_boost_count": 1},
	6: {"bonus_money": 750, "bonus_powerup_count": 2, "bonus_consumable_count": 2, "bonus_level_boost_count": 1},
	7: {"bonus_money": 900, "bonus_powerup_count": 3, "bonus_consumable_count": 2, "bonus_level_boost_count": 2},
	8: {"bonus_money": 1050, "bonus_powerup_count": 3, "bonus_consumable_count": 3, "bonus_level_boost_count": 2},
	9: {"bonus_money": 1200, "bonus_powerup_count": 4, "bonus_consumable_count": 3, "bonus_level_boost_count": 3},
	10: {"bonus_money": 1350, "bonus_powerup_count": 4, "bonus_consumable_count": 4, "bonus_level_boost_count": 3},
	20: {"bonus_money": 2850, "bonus_powerup_count": 9, "bonus_consumable_count": 9, "bonus_level_boost_count": 8}
}

var _test_results: Array[String] = []
var _pass_count: int = 0
var _fail_count: int = 0

@onready var _result_label: Label

func _ready() -> void:
	print("\n=== CHANNEL START BONUS TEST ===\n")
	_build_ui()
	_run_all_tests()
	_display_results()


func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	_result_label = Label.new()
	_result_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_label.add_theme_constant_override("margin_left", 20)
	_result_label.add_theme_constant_override("margin_top", 20)
	_result_label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(_result_label)


func _run_all_tests() -> void:
	_test_formula_accuracy()
	_test_bonus_application()
	_test_fallback_behavior()


func _test_formula_accuracy() -> void:
	_log_test_header("FORMULA ACCURACY TESTS")
	
	var channel_manager = ChannelManager.new()
	for channel in EXPECTED_BONUSES.keys():
		var expected = EXPECTED_BONUSES[channel]
		var actual = channel_manager.get_channel_start_bonus(channel)
		
		var money_ok = actual["bonus_money"] == expected["bonus_money"]
		var pu_ok = actual["bonus_powerup_count"] == expected["bonus_powerup_count"]
		var con_ok = actual["bonus_consumable_count"] == expected["bonus_consumable_count"]
		var lvl_ok = actual["bonus_level_boost_count"] == expected["bonus_level_boost_count"]
		
		if money_ok and pu_ok and con_ok and lvl_ok:
			_pass("Channel %d bonuses match expected" % channel)
		else:
			_fail("Channel %d mismatch: expected %s, got %s" % [channel, str(expected), str(actual)])
	
	channel_manager.queue_free()


func _test_bonus_application() -> void:
	_log_test_header("BONUS APPLICATION TESTS")
	
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		_skip("No GameController in scene - skipping application tests")
		return
	
	# Store original state
	var original_money = PlayerEconomy.money if PlayerEconomy else 0
	
	# Test applying channel 3 bonus
	game_controller._apply_channel_starting_bonuses(3)
	
	if PlayerEconomy:
		var expected_money = 100 + 300
		if PlayerEconomy.money == expected_money:
			_pass("Channel 3 bonus money applied correctly ($%d)" % expected_money)
		else:
			_fail("Channel 3 bonus money mismatch: expected $%d, got $%d" % [expected_money, PlayerEconomy.money])
		
		# Reset for next test
		PlayerEconomy.money = original_money
	
	# Test applying channel 1 bonus (should be no-op)
	game_controller._apply_channel_starting_bonuses(1)
	if PlayerEconomy and PlayerEconomy.money == original_money:
		_pass("Channel 1 produces no bonus (money unchanged)")
	else:
		_fail("Channel 1 should not change money")


func _test_fallback_behavior() -> void:
	_log_test_header("FALLBACK BEHAVIOR TESTS")
	
	var channel_manager = ChannelManager.new()
	var bonus = channel_manager.get_channel_start_bonus(0)
	if bonus["bonus_money"] == 0 and bonus["bonus_powerup_count"] == 0:
		_pass("Channel 0 returns zero bonuses")
	else:
		_fail("Channel 0 should return zero bonuses")
	
	var bonus_neg = channel_manager.get_channel_start_bonus(-5)
	if bonus_neg["bonus_money"] == 0 and bonus_neg["bonus_powerup_count"] == 0:
		_pass("Negative channel returns zero bonuses")
	else:
		_fail("Negative channel should return zero bonuses")
	
	channel_manager.queue_free()


func _log_test_header(header: String) -> void:
	_test_results.append("\n[%s]" % header)
	print("\n[%s]" % header)


func _pass(message: String) -> void:
	_pass_count += 1
	var line = "  [PASS] %s" % message
	_test_results.append(line)
	print(line)


func _fail(message: String) -> void:
	_fail_count += 1
	var line = "  [FAIL] %s" % message
	_test_results.append(line)
	print(line)


func _skip(message: String) -> void:
	var line = "  [SKIP] %s" % message
	_test_results.append(line)
	print(line)


func _display_results() -> void:
	var summary = "\n=== RESULTS ===\nPassed: %d\nFailed: %d\n" % [_pass_count, _fail_count]
	_test_results.append(summary)
	print(summary)
	
	if _result_label:
		_result_label.text = "\n".join(_test_results)
