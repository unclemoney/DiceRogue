extends Node

## StatisticsManager
## 
## Singleton that tracks all game statistics and metrics.
## Accessible globally as "Statistics" autoload.

signal milestone_reached(milestone_name: String, value: int)
signal new_record_set(statistic_name: String, new_value)

# Core Game Metrics
var total_turns: int = 0
var total_rolls: int = 0
var total_rerolls: int = 0
var hands_completed: int = 0
var failed_hands: int = 0

# Economic Metrics
var total_money_earned: int = 0
var total_money_spent: int = 0
var money_spent_on_powerups: int = 0
var money_spent_on_consumables: int = 0
var money_spent_on_mods: int = 0
var current_money: int = 0

# Dice Metrics
var dice_rolled_by_color: Dictionary = {}
var dice_locked_count: int = 0
var highest_single_roll: int = 0
var snake_eyes_count: int = 0
var yahtzee_count: int = 0

# Hand Type Statistics
var ones_scored: int = 0
var twos_scored: int = 0
var threes_scored: int = 0
var fours_scored: int = 0
var fives_scored: int = 0
var sixes_scored: int = 0
var three_of_kind_scored: int = 0
var four_of_kind_scored: int = 0
var full_house_scored: int = 0
var small_straight_scored: int = 0
var large_straight_scored: int = 0
var yahtzee_scored: int = 0
var chance_scored: int = 0

# Power-Up & Item Usage
var powerups_purchased: int = 0
var consumables_purchased: int = 0
var mods_purchased: int = 0
var powerups_used: int = 0
var consumables_used: int = 0

# Session Metrics
var session_start_time: float = 0.0
var total_play_time: float = 0.0
var highest_score: int = 0
var longest_streak: int = 0
var current_streak: int = 0

# Internal tracking
var _last_update_time: float = 0.0

## _ready()
## 
## Initialize the statistics system when the autoload is created.
func _ready():
	session_start_time = Time.get_time_dict_from_system().get("unix", Time.get_unix_time_from_system())
	_last_update_time = Time.get_unix_time_from_system()
	_initialize_dice_color_tracking()
	print("Statistics Manager initialized")

## _initialize_dice_color_tracking()
## 
## Set up the dice color tracking dictionary.
func _initialize_dice_color_tracking():
	var dice_colors = ["red", "blue", "green", "yellow", "purple", "white"]
	for color in dice_colors:
		dice_rolled_by_color[color] = 0

## increment_turns()
## 
## Increment the total turns counter and check for milestones.
func increment_turns():
	total_turns += 1
	_check_milestone("turns", total_turns)

## increment_rolls()
## 
## Increment the total rolls counter.
func increment_rolls():
	total_rolls += 1
	_check_milestone("rolls", total_rolls)

## increment_rerolls()
## 
## Increment the total rerolls counter.
func increment_rerolls():
	total_rerolls += 1

## track_dice_roll(color: String, value: int)
## 
## Track a dice roll by color and value.
func track_dice_roll(color: String, value: int):
	if dice_rolled_by_color.has(color):
		dice_rolled_by_color[color] += 1
	
	if value > highest_single_roll:
		highest_single_roll = value
		new_record_set.emit("highest_single_roll", value)

## track_dice_lock()
## 
## Increment the dice locked counter.
func track_dice_lock():
	dice_locked_count += 1

## record_hand_scored(hand_type: String, _score: int)
## 
## Record a completed hand and its score.
func record_hand_scored(hand_type: String, _score: int):
	hands_completed += 1
	current_streak += 1
	
	if current_streak > longest_streak:
		longest_streak = current_streak
		new_record_set.emit("longest_streak", longest_streak)
	
	match hand_type.to_lower():
		"ones":
			ones_scored += 1
		"twos":
			twos_scored += 1
		"threes":
			threes_scored += 1
		"fours":
			fours_scored += 1
		"fives":
			fives_scored += 1
		"sixes":
			sixes_scored += 1
		"three_of_a_kind":
			three_of_kind_scored += 1
		"four_of_a_kind":
			four_of_kind_scored += 1
		"full_house":
			full_house_scored += 1
		"small_straight":
			small_straight_scored += 1
		"large_straight":
			large_straight_scored += 1
		"yahtzee":
			yahtzee_scored += 1
			yahtzee_count += 1
		"chance":
			chance_scored += 1

## record_failed_hand()
## 
## Record a turn where no valid hand was scored.
func record_failed_hand():
	failed_hands += 1
	current_streak = 0

## add_money_earned(amount: int)
## 
## Add to the total money earned.
func add_money_earned(amount: int):
	total_money_earned += amount
	current_money += amount

## spend_money(amount: int, category: String = "")
## 
## Record money spent, optionally by category.
func spend_money(amount: int, category: String = ""):
	total_money_spent += amount
	current_money -= amount
	
	match category.to_lower():
		"powerup":
			money_spent_on_powerups += amount
		"consumable":
			money_spent_on_consumables += amount
		"mod":
			money_spent_on_mods += amount

## record_purchase(item_type: String)
## 
## Record the purchase of an item.
func record_purchase(item_type: String):
	match item_type.to_lower():
		"powerup":
			powerups_purchased += 1
		"consumable":
			consumables_purchased += 1
		"mod":
			mods_purchased += 1

## record_item_usage(item_type: String)
## 
## Record the usage of an item.
func record_item_usage(item_type: String):
	match item_type.to_lower():
		"powerup":
			powerups_used += 1
		"consumable":
			consumables_used += 1

## update_highest_score(score: int)
## 
## Update the highest score if the new score is higher.
func update_highest_score(score: int):
	if score > highest_score:
		highest_score = score
		new_record_set.emit("highest_score", score)

