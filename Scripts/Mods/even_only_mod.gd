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

func _on_die_roll_completed(value: int) -> void:
	if value % 2 != 0:  # If odd number
		# Force reroll until we get an even number
		_attached_die.value = (randi() % 3 + 1) * 2  # Will give 2, 4, or 6
		print("[EvenOnlyMod] Converted odd roll to even:", _attached_die.value)
