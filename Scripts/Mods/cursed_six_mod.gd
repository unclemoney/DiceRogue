extends Mod
class_name CursedSixMod

## CursedSixMod
##
## The die always rolls a 6 (clamped to the highest face on smaller dice,
## e.g. 4 on a d4), but the player is CHARGED $5 for every roll.
## Sellable, but sells for $0 (see sell_price on the ModData resource).

const ROLL_COST: int = 5

var _attached_die: Dice = null
var _debug_enabled: bool = OS.is_debug_build()

func _ready() -> void:
	add_to_group("mods")
	if _debug_enabled:
		print("[CursedSixMod] Ready")

## apply(dice_target)
##
## Applies the Cursed Six mod to a dice. Forces the die to always roll a 6
## and charges the player $5 for every roll.
func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		if _debug_enabled:
			print("[CursedSixMod] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target  # Store in base class target variable
		# Connect to the rolled signal to force the value and charge the cost
		_attached_die.rolled.connect(_on_die_roll_completed)
		emit_signal("mod_applied")
	else:
		push_error("[CursedSixMod] Invalid target passed to apply()")

## remove()
##
## Removes the Cursed Six mod from the attached dice.
func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	emit_signal("mod_removed")

## _on_die_roll_completed(value)
##
## Callback when the attached die completes a roll. Forces the value to 6
## (clamped to the highest face on smaller dice, e.g. 4 on a d4, so the value
## never exceeds the available faces) and charges the player $5. The charge
## is mandatory — it applies even when the player cannot afford it.
func _on_die_roll_completed(_value: int) -> void:
	# Force the die to show 6, clamped to the die's actual side count
	var forced_value: int = 6
	if _attached_die.dice_data:
		forced_value = mini(6, _attached_die.dice_data.sides)
	_attached_die.value = forced_value
	_attached_die.update_visual()

	# Charge $5 per roll
	PlayerEconomy.remove_money(ROLL_COST, "mod")
	if _debug_enabled:
		print("[CursedSixMod] Forced roll to %d and charged $%d" % [forced_value, ROLL_COST])
