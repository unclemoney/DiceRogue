extends Node
## Debug script to check PlayerEconomy vs Statistics money discrepancy

func _ready():
	print("\n=== Money Debug Check ===")
	
	# Wait a frame to ensure everything is initialized
	await get_tree().process_frame
	
	var player_economy = get_node_or_null("/root/PlayerEconomy")
	var statistics = get_node_or_null("/root/Statistics")
	
	if player_economy:
		print("PlayerEconomy.money:", player_economy.money)
		print("PlayerEconomy.get_money():", player_economy.get_money())
	else:
		print("ERROR: PlayerEconomy not found")
	
	if statistics:
		print("Statistics.get_current_money():", statistics.get_current_money())
		print("Statistics.total_money_earned:", statistics.total_money_earned)
		print("Statistics.total_money_spent:", statistics.total_money_spent)
	else:
		print("ERROR: Statistics not found")
	
	# Test the money change flow
	if player_economy and statistics:
		print("\n--- Testing money changes ---")
		print("Before: PlayerEconomy =", player_economy.money, "Statistics =", statistics.get_current_money())
		
		# Add money through PlayerEconomy
		player_economy.add_money(100)
		print("After adding 100: PlayerEconomy =", player_economy.money, "Statistics =", statistics.get_current_money())
		
		# Remove money through PlayerEconomy
		player_economy.remove_money(50)
		print("After removing 50: PlayerEconomy =", player_economy.money, "Statistics =", statistics.get_current_money())
		
		print("Statistics earned:", statistics.total_money_earned)
		print("Statistics spent:", statistics.total_money_spent)
	
	print("=========================\n")