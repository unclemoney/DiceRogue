extends Consumable
class_name ThePawnShopConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[ThePawnShopConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[ThePawnShopConsumable] Invalid target passed to apply()")
		return
	
	var pu_manager = game_controller.pu_manager
	if not pu_manager:
		push_error("[ThePawnShopConsumable] No PowerUpManager found")
		return
	
	# Check if player has any PowerUps to sell
	if game_controller.active_power_ups.is_empty():
		print("[ThePawnShopConsumable] No PowerUps to sell")
		return
	
	print("[ThePawnShopConsumable] Selling all PowerUps...")
	
	# Calculate total pawn value and collect PowerUps to remove
	var total_pawn_value := 0
	var powerups_to_remove := []
	var sale_breakdown := []
	
	# Iterate through all active power-ups and calculate pawn values
	for power_up_id in game_controller.active_power_ups.keys():
		var def: PowerUpData = pu_manager.get_def(power_up_id)
		if def:
			var purchase_price = def.price
			var pawn_value = int(purchase_price * 1.25)  # 1.25x the purchase value
			total_pawn_value += pawn_value
			powerups_to_remove.append(power_up_id)
			sale_breakdown.append("%s: $%d → $%d" % [def.display_name, purchase_price, pawn_value])
			print("[ThePawnShopConsumable] Selling %s: $%d → $%d" % [power_up_id, purchase_price, pawn_value])
		else:
			push_error("[ThePawnShopConsumable] No definition found for PowerUp: %s" % power_up_id)
	
	# Grant money through PlayerEconomy
	if total_pawn_value > 0:
		var player_economy = get_node("/root/PlayerEconomy")
		if player_economy:
			player_economy.add_money(total_pawn_value)
			print("[ThePawnShopConsumable] Granted $%d total from selling %d PowerUps" % [total_pawn_value, powerups_to_remove.size()])
			print("[ThePawnShopConsumable] Sale breakdown: %s" % ", ".join(sale_breakdown))
		else:
			push_error("[ThePawnShopConsumable] PlayerEconomy autoload not found")
			return
	
	# Remove all PowerUps from the game
	for power_up_id in powerups_to_remove:
		print("[ThePawnShopConsumable] Removing PowerUp: %s" % power_up_id)
		print("[ThePawnShopConsumable] Before removal - Active PowerUps count: %d" % game_controller.active_power_ups.size())
		game_controller.revoke_power_up(power_up_id)
		print("[ThePawnShopConsumable] After removal - Active PowerUps count: %d" % game_controller.active_power_ups.size())
	
	print("[ThePawnShopConsumable] Applied successfully - sold %d PowerUps for $%d total" % [powerups_to_remove.size(), total_pawn_value])