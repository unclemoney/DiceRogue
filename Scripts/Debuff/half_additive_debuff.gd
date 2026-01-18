extends Debuff
class_name HalfAdditiveDebuff

## HalfAdditiveDebuff
##
## Halves all additive bonuses before multipliers are applied.
## When scoring occurs, this debuff intercepts the additive total,
## divides it by 2 (using roundi()), and applies a penalty to achieve the halving effect.
## Example: +10 additive becomes +5 additive before multipliers.

var _game_controller: GameController = null
var _scorecard_ui: ScoreCardUI = null
var _penalty_applied: bool = false

## apply(_target)
##
## Connects to the ScoreCardUI's about_to_score signal to intercept scoring
## and apply the halving penalty before score calculation.
func apply(_target) -> void:
	print("[HalfAdditiveDebuff] Applied - Halving additive bonuses")
	
	# Store the target for cleanup
	self.target = _target
	_game_controller = _target as GameController
	
	if not _game_controller:
		push_error("[HalfAdditiveDebuff] Invalid target - expected GameController")
		return
	
	# Find ScoreCardUI to connect to about_to_score signal
	_scorecard_ui = get_tree().get_first_node_in_group("scorecard_ui") as ScoreCardUI
	if not _scorecard_ui:
		push_error("[HalfAdditiveDebuff] Failed to find ScoreCardUI")
		return
	
	# Connect to about_to_score signal (before score calculation)
	if _scorecard_ui.has_signal("about_to_score"):
		if not _scorecard_ui.is_connected("about_to_score", _on_about_to_score):
			_scorecard_ui.about_to_score.connect(_on_about_to_score)
			print("[HalfAdditiveDebuff] Connected to about_to_score signal")
	else:
		push_error("[HalfAdditiveDebuff] ScoreCardUI missing about_to_score signal")
		return
	
	# Connect to hand_scored signal (after score calculation) for cleanup
	if _scorecard_ui.has_signal("hand_scored"):
		if not _scorecard_ui.is_connected("hand_scored", _on_hand_scored):
			_scorecard_ui.hand_scored.connect(_on_hand_scored)
			print("[HalfAdditiveDebuff] Connected to hand_scored signal")
	
	print("[HalfAdditiveDebuff] Successfully initialized")

## remove()
##
## Disconnects from ScoreCardUI signals and cleans up any pending penalty.
func remove() -> void:
	print("[HalfAdditiveDebuff] Removed - Restoring normal additive behavior")
	
	# Clean up any pending penalty
	_cleanup_penalty()
	
	# Disconnect signals
	if _scorecard_ui:
		if _scorecard_ui.is_connected("about_to_score", _on_about_to_score):
			_scorecard_ui.about_to_score.disconnect(_on_about_to_score)
			print("[HalfAdditiveDebuff] Disconnected from about_to_score signal")
		if _scorecard_ui.is_connected("hand_scored", _on_hand_scored):
			_scorecard_ui.hand_scored.disconnect(_on_hand_scored)
			print("[HalfAdditiveDebuff] Disconnected from hand_scored signal")
	
	_scorecard_ui = null
	_game_controller = null

## _on_about_to_score(_section, _category, _dice_values)
##
## Called before score calculation. Applies a negative additive penalty
## to effectively halve the total additive bonus.
func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	var score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if not score_modifier_manager:
		push_error("[HalfAdditiveDebuff] Failed to find ScoreModifierManager")
		return
	
	# Get current total additive
	var current_additive: int = score_modifier_manager.get_total_additive()
	
	if current_additive <= 0:
		print("[HalfAdditiveDebuff] No additive bonuses to halve (current: %d)" % current_additive)
		return
	
	# Calculate the halved value using roundi()
	var halved_additive: int = roundi(float(current_additive) / 2.0)
	
	# The penalty is the difference between original and halved
	var penalty: int = current_additive - halved_additive
	
	if penalty > 0:
		# Register negative additive to achieve halving effect
		score_modifier_manager.register_additive("half_additive_penalty", -penalty)
		_penalty_applied = true
		print("[HalfAdditiveDebuff] Applied penalty: -%d (original: %d, halved to: %d)" % [penalty, current_additive, halved_additive])

## _on_hand_scored()
##
## Called after scoring completes. Removes the temporary penalty.
func _on_hand_scored() -> void:
	_cleanup_penalty()

## _cleanup_penalty()
##
## Removes the temporary penalty additive from ScoreModifierManager.
func _cleanup_penalty() -> void:
	if not _penalty_applied:
		return
	
	var score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if score_modifier_manager and score_modifier_manager.has_additive("half_additive_penalty"):
		score_modifier_manager.unregister_additive("half_additive_penalty")
		print("[HalfAdditiveDebuff] Cleaned up penalty additive")
	
	_penalty_applied = false
