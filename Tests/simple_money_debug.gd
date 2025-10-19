extends Node

## Simple money debug test

func _ready():
	print("=== MONEY TRACKING DEBUG TEST ===\n")
	
	print("=== INITIAL STATE ===")
	print("PlayerEconomy.money: %d" % PlayerEconomy.money)
	print("Statistics.get_current_money(): %d" % Statistics.get_current_money())
	print("Statistics.total_money_earned: %d" % Statistics.total_money_earned)
	print("Statistics.total_money_spent: %d" % Statistics.total_money_spent)
	print("")
	
	# Test 1: Add money through PlayerEconomy
	print("=== TEST 1: Adding 100 money through PlayerEconomy ===")
	PlayerEconomy.add_money(100)
	
	print("After PlayerEconomy.add_money(100):")
	print("PlayerEconomy.money: %d" % PlayerEconomy.money)
	print("Statistics.get_current_money(): %d" % Statistics.get_current_money())
	print("Statistics.total_money_earned: %d" % Statistics.total_money_earned)
	print("")
	
	# Test 2: Remove money through PlayerEconomy
	print("=== TEST 2: Removing 50 money through PlayerEconomy ===")
	PlayerEconomy.remove_money(50, "test")
	
	print("After PlayerEconomy.remove_money(50, 'test'):")
	print("PlayerEconomy.money: %d" % PlayerEconomy.money)
	print("Statistics.get_current_money(): %d" % Statistics.get_current_money())
	print("Statistics.total_money_spent: %d" % Statistics.total_money_spent)
	print("")
	
	# Test 3: Check for duplicate tracking
	print("=== TEST 3: Check for duplicate tracking ===")
	var initial_earned = Statistics.total_money_earned
	var initial_current = Statistics.get_current_money()
	var initial_economy = PlayerEconomy.money
	
	print("Before PlayerEconomy.add_money(50):")
	print("Economy: %d, Stats Current: %d, Stats Earned: %d" % [initial_economy, initial_current, initial_earned])
	
	PlayerEconomy.add_money(50)
	
	print("After PlayerEconomy.add_money(50):")
	print("Economy: %d (expected: %d)" % [PlayerEconomy.money, initial_economy + 50])
	print("Stats Current: %d (expected: %d)" % [Statistics.get_current_money(), initial_current + 50])
	print("Stats Earned: %d (expected: %d)" % [Statistics.total_money_earned, initial_earned + 50])
	
	var economy_diff = PlayerEconomy.money - initial_economy
	var stats_current_diff = Statistics.get_current_money() - initial_current
	var stats_earned_diff = Statistics.total_money_earned - initial_earned
	
	print("\nDifferences:")
	print("Economy change: %d" % economy_diff)
	print("Stats current change: %d" % stats_current_diff)
	print("Stats earned change: %d" % stats_earned_diff)
	
	if economy_diff != 50:
		print("ERROR: Economy didn't increase by exactly 50!")
	if stats_current_diff != 50:
		print("ERROR: Statistics current_money didn't increase by exactly 50!")
	if stats_earned_diff != 50:
		print("ERROR: Statistics total_money_earned didn't increase by exactly 50!")
	
	print("\n=== DEBUG COMPLETE ===")
	
	# Wait a bit then quit
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()