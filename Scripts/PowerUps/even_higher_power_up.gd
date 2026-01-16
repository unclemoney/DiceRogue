extends PowerUp
class_name EvenHigherPowerUp

## EvenHigherPowerUp
##
## Tracks cumulative even dice scored throughout the game.
## Adds an additive bonus equal to the total even dice scored to each score.
## Example: If player has scored 12 even dice total, next score gets +12.
## Rare rarity, PG-13 rating.

# Reference to scorecard
var scorecard_ref: Scorecard = null
var total_even_dice_scored: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying EvenHigherPowerUp ===")
	
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[EvenHigherPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Connect to score_assigned signal to track even dice after each score
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[EvenHigherPowerUp] Connected to score_assigned signal")
	
	# Register initial additive (0 at start)
	ScoreModifierManager.register_additive("even_higher", total_even_dice_scored)
	print("[EvenHigherPowerUp] Registered additive: %d" % total_even_dice_scored)
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Update cumulative even dice count from Statistics
	# Note: Statistics tracks per-round, we accumulate across the game
	# Use deferred call to ensure Statistics has been updated
	call_deferred("_update_even_dice_count")

func _update_even_dice_count() -> void:
	# Add the even dice from latest scoring to our cumulative total
	# We track this manually since Statistics resets each round
	var current_even = Statistics.even_dice_scored_this_round
	
	# Only update if Statistics has values (it won't right after round reset)
	if current_even >= 0:
		total_even_dice_scored = _get_cumulative_even_dice()
		
		# Update the additive in ScoreModifierManager
		ScoreModifierManager.register_additive("even_higher", total_even_dice_scored)
		print("[EvenHigherPowerUp] Updated additive to: +%d" % total_even_dice_scored)
		
		# Update description
		emit_signal("description_updated", id, get_current_description())
		
		if is_inside_tree():
			_update_power_up_icons()

func _get_cumulative_even_dice() -> int:
	# Returns cumulative even dice scored this round (Statistics tracks round totals)
	return Statistics.even_dice_scored_this_round + _get_previous_rounds_even_dice()

var _previous_rounds_even_dice: int = 0

func _get_previous_rounds_even_dice() -> int:
	return _previous_rounds_even_dice

func store_round_even_dice() -> void:
	# Called at round end to store the current round's even dice
	_previous_rounds_even_dice += Statistics.even_dice_scored_this_round

func get_current_description() -> String:
	var base_desc = "+1 additive per even die scored (cumulative)"
	
	if total_even_dice_scored > 0:
		var progress_desc = "\nCurrent bonus: +%d" % total_even_dice_scored
		return base_desc + progress_desc
	
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("even_higher")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing EvenHigherPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif scorecard_ref:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
			print("[EvenHigherPowerUp] Disconnected from score_assigned signal")
	
	# Unregister additive
	ScoreModifierManager.unregister_additive("even_higher")
	print("[EvenHigherPowerUp] Unregistered additive")
	
	scorecard_ref = null

func _on_tree_exiting() -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	
	ScoreModifierManager.unregister_additive("even_higher")
