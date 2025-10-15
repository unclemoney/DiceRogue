extends Debuff
class_name TheDivisionDebuff

## TheDivisionDebuff
##
## Converts all multiplier power-ups to work as dividers instead.
## When active, any power-up that would normally multiply scores will instead divide them.
## Example: A 2.0 multiplier becomes 1/2.0 = 0.5 (dividing score by 2)

var score_modifier_manager: Node

## apply(_target)
##
## Enables division mode in the ScoreModifierManager to convert 
## multipliers to dividers.
func apply(_target) -> void:
	print("[TheDivisionDebuff] Applied - Converting multipliers to dividers")
	
	# Store the target for cleanup
	self.target = _target
	
	# Find the ScoreModifierManager (should be an autoload)
	score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if not score_modifier_manager:
		push_error("[TheDivisionDebuff] Failed to find ScoreModifierManager")
		return
	
	if not score_modifier_manager.has_method("set_division_mode"):
		push_error("[TheDivisionDebuff] ScoreModifierManager missing set_division_mode method")
		return
	
	# Enable division mode
	score_modifier_manager.set_division_mode(true)
	
	print("[TheDivisionDebuff] Successfully enabled division mode")

## remove()
##
## Disables division mode in the ScoreModifierManager, restoring normal multiplier behavior.
func remove() -> void:
	print("[TheDivisionDebuff] Removed - Restoring normal multiplier behavior")
	
	if score_modifier_manager and score_modifier_manager.has_method("set_division_mode"):
		# Disable division mode
		score_modifier_manager.set_division_mode(false)
		print("[TheDivisionDebuff] Division mode disabled")
	else:
		print("[TheDivisionDebuff] No ScoreModifierManager found to restore")
