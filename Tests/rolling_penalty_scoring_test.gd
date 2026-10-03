extends Node
class_name RollingPenaltyScoringTest

## RollingPenaltyScoringTest
##
## Headless pipeline test for the Rolling Penalty (roll_score_minus_one)
## refactor: the penalty is a ScoreModifierManager negative additive applied
## before multipliers, categorized "debuff" in the breakdown, clamped at zero
## after the additive stage, and never applied twice.
##
## Run: godot --path <project> Tests/rolling_penalty_scoring_test.tscn
## Exits 0 on PASS, 1 on FAIL.

const ScorecardScript = preload("res://Scenes/ScoreCard/score_card.gd")
const RollScoreMinusOneDebuffScript = preload("res://Scripts/Debuff/roll_score_minus_one_debuff.gd")

var _failures: int = 0
var _scorecard: Scorecard


func _ready() -> void:
	await get_tree().process_frame

	ScoreModifierManager.reset()
	_scorecard = ScorecardScript.new()
	_scorecard.name = "TestScorecard"
	add_child(_scorecard)

	_test_penalty_in_breakdown_as_debuff()
	_test_debuff_penalty_sources_categorized()
	_test_penalty_applies_before_multipliers()
	_test_additive_stage_clamps_at_zero()
	_test_decimal_multiplier_floors()
	_test_debuff_runtime_api_and_signal()
	_test_no_double_application()

	ScoreModifierManager.reset()

	if _failures == 0:
		print("[RollingPenaltyScoringTest] ALL TESTS PASSED")
		get_tree().quit(0)
	else:
		print("[RollingPenaltyScoringTest] %d TEST(S) FAILED" % _failures)
		get_tree().quit(1)


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		push_error("  FAIL: %s" % label)


## Case 1: penalty shows up in the breakdown as a debuff additive.
func _test_penalty_in_breakdown_as_debuff() -> void:
	print("[RollingPenaltyScoringTest] Case 1: breakdown includes penalty as debuff source")
	ScoreModifierManager.reset()
	ScoreModifierManager.register_additive("roll_score_minus_one", -2)

	var info: Dictionary = _scorecard.debug_simulate_score("chance", [2, 2, 2, 2, 2])
	_assert(int(info.get("base_score", -1)) == 10, "base score of chance [2,2,2,2,2] is 10")

	var found := false
	for source_info in info.get("additive_sources", []):
		if source_info.get("name", "") == "roll_score_minus_one":
			found = true
			_assert(source_info.get("category", "") == "debuff", "penalty source categorized as 'debuff'")
			_assert(int(source_info.get("value", 0)) == -2, "penalty source value is -2")
	_assert(found, "additive_sources contains roll_score_minus_one")
	_assert(int(info.get("final_score", -1)) == 8, "final score 10 - 2 = 8")


## Case 1b: half_additive and greed penalties also categorize as debuff sources,
## so the scoring animation replays them (category "other" was silently dropped).
func _test_debuff_penalty_sources_categorized() -> void:
	print("[RollingPenaltyScoringTest] Case 1b: debuff penalty sources categorized as debuff")
	ScoreModifierManager.reset()
	ScoreModifierManager.register_additive("half_additive_penalty", -5)
	ScoreModifierManager.register_additive("greed_penalty", -3)

	var info: Dictionary = _scorecard.debug_simulate_score("chance", [2, 2, 2, 2, 2])
	var seen := {}
	for source_info in info.get("additive_sources", []):
		var source_name: String = source_info.get("name", "")
		if source_name == "half_additive_penalty" or source_name == "greed_penalty":
			seen[source_name] = source_info.get("category", "")
	_assert(seen.get("half_additive_penalty", "") == "debuff", "half_additive_penalty categorized as 'debuff'")
	_assert(seen.get("greed_penalty", "") == "debuff", "greed_penalty categorized as 'debuff'")
	_assert(int(info.get("final_score", -1)) == 2, "final score 10 - 5 - 3 = 2")


