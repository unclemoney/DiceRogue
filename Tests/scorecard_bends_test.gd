extends Control

## ScorecardBendsTest
##
## Headless auto-run test for rule-bending scorecard features:
## 1. FourOfAKindYahtzee PowerUp: [4,4,4,4,2] scores 25 in yahtzee with the
##    flag on, 0 with it off, and never trips is_yahtzee() bonus detection.
## 2. TwoPairHouse PowerUp: [3,3,5,5,1] scores 25 in full_house with the
##    flag on, 0 with it off.
## 3. UpperCrustPowerUp: registers its 1.5x multiplier for upper section
##    scores only, and unregisters after scoring.
## 4. BonusSprintConsumable: doubles progress toward the upper bonus
##    threshold and resets at the round transition.
##
## Prints OK/FAILED per check and quits with exit code 0 (pass) or 1 (fail).

var _fail_count := 0

var scorecard: Scorecard
var _fake_score_card_ui: FakeScoreCardUIScript
var _fake_game_controller: FakeGameControllerScript


func _ready() -> void:
	_run_tests.call_deferred()


func _auto_assert(condition: bool, message: String) -> void:
	if condition:
		print("OK: %s" % message)
	else:
		_fail_count += 1
		print("FAILED: %s" % message)


func _run_tests() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("=== ScorecardBendsTest ===")
	
	scorecard = Scorecard.new()
	add_child(scorecard)
	DiceResults.scorecard = scorecard
	
	_test_four_kind_yahtzee()
	_test_two_pair_house()
	_test_upper_crust()
	_test_bonus_sprint()
	
	# Clean up shared state
	DiceResults.scorecard = null
	
	print("=== ScorecardBendsTest complete: %d failure(s) ===" % _fail_count)
	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


## _test_four_kind_yahtzee()
##
## [4,4,4,4,2] scores 25 in yahtzee only while allow_four_kind_yahtzee is set,
## a real Yahtzee still scores 50, and is_yahtzee() is not bent (bonus safe).
func _test_four_kind_yahtzee() -> void:
	print("--- FourKindYahtzee ---")
	var four_kind: Array[int] = [4, 4, 4, 4, 2]
	var real_yahtzee: Array[int] = [5, 5, 5, 5, 5]
	
	_auto_assert(scorecard.calculate_score("yahtzee", four_kind) == 0,
		"yahtzee four-kind scores 0 with flag off")
	
	scorecard.allow_four_kind_yahtzee = true
	_auto_assert(scorecard.calculate_score("yahtzee", four_kind) == 25,
		"yahtzee four-kind scores 25 with flag on (got %d)" % scorecard.calculate_score("yahtzee", four_kind))
	_auto_assert(scorecard.calculate_score("yahtzee", real_yahtzee) == 50,
		"real yahtzee still scores 50 with flag on (got %d)" % scorecard.calculate_score("yahtzee", real_yahtzee))
	_auto_assert(not ScoreEvaluatorSingleton.is_yahtzee(four_kind),
		"is_yahtzee() stays false for four-kind (bonus logic untouched)")
	_auto_assert(ScoreEvaluatorSingleton.is_yahtzee(real_yahtzee),
		"is_yahtzee() still true for a real yahtzee")
	_auto_assert(scorecard.calculate_score("four_of_a_kind", four_kind) == 18,
		"four_of_a_kind category unchanged with flag on (got %d)" % scorecard.calculate_score("four_of_a_kind", four_kind))
	
	scorecard.allow_four_kind_yahtzee = false
	_auto_assert(scorecard.calculate_score("yahtzee", four_kind) == 0,
		"yahtzee four-kind back to 0 with flag off")


## _test_two_pair_house()
##
## [3,3,5,5,1] scores 25 in full_house only while allow_two_pair_full_house
## is set; a real full house is unaffected.
func _test_two_pair_house() -> void:
	print("--- TwoPairHouse ---")
	var two_pair: Array[int] = [3, 3, 5, 5, 1]
	var real_full_house: Array[int] = [3, 3, 3, 5, 5]
	
	_auto_assert(scorecard.calculate_score("full_house", two_pair) == 0,
		"full_house two-pair scores 0 with flag off")
	
	scorecard.allow_two_pair_full_house = true
	_auto_assert(scorecard.calculate_score("full_house", two_pair) == 25,
		"full_house two-pair scores 25 with flag on (got %d)" % scorecard.calculate_score("full_house", two_pair))
	_auto_assert(scorecard.calculate_score("full_house", real_full_house) == 25,
		"real full house still scores 25 with flag on")
	_auto_assert(scorecard.calculate_score("chance", two_pair) == 17,
		"chance category unchanged with flag on (got %d)" % scorecard.calculate_score("chance", two_pair))
	
	scorecard.allow_two_pair_full_house = false
	_auto_assert(scorecard.calculate_score("full_house", two_pair) == 0,
		"full_house two-pair back to 0 with flag off")


