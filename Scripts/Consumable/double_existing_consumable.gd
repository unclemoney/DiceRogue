extends Consumable
class_name DoubleExistingConsumable

signal double_activated
signal double_completed
signal double_denied

var is_active := false

func _ready() -> void:
	add_to_group("consumables")
	print("[DoubleExisting] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[DoubleExisting] Invalid target passed to apply()")
		apply_succeeded = false
		return
		
	# Check if there are any scores to double
	var scorecard = game_controller.scorecard
	if not scorecard or not scorecard.has_any_scores():
		print("[DoubleExisting] No scores available to double")
		emit_signal("double_denied")
		apply_succeeded = false
		return
		
	is_active = true
	print("[DoubleExisting] Double activated, waiting for score selection")
	emit_signal("double_activated")
	
	# Tell the ScoreCardUI to activate double mode
	var score_card_ui = game_controller.score_card_ui
	if score_card_ui:
		score_card_ui.activate_score_double()
	else:
		push_error("[DoubleExisting] No ScoreCardUI found")
		is_active = false
		apply_succeeded = false

func complete_double() -> void:
	print("[DoubleExisting] Completing double")
	is_active = false
	emit_signal("double_completed")
