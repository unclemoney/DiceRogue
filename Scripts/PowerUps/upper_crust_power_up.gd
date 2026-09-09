extends PowerUp
class_name UpperCrustPowerUp

## UpperCrustPowerUp
##
## A rare PowerUp that applies a 1.5x multiplier to every upper section score.
## Multiplier counterpart to LowerTenPowerUp's flat bonus. The multiplier is
## applied through the ScoreModifierManager system and only affects upper
## section categories (ones, twos, threes, fours, fives, sixes).
## Lower section scores are not affected.

# PowerUp configuration
const SCORE_MULTIPLIER: float = 1.5

var _debug_enabled: bool = OS.is_debug_build()

# Reference to target scorecard
var scorecard_ref: Scorecard = null
var score_card_ui_ref: Node = null

# Track upper section scores that have received the multiplier
var upper_scores_applied: int = 0

signal description_updated(power_up_id: String, new_description: String)

# ScoreModifierManager source name
var modifier_source_name: String = "upper_crust"

func _ready() -> void:
	add_to_group("power_ups")
	if _debug_enabled:
		print("[UpperCrustPowerUp] Added to 'power_ups' group")

func _is_score_modifier_manager_available() -> bool:
	return ScoreModifierManager != null

func _get_score_modifier_manager():
	return ScoreModifierManager

func _register_multiplier() -> void:
	if not _is_score_modifier_manager_available():
		return
	
	var manager = _get_score_modifier_manager()
	if manager:
		manager.register_multiplier(modifier_source_name, SCORE_MULTIPLIER)
		if _debug_enabled:
			print("[UpperCrustPowerUp] Registered multiplier: x%.2f" % SCORE_MULTIPLIER)

func _unregister_multiplier() -> void:
	if not _is_score_modifier_manager_available():
		return
	
	var manager = _get_score_modifier_manager()
	if manager and manager.has_multiplier(modifier_source_name):
		manager.unregister_multiplier(modifier_source_name)
		if _debug_enabled:
			print("[UpperCrustPowerUp] Unregistered multiplier")

func _on_about_to_score(section: Scorecard.Section, category: String, _dice_values: Array[int]) -> void:
	# Register multiplier for upper section scores only
	if section == Scorecard.Section.UPPER:
		_register_multiplier()
		if _debug_enabled:
			print("[UpperCrustPowerUp] Registered multiplier for upper section category: %s" % category)
	else:
		# Ensure no multiplier for lower sections
		_unregister_multiplier()
		if _debug_enabled:
			print("[UpperCrustPowerUp] Unregistered multiplier for lower section category: %s" % category)

func _on_score_assigned(section: Scorecard.Section, category: String, _score: int) -> void:
	# Track upper section score applications for description updates
	if section == Scorecard.Section.UPPER:
		upper_scores_applied += 1
		emit_signal("description_updated", id, get_current_description())
		if _debug_enabled:
			print("[UpperCrustPowerUp] Upper section score tracked: %s (total applied: %d)" % [category, upper_scores_applied])
	
	# Clean up multiplier after any scoring to reset state
	_unregister_multiplier()
	if _debug_enabled:
		print("[UpperCrustPowerUp] Cleaned up multiplier after scoring")

func apply(target) -> void:
	if _debug_enabled:
		print("=== Applying UpperCrustPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[UpperCrustPowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Connect to about_to_score signal to register multiplier conditionally
	# Use GameController's score_card_ui reference for reliability
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			if _debug_enabled:
				print("[UpperCrustPowerUp] Connected to about_to_score signal")
	else:
		push_error("[UpperCrustPowerUp] Could not find ScoreCardUI via GameController")
	
	# Connect to score assignment signals for tracking and cleanup
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		if _debug_enabled:
			print("[UpperCrustPowerUp] Connected to score_assigned signal for tracking")
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	if _debug_enabled:
		print("[UpperCrustPowerUp] Applied successfully - upper section scores get x%.2f" % SCORE_MULTIPLIER)

func remove(target) -> void:
	if _debug_enabled:
		print("=== Removing UpperCrustPowerUp ===")
	
	# Unregister from ScoreModifierManager
	_unregister_multiplier()
	
	# Disconnect from ScoreCardUI
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
		if _debug_enabled:
			print("[UpperCrustPowerUp] Disconnected from about_to_score signal")
	
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
	upper_scores_applied = 0

func get_current_description() -> String:
	if upper_scores_applied > 0:
		return "Upper section scores get x%.1f (%d applied)" % [SCORE_MULTIPLIER, upper_scores_applied]
	else:
		return "Upper section scores get x%.1f" % SCORE_MULTIPLIER

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("upper_crust")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	_unregister_multiplier()
	
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		if _debug_enabled:
			print("[UpperCrustPowerUp] Cleanup: Disconnected signals")
