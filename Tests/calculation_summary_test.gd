extends Control

func _ready() -> void:
	print("=== Calculation Summary Test ===")
	_test_calculation_summary()
	print("=== Test Complete ===")

func _test_calculation_summary() -> void:
	print("\n--- Testing LogEntry Calculation Summary ---")
	
	# Test case: Poor House (additive) + Consumer PowerUp (multiplier)
	# Should show: (22+500 Poor House) × 1.3 The Consumer is Always Right = 652
	
	var breakdown_info = {
		"base_score": 22,
		"final_score": 652,
		"has_modifiers": true,
		"category_display": "Ones",
		"total_additive": 500,
		"total_multiplier": 1.3,
		"additive_sources": [
			{"name": "poor_house_bonus", "category": "consumable", "value": 500}
		],
		"multiplier_sources": [
			{"name": "the_consumer_is_always_right", "category": "powerup", "value": 1.3}
		]
	}
	
	# Create a LogEntry to test the calculation summary
	var log_entry = preload("res://Scripts/Core/LogEntry.gd").new(
		[], [], [], "ones", "upper_section", [], [], 22, [], 652, 1, breakdown_info
	)
	
	var summary = log_entry.calculation_summary
	print("Generated summary: ", summary)
	
	# Check that it shows the correct source names
	assert(summary.contains("Poor House"), "Summary should contain 'Poor House' for additive")
	assert(summary.contains("The Consumer is Always Right"), "Summary should contain 'The Consumer is Always Right' for multiplier")
	assert(summary.contains("500 Poor House"), "Summary should show '500 Poor House' for additive amount")
	assert(summary.contains("×1.3 The Consumer is Always Right"), "Summary should show '×1.3 The Consumer is Always Right' for multiplier")
	
	print("✓ Calculation summary correctly shows source names")