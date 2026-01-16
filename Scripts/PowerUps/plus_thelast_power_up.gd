extends PowerUp
class_name PlusTheLastPowerUp

## PlusTheLastPowerUp
##
## A rare PowerUp that adds the score of the last scored category as an additive
## bonus to the current score.
## Example: Last score was Full House (25 points), current Large Straight gets +25.

# Reference to target scorecard and UI
var scorecard_ref: Scorecard = null
var score_card_ui_ref: Node = null

# Track the last scored value
var last_scored_value: int = 0

signal description_updated(power_up_id: String, new_description: String)

# ScoreModifierManager source name
var modifier_source_name: String = "plus_thelast"

func _ready() -> void:
	add_to_group("power_ups")
	print("[PlusTheLastPowerUp] Added to 'power_ups' group")

func _is_score_modifier_manager_available() -> bool:
	return ScoreModifierManager != null

func _get_score_modifier_manager():
	return ScoreModifierManager

func _register_additive() -> void:
	if not _is_score_modifier_manager_available():
		return
	
	if last_scored_value > 0:
		var manager = _get_score_modifier_manager()
		if manager:
			manager.register_additive(modifier_source_name, last_scored_value)
			print("[PlusTheLastPowerUp] Registered additive: +%d (last score)" % last_scored_value)

func _unregister_additive() -> void:
	if not _is_score_modifier_manager_available():
		return
	
	var manager = _get_score_modifier_manager()
	if manager and manager.has_additive(modifier_source_name):
		manager.unregister_additive(modifier_source_name)
		print("[PlusTheLastPowerUp] Unregistered additive")

func _on_about_to_score(_section: Scorecard.Section, category: String, _dice_values: Array[int]) -> void:
	# Register additive based on last scored value (if any)
	if last_scored_value > 0:
		_register_additive()
		print("[PlusTheLastPowerUp] Registered +%d additive for category: %s" % [last_scored_value, category])
	else:
		print("[PlusTheLastPowerUp] No last score to add for category: %s" % category)

func _on_score_assigned(_section: Scorecard.Section, category: String, score: int) -> void:
	# First, clean up the additive that was applied for THIS scoring
	_unregister_additive()
	
	# Then, store this score as the "last scored value" for NEXT scoring
	last_scored_value = score
	print("[PlusTheLastPowerUp] Stored last score: %d from category: %s" % [score, category])
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	# Update UI icons
	if is_inside_tree():
		_update_power_up_icons()

func apply(target) -> void:
	print("=== Applying PlusTheLastPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[PlusTheLastPowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Connect to about_to_score signal to register additive
	# Use GameController's score_card_ui reference for reliability
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			print("[PlusTheLastPowerUp] Connected to about_to_score signal")
	else:
		push_error("[PlusTheLastPowerUp] Could not find ScoreCardUI via GameController")
	
	# Connect to score assignment signals for tracking last score and cleanup
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[PlusTheLastPowerUp] Connected to score_assigned signal")
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[PlusTheLastPowerUp] Applied successfully - will add last score as additive")

func remove(target) -> void:
	print("=== Removing PlusTheLastPowerUp ===")
	
	# Unregister from ScoreModifierManager
	_unregister_additive()
	
	# Disconnect from ScoreCardUI
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
		print("[PlusTheLastPowerUp] Disconnected from about_to_score signal")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
	
	scorecard_ref = null
	score_card_ui_ref = null
	last_scored_value = 0

func get_current_description() -> String:
	if last_scored_value > 0:
		return "Adds last score to current score\nLast: +%d" % last_scored_value
	else:
		return "Adds last score to current score\nLast: None"

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("plus_thelast")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	_unregister_additive()
	
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		print("[PlusTheLastPowerUp] Cleanup: Disconnected signals")