## check_snake_eyes(dice_values: Array)
## 
## Check if all dice show 1 and increment counter if so.
func check_snake_eyes(dice_values: Array):
	var all_ones = true
	for value in dice_values:
		if value != 1:
			all_ones = false
			break
	
	if all_ones and dice_values.size() > 0:
		snake_eyes_count += 1
		milestone_reached.emit("snake_eyes", snake_eyes_count)

## get_total_play_time()
## 
## Get the total play time in seconds for the current session.
func get_total_play_time() -> float:
	var current_time = Time.get_unix_time_from_system()
	total_play_time = current_time - session_start_time
	return total_play_time

## get_scoring_percentage()
## 
## Calculate the percentage of turns that resulted in a scored hand.
func get_scoring_percentage() -> float:
	if total_turns == 0:
		return 0.0
	return (hands_completed / float(total_turns)) * 100.0

## get_money_efficiency()
## 
## Calculate money earned per turn.
func get_money_efficiency() -> float:
	if total_turns == 0:
		return 0.0
	return total_money_earned / float(total_turns)

## get_favorite_dice_color()
## 
## Get the dice color that has been rolled the most.
func get_favorite_dice_color() -> String:
	var max_rolls = 0
	var favorite_color = "none"
	
	for color in dice_rolled_by_color.keys():
		if dice_rolled_by_color[color] > max_rolls:
			max_rolls = dice_rolled_by_color[color]
			favorite_color = color
	
	return favorite_color

## get_average_score_per_hand()
## 
## Calculate the average score per completed hand.
func get_average_score_per_hand() -> float:
	if hands_completed == 0:
		return 0.0
	return total_money_earned / float(hands_completed)

## get_all_statistics()
## 
## Get a dictionary containing all current statistics.
func get_all_statistics() -> Dictionary:
	return {
		"core_metrics": {
			"total_turns": total_turns,
			"total_rolls": total_rolls,
			"total_rerolls": total_rerolls,
			"hands_completed": hands_completed,
			"failed_hands": failed_hands
		},
		"economic_metrics": {
			"total_money_earned": total_money_earned,
			"total_money_spent": total_money_spent,
			"money_spent_on_powerups": money_spent_on_powerups,
			"money_spent_on_consumables": money_spent_on_consumables,
			"money_spent_on_mods": money_spent_on_mods,
			"current_money": current_money
		},
		"dice_metrics": {
			"dice_rolled_by_color": dice_rolled_by_color,
			"dice_locked_count": dice_locked_count,
			"highest_single_roll": highest_single_roll,
			"snake_eyes_count": snake_eyes_count,
			"yahtzee_count": yahtzee_count
		},
		"hand_statistics": {
			"ones_scored": ones_scored,
			"twos_scored": twos_scored,
			"threes_scored": threes_scored,
			"fours_scored": fours_scored,
			"fives_scored": fives_scored,
			"sixes_scored": sixes_scored,
			"three_of_kind_scored": three_of_kind_scored,
			"four_of_kind_scored": four_of_kind_scored,
			"full_house_scored": full_house_scored,
			"small_straight_scored": small_straight_scored,
			"large_straight_scored": large_straight_scored,
			"yahtzee_scored": yahtzee_scored,
			"chance_scored": chance_scored
		},
		"item_usage": {
			"powerups_purchased": powerups_purchased,
			"consumables_purchased": consumables_purchased,
			"mods_purchased": mods_purchased,
			"powerups_used": powerups_used,
			"consumables_used": consumables_used
		},
		"session_metrics": {
			"session_start_time": session_start_time,
			"total_play_time": get_total_play_time(),
			"highest_score": highest_score,
			"longest_streak": longest_streak,
			"current_streak": current_streak
		},
		"calculated_stats": {
			"scoring_percentage": get_scoring_percentage(),
			"money_efficiency": get_money_efficiency(),
			"favorite_dice_color": get_favorite_dice_color(),
			"average_score_per_hand": get_average_score_per_hand()
		}
	}

## reset_statistics()
## 
## Reset all statistics to their initial values (useful for testing).
func reset_statistics():
	total_turns = 0
	total_rolls = 0
	total_rerolls = 0
	hands_completed = 0
	failed_hands = 0
	
	total_money_earned = 0
	total_money_spent = 0
	money_spent_on_powerups = 0
	money_spent_on_consumables = 0
	money_spent_on_mods = 0
	current_money = 0
	
	dice_locked_count = 0
	highest_single_roll = 0
	snake_eyes_count = 0
	yahtzee_count = 0
	
	ones_scored = 0
	twos_scored = 0
	threes_scored = 0
	fours_scored = 0
	fives_scored = 0
	sixes_scored = 0
	three_of_kind_scored = 0
	four_of_kind_scored = 0
	full_house_scored = 0
	small_straight_scored = 0
	large_straight_scored = 0
	yahtzee_scored = 0
	chance_scored = 0
	
	powerups_purchased = 0
	consumables_purchased = 0
	mods_purchased = 0
	powerups_used = 0
	consumables_used = 0
	
	session_start_time = Time.get_unix_time_from_system()
	total_play_time = 0.0
	highest_score = 0
	longest_streak = 0
	current_streak = 0
	
	_initialize_dice_color_tracking()
	print("Statistics reset")

## _check_milestone(stat_name: String, value: int)
## 
## Check if a statistic has reached a milestone and emit signal if so.
func _check_milestone(stat_name: String, value: int):
	var milestones = [10, 25, 50, 100, 250, 500, 1000]
	
	if value in milestones:
		milestone_reached.emit(stat_name, value)
