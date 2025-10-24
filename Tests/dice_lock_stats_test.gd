extends Control

func _ready() -> void:
	print("=== Dice Locking Statistics Test ===")
	_test_dice_lock_tracking()
	print("=== Test Complete ===")

func _test_dice_lock_tracking() -> void:
	print("\n--- Testing Dice Lock Statistics Tracking ---")
	
	# Check initial state
	var initial_count = Statistics.dice_locked_count
	print("Initial dice locked count:", initial_count)
	
	# Directly test the tracking function
	Statistics.track_dice_lock()
	var after_track = Statistics.dice_locked_count
	print("After track_dice_lock():", after_track)
	
	# Verify increment
	assert(after_track == initial_count + 1, "track_dice_lock should increment counter")
	
	# Test multiple locks
	Statistics.track_dice_lock()
	Statistics.track_dice_lock()
	var final_count = Statistics.dice_locked_count
	print("After 3 total locks:", final_count)
	
	assert(final_count == initial_count + 3, "Should track multiple dice locks")
	
	print("✓ Dice lock statistics tracking working correctly")
	print("✓ Next step: Connect to actual dice locking in game")