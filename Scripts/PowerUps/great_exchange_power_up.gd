extends PowerUp
class_name GreatExchangePowerUp

## GreatExchangePowerUp
##
## Rare PowerUp that grants +2 dice but removes 1 roll per turn.
## Example: 5 dice → 7 dice, 3 rolls → 2 rolls.
## Consumables that grant extra rolls still work normally.
## When sold, 2 dice are removed and 1 roll is restored.
## Price: $350, Rarity: Rare, Rating: R

const EXTRA_DICE: int = 2
const ROLLS_REMOVED: int = 1

var dice_hand_ref: DiceHand = null
var turn_tracker_ref: TurnTracker = null

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying GreatExchangePowerUp ===")
	var game_controller = target as GameController
	if not game_controller:
		push_error("[GreatExchangePowerUp] Target is not a GameController")
		return

	dice_hand_ref = game_controller.dice_hand
	turn_tracker_ref = game_controller.turn_tracker

	if not dice_hand_ref:
		push_error("[GreatExchangePowerUp] No dice_hand found on GameController")
		return
	if not turn_tracker_ref:
		push_error("[GreatExchangePowerUp] No turn_tracker found on GameController")
		return

	# Add 2 dice
	dice_hand_ref.dice_count += EXTRA_DICE
	print("[GreatExchangePowerUp] Added %d dice. Dice count now: %d" % [EXTRA_DICE, dice_hand_ref.dice_count])

	# Remove 1 roll
	turn_tracker_ref.MAX_ROLLS -= ROLLS_REMOVED
	turn_tracker_ref.emit_signal("max_rolls_changed", turn_tracker_ref.MAX_ROLLS)
	print("[GreatExchangePowerUp] Removed %d roll. MAX_ROLLS now: %d" % [ROLLS_REMOVED, turn_tracker_ref.MAX_ROLLS])

	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing GreatExchangePowerUp ===")

	# Remove 2 dice
	if dice_hand_ref:
		dice_hand_ref.dice_count -= EXTRA_DICE
		print("[GreatExchangePowerUp] Removed %d dice. Dice count now: %d" % [EXTRA_DICE, dice_hand_ref.dice_count])

	# Restore 1 roll
	if turn_tracker_ref:
		turn_tracker_ref.MAX_ROLLS += ROLLS_REMOVED
		turn_tracker_ref.emit_signal("max_rolls_changed", turn_tracker_ref.MAX_ROLLS)
		print("[GreatExchangePowerUp] Restored %d roll. MAX_ROLLS now: %d" % [ROLLS_REMOVED, turn_tracker_ref.MAX_ROLLS])

	dice_hand_ref = null
	turn_tracker_ref = null

func _on_tree_exiting() -> void:
	if dice_hand_ref:
		dice_hand_ref.dice_count -= EXTRA_DICE
	if turn_tracker_ref:
		turn_tracker_ref.MAX_ROLLS += ROLLS_REMOVED
		turn_tracker_ref.emit_signal("max_rolls_changed", turn_tracker_ref.MAX_ROLLS)
