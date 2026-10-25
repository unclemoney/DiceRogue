extends Mod
class_name SafetyTwosMod

var _attached_die: Dice = null

func _ready() -> void:
	add_to_group("mods")
	print("[SafetyTwosMod] Ready")

## apply(dice_target)
##
## Attaches the mod to a die and connects its roll-completion signal.
func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		print("[SafetyTwosMod] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target
		_attached_die.rolled.connect(_on_die_roll_completed)
		emit_signal("mod_applied")
	else:
		push_error("[SafetyTwosMod] Invalid target passed to apply()")

## remove()
##
## Disconnects the mod from its attached die.
func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	emit_signal("mod_removed")

## _on_die_roll_completed(_value)
##
## TODO: Exempt only this die at the disabled-twos enforcement boundary.
func _on_die_roll_completed(_value: int) -> void:
	pass
