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

func _on_die_roll_completed(value: int) -> void:
	if value % 2 == 0:  # If even number
		# Force reroll to odd number
		_attached_die.value = (randi() % 3) * 2 + 1  # Will give 1, 3, or 5
		print("[OddOnlyMod] Converted even roll to odd:", _attached_die.value)
