extends Consumable
class_name ThreeMoreRollsConsumable

signal rolls_increased(additional_rolls: int)

func _ready() -> void:
	add_to_group("consumables")
	print("[ThreeMoreRollsConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[ThreeMoreRollsConsumable] Invalid target passed to apply()")
		return
		
	var turn_tracker = game_controller.turn_tracker
	if not turn_tracker:
		push_error("[ThreeMoreRollsConsumable] No TurnTracker found")
		return
		
	# Add 3 more rolls for the current turn
	turn_tracker.rolls_left += 3
	print("[ThreeMoreRollsConsumable] Added 3 more rolls. Rolls left:", turn_tracker.rolls_left)
	
	# Emit signal for UI updates
	turn_tracker.emit_signal("rolls_updated", turn_tracker.rolls_left)
	emit_signal("rolls_increased", 3)
	
