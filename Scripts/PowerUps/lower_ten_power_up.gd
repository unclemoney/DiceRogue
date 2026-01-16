extends PowerUp
class_name LowerTenPowerUp

## LowerTenPowerUp
##
## An uncommon PowerUp that adds +10 additive bonus to every lower section score.
## This bonus is applied through the ScoreModifierManager system and only affects
## lower section categories (three_of_a_kind, four_of_a_kind, full_house, 
## small_straight, large_straight, yahtzee, chance).
## Upper section scores are not affected.

# PowerUp configuration
const ADDITIVE_BONUS: int = 10

# Reference to target scorecard
var scorecard_ref: Scorecard = null
var score_card_ui_ref: Node = null

# Track lower section scores that have received the bonus
var lower_scores_applied: int = 0

signal description_updated(power_up_id: String, new_description: String)

# ScoreModifierManager source name
var modifier_source_name: String = "lower_ten"

func _ready() -> void:
	add_to_group("power_ups")
	print("[LowerTenPowerUp] Added to 'power_ups' group")

func _is_score_modifier_manager_available() -> bool:
	return ScoreModifierManager != null

func _get_score_modifier_manager():
	return ScoreModifierManager

func _register_additive() -> void:
	if not _is_score_modifier_manager_available():
		return
	
	var manager = _get_score_modifier_manager()
	if manager:
		manager.register_additive(modifier_source_name, ADDITIVE_BONUS)
		print("[LowerTenPowerUp] Registered additive: +%d" % ADDITIVE_BONUS)

func _unregister_additive() -> void:
	if not _is_score_modifier_manager_available():
		return
	
	var manager = _get_score_modifier_manager()
	if manager and manager.has_additive(modifier_source_name):
		manager.unregister_additive(modifier_source_name)
		print("[LowerTenPowerUp] Unregistered additive")

func _on_about_to_score(section: Scorecard.Section, category: String, _dice_values: Array[int]) -> void:
	# Register additive for lower section scores only
	if section == Scorecard.Section.LOWER:
		_register_additive()
		print("[LowerTenPowerUp] Registered additive for lower section category: %s" % category)
	else:
		# Ensure no additive for upper sections
		_unregister_additive()
		print("[LowerTenPowerUp] Unregistered additive for upper section category: %s" % category)

func _on_score_assigned(section: Scorecard.Section, category: String, _score: int) -> void:
	# Track lower section score applications for description updates
	if section == Scorecard.Section.LOWER:
		lower_scores_applied += 1
		emit_signal("description_updated", id, get_current_description())
		print("[LowerTenPowerUp] Lower section score tracked: %s (total applied: %d)" % [category, lower_scores_applied])
	
	# Clean up additive after any scoring to reset state
	_unregister_additive()
	print("[LowerTenPowerUp] Cleaned up additive after scoring")

func apply(target) -> void:
	print("=== Applying LowerTenPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[LowerTenPowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Connect to about_to_score signal to register additive conditionally
	# Use GameController's score_card_ui reference for reliability
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			print("[LowerTenPowerUp] Connected to about_to_score signal")
	else:
		push_error("[LowerTenPowerUp] Could not find ScoreCardUI via GameController")
	
	# Connect to score assignment signals for tracking and cleanup
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[LowerTenPowerUp] Connected to score_assigned signal for tracking")
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[LowerTenPowerUp] Applied successfully - will add +%d to lower section scores only" % ADDITIVE_BONUS)

func remove(target) -> void:
	print("=== Removing LowerTenPowerUp ===")
	
	# Unregister from ScoreModifierManager
	_unregister_additive()
	
	# Disconnect from ScoreCardUI
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
		print("[LowerTenPowerUp] Disconnected from about_to_score signal")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Disconnect signals
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
	
	scorecard_ref = null
	score_card_ui_ref = null
	lower_scores_applied = 0

func get_current_description() -> String:
	if lower_scores_applied > 0:
		return "Lower section scores get +%d (%d applied)" % [ADDITIVE_BONUS, lower_scores_applied]
	else:
		return "Lower section scores get +%d" % ADDITIVE_BONUS

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("lower_ten")
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
		print("[LowerTenPowerUp] Cleanup: Disconnected signals")
