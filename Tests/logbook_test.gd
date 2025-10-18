extends Node

## LogbookTest
##
## Test scene to verify the logbook functionality

var test_scorecard: Scorecard
var test_dice_results = [4, 4, 4, 2, 1]
var test_colors = ["red", "red", "red", "blue", "white"]

func _ready():
	print("=== LOGBOOK SYSTEM TEST ===")
	
	# Test basic logbook entry creation
	test_basic_logbook_entry()
	
	# Test logbook retrieval methods
	test_logbook_retrieval()
	
	# Test logbook formatting
	test_logbook_formatting()
	
	# Test logbook export
	test_logbook_export()

func test_basic_logbook_entry():
	print("\n--- Testing Basic Logbook Entry ---")
	
	Statistics.reset_statistics()
	
	# Create a test log entry
	Statistics.log_hand_scored(
		test_dice_results,
		test_colors,
		[],  # no mods
		"three_of_a_kind",
		"lower",
		[],  # no consumables
		[],  # no powerups
		15,  # base score
		[],  # no effects
		15   # final score
	)
	
	print("Logbook entries count:", Statistics.logbook.size())
	
	if Statistics.logbook.size() > 0:
		var entry = Statistics.logbook[0]
		print("✓ Entry created successfully")
		print("  - Category:", entry.scorecard_category)
		print("  - Dice values:", entry.dice_values)
		print("  - Dice colors:", entry.dice_colors) 
		print("  - Final score:", entry.final_score)
		print("  - Formatted line:", entry.formatted_log_line)
	else:
		print("❌ Failed to create logbook entry")

func test_logbook_retrieval():
	print("\n--- Testing Logbook Retrieval ---")
	
	# Add a few more entries
	Statistics.log_hand_scored([5, 5, 5, 5, 5], ["green", "green", "green", "green", "green"], 
		[], "yahtzee", "lower", [], [], 50, [], 50)
	
	Statistics.log_hand_scored([1, 2, 3, 4, 5], ["white", "white", "white", "white", "white"], 
		[], "large_straight", "lower", [], [], 40, [], 40)
	
	# Test getting recent entries
	var recent = Statistics.get_recent_log_entries(2)
	print("Recent entries count:", recent.size())
	
	for entry in recent:
		print("  - ", entry.formatted_log_line)
	
	# Test filtering
	var yahtzee_entries = Statistics.get_logbook_entries({"category": "yahtzee"})
	print("Yahtzee entries count:", yahtzee_entries.size())
	
	# Test summary
	var summary = Statistics.get_logbook_summary()
	print("Logbook summary:")
	print("  - Total entries:", summary.total_entries)
	print("  - Average score:", summary.average_score)
	print("  - Most common category:", summary.most_common_category)

func test_logbook_formatting():
	print("\n--- Testing Logbook Formatting ---")
	
	var formatted = Statistics.get_formatted_recent_logs(3)
	print("Formatted recent logs:")
	print(formatted)
	
	# Test individual LogEntry methods
	if Statistics.logbook.size() > 0:
		var entry = Statistics.logbook[0]
		print("Entry timestamp string:", entry.get_timestamp_string())
		print("Entry has modifiers:", entry.has_modifiers())
		print("Entry modifier value:", entry.get_total_modifier_value())

func test_logbook_export():
	print("\n--- Testing Logbook Export ---")
	
	var export_path = Statistics.export_logbook_to_file("test_logbook.json")
	if export_path != "":
		print("✓ Logbook exported to:", export_path)
	else:
		print("❌ Failed to export logbook")
	
	# Test clearing
	var original_count = Statistics.logbook.size()
	Statistics.clear_logbook()
	print("Logbook cleared. Entries before:", original_count, "after:", Statistics.logbook.size())
	
	print("\n=== LOGBOOK TEST COMPLETE ===")