extends Mod
class_name EvenOnlyMod

var _attached_die: Dice = null

func _ready() -> void:
	add_to_group("mods")
	print("[EvenOnlyMod] Ready")

func apply(target) -> void:
	var dice = target as Dice
	if dice:
		print("[EvenOnlyMod] Applied to die:", dice.name)
		_attached_die = dice
		# Just connect normally - we'll handle the value modification in the callback
		_attached_die.rolled.connect(_on_die_roll_completed)
		emit_signal("mod_applied")
	else:
		push_error("[EvenOnlyMod] Invalid target passed to apply()")

func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	emit_signal("mod_removed")

## _on_die_roll_completed(value: int)
##
## Converts odd rolls to a random even face valid for the die's actual side
## count (d4 evens = [2,4], d6 evens = [2,4,6], etc.), then refreshes the visual
## so the displayed face always matches die.value.
func _on_die_roll_completed(value: int) -> void:
	if value % 2 != 0:  # If odd number
		var even_values: Array[int] = []
		if not _attached_die.dice_data:
			push_error("[EvenOnlyMod] Attached die has no DiceData")
			return
		for i in range(1, _attached_die.dice_data.sides + 1):
			if i % 2 == 0:
				even_values.append(i)
		if even_values.is_empty():
			push_error("[EvenOnlyMod] No even faces available on die: ", _attached_die.name)
			return
		_attached_die.value = even_values[GameRNG.randi_mod(even_values.size())]
		_attached_die.update_visual()
		print("[EvenOnlyMod] Converted odd roll to even:", _attached_die.value)
