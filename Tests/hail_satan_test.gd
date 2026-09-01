extends Control

## hail_satan_test.gd
##
## Verifies the Hail Satan debuff (id "hail_satan"):
## resource config, scene instantiation, and the roll trigger — 3+ sixes
## in the hand (locked dice included, via DiceResults.values) ends the turn
## immediately with a 0 scored in a random unscored category.

const DiceHandScene := preload("res://Scenes/Dice/dice_hand.tscn")
const ScoreCardScene := preload("res://Scenes/ScoreCard/score_card.tscn")

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


## StubGameController
##
## GameController subclass that never enters the tree, so its @onready
## node lookups never run; references are assigned directly by the test.
class StubGameController extends GameController:
	pass


## StubScoreCardUI
##
## Minimal scorecard_ui group member tracking the calls the debuff makes.
class StubScoreCardUI extends Node:
	signal hand_scored
	var turn_scored := false
	var buttons_disabled := false

	func disable_all_score_buttons() -> void:
		buttons_disabled = true

	func enable_all_score_buttons() -> void:
		buttons_disabled = false


func _ready() -> void:
	print("\n=== HAIL SATAN DEBUFF TEST ===")
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


func _scored_category_count(scorecard: Scorecard) -> int:
	var count := 0
	for category in scorecard.upper_scores:
		if scorecard.upper_scores[category] != null:
			count += 1
	for category in scorecard.lower_scores:
		if scorecard.lower_scores[category] != null:
			count += 1
	return count


func _run_tests() -> void:
	# 1. Resource loads with expected metadata
	var data: DebuffData = load("res://Scripts/Debuff/HailSatanDebuff.tres")
	_check(data != null, "HailSatanDebuff.tres loads as DebuffData")
	if not data:
		return
	_check(data.id == "hail_satan", "id is 'hail_satan'")
	_check(data.difficulty_rating == 4, "difficulty_rating is 4")
	_check(data.scene != null, "scene is assigned")
	_check(not data.is_grounding, "is not a grounding")

	# 2. Scene instantiates as the right class
	var debuff = data.scene.instantiate()
	add_child(debuff)
	_check(debuff is HailSatanDebuff, "scene instantiates as HailSatanDebuff")
	_check(debuff is Debuff, "scene root extends Debuff")

	# 3. Trigger behavior against a stub GameController
	var gc := StubGameController.new()
	var dice_hand: DiceHand = DiceHandScene.instantiate()
	add_child(dice_hand)
	var scorecard: Scorecard = ScoreCardScene.instantiate()
	add_child(scorecard)
	var turn_tracker := TurnTracker.new()
	var stub_ui := StubScoreCardUI.new()
	stub_ui.add_to_group("scorecard_ui")
	add_child(stub_ui)
	gc.dice_hand = dice_hand
	gc.scorecard = scorecard
	gc.turn_tracker = turn_tracker

	debuff.id = data.id
	debuff.apply(gc)
	_check(debuff.is_active, "apply() activates the debuff")
	_check(dice_hand.is_connected("roll_complete", debuff._on_roll_complete), "connected to roll_complete")

	# 3a. Two sixes do not trigger
	DiceResults.values = [6, 6, 1, 2, 3]
	dice_hand.emit_signal("roll_complete")
	_check(_scored_category_count(scorecard) == 0, "2 sixes: no category scored")
	_check(turn_tracker.current_turn == 1, "2 sixes: turn did not advance")

	# 3b. Three sixes trigger: 0 scored in one category, turn advances
	DiceResults.values = [6, 6, 6, 2, 3]
	dice_hand.emit_signal("roll_complete")
	_check(_scored_category_count(scorecard) == 1, "3 sixes: exactly one category scored")
	_check(scorecard.get_total_score() == 0, "3 sixes: scored value is 0")
	_check(turn_tracker.current_turn == 2, "3 sixes: turn advanced")
	_check(not stub_ui.buttons_disabled, "3 sixes: score buttons re-enabled for next turn")
	_check(not stub_ui.turn_scored, "3 sixes: turn_scored reset for next turn")

	# 3c. remove() disconnects — further 3-six rolls do nothing
	debuff.remove()
	_check(not dice_hand.is_connected("roll_complete", debuff._on_roll_complete), "remove() disconnects roll_complete")
	DiceResults.values = [6, 6, 6, 6, 6]
	dice_hand.emit_signal("roll_complete")
	_check(_scored_category_count(scorecard) == 1, "after remove(): no further scoring")

	stub_ui.remove_from_group("scorecard_ui")
	stub_ui.queue_free()
	debuff.queue_free()
	dice_hand.queue_free()
	scorecard.queue_free()
	turn_tracker.free()
	DiceResults.values = []


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[HailSatanTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(_failures)
