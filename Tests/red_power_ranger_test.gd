extends Control

## red_power_ranger_test.gd
##
## Regression test for the Red Power Ranger additive persistence bug:
## ScoreModifierManager.reset() on channel transitions wiped the accumulated
## additive, and apply() never re-registered it, so the bonus only appeared
## on hands that scored red dice. The additive must apply to every scored
## hand once accumulated, and re-register on apply() and on any score.

const RedPowerRangerScene := preload("res://Scenes/PowerUp/RedPowerRanger.tscn")
const ScoreCardScene := preload("res://Scenes/ScoreCard/score_card.tscn")

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	print("\n=== RED POWER RANGER PERSISTENCE TEST ===")
	await get_tree().process_frame
	_run_tests()
	_finish()


func _check(condition: bool, label: String) -> void:
	var status := "PASS" if condition else "FAIL"
	if not condition:
		_failures += 1
	var line := "%s: %s" % [status, label]
	print(line)
	_lines.append(line)


func _run_tests() -> void:
	ScoreModifierManager.reset()
	if DiceResults:
		DiceResults.dice_refs = []

	var scorecard: Scorecard = ScoreCardScene.instantiate()
	add_child(scorecard)

	var power_up = RedPowerRangerScene.instantiate()
	add_child(power_up)
	_check(power_up is RedPowerRangerPowerUp, "scene instantiates as RedPowerRangerPowerUp")

	power_up.apply(scorecard)

	# Simulate previously accumulated additive (as if red dice were scored before)
	power_up.current_additive = 5
	power_up.total_red_dice_scored = 1

	# 1. Channel transition: reset wipes registrations, re-apply must restore
	ScoreModifierManager.reset()
	_check(not ScoreModifierManager.has_additive("red_power_ranger"), "reset() wipes red_power_ranger additive")
	power_up.apply(scorecard)
	_check(ScoreModifierManager.get_additive("red_power_ranger") == 5, "apply() re-registers accumulated additive after reset")

	# 2. Self-heal: a non-red scored hand re-registers the accumulated additive
	ScoreModifierManager.reset()
	scorecard.emit_signal("score_assigned", Scorecard.Section.UPPER, "ones", 3)
	_check(ScoreModifierManager.get_additive("red_power_ranger") == 5, "non-red score re-registers accumulated additive")

	# 3. Non-red hand does not grow the total
	_check(power_up.current_additive == 5, "non-red hand leaves current_additive unchanged")
	_check(power_up.total_red_dice_scored == 1, "non-red hand leaves total_red_dice_scored unchanged")

	# 4. remove() unregisters the additive
	power_up.remove(scorecard)
	_check(not ScoreModifierManager.has_additive("red_power_ranger"), "remove() unregisters additive")

	power_up.queue_free()
	scorecard.queue_free()
	ScoreModifierManager.reset()


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[RedPowerRangerTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(_failures)
