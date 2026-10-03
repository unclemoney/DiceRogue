extends Debuff
class_name TornScorecardDebuff

## TornScorecardDebuff
##
## Scorecard category level factors divide instead of multiply.
## Level N (normally xN) becomes /N. Level 1 (x1) stays /1 - the debuff
## punishes upgraded categories only. Dice-color and PowerUp multipliers
## are unaffected (that is The Division / Ripped POGs territory).

var score_modifier_manager: Node

## apply(_target)
##
## Enables level division mode in the ScoreModifierManager so scorecard
## category levels use the inverted multiply/divide policy.
func apply(_target) -> void:
	print("[TornScorecardDebuff] Applied - Scorecard levels now divide")

	# Store the target for cleanup
	self.target = _target

	# Find the ScoreModifierManager (should be an autoload)
	score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if not score_modifier_manager:
		push_error("[TornScorecardDebuff] Failed to find ScoreModifierManager")
		return

	if not score_modifier_manager.has_method("set_level_division_mode"):
		push_error("[TornScorecardDebuff] ScoreModifierManager missing set_level_division_mode method")
		return

	# Enable level division mode
	score_modifier_manager.set_level_division_mode(true)

	print("[TornScorecardDebuff] Successfully enabled level division mode")

## remove()
##
## Disables level division mode in the ScoreModifierManager, restoring normal
## category level multiplier behavior.
func remove() -> void:
	print("[TornScorecardDebuff] Removed - Restoring normal level behavior")

	if is_instance_valid(score_modifier_manager) and score_modifier_manager.has_method("set_level_division_mode"):
		# Disable level division mode
		score_modifier_manager.set_level_division_mode(false)
		print("[TornScorecardDebuff] Level division mode disabled")
	else:
		print("[TornScorecardDebuff] No ScoreModifierManager found to restore")
