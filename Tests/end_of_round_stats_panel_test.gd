extends Control

## EndOfRoundStatsPanelTest
##
## Test scene for validating the End of Round Statistics Panel functionality.
## Tests bonus calculations, animations, and UI display.

const EMPTY_CATEGORY_BONUS: int = 10
const POINTS_ABOVE_TARGET_BONUS: int = 1
const SCORE_ABOVE_TARGET_CAP: int = 100
const DEFAULT_POWER_UP_BONUS: int = 100

@onready var stats_panel = $EndOfRoundStatsPanel
@onready var output_label: RichTextLabel = $OutputLabel

# Test controls
var test_round: int = 1
var test_challenge_target: int = 100
var test_final_score: int = 130
var test_empty_categories: int = 3

# Mock scorecard for testing
var mock_scorecard: Dictionary = {
	"upper_scores": {
		"ones": 3,
		"twos": null,  # Empty
		"threes": 9,
		"fours": null,  # Empty
		"fives": 20,
		"sixes": 24
	},
	"lower_scores": {
		"three_of_a_kind": 22,
		"four_of_a_kind": null,  # Empty
		"full_house": 25,
		"small_straight": 30,
		"large_straight": 40,
		"yahtzee": 50,
		"chance": 18
	}
}


func _ready() -> void:
	_log("=== End of Round Stats Panel Test ===")
	_log("Press keys to test:")
	_log("  1 - Show stats panel with Allowance bonus included")
	_log("  2 - Show stats panel with score-above-target cap and PowerUp bonuses")
	_log("  3 - Show stats panel with no bonuses")
	_log("  4 - Show stats panel with many empty categories")
	_log("  5 - Test bonus calculations only")
	_log("  ESC - Close panel")
	_log("")
	
	# Connect to panel signals
	if stats_panel:
		stats_panel.continue_to_shop_pressed.connect(_on_continue_pressed)
		stats_panel.panel_closed.connect(_on_panel_closed)
		_log("[OK] Stats panel found and signals connected")
	else:
		_log("[ERROR] Stats panel not found!")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_test_default_values()
			KEY_2:
				_test_high_bonuses()
			KEY_3:
				_test_no_bonuses()
			KEY_4:
				_test_many_empty_categories()
			KEY_5:
				_test_bonus_calculations()
			KEY_ESCAPE:
				if stats_panel and stats_panel.visible:
					stats_panel._hide_panel()


func _test_default_values() -> void:
	_log("\n--- Test: Default Values ---")
	_log("Round: 1, Target: 100, Final: 130, Empty: 3, PowerUp Bonus: 100")
	
	var data = {
		"round_number": 1,
		"challenge_target": 100,
		"final_score": 130,
		"empty_categories": 3,
		"empty_categories_bonus": 30,
		"points_above_target": 30,
		"score_above_bonus": 30,
		"power_up_bonus": DEFAULT_POWER_UP_BONUS
	}
	
	stats_panel.show_stats(data)
	
	# Expected: Empty bonus = 3 * $5 = $30, Score bonus = 30 * $1 = $30, PowerUp = $100, Total = $160
	_log("Expected bonuses: Empty=$15, Score=$30, PowerUps=$100, Total=$145")


func _test_high_bonuses() -> void:
	_log("\n--- Test: High Bonuses ---")
	_log("Round: 3, Target: 150, Final: 320, Empty: 7, PowerUp Bonus: 180")
	
	var data = {
		"round_number": 3,
		"challenge_target": 150,
		"final_score": 320,
		"empty_categories": 7,
		"empty_categories_bonus": 70,
		"points_above_target": 170,
		"score_above_bonus": SCORE_ABOVE_TARGET_CAP,
		"power_up_bonus": 180
	}
	
	stats_panel.show_stats(data)
	
	# Expected: Empty bonus = 7 * $5 = $35, Score bonus = capped at $100, PowerUps = $180, Total = $315
	_log("Expected bonuses: Empty=$35, Score=$100 (capped), PowerUps=$180, Total=$315")


func _test_no_bonuses() -> void:
	_log("\n--- Test: No Bonuses ---")
	_log("Round: 2, Target: 200, Final: 180, Empty: 0")
	
	var data = {
		"round_number": 2,
		"challenge_target": 200,
		"final_score": 180,
		"empty_categories": 0,
		"empty_categories_bonus": 0,
		"points_above_target": 0,
		"score_above_bonus": 0,
		"power_up_bonus": 0
	}
	
	stats_panel.show_stats(data)
	
	# Expected: Empty bonus = 0, Score bonus = 0 (below target), Total = $0
	_log("Expected bonuses: Empty=$0, Score=$0, Total=$0")


func _test_many_empty_categories() -> void:
	_log("\n--- Test: Many Empty Categories ---")
	_log("Round: 1, Target: 50, Final: 50, Empty: 10")
	
	var data = {
		"round_number": 1,
		"challenge_target": 50,
		"final_score": 50,
		"empty_categories": 10,
		"empty_categories_bonus": 100,
		"points_above_target": 0,
		"score_above_bonus": 0,
		"power_up_bonus": 0
	}
	
	stats_panel.show_stats(data)
	
	# Expected: Empty bonus = 10 * $10 = $100, Score bonus = 0, Total = $100
	_log("Expected bonuses: Empty=$100, Score=$0, PowerUps=$0, Total=$100")


func _test_bonus_calculations() -> void:
	_log("\n--- Test: Bonus Calculations (no UI) ---")
	
	# Test empty category counting with mock scorecard
	var empty_count = _count_mock_empty_categories()
	_log("Mock scorecard empty categories: %d" % empty_count)
	_log("Expected: 3 (twos, fours, four_of_a_kind)")
	
	# Test bonus formulas
	var empty_bonus = empty_count * EMPTY_CATEGORY_BONUS
	_log("Empty category bonus ($10 each): $%d" % empty_bonus)
	
	var points_above = max(0, 130 - 100)
	var score_bonus = min(SCORE_ABOVE_TARGET_CAP, points_above * POINTS_ABOVE_TARGET_BONUS)
	_log("Points above target bonus (30 × $1): $%d" % score_bonus)

	var power_up_bonus = DEFAULT_POWER_UP_BONUS
	_log("PowerUp bonus preview: $%d" % power_up_bonus)
	
	var total = empty_bonus + score_bonus + power_up_bonus
	_log("Total bonus: $%d" % total)
	
	# Verify
	if empty_count == 3 and empty_bonus == 30 and score_bonus == 30 and total == 160:
		_log("[PASS] All calculations correct!")
	else:
		_log("[FAIL] Calculation mismatch!")


func _count_mock_empty_categories() -> int:
	var count = 0
	for category in mock_scorecard.upper_scores.keys():
		if mock_scorecard.upper_scores[category] == null:
			count += 1
	for category in mock_scorecard.lower_scores.keys():
		if mock_scorecard.lower_scores[category] == null:
			count += 1
	return count


func _on_continue_pressed() -> void:
	_log("\n[EVENT] Continue to shop pressed!")
	_log("Total bonus awarded: $%d" % stats_panel.get_total_bonus())
	_log("  - Empty categories: $%d" % stats_panel.get_empty_categories_bonus())
	_log("  - Score above target: $%d" % stats_panel.get_score_above_bonus())
	_log("  - PowerUp bonuses: $%d" % stats_panel.get_power_up_bonus())


func _on_panel_closed() -> void:
	_log("[EVENT] Panel closed")


func _log(message: String) -> void:
	print(message)
	if output_label:
		output_label.append_text(message + "\n")
