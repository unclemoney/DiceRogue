extends Control
class_name BestHandDiceSetTest

## best_hand_dice_set_test.gd
##
## Verifies the Best Hand panel and scorecard row labels follow the active
## dice set:
## 1. On d4, row labels read Evens/Odds/EO Full House and the Best Hand
##    preview uses the same dice-set-aware names (never "Fives"/"Sixes"/
##    "Large Straight").
## 2. Switching the dice set clears the stale Best Hand preview and
##    restores the correct row labels.
## 3. The previewed category is always available for the active dice set.
##
## Run headless with `-- --auto-test` to run the suite and quit with an
## exit code (0 = pass, 1 = fail).

const ScorecardScript = preload("res://Scenes/ScoreCard/score_card.gd")

var scorecard: Scorecard
var score_card_ui: ScoreCardUI
var _fail_count := 0
var _test_completed := false

func _ready() -> void:
	print("=== Best Hand Dice Set Test ===")
	_setup()
	await get_tree().process_frame
	await get_tree().process_frame
	_run_tests()
	_test_completed = true
	if "--auto-test" in OS.get_cmdline_user_args():
		_quit_with_result()
	elif DisplayServer.get_name() == "headless":
		_quit_with_result()

func _setup() -> void:
	scorecard = ScorecardScript.new()
	scorecard.name = "TestScorecard"
	add_child(scorecard)
	var ui_scene = preload("res://Scenes/UI/score_card_ui.tscn")
	score_card_ui = ui_scene.instantiate()
	add_child(score_card_ui)
	score_card_ui.bind_scorecard(scorecard)

func _run_tests() -> void:
	if not score_card_ui:
		_fail("ScoreCardUI missing")
		return

	print("--- d4 labels ---")
	_set_dice_set(4)
	_assert_equals(_row_button_text("fives"), "Evens:", "d4 fives row labeled Evens:")
	_assert_equals(_row_button_text("sixes"), "Odds:", "d4 sixes row labeled Odds:")
	_assert_equals(_large_straight_button_text(), "EO Full House:", "d4 large straight row labeled EO Full House:")

	print("--- d4 best hand preview ---")
	var d4_hand: Array[int] = [2, 2, 3, 3, 3]
	score_card_ui.update_best_hand_preview(d4_hand)
	var label_text: String = score_card_ui.best_hand_label.text
	_assert(label_text.contains("Even Odd Full House"), "d4 best hand shows Even Odd Full House (got: %s)" % label_text)
	_assert(not _contains_d6_only_name(label_text), "d4 best hand has no d6-only names (got: %s)" % label_text)
	_assert(scorecard.is_category_available_for_dice_set(score_card_ui.current_best_hand_category),
		"d4 best hand category '%s' is available for the set" % score_card_ui.current_best_hand_category)

	# A yahtzee roll on d4 must also avoid d6-only names
	var d4_yahtzee: Array[int] = [4, 4, 4, 4, 4]
	score_card_ui.update_best_hand_preview(d4_yahtzee)
	label_text = score_card_ui.best_hand_label.text
	_assert(label_text.contains("Yahtzee"), "d4 best hand shows Yahtzee for [4,4,4,4,4] (got: %s)" % label_text)
	_assert(not _contains_d6_only_name(label_text), "d4 yahtzee preview has no d6-only names (got: %s)" % label_text)

	print("--- dice set switch clears stale best hand ---")
	_set_dice_set(6)
	_assert_equals(score_card_ui.best_hand_label.text, ScoreCardUI.SUMMARY_BEST_HAND_PLACEHOLDER,
		"Best Hand label reset to placeholder after switching to d6")
	_assert_equals(score_card_ui.current_best_hand_category, "", "Best Hand category cleared after switch")
	_assert_equals(_row_button_text("fives"), "Fives:", "d6 fives row restored")
	_assert_equals(_row_button_text("sixes"), "Sixes:", "d6 sixes row restored")
	_assert_equals(_large_straight_button_text(), "L Straight:", "d6 large straight row restored")

	print("--- d6 best hand preview ---")
	var d6_yahtzee: Array[int] = [5, 5, 5, 5, 5]
	score_card_ui.update_best_hand_preview(d6_yahtzee)
	label_text = score_card_ui.best_hand_label.text
	_assert(label_text.contains("Yahtzee"), "d6 best hand shows Yahtzee for [5,5,5,5,5] (got: %s)" % label_text)

	print("--- d20 sixth slot ---")
	_set_dice_set(20)
	_assert_equals(_row_button_text("sixes"), "Twenties:", "d20 sixes row labeled Twenties:")
	var d20_yahtzee: Array[int] = [20, 20, 20, 20, 20]
	score_card_ui.update_best_hand_preview(d20_yahtzee)
	label_text = score_card_ui.best_hand_label.text
	_assert(not label_text.contains("Sixes"), "d20 best hand never shows 'Sixes' (got: %s)" % label_text)
	_set_dice_set(6)

	var result_text := "PASS"
	if _fail_count > 0:
		result_text = "FAIL"
	print("=== Best Hand Dice Set Test Complete: %s ===" % result_text)

## _set_dice_set(sides) -> void
##
## Applies a dice set the way RoundManager.start_round() does: scorecard,
## evaluator, and UI labels together.
func _set_dice_set(sides: int) -> void:
	scorecard.set_dice_type(sides)
	ScoreEvaluatorSingleton.set_dice_sides(sides)
	score_card_ui.update_dice_set_category_labels()

func _row_button_text(category: String) -> String:
	var node_name: String = category.capitalize()
	var button = score_card_ui.get_node_or_null(
		"VBoxContainer/UpperVBoxContainer/UpperGridContainer/%sContainer/%sButton" % [node_name, node_name])
	if button:
		return button.text
	return "<missing>"

func _large_straight_button_text() -> String:
	var button = score_card_ui.get_node_or_null(
		"VBoxContainer/LowerVBoxContainer/LowerGridContainer/Largestraight/LargestraightButton")
	if button:
		return button.text
	return "<missing>"

func _contains_d6_only_name(text: String) -> bool:
	# "Fives"/"Sixes"/"Large Straight" are d6-era names; on d4 the rows are
	# Evens/Odds/EO Full House. ("Even Odd Full House" contains no d6 name.)
	if text.contains("Fives") or text.contains("Sixes"):
		return true
	if text.contains("Large Straight") and not text.contains("Even Odd Full House"):
		return true
	return false

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("✓ %s" % message)
	else:
		_fail_count += 1
		push_error("[BestHandDiceSetTest] FAIL: %s" % message)
		print("✗ %s" % message)

func _assert_equals(actual, expected, message: String) -> void:
	_assert(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func _fail(message: String) -> void:
	_fail_count += 1
	push_error("[BestHandDiceSetTest] FAIL: %s" % message)
	print("✗ %s" % message)

func _quit_with_result() -> void:
	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _input(event: InputEvent) -> void:
	if _test_completed and event.is_action_pressed("ui_accept"):
		_quit_with_result()
