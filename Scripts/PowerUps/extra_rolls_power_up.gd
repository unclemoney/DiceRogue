extends PowerUp
class_name ExtraRollsPowerUp

@export var extra_rolls: int = 1

func apply(target) -> void:
	var tracker: TurnTracker = target as TurnTracker
	if tracker:
		tracker.MAX_ROLLS = 4
		emit_signal("max_rolls_changed", 4)
	else:
		push_error("[ExtraRolls] Invalid target passed to apply()")


func remove(target) -> void:
	var tracker: TurnTracker = target as TurnTracker
	if tracker:
		tracker.MAX_ROLLS = 3
		emit_signal("max_rolls_changed", 3)
	else:
		push_error("[ExtraRolls] Invalid target passed to apply()")
