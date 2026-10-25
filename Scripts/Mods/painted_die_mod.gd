extends Mod
class_name PaintedDieMod

## PaintedDieMod
##
## Paints the die a single random color on apply and keeps it that color for
## the life of the mod (re-asserted after every roll, since Dice.roll()
## re-runs its random color assignment). The chosen color is stored in
## painted_color for tooltips/saves. Removing the mod clears the color.

var painted_color: DiceColor.Type = DiceColor.Type.NONE

var _attached_die: Dice = null
var _debug_enabled: bool = OS.is_debug_build()

func _ready() -> void:
	add_to_group("mods")
	if _debug_enabled:
		print("[PaintedDieMod] Ready")

## apply(dice_target)
##
## Picks from progression-unlocked colors and forces one onto the die. If none
## are unlocked, the mod remains attached without changing the die's color.
func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		if _debug_enabled:
			print("[PaintedDieMod] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target

		if painted_color == DiceColor.Type.NONE:
			var unlocked_colors = _get_unlocked_paint_colors()
			if not unlocked_colors.is_empty():
				painted_color = GameRNG.random_choice(unlocked_colors)
		if painted_color != DiceColor.Type.NONE:
			dice.force_color(painted_color)
		if _debug_enabled:
			print("[PaintedDieMod] Painted die:", DiceColor.get_color_name(painted_color))

		if not _attached_die.rolled.is_connected(_on_die_rolled):
			_attached_die.rolled.connect(_on_die_rolled)

		emit_signal("mod_applied")
	else:
		push_error("[PaintedDieMod] Invalid target passed to apply()")


func _get_unlocked_paint_colors(progress_manager_override: Node = null) -> Array[DiceColor.Type]:
	var unlocked_colors: Array[DiceColor.Type] = []
	var progress_manager := progress_manager_override
	if progress_manager == null:
		progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager == null:
		return unlocked_colors

	for color_type in DiceColor.get_all_colors():
		var unlock_id := DiceColor.get_color_name(color_type).to_lower() + "_dice"
		if progress_manager.is_item_unlocked(unlock_id):
			unlocked_colors.append(color_type)
	return unlocked_colors


func reset_for_roll() -> void:
	if _attached_die and painted_color != DiceColor.Type.NONE:
		_attached_die.force_color(painted_color)

## remove()
##
## Removes the mod and clears the die's color back to NONE.
func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_rolled):
			_attached_die.rolled.disconnect(_on_die_rolled)
		_attached_die.clear_color()
		_attached_die = null
	painted_color = DiceColor.Type.NONE
	emit_signal("mod_removed")

## _on_die_rolled(_value)
##
## Re-asserts the painted color after each roll.
func _on_die_rolled(_value: int) -> void:
	if _attached_die and painted_color != DiceColor.Type.NONE:
		_attached_die.force_color(painted_color)

## get_painted_color_name() -> String
##
## Returns the display name of the painted color (for tooltips/saves).
func get_painted_color_name() -> String:
	return DiceColor.get_color_name(painted_color)
