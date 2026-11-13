extends Node

## Verifies consumable-added dice roll immediately and publish the complete
## hand through DiceResults and DiceHand.roll_complete without another roll.

const DICE_HAND_SCENE := preload("res://Scenes/Dice/dice_hand.tscn")
const SCORECARD_SCENE := preload("res://Scenes/ScoreCard/score_card.tscn")
const SCORECARD_UI_SCENE := preload("res://Scenes/UI/Scorecard/scorecard.tscn")

var _hand: DiceHand
var _tracker: TurnTracker
var _scorecard: Scorecard
var _scorecard_ui: ScoreCardUI
var _game_controller: GameController
var _fail_count := 0


func _ready() -> void:
	print("=== Consumable Dice Timing Test ===")
	_setup()
	await _run_tests()
	print("=== Consumable Dice Timing Test: %s ===" % ("FAIL" if _fail_count > 0 else "PASS"))
	_game_controller.free()
	await get_tree().process_frame
	get_tree().quit(1 if _fail_count > 0 else 0)


func _setup() -> void:
	_hand = DICE_HAND_SCENE.instantiate()
	add_child(_hand)
	_tracker = TurnTracker.new()
	add_child(_tracker)
	_scorecard = SCORECARD_SCENE.instantiate()
	add_child(_scorecard)
	_scorecard_ui = SCORECARD_UI_SCENE.instantiate()
	add_child(_scorecard_ui)
	_scorecard_ui.bind_scorecard(_scorecard)
	_game_controller = GameController.new()
	_game_controller.dice_hand = _hand
	_game_controller.turn_tracker = _tracker
	_game_controller.scorecard = _scorecard


func _run_tests() -> void:
	await _hand.spawn_dice()
	_hand.roll_all()
	await _hand.roll_complete
	await get_tree().process_frame

	var original_values := _hand.get_current_dice_values()
	_scorecard_ui.clear_projections()
	var extra_dice := OneExtraDiceConsumable.new()
	add_child(extra_dice)
	extra_dice.apply(_game_controller)
	await _hand.roll_complete
	_assert(_hand.dice_list.size() == 6, "One Extra Dice immediately spawns a sixth die")
	_assert(_hand.dice_list[5].current_state == Dice.DiceState.ROLLED, "One Extra Dice immediately rolls the new die")
	_assert(_published_full_hand(6), "One Extra Dice publishes all six dice to DiceResults")
	_assert(_existing_values_unchanged(original_values), "One Extra Dice does not reroll existing dice")
	_assert(_scorecard_ui._has_roll_context, "One Extra Dice refreshes best-hand previews through roll_complete")
	extra_dice.queue_free()

	_hand.dice_count = 5
	_hand.update_dice_count()
	await get_tree().process_frame
	original_values = _hand.get_current_dice_values()
	_scorecard_ui.clear_projections()
	var surge := DiceSurgeConsumable.new()
	add_child(surge)
	surge.apply(_game_controller)
	await _hand.roll_complete
	_assert(_hand.dice_list.size() == 7, "Dice Surge immediately spawns two additional dice")
	_assert(_published_full_hand(7), "Dice Surge publishes all seven dice to DiceResults")
	_assert(_existing_values_unchanged(original_values), "Dice Surge does not reroll existing dice")
	_assert(_scorecard_ui._has_roll_context, "Dice Surge refreshes best-hand previews through roll_complete")
	for i in range(5, 7):
		_assert(_hand.dice_list[i].current_state == Dice.DiceState.ROLLED, "Surge die %d is rolled" % (i - 4))
	surge.queue_free()


func _published_full_hand(expected_count: int) -> bool:
	return DiceResults.values.size() == expected_count and DiceResults.values == _hand.get_current_dice_values()


func _existing_values_unchanged(original_values: Array[int]) -> bool:
	var current_values := _hand.get_current_dice_values()
	for i in range(original_values.size()):
		if current_values[i] != original_values[i]:
			return false
	return true


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail_count += 1
		push_error("[ConsumableDiceTimingTest] FAIL: %s" % message)
