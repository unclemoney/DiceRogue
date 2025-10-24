extends Node
## Test script for GreenMonster PowerUp functionality and dice scoring tracking

func _ready():
	print("=== Green Monster PowerUp Test ===")
	
	# Wait a frame for singletons to initialize
	await get_tree().process_frame
	
	test_green_monster_powerup()
	test_dice_scoring_tracking()

func test_green_monster_powerup():
	print("\n--- Testing GreenMonster PowerUp ---")
	
	# Check if PowerUp loads correctly
	var green_monster_scene = preload("res://Scenes/PowerUp/GreenWithEnvy.tscn")
	if green_monster_scene:
		print("✓ GreenMonster PowerUp scene loads correctly")
		
		var green_monster = green_monster_scene.instantiate()
		add_child(green_monster)
		
		# Test if it has the correct methods
		if green_monster.has_method("_on_score_assigned"):
			print("✓ GreenMonster has _on_score_assigned method")
		else:
			print("✗ GreenMonster missing _on_score_assigned method")
			
		if green_monster.has_method("apply"):
			print("✓ GreenMonster has apply method")
		else:
			print("✗ GreenMonster missing apply method")
			
		green_monster.queue_free()
	else:
		print("✗ Failed to load GreenMonster PowerUp scene")

func test_dice_scoring_tracking():
	print("\n--- Testing Dice Scoring Tracking ---")
	
	# Check if Statistics singleton exists and has tracking method
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		print("✓ Statistics singleton found")
		
		if stats.has_method("track_dice_array_scored"):
			print("✓ Statistics has track_dice_array_scored method")
			
			# Test with mock dice data (simplified)
			var mock_dice = []
			# Create simple mock objects with just the properties we need
			for i in 5:
				var mock_die = {}
				mock_die.value = i + 1
				# Set a mock color - we'll test with different colors
				if i < 2:
					mock_die.color = "green"
				elif i < 4:
					mock_die.color = "red"
				else:
					mock_die.color = "blue"
				mock_dice.append(mock_die)
			
			# Get initial counts
			var initial_green = stats.dice_scored_by_color.get("green", 0)
			var initial_red = stats.dice_scored_by_color.get("red", 0)
			var initial_blue = stats.dice_scored_by_color.get("blue", 0)
			
			print("Initial counts - Green: %d, Red: %d, Blue: %d" % [initial_green, initial_red, initial_blue])
			
			# Track the mock dice
			stats.track_dice_array_scored(mock_dice)
			
			# Check if counts increased
			var final_green = stats.dice_scored_by_color.get("green", 0)
			var final_red = stats.dice_scored_by_color.get("red", 0)
			var final_blue = stats.dice_scored_by_color.get("blue", 0)
			
			print("Final counts - Green: %d, Red: %d, Blue: %d" % [final_green, final_red, final_blue])
			
			if final_green == initial_green + 2:
				print("✓ Green dice tracking works correctly (+2)")
			else:
				print("✗ Green dice tracking failed (expected +2, got +%d)" % (final_green - initial_green))
				
			if final_red == initial_red + 2:
				print("✓ Red dice tracking works correctly (+2)")
			else:
				print("✗ Red dice tracking failed (expected +2, got +%d)" % (final_red - initial_red))
				
			if final_blue == initial_blue + 1:
				print("✓ Blue dice tracking works correctly (+1)")
			else:
				print("✗ Blue dice tracking failed (expected +1, got +%d)" % (final_blue - initial_blue))
			
			# No cleanup needed for dictionary objects
				
		else:
			print("✗ Statistics missing track_dice_array_scored method")
	else:
		print("✗ Statistics singleton not found")

	print("\n=== Test Complete ===")