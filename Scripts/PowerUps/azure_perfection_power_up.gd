extends PowerUp
class_name AzurePerfectionPowerUp

## AzurePerfectionPowerUp
##
## Legendary PowerUp that makes blue dice ALWAYS count as "used" in scoring.
## This completely eliminates the blue dice penalty (division effect).
## Blue dice will always multiply the score instead of dividing it.
## Price: $600, Rarity: Legendary

var dice_color_manager_ref = null

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(_target) -> void:
	print("=== Applying AzurePerfectionPowerUp ===")
	
	dice_color_manager_ref = get_tree().get_first_node_in_group("dice_color_manager")
	if not dice_color_manager_ref:
		dice_color_manager_ref = get_node_or_null("/root/DiceColorManager")
	
	if not dice_color_manager_ref:
		push_error("[AzurePerfectionPowerUp] No DiceColorManager found")
		return
	
	# Set blue_always_used flag on DiceColorManager
	dice_color_manager_ref.blue_always_used = true
	print("[AzurePerfectionPowerUp] Blue dice will ALWAYS count as used in scoring!")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing AzurePerfectionPowerUp ===")
	if dice_color_manager_ref:
		dice_color_manager_ref.blue_always_used = false
		print("[AzurePerfectionPowerUp] Reset blue_always_used flag")
	dice_color_manager_ref = null

func get_current_description() -> String:
	return "Blue dice ALWAYS count as 'used' in scoring!\nNo more division penalties - only multiplication bonuses!"

func _on_tree_exiting() -> void:
	if dice_color_manager_ref:
		dice_color_manager_ref.blue_always_used = false
