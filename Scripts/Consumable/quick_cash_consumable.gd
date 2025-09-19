extends Consumable
class_name QuickCashConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[QuickCashConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[QuickCashConsumable] Invalid target passed to apply()")
		return
		
	var total_power_up_value := calculate_total_power_up_value(game_controller)
	var cash_amount := int(total_power_up_value * 0.2)  # 20% of total value
	
	if cash_amount > 0:
		# Grant money through PlayerEconomy
		var player_economy = get_node("/root/PlayerEconomy")
		if player_economy:
			player_economy.add_money(cash_amount)
			print("[QuickCashConsumable] Granted %d dollars (20%% of %d total PowerUp value)" % [cash_amount, total_power_up_value])
		else:
			push_error("[QuickCashConsumable] PlayerEconomy autoload not found")
	else:
		print("[QuickCashConsumable] No PowerUps owned, granted 0 dollars")

func calculate_total_power_up_value(game_controller: GameController) -> int:
	var total_value := 0
	
	# Access the PowerUpManager to get price data
	if not game_controller.pu_manager:
		push_error("[QuickCashConsumable] PowerUpManager not found")
		return 0
		
	# Iterate through all active power-ups and sum their prices
	for power_up_id in game_controller.active_power_ups.keys():
		var def: PowerUpData = game_controller.pu_manager.get_def(power_up_id)
		if def:
			total_value += def.price
			print("[QuickCashConsumable] PowerUp '%s' value: %d" % [power_up_id, def.price])
		else:
			push_error("[QuickCashConsumable] No definition found for PowerUp: %s" % power_up_id)
	
	print("[QuickCashConsumable] Total PowerUp value: %d" % total_value)
	return total_value