extends Mod
class_name OddOnlyMod

var _attached_die: Dice = null

func _ready() -> void:
	add_to_group("mods")
	print("[OddOnlyMod] Ready")

func apply(target) -> void:
	var dice = target as Dice
	if dice:
		print("[OddOnlyMod] Applied to die:", dice.name)
		_attached_die = dice
		_attached_die.rolled.connect(_on_die_roll_completed)
		emit_signal("mod_applied")
	else:
		push_error("[OddOnlyMod] Invalid target passed to apply()")

func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	emit_signal("mod_removed")

## _on_die_roll_completed(value: int)
##
## Converts even rolls to a random odd face valid for the die's actual side
## count (d4 odds = [1,3], d6 odds = [1,3,5], etc.), then refreshes the visual
## so the displayed face always matches die.value.
func _on_die_roll_completed(value: int) -> void:
	if value % 2 == 0:  # If even number
		var odd_values: Array[int] = []
		if not _attached_die.dice_data:
			push_error("[OddOnlyMod] Attached die has no DiceData")
			return
		for i in range(1, _attached_die.dice_data.sides + 1):
			if i % 2 != 0:
				odd_values.append(i)
		if odd_values.is_empty():
			push_error("[OddOnlyMod] No odd faces available on die: ", _attached_die.name)
			return
		_attached_die.value = odd_values[GameRNG.randi_mod(odd_values.size())]
		_attached_die.update_visual()
		print("[OddOnlyMod] Converted even roll to odd:", _attached_die.value)
