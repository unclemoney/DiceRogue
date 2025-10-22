extends Consumable
class_name TheRaritiesConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[TheRaritiesConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[TheRaritiesConsumable] Invalid target passed to apply()")
		return
	
	var pu_manager = game_controller.pu_manager
	if not pu_manager:
		push_error("[TheRaritiesConsumable] No PowerUpManager found")
		return
	
	# Count powerups by rarity and calculate payment
	var rarity_counts = {
		"common": 0,
		"uncommon": 0,
		"rare": 0,
		"epic": 0,
		"legendary": 0
	}
	
	var payment_rates = {
		"common": 20,
		"uncommon": 25,
		"rare": 50,
		"epic": 75,
		"legendary": 150
	}
	
	print("[TheRaritiesConsumable] Counting active powerups...")
	
	# Iterate through all active power-ups and count by rarity
	for power_up_id in game_controller.active_power_ups.keys():
		var def: PowerUpData = pu_manager.get_def(power_up_id)
		if def:
			var rarity = def.rarity.to_lower()
			if rarity_counts.has(rarity):
				rarity_counts[rarity] += 1
				print("[TheRaritiesConsumable] Found %s powerup: %s" % [rarity, power_up_id])
			else:
				print("[TheRaritiesConsumable] Unknown rarity '%s' for powerup: %s" % [rarity, power_up_id])
		else:
			push_error("[TheRaritiesConsumable] No definition found for PowerUp: %s" % power_up_id)
	
	# Calculate total payment
	var total_payment := 0
	var payment_breakdown := []
	
	for rarity in rarity_counts.keys():
		var count = rarity_counts[rarity]
		if count > 0:
			var rarity_payment = count * payment_rates[rarity]
			total_payment += rarity_payment
			payment_breakdown.append("%d %s ($%d each = $%d)" % [count, rarity, payment_rates[rarity], rarity_payment])
			print("[TheRaritiesConsumable] %d %s powerups: $%d" % [count, rarity, rarity_payment])
	
	# Grant money through PlayerEconomy
	if total_payment > 0:
		var player_economy = get_node("/root/PlayerEconomy")
		if player_economy:
			player_economy.add_money(total_payment)
			print("[TheRaritiesConsumable] Granted $%d total (%s)" % [total_payment, ", ".join(payment_breakdown)])
		else:
			push_error("[TheRaritiesConsumable] PlayerEconomy autoload not found")
	else:
		print("[TheRaritiesConsumable] No powerups owned, granted $0")
	
	print("[TheRaritiesConsumable] Applied successfully")