## Case 2: penalty applies BEFORE multipliers (not after).
func _test_penalty_applies_before_multipliers() -> void:
	print("[RollingPenaltyScoringTest] Case 2: penalty applies before multipliers")
	ScoreModifierManager.reset()
	ScoreModifierManager.register_additive("roll_score_minus_one", -2)
	ScoreModifierManager.register_multiplier("test_powerup", 2.0)

	var info: Dictionary = _scorecard.debug_simulate_score("chance", [2, 2, 2, 2, 2])
	# int(max(0, 10 - 2) * 2.0) = 16; post-multiplier penalty would give 18
	_assert(int(info.get("final_score", -1)) == 16, "final score int(max(0, 10-2) x 2.0) = 16 (not 18)")


## Case 3: the score clamps to zero after the additive stage.
func _test_additive_stage_clamps_at_zero() -> void:
	print("[RollingPenaltyScoringTest] Case 3: additive stage clamps at zero")
	ScoreModifierManager.reset()
	ScoreModifierManager.register_additive("roll_score_minus_one", -15)
	ScoreModifierManager.register_multiplier("test_powerup", 2.0)

	var info: Dictionary = _scorecard.debug_simulate_score("chance", [2, 2, 2, 2, 2])
	_assert(float(info.get("score_after_additives", -1.0)) == 0.0, "score_after_additives clamped to 0")
	_assert(int(info.get("final_score", -1)) == 0, "final score is 0 (multipliers never amplify a negative)")


## Case 4: decimal multipliers floor (truncate) the authoritative score.
func _test_decimal_multiplier_floors() -> void:
	print("[RollingPenaltyScoringTest] Case 4: decimal multipliers floor the final score")
	ScoreModifierManager.reset()
	ScoreModifierManager.register_additive("roll_score_minus_one", -1)
	ScoreModifierManager.register_multiplier("test_powerup", 1.5)

	var info: Dictionary = _scorecard.debug_simulate_score("chance", [2, 2, 2, 2, 2])
	# max(0, 10 - 1) * 1.5 = 13.5 -> int() = 13
	_assert(int(info.get("final_score", -1)) == 13, "final score int(9 x 1.5) = 13 (floor, not round-up)")


## Case 5: runtime API and signal on the debuff itself.
func _test_debuff_runtime_api_and_signal() -> void:
	print("[RollingPenaltyScoringTest] Case 5: get_current_penalty / penalty_changed")
	ScoreModifierManager.reset()
	var debuff = RollScoreMinusOneDebuffScript.new()
	debuff.name = "TestRollingPenalty"
	add_child(debuff)
	debuff.is_active = true  # apply() needs a GameController; drive the roll hook directly

	var emissions: Array = []
	debuff.penalty_changed.connect(func(new_penalty: int): emissions.append(new_penalty))

	for i in range(3):
		debuff._on_roll_complete()

	_assert(debuff.roll_count == 3, "roll_count is 3 after three rolls")
	_assert(debuff.get_current_penalty() == 3, "get_current_penalty() returns raw roll count (3)")
	_assert(emissions == [1, 2, 3], "penalty_changed emitted per roll with the new value")
	_assert(ScoreModifierManager.has_additive("roll_score_minus_one"), "negative additive registered")
	_assert(ScoreModifierManager.get_additive("roll_score_minus_one") == -3, "registered additive value is -3 (single registration, updated)")

	debuff.remove()
	_assert(not ScoreModifierManager.has_additive("roll_score_minus_one"), "additive unregistered on remove()")
	_assert(debuff.roll_count == 0, "roll_count reset on remove()")
	debuff.queue_free()


## Case 6: the penalty is not applied twice through set_score's legacy path.
func _test_no_double_application() -> void:
	print("[RollingPenaltyScoringTest] Case 6: no double application via set_score")
	ScoreModifierManager.reset()
	ScoreModifierManager.register_additive("roll_score_minus_one", -3)

	var result: Dictionary = _scorecard.calculate_score_with_breakdown("chance", [2, 2, 2, 2, 2], false)
	var computed := int(result.get("final_score", -1))
	_assert(computed == 7, "pipeline score 10 - 3 = 7")

	_scorecard.set_score(Scorecard.Section.LOWER, "chance", computed)
	_assert(int(_scorecard.lower_scores["chance"]) == 7, "stored score equals pipeline score (legacy modifier path does not subtract again)")
	ScoreModifierManager.reset()
