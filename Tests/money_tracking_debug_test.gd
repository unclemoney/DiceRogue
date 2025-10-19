extends Control

## MoneyTrackingDebugTest
##
## Test script to debug money tracking issues between PlayerEconomy and Statistics

@onready var debug_label: Label = $VBoxContainer/DebugLabel

func _ready():
	debug_label.text = "Money Tracking Debug Test\n\n"
	
	# Wait a frame for systems to initialize
	await get_tree().process_frame
	
	run_debug_test()

func run_debug_test():
	debug_label.text += "=== INITIAL STATE ===\n"
	debug_label.text += "PlayerEconomy.money: %d\n" % PlayerEconomy.money
	debug_label.text += "Statistics.get_current_money(): %d\n" % Statistics.get_current_money()
	debug_label.text += "Statistics.total_money_earned: %d\n" % Statistics.total_money_earned
	debug_label.text += "Statistics.total_money_spent: %d\n" % Statistics.total_money_spent
	debug_label.text += "\n"
	
	# Test 1: Add money through PlayerEconomy
	debug_label.text += "=== TEST 1: Adding 100 money through PlayerEconomy ===\n"
	PlayerEconomy.add_money(100)
	
	debug_label.text += "After PlayerEconomy.add_money(100):\n"
	debug_label.text += "PlayerEconomy.money: %d\n" % PlayerEconomy.money
	debug_label.text += "Statistics.get_current_money(): %d\n" % Statistics.get_current_money()
	debug_label.text += "Statistics.total_money_earned: %d\n" % Statistics.total_money_earned
	debug_label.text += "\n"
	
	# Test 2: Remove money through PlayerEconomy
	debug_label.text += "=== TEST 2: Removing 50 money through PlayerEconomy ===\n"
	PlayerEconomy.remove_money(50, "test")
	
	debug_label.text += "After PlayerEconomy.remove_money(50, 'test'):\n"
	debug_label.text += "PlayerEconomy.money: %d\n" % PlayerEconomy.money
	debug_label.text += "Statistics.get_current_money(): %d\n" % Statistics.get_current_money()
	debug_label.text += "Statistics.total_money_spent: %d\n" % Statistics.total_money_spent
	debug_label.text += "\n"
	
	# Test 3: Direct Statistics manipulation
	debug_label.text += "=== TEST 3: Direct Statistics manipulation ===\n"
	debug_label.text += "Before direct Statistics.add_money_earned(200):\n"
	debug_label.text += "Statistics.total_money_earned: %d\n" % Statistics.total_money_earned
	debug_label.text += "Statistics.get_current_money(): %d\n" % Statistics.get_current_money()
	
	Statistics.add_money_earned(200)
	
	debug_label.text += "After Statistics.add_money_earned(200):\n"
	debug_label.text += "Statistics.total_money_earned: %d\n" % Statistics.total_money_earned
	debug_label.text += "Statistics.get_current_money(): %d\n" % Statistics.get_current_money()
	debug_label.text += "PlayerEconomy.money: %d (should be unchanged)\n" % PlayerEconomy.money
	debug_label.text += "\n"
	
	# Test 4: Check if there are multiple money additions happening
	debug_label.text += "=== TEST 4: Check for duplicate tracking ===\n"
	var initial_earned = Statistics.total_money_earned
	var initial_current = Statistics.get_current_money()
	var initial_economy = PlayerEconomy.money
	
	debug_label.text += "Before PlayerEconomy.add_money(50):\n"
	debug_label.text += "Economy: %d, Stats Current: %d, Stats Earned: %d\n" % [initial_economy, initial_current, initial_earned]
	
	PlayerEconomy.add_money(50)
	
	debug_label.text += "After PlayerEconomy.add_money(50):\n"
	debug_label.text += "Economy: %d (expected: %d)\n" % [PlayerEconomy.money, initial_economy + 50]
	debug_label.text += "Stats Current: %d (expected: %d)\n" % [Statistics.get_current_money(), initial_current + 50]
	debug_label.text += "Stats Earned: %d (expected: %d)\n" % [Statistics.total_money_earned, initial_earned + 50]
	
	var economy_diff = PlayerEconomy.money - initial_economy
	var stats_current_diff = Statistics.get_current_money() - initial_current
	var stats_earned_diff = Statistics.total_money_earned - initial_earned
	
	debug_label.text += "\nDifferences:\n"
	debug_label.text += "Economy change: %d\n" % economy_diff
	debug_label.text += "Stats current change: %d\n" % stats_current_diff
	debug_label.text += "Stats earned change: %d\n" % stats_earned_diff
	
	if economy_diff != 50:
		debug_label.text += "ERROR: Economy didn't increase by exactly 50!\n"
	if stats_current_diff != 50:
		debug_label.text += "ERROR: Statistics current_money didn't increase by exactly 50!\n"
	if stats_earned_diff != 50:
		debug_label.text += "ERROR: Statistics total_money_earned didn't increase by exactly 50!\n"
	
	debug_label.text += "\n=== DEBUG COMPLETE ===\n"