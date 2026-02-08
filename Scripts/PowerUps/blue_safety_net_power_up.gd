extends PowerUp
class_name BlueSafetyNetPowerUp

## BlueSafetyNetPowerUp
##
## Uncommon PowerUp that reduces blue dice penalties by 50%.
## When a blue die is NOT used in scoring, the division penalty is halved.
## Uses DiceColorManager's blue_penalty_reduction_factor property.
## Price: $125, Rarity: Uncommon

const PENALTY_REDUCTION: float = 0.5  # 50% reduction

var dice_color_manager_ref = null

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(_target) -> void:
	print("=== Applying BlueSafetyNetPowerUp ===")
	
	dice_color_manager_ref = get_tree().get_first_node_in_group("dice_color_manager")
	if not dice_color_manager_ref:
		dice_color_manager_ref = get_node_or_null("/root/DiceColorManager")
	
	if not dice_color_manager_ref:
		push_error("[BlueSafetyNetPowerUp] No DiceColorManager found")
		return
	
	# Register blue penalty reduction
	dice_color_manager_ref.blue_penalty_reduction_factor = PENALTY_REDUCTION
	print("[BlueSafetyNetPowerUp] Registered blue penalty reduction: %.0f%%" % (PENALTY_REDUCTION * 100))
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing BlueSafetyNetPowerUp ===")
	if dice_color_manager_ref:
		dice_color_manager_ref.blue_penalty_reduction_factor = 1.0
		print("[BlueSafetyNetPowerUp] Reset blue penalty reduction")
	dice_color_manager_ref = null

func get_current_description() -> String:
	return "Blue dice penalties reduced by 50%%.\nDivision effect halved when blue dice aren't used in scoring."

func _on_tree_exiting() -> void:
	if dice_color_manager_ref:
		dice_color_manager_ref.blue_penalty_reduction_factor = 1.0
