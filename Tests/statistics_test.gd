extends Node

## StatisticsTest
## 
## Test scene to verify the Statistics system functionality.

var stats_manager: Node

func _ready():
	print("=== Statistics System Test ===")
	
	# Get reference to Statistics autoload
	stats_manager = get_node_or_null("/root/Statistics")
	
	if not stats_manager:
		print("❌ ERROR: Statistics autoload not found!")
		return
	
	print("✅ Statistics manager found, running tests...")
	
	# Test basic incrementing
	print("Initial turns:", stats_manager.total_turns)
	stats_manager.increment_turns()
	print("After increment:", stats_manager.total_turns)
	
	# Test dice tracking
	stats_manager.track_dice_roll("red", 6)
	stats_manager.track_dice_roll("blue", 3)
	stats_manager.track_dice_roll("red", 4)
	print("Red dice rolls:", stats_manager.dice_rolled_by_color["red"])
	print("Blue dice rolls:", stats_manager.dice_rolled_by_color["blue"])
	print("Highest single roll:", stats_manager.highest_single_roll)
	print("Favorite color:", stats_manager.get_favorite_dice_color())
	
	# Test hand scoring
	stats_manager.record_hand_scored("yahtzee", 50)
	print("Yahtzees scored:", stats_manager.yahtzee_scored)
	print("Hands completed:", stats_manager.hands_completed)
	print("Current streak:", stats_manager.current_streak)
	
	# Test money tracking
	stats_manager.add_money_earned(100)
	stats_manager.spend_money(25, "powerup")
	print("Current money:", stats_manager.current_money)
	print("Total earned:", stats_manager.total_money_earned)
	print("Spent on powerups:", stats_manager.money_spent_on_powerups)
	
	# Test calculated stats
	print("Scoring percentage:", stats_manager.get_scoring_percentage())
	print("Money efficiency:", stats_manager.get_money_efficiency())
	
	# Test snake eyes
	stats_manager.check_snake_eyes([1, 1, 1, 1, 1])
	print("Snake eyes count:", stats_manager.snake_eyes_count)
	
	# Test milestone signals
	stats_manager.milestone_reached.connect(_on_milestone_reached)
	
	# Trigger some milestones
	for i in range(8):
		stats_manager.increment_rolls()
	
	print("=== Test Complete ===")

func _on_milestone_reached(milestone_name: String, value: int):
	print("🎉 Milestone reached: %s = %d" % [milestone_name, value])