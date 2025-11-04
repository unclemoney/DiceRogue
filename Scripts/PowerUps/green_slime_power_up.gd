extends PowerUp
class_name GreenSlimePowerUp

## GreenSlime PowerUp
## Halves the chance denominator for green dice (1 in 25 to 1 in 12.5)
## This doubles the probability of rolling green dice

# PowerUp-specific variables
var color_modifier: float = 0.5  # Half the chance denominator = double the probability

# Reference to DiceColorManager
var dice_color_manager_ref = null

func _ready() -> void:
	add_to_group("power_ups")
	print("[GreenSlimePowerUp] Added to 'power_ups' group")

func apply(_target) -> void:
	print("=== Applying GreenSlimePowerUp ===")
	
	# Get DiceColorManager reference
	dice_color_manager_ref = get_tree().get_first_node_in_group("dice_color_manager")
	if not dice_color_manager_ref:
		dice_color_manager_ref = get_node_or_null("/root/DiceColorManager")
	
	if not dice_color_manager_ref:
		push_error("[GreenSlimePowerUp] No DiceColorManager found")
		return
	
	# Register color chance modifier for green dice
	dice_color_manager_ref.register_color_chance_modifier(DiceColor.Type.GREEN, color_modifier)
	print("[GreenSlimePowerUp] Registered green dice chance modifier: ×%.2f" % color_modifier)
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing GreenSlimePowerUp ===")
	
	if dice_color_manager_ref:
		dice_color_manager_ref.unregister_color_chance_modifier(DiceColor.Type.GREEN)
		print("[GreenSlimePowerUp] Unregistered green dice chance modifier")
	
	dice_color_manager_ref = null

func get_current_description() -> String:
	var base_chance = DiceColor.get_color_chance(DiceColor.Type.GREEN)
	var modified_chance = int(base_chance * color_modifier)
	return "Doubles green dice probability (1 in %d → 1 in %d)" % [base_chance, modified_chance]

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if dice_color_manager_ref:
		dice_color_manager_ref.unregister_color_chance_modifier(DiceColor.Type.GREEN)