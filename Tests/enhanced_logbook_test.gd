extends Node

## Enhanced Logbook Display Test
##
## Test the new enhanced logbook system with detailed scoring breakdowns

func _ready():
	print("=== Enhanced Logbook Display Test ===")
	await get_tree().process_frame
	
	test_enhanced_logbook_entry()
	
	print("\n=== Test Complete ===")
	get_tree().quit()

func test_enhanced_logbook_entry():
	print("\n1. Testing enhanced logbook entry creation...")
	
	# Create test breakdown info that would come from calculate_score_with_breakdown
	var test_breakdown_info = {
		"base_score": 25,
		"regular_additive": 0,
		"dice_color_additive": 5,
		"total_additive": 5,
		"regular_multiplier": 5.0,
		"dice_color_multiplier": 1.0,
		"total_multiplier": 5.0,
		"score_after_additives": 30,
		"final_score": 150,
		"category_display": "Full House",
		"active_powerups": ["pin_head"],
		"active_consumables": [],
		"dice_color_money": 0,
		"has_modifiers": true
	}
	
	# Create test LogEntry with the enhanced breakdown info
	var test_entry = LogEntry.new(
		[2, 2, 2, 3, 3],         # dice_values
		["red", "white", "white", "white", "white"],  # dice_colors
		["", "", "", "", ""],     # dice_mods
		"full_house",             # category
		"lower",                  # section
		[],                       # consumables
		["pin_head"],            # powerups
		25,                       # base_score
		[],                       # effects (legacy)
		150,                      # final_score
		1,                        # turn
		test_breakdown_info       # breakdown_info
	)
	
	print("Test entry created successfully!")
	print("Formatted log line: ", test_entry.formatted_log_line)
	print("Calculation summary: ", test_entry.calculation_summary)
	
	# Test another entry without modifiers
	var simple_breakdown_info = {
		"base_score": 30,
		"final_score": 30,
		"category_display": "Large Straight",
		"has_modifiers": false
	}
	
	var simple_entry = LogEntry.new(
		[1, 2, 3, 4, 5],         # dice_values
		["white", "white", "white", "white", "white"],  # dice_colors
		["", "", "", "", ""],     # dice_mods
		"large_straight",         # category
		"lower",                  # section
		[],                       # consumables
		[],                       # powerups
		30,                       # base_score
		[],                       # effects (legacy)
		30,                       # final_score
		2,                        # turn
		simple_breakdown_info     # breakdown_info
	)
	
	print("\nSimple entry (no modifiers):")
	print("Formatted log line: ", simple_entry.formatted_log_line)
	print("Calculation summary: ", simple_entry.calculation_summary)
	
	# Test entry with multiple modifiers
	var complex_breakdown_info = {
		"base_score": 18,
		"regular_additive": 10,
		"dice_color_additive": 8,
		"total_additive": 18,
		"regular_multiplier": 2.0,
		"dice_color_multiplier": 1.5,
		"total_multiplier": 3.0,
		"score_after_additives": 36,
		"final_score": 108,
		"category_display": "Sixes",
		"active_powerups": ["bonus_money", "pin_head"],
		"active_consumables": [],
		"dice_color_money": 0,
		"has_modifiers": true
	}
	
	var complex_entry = LogEntry.new(
		[6, 6, 6, 1, 2],         # dice_values
		["red", "red", "purple", "white", "white"],  # dice_colors
		["", "", "", "", ""],     # dice_mods
		"sixes",                  # category
		"upper",                  # section
		[],                       # consumables
		["bonus_money", "pin_head"],  # powerups
		18,                       # base_score
		[],                       # effects (legacy)
		108,                      # final_score
		3,                        # turn
		complex_breakdown_info    # breakdown_info
	)
	
	print("\nComplex entry (multiple modifiers):")
	print("Formatted log line: ", complex_entry.formatted_log_line)
	print("Calculation summary: ", complex_entry.calculation_summary)