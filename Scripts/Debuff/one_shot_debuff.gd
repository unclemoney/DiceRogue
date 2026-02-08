extends Debuff
class_name OneShotDebuff

## OneShotDebuff
##
## Reduces the maximum number of rolls per turn to 1 instead of the
## normal amount (usually 3). This creates an extreme challenge where
## the player must score with whatever they roll on their first and
## only attempt each turn. The effect is reversible — removing the
## debuff restores the original MAX_ROLLS value.

var turn_tracker: Node
var original_max_rolls: int = 3

## apply(_target)
##
## Stores the current MAX_ROLLS value, then reduces it to 1.
## Also caps the current turn's remaining rolls if already higher.
## Emits max_rolls_changed to update UI elements.
func apply(_target) -> void:
	print("[OneShot] Applied - Reducing MAX_ROLLS to 1")
	self.target = _target

	turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if not turn_tracker:
		push_error("[OneShot] Could not find TurnTracker")
		return

	# Store and override MAX_ROLLS
	original_max_rolls = turn_tracker.MAX_ROLLS
	turn_tracker.MAX_ROLLS = 1
	print("[OneShot] MAX_ROLLS changed from %d to 1" % original_max_rolls)

	# Cap current rolls if mid-turn
	if turn_tracker.rolls_left > 1:
		turn_tracker.rolls_left = 1
		turn_tracker.emit_signal("rolls_updated", turn_tracker.rolls_left)

	# Notify UI of the change
	turn_tracker.emit_signal("max_rolls_changed", 1)

## remove()
##
## Restores the original MAX_ROLLS value and notifies the UI.
func remove() -> void:
	print("[OneShot] Removed - Restoring MAX_ROLLS to %d" % original_max_rolls)

	if turn_tracker and is_instance_valid(turn_tracker):
		turn_tracker.MAX_ROLLS = original_max_rolls
		turn_tracker.emit_signal("max_rolls_changed", original_max_rolls)
		print("[OneShot] MAX_ROLLS restored to %d" % original_max_rolls)
