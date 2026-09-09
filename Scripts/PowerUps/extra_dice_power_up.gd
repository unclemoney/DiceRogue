extends PowerUp
class_name ExtraDicePowerUp

@export var extra_dice: int = 1

func apply(target) -> void:
	var hand: DiceHand = target as DiceHand
	if hand:
		hand.dice_count += extra_dice
	else:
		push_error("[ExtraDice] Invalid target passed to apply()")

func remove(target) -> void:
	var hand: DiceHand = target as DiceHand
	if hand:
		hand.dice_count -= extra_dice
	else:
		push_error("[ExtraDice] Invalid target passed to remove()")