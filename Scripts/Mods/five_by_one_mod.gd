extends Mod
class_name FiveByOneMod

var _attached_die: Dice = null
var roll_count: int = 0
var _mod_id: String = "five_by_one"

func _ready() -> void:
	add_to_group("mods")
	print("[FiveByOneMod] Ready")

## apply(dice_target)
##
## Applies the Five By One mod to a dice. This mod forces the die to always roll a 5
## and tracks how many times it has been rolled to add bonus points to scores.
func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		print("[FiveByOneMod] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target  # Store in base class target variable
		
		# Connect to the rolled signal to modify the value and track rolls
		_attached_die.rolled.connect(_on_die_roll_completed)
		
		# Register additive bonus with ScoreModifierManager
		_update_score_additive()
		
		emit_signal("mod_applied")
	else:
		push_error("[FiveByOneMod] Invalid target passed to apply()")

## remove()
##
## Removes the Five By One mod from the attached dice and cleans up score modifiers.
func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	
	# Unregister score additive
	if ScoreModifierManager.has_additive(_mod_id):
		ScoreModifierManager.unregister_additive(_mod_id)
		print("[FiveByOneMod] Unregistered score additive")
	
	# Reset roll count when mod is removed (sold)
	roll_count = 0
	print("[FiveByOneMod] Reset roll count to 0")
	
	emit_signal("mod_removed")

## _on_die_roll_completed(value)
##
## Callback when the attached die completes a roll. Forces the value to 5,
## increments roll count, and updates the score bonus.
func _on_die_roll_completed(value: int) -> void:
	# Force the die to show 5
	_attached_die.value = 5
	
	# Increment roll count
	roll_count += 1
	print("[FiveByOneMod] Forced roll to 5, roll count now: ", roll_count)
	
	# Update the additive score bonus
	_update_score_additive()

## _update_score_additive()
##
## Updates the additive score bonus based on current roll count.
func _update_score_additive() -> void:
	if roll_count > 0:
		ScoreModifierManager.register_additive(_mod_id, roll_count)
		print("[FiveByOneMod] Updated score additive to +", roll_count, " points")
	else:
		# Remove additive if count is 0
		if ScoreModifierManager.has_additive(_mod_id):
			ScoreModifierManager.unregister_additive(_mod_id)
			print("[FiveByOneMod] Removed score additive")

## get_roll_count() -> int
##
## Returns the current roll count for this mod instance.
func get_roll_count() -> int:
	return roll_count

## reset_count()
##
## Resets the roll count (used when mod is sold/removed).
func reset_count() -> void:
	roll_count = 0
	_update_score_additive()
	print("[FiveByOneMod] Roll count reset to 0")