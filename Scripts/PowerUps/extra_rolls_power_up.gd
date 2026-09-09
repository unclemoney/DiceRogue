extends PowerUp
class_name ExtraRollsPowerUp

@export var extra_rolls: int = 1

func apply(target) -> void:
	var tracker: TurnTracker = target as TurnTracker
	if tracker:
		tracker.add_rolls(extra_rolls)
	else:
		push_error("[ExtraRolls] Invalid target passed to apply()")


func remove(target) -> void:
	var tracker: TurnTracker = target as TurnTracker
	if tracker:
		tracker.remove_rolls(extra_rolls)
	else:
		push_error("[ExtraRolls] Invalid target passed to remove()")
