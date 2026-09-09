extends PowerUp
class_name SlimePowerUp

## SlimePowerUp
## Halves the chance denominator for the configured dice color (e.g. 1 in 25 to 1 in 12)
## This doubles the probability of rolling dice of that color

## Which dice color this slime boosts
@export var dice_color_type: DiceColor.Type = DiceColor.Type.GREEN
## Half the chance denominator = double the probability
@export var color_modifier: float = 0.5

# Reference to DiceColorManager
var dice_color_manager_ref = null

## Enable verbose debug logging (auto-enabled in debug builds)
var _debug_enabled: bool = OS.is_debug_build()

func _ready() -> void:
	add_to_group("power_ups")
	if _debug_enabled:
		print("[SlimePowerUp] Added to 'power_ups' group")

func apply(_target) -> void:
	if _debug_enabled:
		print("=== Applying SlimePowerUp (%s) ===" % DiceColor.get_color_name(dice_color_type))

	# Get DiceColorManager reference
	dice_color_manager_ref = get_tree().get_first_node_in_group("dice_color_manager")
	if not dice_color_manager_ref:
		dice_color_manager_ref = get_node_or_null("/root/DiceColorManager")

	if not dice_color_manager_ref:
		push_error("[SlimePowerUp] No DiceColorManager found")
		return

	# Register color chance modifier for the configured dice color
	dice_color_manager_ref.register_color_chance_modifier(dice_color_type, color_modifier)
	if _debug_enabled:
		print("[SlimePowerUp] Registered %s dice chance modifier: ×%.2f" % [DiceColor.get_color_name(dice_color_type).to_lower(), color_modifier])

	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	if _debug_enabled:
		print("=== Removing SlimePowerUp (%s) ===" % DiceColor.get_color_name(dice_color_type))

	if dice_color_manager_ref:
		dice_color_manager_ref.unregister_color_chance_modifier(dice_color_type)
		if _debug_enabled:
			print("[SlimePowerUp] Unregistered %s dice chance modifier" % DiceColor.get_color_name(dice_color_type).to_lower())

	dice_color_manager_ref = null

func get_current_description() -> String:
	var base_chance = DiceColor.get_color_chance(dice_color_type)
	var modified_chance = int(base_chance * color_modifier)
	return "Doubles %s dice probability (1 in %d → 1 in %d)" % [DiceColor.get_color_name(dice_color_type).to_lower(), base_chance, modified_chance]

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if dice_color_manager_ref:
		dice_color_manager_ref.unregister_color_chance_modifier(dice_color_type)
