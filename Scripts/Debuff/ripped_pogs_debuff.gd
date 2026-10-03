extends Debuff
class_name RippedPogsDebuff

## RippedPogsDebuff
##
## PowerUp multipliers divide instead of multiply - ONLY PowerUp-registered
## multiplier sources (ScoreModifierManager sources categorized "powerup").
## Dice-color multipliers (purple/blue) are EXCLUDED and continue to multiply.
## Deliberately narrower than The Division, which also flips dice colors.

var score_modifier_manager: Node

## apply(_target)
##
## Enables PowerUp division mode in the ScoreModifierManager so PowerUp score
## factors use the inverted multiply/divide policy.
func apply(_target) -> void:
	print("[RippedPogsDebuff] Applied - PowerUp multipliers now divide")

	# Store the target for cleanup
	self.target = _target

	# Find the ScoreModifierManager (should be an autoload)
	score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if not score_modifier_manager:
		push_error("[RippedPogsDebuff] Failed to find ScoreModifierManager")
		return

	if not score_modifier_manager.has_method("set_powerup_division_mode"):
		push_error("[RippedPogsDebuff] ScoreModifierManager missing set_powerup_division_mode method")
		return

	# Enable PowerUp division mode
	score_modifier_manager.set_powerup_division_mode(true)

	print("[RippedPogsDebuff] Successfully enabled PowerUp division mode")

## remove()
##
## Disables PowerUp division mode in the ScoreModifierManager, restoring normal
## PowerUp multiplier behavior.
func remove() -> void:
	print("[RippedPogsDebuff] Removed - Restoring normal PowerUp multiplier behavior")

	if is_instance_valid(score_modifier_manager) and score_modifier_manager.has_method("set_powerup_division_mode"):
		# Disable PowerUp division mode
		score_modifier_manager.set_powerup_division_mode(false)
		print("[RippedPogsDebuff] PowerUp division mode disabled")
	else:
		print("[RippedPogsDebuff] No ScoreModifierManager found to restore")
