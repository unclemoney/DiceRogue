extends Mod
class_name WildcardMod

var possible_values: Array[int] = []

func _ready() -> void:
	add_to_group("mods")
	print("[WildcardMod] Ready")

func apply(target) -> void:
	var dice = target as Dice
	if dice and dice.dice_data:
		print("[WildcardMod] Applied to die:", dice.name)
		# Store original value
		var original_value = dice.value
		# Create typed array and populate it
		possible_values.clear()
		
		# Access sides through dice_data instead of directly
		for i in range(1, dice.dice_data.sides + 1):
			if i != original_value:
				possible_values.append(i)
		
		print("[WildcardMod] Possible values:", possible_values)
		emit_signal("mod_applied")
	else:
		push_error("[WildcardMod] Invalid target or missing dice_data")

func get_possible_values() -> Array[int]:
	return possible_values

func remove() -> void:
	possible_values.clear()
	emit_signal("mod_removed")
