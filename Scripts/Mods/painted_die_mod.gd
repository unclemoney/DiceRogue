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
## Picks a random non-NONE color via GameRNG and forces it onto the die.
func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		if _debug_enabled:
			print("[PaintedDieMod] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target  # Store in base class target variable

		painted_color = GameRNG.random_choice(DiceColor.get_all_colors())
		dice.force_color(painted_color)
		if _debug_enabled:
			print("[PaintedDieMod] Painted die:", DiceColor.get_color_name(painted_color))

		# Dice.roll() re-assigns a random color each roll; re-assert ours after
		if not _attached_die.rolled.is_connected(_on_die_rolled):
			_attached_die.rolled.connect(_on_die_rolled)

		emit_signal("mod_applied")
	else:
		push_error("[PaintedDieMod] Invalid target passed to apply()")

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
