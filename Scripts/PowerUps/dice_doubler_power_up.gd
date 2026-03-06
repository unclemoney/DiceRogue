extends PowerUp
class_name DiceDoublerPowerUp

## DiceDoublerPowerUp
##
## Common PowerUp (Rating: G) that doubles the face value of every die after each roll,
## before scoring evaluation occurs.
## Price: $75, Rarity: Common, Rating: G
##
## Side-effects:
## - Connects to DiceHand.roll_complete on apply(), disconnects on remove().
## - Modifies Dice.value directly and refreshes each die's visual.

var _dice_hand_ref: DiceHand = null

func apply(target) -> void:
	var hand := target as DiceHand
	if not hand:
		push_error("[DiceDoubler] Invalid target passed to apply()")
		return

	_dice_hand_ref = hand

	if not _dice_hand_ref.is_connected("roll_complete", _on_roll_complete):
		_dice_hand_ref.roll_complete.connect(_on_roll_complete)

	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

	print("[DiceDoubler] Applied — will double all dice values after each roll")

func remove(target) -> void:
	var hand := target as DiceHand
	if not hand:
		push_error("[DiceDoubler] Invalid target passed to remove()")
		return

	if _dice_hand_ref and _dice_hand_ref.is_connected("roll_complete", _on_roll_complete):
		_dice_hand_ref.roll_complete.disconnect(_on_roll_complete)

	_dice_hand_ref = null
	print("[DiceDoubler] Removed")

func _on_roll_complete() -> void:
	if not _dice_hand_ref:
		return

	for die in _dice_hand_ref.dice_list:
		die.value *= 2
		die.update_visual()

	print("[DiceDoubler] Doubled all dice values")

func _on_tree_exiting() -> void:
	if _dice_hand_ref and _dice_hand_ref.is_connected("roll_complete", _on_roll_complete):
		_dice_hand_ref.roll_complete.disconnect(_on_roll_complete)
