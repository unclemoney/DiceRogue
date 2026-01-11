extends PowerUp
class_name PerfectStrangersPowerUp

## PerfectStrangersPowerUp
##
## When scoring CHANCE category, applies a random multiplier (1.1x to 1.5x) to that score.
## Connects to ScoreCardUI.about_to_score to register multiplier BEFORE score calculation,
## then unregisters it after scoring completes (one-time use per CHANCE score).

# Reference to the scorecard to listen for score completion
var scorecard_ref: Scorecard = null
var score_card_ui_ref: Control = null

# Track the last applied random multiplier for display purposes
var last_applied_multiplier: float = 0.0
var times_triggered: int = 0

# Possible random multiplier values
const RANDOM_MULTIPLIERS: Array[float] = [1.1, 1.2, 1.3, 1.4, 1.5]

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[PerfectStrangersPowerUp] Added to 'power_ups' group")

## apply(target)
##
## Connects to ScoreCardUI.about_to_score signal to intercept CHANCE scoring BEFORE calculation.
## Also connects to score_assigned to clean up the multiplier AFTER scoring completes.
func apply(target) -> void:
	print("=== Applying PerfectStrangersPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[PerfectStrangersPowerUp] Target is not a Scorecard")
		return
	
	# Store a reference to the scorecard
	scorecard_ref = scorecard
	print("[PerfectStrangersPowerUp] Target scorecard:", scorecard)
	
	# Find ScoreCardUI to connect to about_to_score signal
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		
		# Connect to about_to_score - fires BEFORE score calculation
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			print("[PerfectStrangersPowerUp] Connected to ScoreCardUI.about_to_score signal")
	else:
		push_error("[PerfectStrangersPowerUp] Cannot find ScoreCardUI")
	
	# Connect to score_assigned - fires AFTER score calculation (for cleanup)
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[PerfectStrangersPowerUp] Connected to score_assigned signal")
	
	if not scorecard.is_connected("score_auto_assigned", _on_score_auto_assigned):
		scorecard.score_auto_assigned.connect(_on_score_auto_assigned)
		print("[PerfectStrangersPowerUp] Connected to score_auto_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

## remove(target)
##
## Disconnects all signals and cleans up any active multiplier.
func remove(target) -> void:
	print("=== Removing PerfectStrangersPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Disconnect scorecard signals
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
		if scorecard.is_connected("score_auto_assigned", _on_score_auto_assigned):
			scorecard.score_auto_assigned.disconnect(_on_score_auto_assigned)
		print("[PerfectStrangersPowerUp] Disconnected from scorecard signals")
	
	# Disconnect from ScoreCardUI
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
		print("[PerfectStrangersPowerUp] Disconnected from ScoreCardUI signals")
	
	# Clean up any lingering multiplier
	_unregister_multiplier()
	
	scorecard_ref = null
	score_card_ui_ref = null

## _on_about_to_score(section, category, dice_values)
##
## Called BEFORE score calculation. If category is CHANCE, registers a random multiplier.
func _on_about_to_score(section: Scorecard.Section, category: String, _dice_values: Array[int]) -> void:
	print("\n=== PERFECT STRANGERS: ABOUT TO SCORE ===")
	print("[PerfectStrangersPowerUp] Section:", section, " Category:", category)
	
	# Only trigger for CHANCE category
	if category != "chance":
		print("[PerfectStrangersPowerUp] Not CHANCE category - skipping")
		return
	
	# Pick a random multiplier from our options
	var random_index = randi() % RANDOM_MULTIPLIERS.size()
	var random_multiplier = RANDOM_MULTIPLIERS[random_index]
	
	print("[PerfectStrangersPowerUp] ✓ CHANCE category detected!")
	print("[PerfectStrangersPowerUp] ✓ Selected random multiplier: %.1fx" % random_multiplier)
	
	# Register the multiplier BEFORE score calculation
	var manager = _get_score_modifier_manager()
	if manager:
		manager.register_multiplier("perfect_strangers", random_multiplier)
		last_applied_multiplier = random_multiplier
		times_triggered += 1
		print("[PerfectStrangersPowerUp] ✓ Registered %.1fx multiplier with ScoreModifierManager" % random_multiplier)
		print("[PerfectStrangersPowerUp] Total times triggered: %d" % times_triggered)
		
		# Update description to show the applied multiplier
		emit_signal("description_updated", id, get_current_description())
	else:
		push_error("[PerfectStrangersPowerUp] Cannot find ScoreModifierManager")

## _on_score_assigned(section, category, score)
##
## Called AFTER score calculation. If we applied a multiplier for CHANCE, unregister it.
func _on_score_assigned(_section: Scorecard.Section, category: String, _score: int) -> void:
	_cleanup_after_scoring(category)

## _on_score_auto_assigned(section, category, score, breakdown_info)
##
## Called AFTER auto-score calculation. If we applied a multiplier for CHANCE, unregister it.
func _on_score_auto_assigned(_section: Scorecard.Section, category: String, _score: int, _breakdown_info: Dictionary = {}) -> void:
	_cleanup_after_scoring(category)

## _cleanup_after_scoring(category)
##
## Unregisters the multiplier after CHANCE scoring completes.
func _cleanup_after_scoring(category: String) -> void:
	if category != "chance":
		return
	
	print("\n=== PERFECT STRANGERS: CLEANUP AFTER SCORING ===")
	_unregister_multiplier()

## _unregister_multiplier()
##
## Removes the Perfect Strangers multiplier from ScoreModifierManager if registered.
func _unregister_multiplier() -> void:
	var manager = _get_score_modifier_manager()
	if manager and manager.has_multiplier("perfect_strangers"):
		manager.unregister_multiplier("perfect_strangers")
		print("[PerfectStrangersPowerUp] ✓ Unregistered multiplier from ScoreModifierManager")

## _get_score_modifier_manager()
##
## Gets a reference to the ScoreModifierManager singleton or group node.
## Returns null if not found.
func _get_score_modifier_manager():
	# Check if ScoreModifierManager exists as an autoload singleton
	if Engine.has_singleton("ScoreModifierManager"):
		return ScoreModifierManager
	
	# Fallback: check new group name first
	if get_tree():
		var group_node = get_tree().get_first_node_in_group("score_modifier_manager")
		if group_node:
			return group_node
		# Then check old group name for backward compatibility
		var old_group_node = get_tree().get_first_node_in_group("multiplier_manager")
		if old_group_node:
			return old_group_node
	
	return null

## get_current_description()
##
## Returns the current description of the PowerUp, including trigger count.
func get_current_description() -> String:
	var base_desc = "When scoring CHANCE, gain a random 1.1x-1.5x multiplier"
	
	if times_triggered > 0:
		var stats_desc = "\nTriggered: %d time(s)" % times_triggered
		if last_applied_multiplier > 0:
			stats_desc += " (last: %.1fx)" % last_applied_multiplier
		return base_desc + stats_desc
	
	return base_desc

## _on_tree_exiting()
##
## Cleanup when PowerUp is destroyed - unregisters multiplier and disconnects signals.
func _on_tree_exiting() -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		if scorecard_ref.is_connected("score_auto_assigned", _on_score_auto_assigned):
			scorecard_ref.score_auto_assigned.disconnect(_on_score_auto_assigned)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	_unregister_multiplier()