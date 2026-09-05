extends Control
class_name BestHandDiceSetTest

## best_hand_dice_set_test.gd
##
## Verifies scorecard row labels and ghost previews follow the active
## dice set:
## 1. On d4, row labels read Evens/Odds/Even Odd Full House (never
##    "Fives"/"Sixes"/"Large Straight").
## 2. Switching the dice set restores the correct row labels.
## 3. Ghost previews qualify rows the current dice actually score in.
##
## The old Best Hand panel this test originally targeted was removed in the
## scorecard row-list refactor; per-row ghost previews replaced it.
##
## Run headless with `-- --auto-test` to run the suite and quit with an
## exit code (0 = pass, 1 = fail).

const ScorecardScript = preload("res://Scenes/ScoreCard/score_card.gd")
const SCORECARD_UI_SCENE := preload("res://Scenes/UI/Scorecard/scorecard.tscn")

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
	score_card_ui = SCORECARD_UI_SCENE.instantiate()
	add_child(score_card_ui)
	score_card_ui.bind_scorecard(scorecard)

func _run_tests() -> void:
	if not score_card_ui:
		_fail("ScoreCardUI missing")
		return

	print("--- d4 labels ---")
	_set_dice_set(4)
	_assert_equals(_row_label_text("fives"), "Evens", "d4 fives row labeled Evens")
	_assert_equals(_row_label_text("sixes"), "Odds", "d4 sixes row labeled Odds")
	_assert_equals(_row_label_text("large_straight"), "Even Odd Full House", "d4 large straight row labeled Even Odd Full House")

	print("--- d4 ghost preview ---")
	# [2,2,3,3,3] is an even/odd full house on the d4 set
	DiceResults.set_values([2, 2, 3, 3, 3])
	score_card_ui.update_best_hand_preview(DiceResults.values)
	var eo_row: ScorecardRow = score_card_ui.rows[&"large_straight"]
	_assert(eo_row._has_ghost, "d4 ghost shown on Even Odd Full House row for [2,2,3,3,3]")
	_assert(not _contains_d6_only_name(_row_label_text("large_straight")), "d4 row has no d6-only name (got: %s)" % _row_label_text("large_straight"))

	print("--- dice set switch restores labels ---")
	_set_dice_set(6)
	_assert_equals(_row_label_text("fives"), "Fives", "d6 fives row restored")
	_assert_equals(_row_label_text("sixes"), "Sixes", "d6 sixes row restored")
	_assert_equals(_row_label_text("large_straight"), "Large Straight", "d6 large straight row restored")

	print("--- d6 ghost preview ---")
	DiceResults.set_values([5, 5, 5, 5, 5])
	score_card_ui.update_best_hand_preview(DiceResults.values)
	var yahtzee_row: ScorecardRow = score_card_ui.rows[&"yahtzee"]
	_assert(yahtzee_row._has_ghost, "d6 ghost shown on Yahtzee row for [5,5,5,5,5]")

	print("--- d20 sixth slot ---")
	_set_dice_set(20)
	_assert_equals(_row_label_text("sixes"), "Twenties", "d20 sixes row labeled Twenties")
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

func _row_label_text(category: String) -> String:
	var row: ScorecardRow = score_card_ui.rows.get(StringName(category))
	if row:
		return row.name_label.text
	return "<missing>"

func _contains_d6_only_name(text: String) -> bool:
	# "Fives"/"Sixes"/"Large Straight" are d6-era names; on d4 the rows are
	# Evens/Odds/Even Odd Full House.
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
