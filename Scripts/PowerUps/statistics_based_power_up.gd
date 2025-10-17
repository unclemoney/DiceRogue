extends PowerUp
class_name StatisticsBasedPowerUp

## StatisticsBasedPowerUp
## 
## Example power-up that demonstrates using statistics for dynamic effects.
## This is a template showing how future power-ups can leverage the Statistics system.

## _ready()
## 
## Initialize the statistics-based power-up.
func _ready() -> void:
	id = "statistics_roll_bonus"

## apply(_target)
## 
## Apply the power-up effect. This example shows how to access statistics.
func apply(_target) -> void:
	print("[StatisticsBasedPowerUp] Applied - Current stats:")
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		print("  Total rolls: ", stats.total_rolls)
		print("  Total turns: ", stats.total_turns)
		print("  Hands completed: ", stats.hands_completed)
		print("  Money earned: ", stats.total_money_earned)
		print("  Favorite dice color: ", stats.get_favorite_dice_color())
		print("  Scoring percentage: ", "%.1f%%" % stats.get_scoring_percentage())
	else:
		print("  Statistics system not available")

## get_bonus_based_on_rolls() -> int
## 
## Example method showing how to calculate bonuses from statistics.
func get_bonus_based_on_rolls() -> int:
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		# Example: 1 bonus point per 10 rolls
		return stats.total_rolls / 10
	return 0

## is_milestone_reached(stat_name: String, threshold: int) -> bool
## 
## Example method for checking if player has reached certain milestones.
func is_milestone_reached(stat_name: String, threshold: int) -> bool:
	var stats = get_node_or_null("/root/Statistics")
	if not stats:
		return false
		
	match stat_name:
		"rolls":
			return stats.total_rolls >= threshold
		"hands":
			return stats.hands_completed >= threshold
		"money":
			return stats.total_money_earned >= threshold
		"streak":
			return stats.longest_streak >= threshold
		_:
			return false