extends Debuff
class_name DisabledColorsDebuff

## DisabledColorsDebuff
##
## Disables all colored dice functionality while active.
## Calls DiceColorManager.set_colors_enabled(false) to disable the color system.
## Restores colors when removed.

var dice_color_manager: Node

## apply(_target)
##
## Disables the dice color system globally.
func apply(_target) -> void:
	print("[DisabledColorsDebuff] Applied - Disabling all colored dice")
	self.target = _target
	
	# Find DiceColorManager
	dice_color_manager = get_tree().get_first_node_in_group("dice_color_manager")
	if not dice_color_manager:
		# Try autoload fallback
		dice_color_manager = get_node_or_null("/root/DiceColorManager")
	
	if not dice_color_manager:
		push_error("[DisabledColorsDebuff] Failed to find DiceColorManager")
		return
	
	if dice_color_manager.has_method("set_colors_enabled"):
		dice_color_manager.set_colors_enabled(false)
		print("[DisabledColorsDebuff] Dice colors disabled globally")

## remove()
##
## Re-enables the dice color system.
func remove() -> void:
	print("[DisabledColorsDebuff] Removed - Re-enabling colored dice")
	
	if dice_color_manager and dice_color_manager.has_method("set_colors_enabled"):
		dice_color_manager.set_colors_enabled(true)
		print("[DisabledColorsDebuff] Dice colors re-enabled")
