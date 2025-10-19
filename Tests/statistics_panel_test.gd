extends Control

## StatisticsPanelTestScript
## 
## Test script that demonstrates the Statistics system and panel functionality.

var statistics_panel: Control
var stats_manager: Node

func _ready():
	statistics_panel = $StatisticsPanel
	stats_manager = get_node_or_null("/root/Statistics")
	
	print("=== Statistics Panel Integration Test ===")
	print("Press F10 to toggle the statistics panel")
	print("Press SPACE to generate some test statistics")
	print("Press R to reset all statistics")
	
	if stats_manager:
		print("✅ Statistics manager found")
		# Generate some initial test data
		_generate_test_statistics()
	else:
		print("❌ Statistics manager not found - check autoload configuration")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # SPACE key
		if stats_manager:
			_generate_test_statistics()
			print("Generated more test statistics")
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_F10:
			if statistics_panel and statistics_panel.has_method("toggle_visibility"):
				statistics_panel.toggle_visibility()
		elif event.keycode == KEY_R:
			if stats_manager:
				stats_manager.reset_statistics()
				print("Statistics reset")

func _generate_test_statistics():
	if not stats_manager:
		return
		
	# Simulate some game activity
	for i in range(5):
		stats_manager.increment_rolls()
		stats_manager.track_dice_roll(["red", "blue", "green", "yellow", "purple"][i % 5], randi_range(1, 6))
	
	stats_manager.increment_turns()
	
	if randf() > 0.5:
		var hand_types = ["ones", "twos", "threes", "full_house", "yahtzee", "chance"]
		var hand = hand_types[randi() % hand_types.size()]
		var score = randi_range(10, 50)
		stats_manager.record_hand_scored(hand, score)
		stats_manager.add_money_earned(score)
	else:
		stats_manager.record_failed_hand()
	
	# Simulate some purchases
	if randf() > 0.7:
		stats_manager.spend_money(randi_range(10, 30), ["powerup", "consumable", "mod"][randi() % 3])
		stats_manager.record_purchase(["powerup", "consumable", "mod"][randi() % 3])
	
	print("Current statistics - Rolls: %d, Turns: %d, Money: %d" % [
		stats_manager.total_rolls,
		stats_manager.total_turns, 
		stats_manager.get_current_money()
	])