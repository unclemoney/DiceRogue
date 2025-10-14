extends Consumable
class_name RandomPowerUpUncommonConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[RandomPowerUpUncommonConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[RandomPowerUpUncommonConsumable] Invalid target passed to apply()")
		return
	
	var pu_manager = game_controller.pu_manager
	if not pu_manager:
		push_error("[RandomPowerUpUncommonConsumable] No PowerUpManager found")
		return
	
	# Get all uncommon power-ups
	var uncommon_power_ups: Array[String] = []
	for power_up_id in pu_manager._defs_by_id:
		var def = pu_manager._defs_by_id[power_up_id] as PowerUpData
		if def and def.rarity == "uncommon":
			uncommon_power_ups.append(power_up_id)
	
	# Filter out already owned PowerUps
	var unowned_uncommon_power_ups: Array[String] = []
	for power_up_id in uncommon_power_ups:
		if not game_controller.active_power_ups.has(power_up_id):
			unowned_uncommon_power_ups.append(power_up_id)
	
	if unowned_uncommon_power_ups.is_empty():
		print("[RandomPowerUpUncommonConsumable] No unowned uncommon power-ups available")
		return
	
	# Select a random unowned uncommon power-up
	var random_index = randi() % unowned_uncommon_power_ups.size()
	var selected_power_up = unowned_uncommon_power_ups[random_index]
	
	print("[RandomPowerUpUncommonConsumable] Granting random uncommon power-up: ", selected_power_up)
	
	# Grant the power-up using the existing system
	game_controller.grant_power_up(selected_power_up)
	
	print("[RandomPowerUpUncommonConsumable] Applied successfully")