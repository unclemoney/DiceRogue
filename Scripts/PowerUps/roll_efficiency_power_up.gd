extends PowerUp
class_name RollEfficiencyPowerUp

## RollEfficiencyPowerUp
##
## Adds +N additive bonus to all scores, where N = number of rolls used this turn.
## Registers additive before scoring based on (MAX_ROLLS - rolls_left + 1).
## If you used 1 roll, you get +1. If you used all 3, you get +3.
## Common rarity, $25 price.

# References
var scorecard_ref: Scorecard = null
var turn_tracker_ref: TurnTracker = null
var score_card_ui_ref = null

# ScoreModifierManager source name
var modifier_source_name: String = "roll_efficiency"

# Track for description
var last_rolls_used: int = 0
var total_bonus_applied: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying RollEfficiencyPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[RollEfficiencyPowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Get turn tracker and score_card_ui from tree
	var tree = scorecard.get_tree()
	if tree:
		turn_tracker_ref = tree.get_first_node_in_group("turn_tracker")
		
		# Get score_card_ui via GameController for reliability
		var game_controller = tree.get_first_node_in_group("game_controller")
		if game_controller and game_controller.score_card_ui:
			score_card_ui_ref = game_controller.score_card_ui
	
	# Connect to about_to_score to register additive
	if score_card_ui_ref:
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			print("[RollEfficiencyPowerUp] Connected to about_to_score signal")
	
	# Connect to score_assigned to clean up additive
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[RollEfficiencyPowerUp] Connected to score_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	if not turn_tracker_ref:
		return
	
	# Calculate rolls used this turn: MAX_ROLLS - rolls_left + 1 (because first roll counts)
	# Actually, if rolls_left is the number remaining AFTER using rolls:
	# Turn starts with MAX_ROLLS (e.g., 3)
	# After 1 roll: rolls_left = 2, rolls_used = 1
	# After 2 rolls: rolls_left = 1, rolls_used = 2
	# After 3 rolls: rolls_left = 0, rolls_used = 3
	# So rolls_used = MAX_ROLLS - rolls_left
	var rolls_used = turn_tracker_ref.MAX_ROLLS - turn_tracker_ref.rolls_left
	
	# Ensure at least 1 roll was used (can't score without rolling)
	if rolls_used < 1:
		rolls_used = 1
	
	last_rolls_used = rolls_used
	
	# Register the additive
	ScoreModifierManager.register_additive(modifier_source_name, rolls_used)
	print("[RollEfficiencyPowerUp] Registered additive +%d for %d rolls used" % [rolls_used, rolls_used])

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Track bonus for description
	if last_rolls_used > 0:
		total_bonus_applied += last_rolls_used
	
	# Clean up additive after scoring
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
		print("[RollEfficiencyPowerUp] Cleaned up additive after scoring")
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var base_desc = "+N to all scores (N = rolls used this turn)"
	
	if total_bonus_applied > 0:
		base_desc += "\nTotal bonus applied: +%d" % total_bonus_applied
	
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("roll_efficiency")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing RollEfficiencyPowerUp ===")
	
	# Unregister from ScoreModifierManager
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
			print("[RollEfficiencyPowerUp] Disconnected from about_to_score signal")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
			print("[RollEfficiencyPowerUp] Disconnected from score_assigned signal")
	
	scorecard_ref = null
	turn_tracker_ref = null
	score_card_ui_ref = null

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
