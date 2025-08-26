extends Mod
class_name GoldSixMod

var _attached_die: Dice = null

func _ready() -> void:
	add_to_group("mods")
	print("[GoldSixMod] Ready")

func apply(target) -> void:
	var dice = target as Dice
	if dice:
		print("[GoldSixMod] Applied to die:", dice.name)
		_attached_die = dice
		# Connect to the die's 'rolled' signal
		_attached_die.rolled.connect(_on_die_roll_completed)
		emit_signal("mod_applied")
	else:
		push_error("[GoldSixMod] Invalid target passed to apply()")

func remove() -> void:
	if _attached_die:
		# Clean up signal connection
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	emit_signal("mod_removed")

func _on_die_roll_completed(value: int) -> void:
	if value == 6:
		print("[GoldSixMod] Rolled a 6! Adding money")
		PlayerEconomy.add_money(60)
