extends Debuff
class_name TooGreedyDebuff

## TooGreedyDebuff
##
## Penalizes players for hoarding money. Before scoring, this debuff takes
## the player's total money, divides by divisor (scaled by intensity), and subtracts
## that amount from the additive score. Only applies if money > floor (scaled by intensity).
## Intensity scaling: Higher intensity = lower divisor (more penalty) and lower floor.
## Example at 1.0: $250 money = -3 penalty (250/100, floor $50)
## Example at 2.0: $200 money = -4 penalty (200/50, floor $25)

const BASE_MONEY_FLOOR: int = 50  ## Base floor before intensity scaling
const BASE_DIVISOR: int = 100  ## Base divisor before intensity scaling

var _effective_floor: int = 50  ## Floor after intensity scaling
var _effective_divisor: int = 100  ## Divisor after intensity scaling
var _game_controller: GameController = null
var _scorecard_ui: ScoreCardUI = null
var _penalty_applied: bool = false

## apply(_target)
##
## Connects to the ScoreCardUI's about_to_score signal to intercept scoring
## and apply the greed penalty based on player's current money.
func apply(_target) -> void:
	# Calculate effective values based on intensity
	_effective_floor = int(round(BASE_MONEY_FLOOR / intensity))
	_effective_divisor = int(round(BASE_DIVISOR / intensity))
	_effective_divisor = maxi(10, _effective_divisor)  # Prevent division by very small numbers
	
	print("[TooGreedyDebuff] Applied - Intensity:", intensity, "Floor: $%d, Divisor: %d" % [_effective_floor, _effective_divisor])
	
	# Store the target for cleanup
	self.target = _target
	_game_controller = _target as GameController
	
	if not _game_controller:
		push_error("[TooGreedyDebuff] Invalid target - expected GameController")
		return
	
	# Find ScoreCardUI to connect to about_to_score signal
	_scorecard_ui = get_tree().get_first_node_in_group("scorecard_ui") as ScoreCardUI
	if not _scorecard_ui:
		push_error("[TooGreedyDebuff] Failed to find ScoreCardUI")
		return
	
	# Connect to about_to_score signal (before score calculation)
	if _scorecard_ui.has_signal("about_to_score"):
		if not _scorecard_ui.is_connected("about_to_score", _on_about_to_score):
			_scorecard_ui.about_to_score.connect(_on_about_to_score)
			print("[TooGreedyDebuff] Connected to about_to_score signal")
	else:
		push_error("[TooGreedyDebuff] ScoreCardUI missing about_to_score signal")
		return
	
	# Connect to hand_scored signal (after score calculation) for cleanup
	if _scorecard_ui.has_signal("hand_scored"):
		if not _scorecard_ui.is_connected("hand_scored", _on_hand_scored):
			_scorecard_ui.hand_scored.connect(_on_hand_scored)
			print("[TooGreedyDebuff] Connected to hand_scored signal")
	
	print("[TooGreedyDebuff] Successfully initialized")

## remove()
##
## Disconnects from ScoreCardUI signals and cleans up any pending penalty.
func remove() -> void:
	print("[TooGreedyDebuff] Removed - No longer penalizing money")
	
	# Clean up any pending penalty
	_cleanup_penalty()
	
	# Disconnect signals
	if _scorecard_ui:
		if _scorecard_ui.is_connected("about_to_score", _on_about_to_score):
			_scorecard_ui.about_to_score.disconnect(_on_about_to_score)
			print("[TooGreedyDebuff] Disconnected from about_to_score signal")
		if _scorecard_ui.is_connected("hand_scored", _on_hand_scored):
			_scorecard_ui.hand_scored.disconnect(_on_hand_scored)
			print("[TooGreedyDebuff] Disconnected from hand_scored signal")
	
	_scorecard_ui = null
	_game_controller = null

## _on_about_to_score(_section, _category, _dice_values)
##
## Called before score calculation. Applies a negative additive penalty
## based on the player's current money (money / divisor, only if money > floor).
func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	# Get current player money
	var current_money: int = PlayerEconomy.get_money()
	
	# Only apply penalty if money exceeds the floor
	if current_money <= _effective_floor:
		print("[TooGreedyDebuff] Money ($%d) at or below floor ($%d) - no penalty" % [current_money, _effective_floor])
		return
	
	# Calculate penalty: money / divisor, rounded
	var penalty: int = roundi(float(current_money) / float(_effective_divisor))
	
	if penalty <= 0:
		print("[TooGreedyDebuff] Calculated penalty is 0 - no penalty applied")
		return
	
	var score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if not score_modifier_manager:
		push_error("[TooGreedyDebuff] Failed to find ScoreModifierManager")
		return
	
	# Register negative additive as penalty
	score_modifier_manager.register_additive("greed_penalty", -penalty)
	_penalty_applied = true
	print("[TooGreedyDebuff] Applied greed penalty: -%d (money: $%d, divisor: %d)" % [penalty, current_money, _effective_divisor])

## _on_hand_scored()
##
## Called after scoring completes. Removes the temporary penalty.
func _on_hand_scored() -> void:
	_cleanup_penalty()

## _cleanup_penalty()
##
## Removes the temporary greed penalty from ScoreModifierManager.
func _cleanup_penalty() -> void:
	if not _penalty_applied:
		return
	
	var score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if score_modifier_manager and score_modifier_manager.has_additive("greed_penalty"):
		score_modifier_manager.unregister_additive("greed_penalty")
		print("[TooGreedyDebuff] Cleaned up greed penalty additive")
	
	_penalty_applied = false
