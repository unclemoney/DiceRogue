extends Consumable
class_name AnyScoreConsumable

signal any_score_activated
signal any_score_completed
signal any_score_denied

var is_active := false
var has_been_used := false

func _ready() -> void:
	add_to_group("consumables")
	print("[AnyScoreConsumable] Ready")

## apply(target)
##
## Activates the AnyScore consumable, allowing the player to score the current dice
## in any category, even if the dice don't match that category's requirements.
func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[AnyScoreConsumable] Invalid target passed to apply()")
		return
		
	if has_been_used:
		print("[AnyScoreConsumable] Consumable has already been used")
		emit_signal("any_score_denied")
		return
		
	# Check if we have dice values to score
	var dice_values = DiceResults.values
	if dice_values.is_empty():
		print("[AnyScoreConsumable] No dice values available to score")
		emit_signal("any_score_denied")
		return
		
	# Check if there are any open categories to score in
	var scorecard = game_controller.scorecard
	if not scorecard:
		print("[AnyScoreConsumable] No scorecard available")
		emit_signal("any_score_denied")
		return
		
	if not _has_open_categories(scorecard):
		print("[AnyScoreConsumable] No open categories available to score")
		emit_signal("any_score_denied")
		return
		
	# Activate the special scoring mode
	is_active = true
	_activate_any_score_mode(game_controller)
	emit_signal("any_score_activated")
	print("[AnyScoreConsumable] AnyScore mode activated - click any open category to score current dice")

## _has_open_categories(scorecard)
##
## Checks if there are any open (unscored) categories available
func _has_open_categories(scorecard: Scorecard) -> bool:
	# Check upper section
	for category in scorecard.upper_scores.keys():
		if scorecard.upper_scores[category] == null:
			return true
	
	# Check lower section  
	for category in scorecard.lower_scores.keys():
		if scorecard.lower_scores[category] == null:
			return true
			
	return false

## _activate_any_score_mode(game_controller)
##
## Sets up the special UI state for AnyScore mode
func _activate_any_score_mode(game_controller: GameController) -> void:
	var score_card_ui = game_controller.score_card_ui
	if score_card_ui:
		score_card_ui.activate_any_score_mode()
		# Connect to score assignment to know when consumable is used
		if not score_card_ui.is_connected("hand_scored", _on_any_score_used):
			score_card_ui.hand_scored.connect(_on_any_score_used)
	else:
		push_error("[AnyScoreConsumable] No ScoreCardUI found")

## _on_any_score_used()
##
## Called when player scores using AnyScore mode
func _on_any_score_used() -> void:
	print("[AnyScoreConsumable] AnyScore used - completing consumable")
	complete_any_score()

## complete_any_score()
##
## Marks the consumable as used and deactivates the mode
func complete_any_score() -> void:
	print("[AnyScoreConsumable] Completing AnyScore")
	is_active = false
	has_been_used = true
	
	# Ensure the UI mode is properly deactivated
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		var score_card_ui = game_controller.score_card_ui
		if score_card_ui and score_card_ui.has_method("deactivate_any_score_mode"):
			score_card_ui.deactivate_any_score_mode()
	
	emit_signal("any_score_completed")

## cancel_any_score()
##
## Cancels the any_score mode without using the consumable
func cancel_any_score() -> void:
	print("[AnyScoreConsumable] Cancelling AnyScore")
	is_active = false
	# Don't mark as used since it was cancelled
	
	# Ensure the UI mode is properly deactivated
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		var score_card_ui = game_controller.score_card_ui
		if score_card_ui and score_card_ui.has_method("deactivate_any_score_mode"):
			score_card_ui.deactivate_any_score_mode()
	
	emit_signal("any_score_denied")