extends PowerUp
class_name StepByStepPowerUp

## StepByStepPowerUp
##
## A common PowerUp that adds +6 additive bonus to every upper section score only.
## This bonus is applied through the ScoreModifierManager system and only affects
## upper section categories (ones, twos, threes, fours, fives, sixes).
## Lower section scores (Full House, etc.) are not affected.

# PowerUp configuration
const ADDITIVE_BONUS: int = 6

# Reference to target scorecard
var scorecard_ref: Scorecard = null

# Track upper section scores that have received the bonus
var upper_scores_applied: int = 0

signal description_updated(power_up_id: String, new_description: String)

# ScoreModifierManager source name
var modifier_source_name: String = "step_by_step"

func _ready() -> void:
	add_to_group("power_ups")
	print("[StepByStepPowerUp] Added to 'power_ups' group")

	# Guard against missing ScoreModifierManager
	if not _is_score_modifier_manager_available():
		push_error("[StepByStepPowerUp] ScoreModifierManager not available")
		return
	
	# Get the correct ScoreModifierManager reference
	var manager = _get_score_modifier_manager()
	
	# Connect to ScoreModifierManager signals to update UI when total additive changes
	if manager and not manager.is_connected("additive_changed", _on_additive_manager_changed):
		manager.additive_changed.connect(_on_additive_manager_changed)
		print("[StepByStepPowerUp] Connected to ScoreModifierManager signals")

func _is_score_modifier_manager_available() -> bool:
	# ScoreModifierManager is an autoload, so it's always available
	return ScoreModifierManager != null

func _get_score_modifier_manager():
	# ScoreModifierManager is an autoload, so access it directly
	return ScoreModifierManager

func _update_additive_manager() -> void:
	if not _is_score_modifier_manager_available():
		print("[StepByStepPowerUp] ScoreModifierManager not available, skipping update")
		return
	
	var manager = _get_score_modifier_manager()
	
	if manager:
		manager.register_additive(modifier_source_name, ADDITIVE_BONUS)
		print("[StepByStepPowerUp] ScoreModifierManager updated with additive:", ADDITIVE_BONUS)
	else:
		push_error("[StepByStepPowerUp] Could not access ScoreModifierManager")

func _on_additive_manager_changed(total_additive: int) -> void:
	print("[StepByStepPowerUp] ScoreModifierManager total additive changed to:", total_additive)
	emit_signal("description_updated", id, get_current_description())
	
	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func _update_power_up_icons() -> void:
	# Update UI icons if description changes
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("step_by_step")
		if icon:
			icon.update_hover_description()
			
			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_about_to_score(section: Scorecard.Section, category: String, _dice_values: Array[int]) -> void:
	# Only register additive for upper section scores
	if section == Scorecard.Section.UPPER:
		_register_additive()
		print("[StepByStepPowerUp] Registered additive for upper section category: %s" % category)

func _register_additive() -> void:
	if not _is_score_modifier_manager_available():
		return
	
	var manager = _get_score_modifier_manager()
	if manager:
		manager.register_additive(modifier_source_name, ADDITIVE_BONUS)

func _unregister_additive() -> void:
	if not _is_score_modifier_manager_available():
		return
	
	var manager = _get_score_modifier_manager()
	if manager:
		manager.unregister_additive(modifier_source_name)

func apply(target) -> void:
	print("=== Applying StepByStepPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[StepByStepPowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Connect to about_to_score signal to register additive conditionally
	# Use scorecard's scene tree instead of our own (which may not exist)
	var score_card_ui = scorecard.get_tree().get_first_node_in_group("score_card_ui")
	if score_card_ui and not score_card_ui.is_connected("about_to_score", _on_about_to_score):
		score_card_ui.about_to_score.connect(_on_about_to_score)
		print("[StepByStepPowerUp] Connected to about_to_score signal")
	
	# Connect to score assignment signals for tracking and cleanup
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[StepByStepPowerUp] Connected to score_assigned signal for tracking")
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[StepByStepPowerUp] Applied successfully - will add +%d to upper section scores only" % ADDITIVE_BONUS)

func remove(target) -> void:
	print("=== Removing StepByStepPowerUp ===")
	
	# Unregister from ScoreModifierManager
	_unregister_additive()
	
	# Disconnect from ScoreCardUI
	if scorecard_ref:
		var score_card_ui = scorecard_ref.get_tree().get_first_node_in_group("score_card_ui")
		if score_card_ui and score_card_ui.is_connected("about_to_score", _on_about_to_score):
			score_card_ui.about_to_score.disconnect(_on_about_to_score)
			print("[StepByStepPowerUp] Disconnected from about_to_score signal")
	
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
	upper_scores_applied = 0

func _on_score_assigned(section: Scorecard.Section, category: String, _score: int) -> void:
	# Track upper section score applications for description updates
	if section == Scorecard.Section.UPPER:
		upper_scores_applied += 1
		emit_signal("description_updated", id, get_current_description())
		print("[StepByStepPowerUp] Upper section score tracked: %s (total applied: %d)" % [category, upper_scores_applied])
		
		# Clean up the additive after upper section scoring
		_unregister_additive()
		print("[StepByStepPowerUp] Cleaned up additive after upper section scoring")

func get_current_description() -> String:
	if upper_scores_applied > 0:
		return "Upper section scores get +%d (%d applied)" % [ADDITIVE_BONUS, upper_scores_applied]
	else:
		return "Upper section scores get +%d" % ADDITIVE_BONUS

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_additive(modifier_source_name)
			print("[StepByStepPowerUp] Cleanup: Unregistered additive from ScoreModifierManager")
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		print("[StepByStepPowerUp] Cleanup: Disconnected signals")