## _test_upper_crust()
##
## UpperCrustPowerUp registers a 1.5x multiplier when about_to_score fires
## for the UPPER section and unregisters it on score_assigned.
func _test_upper_crust() -> void:
	print("--- UpperCrust ---")
	
	# Stub ScoreCardUI + GameController so apply() can connect its signals
	_fake_score_card_ui = FakeScoreCardUIScript.new()
	add_child(_fake_score_card_ui)
	
	_fake_game_controller = FakeGameControllerScript.new()
	_fake_game_controller.score_card_ui = _fake_score_card_ui
	add_child(_fake_game_controller)
	
	var power_up = UpperCrustPowerUp.new()
	add_child(power_up)
	power_up.apply(scorecard)
	
	_auto_assert(not ScoreModifierManager.has_multiplier("upper_crust"),
		"no upper_crust multiplier before scoring")
	
	# Upper section: multiplier registers and affects the calculated score
	var sixes_values: Array[int] = [6, 6, 6, 1, 2]
	_fake_score_card_ui.about_to_score.emit(Scorecard.Section.UPPER, "sixes", sixes_values)
	_auto_assert(ScoreModifierManager.has_multiplier("upper_crust"),
		"upper_crust multiplier registered for upper section")
	_auto_assert(is_equal_approx(ScoreModifierManager.get_multiplier("upper_crust"), 1.5),
		"upper_crust multiplier is 1.5 (got %.2f)" % ScoreModifierManager.get_multiplier("upper_crust"))
	_auto_assert(scorecard.calculate_score("sixes", [6, 6, 6, 1, 2]) == 27,
		"sixes [6,6,6,1,2] scores 27 with 1.5x (got %d)" % scorecard.calculate_score("sixes", [6, 6, 6, 1, 2]))
	
	# score_assigned unregisters the multiplier
	scorecard.set_score(Scorecard.Section.UPPER, "sixes", 27)
	_auto_assert(not ScoreModifierManager.has_multiplier("upper_crust"),
		"upper_crust multiplier unregistered after score_assigned")
	
	# Lower section: multiplier does not register
	_fake_score_card_ui.about_to_score.emit(Scorecard.Section.LOWER, "chance", sixes_values)
	_auto_assert(not ScoreModifierManager.has_multiplier("upper_crust"),
		"no upper_crust multiplier for lower section")
	_auto_assert(scorecard.calculate_score("chance", sixes_values) == 21,
		"chance [6,6,6,1,2] scores 21 unmodified (got %d)" % scorecard.calculate_score("chance", sixes_values))
	
	power_up.remove(scorecard)
	power_up.queue_free()
	_fake_game_controller.queue_free()
	_fake_score_card_ui.queue_free()


## _test_bonus_sprint()
##
## upper_bonus_progress_multiplier doubles progress toward the 63 threshold
## (raw scores unchanged) and resets via reset_scores_preserve_levels().
func _test_bonus_sprint() -> void:
	print("--- BonusSprint ---")
	scorecard.reset_scores()
	
	# Baseline: raw 33 in the upper section does not award the bonus
	scorecard.set_score(Scorecard.Section.UPPER, "sixes", 18)
	scorecard.set_score(Scorecard.Section.UPPER, "fives", 15)
	_auto_assert(scorecard.get_upper_section_total() == 33,
		"raw upper total is 33")
	_auto_assert(scorecard.get_upper_bonus_progress() == 33,
		"bonus progress matches raw total at x1.0")
	_auto_assert(not scorecard.upper_bonus_awarded,
		"no upper bonus at raw 33 / threshold 63")
	
	# Round transition resets any lingering consumable state
	scorecard.reset_scores_preserve_levels()
	_auto_assert(is_equal_approx(scorecard.upper_bonus_progress_multiplier, 1.0),
		"progress multiplier is 1.0 after round reset")
	_auto_assert(scorecard.upper_bonus_progress_extra == 0,
		"extra progress is 0 after round reset")
	
	# Consumable effect: upper scores count double toward the threshold
	scorecard.upper_bonus_progress_multiplier = 2.0
	scorecard.set_score(Scorecard.Section.UPPER, "sixes", 18)
	_auto_assert(scorecard.get_upper_section_total() == 18,
		"raw upper total still 18 with Bonus Sprint active")
	_auto_assert(scorecard.get_upper_bonus_progress() == 36,
		"bonus progress doubled to 36 (got %d)" % scorecard.get_upper_bonus_progress())
	scorecard.set_score(Scorecard.Section.UPPER, "fives", 15)
	_auto_assert(scorecard.get_upper_bonus_progress() == 66,
		"bonus progress 66 after doubled 15 (got %d)" % scorecard.get_upper_bonus_progress())
	_auto_assert(scorecard.upper_bonus_awarded,
		"upper bonus awarded at progress 66 despite raw total 33")
	_auto_assert(scorecard.upper_bonus == 35,
		"upper bonus amount is 35")
	_auto_assert(scorecard.get_upper_section_final_total() == 68,
		"upper final total includes bonus: 33 + 35 = 68 (got %d)" % scorecard.get_upper_section_final_total())
	
	# One-round duration: round reset restores normal behavior
	scorecard.reset_scores_preserve_levels()
	_auto_assert(is_equal_approx(scorecard.upper_bonus_progress_multiplier, 1.0),
		"progress multiplier reset to 1.0 at round end")
	_auto_assert(scorecard.upper_bonus_progress_extra == 0,
		"extra progress reset at round end")
	_auto_assert(not scorecard.upper_bonus_awarded,
		"upper bonus award reset at round end")
	scorecard.set_score(Scorecard.Section.UPPER, "sixes", 18)
	_auto_assert(scorecard.get_upper_bonus_progress() == 18,
		"progress no longer doubled after reset (got %d)" % scorecard.get_upper_bonus_progress())


## FakeScoreCardUIScript
##
## Minimal stub exposing the about_to_score signal UpperCrustPowerUp connects to.
class FakeScoreCardUIScript extends Node:
	signal about_to_score(section: Scorecard.Section, category: String, dice_values: Array[int])


## FakeGameControllerScript
##
## Minimal stub standing in for GameController in the game_controller group.
class FakeGameControllerScript extends Node:
	var score_card_ui: Node = null
	
	func _enter_tree() -> void:
		add_to_group("game_controller")
