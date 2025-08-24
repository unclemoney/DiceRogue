extends Mod
class_name WildcardMod

var possible_values: Array[int] = []

func _ready() -> void:
	add_to_group("mods")
	print("[WildcardMod] Ready")

func apply(target) -> void:
	var dice = target as Dice
	if dice:
		print("[WildcardMod] Applied to die:", dice.name)
		# Store original value
		var original_value = dice.value
		# Create typed array and populate it
		possible_values.clear()
		for i in range(1, dice.sides + 1):
			if i != original_value:
				possible_values.append(i)
		
		print("[WildcardMod] Possible values:", possible_values)
		emit_signal("mod_applied")
	else:
		push_error("[WildcardMod] Invalid target passed to apply()")

func get_possible_values() -> Array[int]:
	return possible_values

func remove() -> void:
	possible_values.clear()
	emit_signal("mod_removed")
