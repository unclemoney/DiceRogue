extends Mod
class_name ThreeButThreeMod

var _attached_die: Dice = null

func _ready() -> void:
	add_to_group("mods")
	print("[ThreeButThreeMod] Ready")

## apply(dice_target)
##
## Applies the Three But Three mod to a dice. This mod forces the die to always roll a 3
## and grants the player $3 for every roll.
func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		print("[ThreeButThreeMod] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target  # Store in base class target variable
		# Connect to the rolled signal to modify the value and grant money
		_attached_die.rolled.connect(_on_die_roll_completed)
		emit_signal("mod_applied")
	else:
		push_error("[ThreeButThreeMod] Invalid target passed to apply()")

## remove()
##
## Removes the Three But Three mod from the attached dice.
func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	emit_signal("mod_removed")

## _on_die_roll_completed(value)
##
## Callback when the attached die completes a roll. Forces the value to 3 and grants $3 to the player.
func _on_die_roll_completed(value: int) -> void:
	# Force the die to show 3
	_attached_die.value = 3
	print("[ThreeButThreeMod] Forced roll to 3 and granting $3")
	
	# Grant $3 to the player using PlayerEconomy
	PlayerEconomy.add_money(3)