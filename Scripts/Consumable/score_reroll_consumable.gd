extends Consumable
class_name ScoreRerollConsumable

signal reroll_activated
signal reroll_completed
signal reroll_denied

var is_active := false

func apply(target) -> void:
	var game_controller = target as Node
	if not game_controller:
		push_error("[ScoreReroll] Invalid target passed to apply()")
		apply_succeeded = false
		return
		
	# Check if there are any scores to reroll
	var scorecard = game_controller.scorecard
	if not scorecard or not scorecard.has_any_scores():
		print("[ScoreReroll] No scores available to reroll")
		emit_signal("reroll_denied")
		apply_succeeded = false
		return
		
	is_active = true
	emit_signal("reroll_activated")

func complete_reroll() -> void:
	print("ScoreRerollConsumable: Completing reroll")
	is_active = false
	emit_signal("reroll_completed")

