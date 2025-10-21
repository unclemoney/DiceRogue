extends Node

## StatisticsManager
## 
## Singleton that tracks all game statistics and metrics.
## Accessible globally as "Statistics" autoload.

const LogEntry = preload("res://Scripts/Core/LogEntry.gd")

signal milestone_reached(milestone_name: String, value: int)
signal new_record_set(statistic_name: String, new_value)
signal logbook_entry_added(entry: LogEntry)

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
# Note: current_money is now retrieved from PlayerEconomy, not stored here

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

# Logbook System
var logbook: Array[LogEntry] = []
var max_logbook_entries: int = 1000
var show_detailed_logs: bool = true
var auto_clear_extrainfo: bool = true
var extrainfo_display_count: int = 3
var save_logs_to_file: bool = false

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
## Add to the total money earned (tracking only, money is managed by PlayerEconomy).
func add_money_earned(amount: int):
	total_money_earned += amount

## spend_money(amount: int, category: String = "")
## 
## Record money spent, optionally by category (tracking only, money is managed by PlayerEconomy).
func spend_money(amount: int, category: String = ""):
	total_money_spent += amount
	
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

## get_current_money() -> int
## 
## Get current player money from PlayerEconomy.
func get_current_money() -> int:
	var economy = get_node_or_null("/root/PlayerEconomy")
	if economy:
		return economy.money
	return 0

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
			"current_money": get_current_money()
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
	# Note: current_money is retrieved from PlayerEconomy, not reset here
	
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
	logbook.clear()
	print("Statistics reset")

## log_hand_scored()
## 
## Create a detailed log entry for a scored hand with all relevant information.
func log_hand_scored(
	dice_values: Array[int],
	dice_colors: Array[String] = [],
	dice_mods: Array[String] = [],
	category: String = "",
	section: String = "",
	consumables: Array[String] = [],
	powerups: Array[String] = [],
	base_score: int = 0,
	effects: Array[Dictionary] = [],
	final_score: int = 0,
	breakdown_info: Dictionary = {}
) -> void:
	# Debug logging for logbook entry creation
	print("[Statistics] Creating logbook entry:")
	print("  PowerUps:", powerups)
	print("  Consumables:", consumables)
	print("  Category:", category, " | Score:", base_score, "→", final_score)
	
	var entry = LogEntry.new(
		dice_values,
		dice_colors,
		dice_mods,
		category,
		section,
		consumables,
		powerups,
		base_score,
		effects,
		final_score,
		total_turns,
		breakdown_info
	)
	
	print("[Statistics] Entry created - PowerUps Applied:", entry.powerups_applied.size(), entry.powerups_applied)
	print("[Statistics] Entry created - Has Modifiers:", entry.has_modifiers())
	
	logbook.append(entry)
	logbook_entry_added.emit(entry)
	
	# Manage logbook size
	if logbook.size() > max_logbook_entries:
		logbook.pop_front()
	
	if save_logs_to_file:
		_save_log_entry_to_file(entry)

## get_recent_log_entries()
## 
## Get the most recent log entries for UI display.
func get_recent_log_entries(count: int = -1) -> Array[LogEntry]:
	if count == -1:
		count = extrainfo_display_count
	
	var recent_count = min(count, logbook.size())
	var result: Array[LogEntry] = []
	
	for i in range(recent_count):
		var index = logbook.size() - 1 - i
		result.append(logbook[index])
	
	return result

## get_logbook_entries()
## 
## Get logbook entries with optional filtering.
func get_logbook_entries(filter_dict: Dictionary = {}) -> Array[LogEntry]:
	if filter_dict.is_empty():
		return logbook.duplicate()
	
	var filtered: Array[LogEntry] = []
	for entry in logbook:
		if entry.matches_filter(filter_dict):
			filtered.append(entry)
	
	return filtered

## get_logbook_summary()
## 
## Get a summary of logbook statistics for the statistics panel.
func get_logbook_summary() -> Dictionary:
	var summary = {
		"total_entries": logbook.size(),
		"entries_with_modifiers": 0,
		"average_score": 0.0,
		"highest_score_entry": null,
		"most_common_category": "",
		"category_counts": {},
		"modifier_usage": {
			"powerups": 0,
			"consumables": 0,
			"mods": 0
		}
	}
	
	if logbook.is_empty():
		return summary
	
	var total_score = 0
	var session_highest_score = 0
	var highest_entry = null
	
	for entry in logbook:
		total_score += entry.final_score
		
		if entry.final_score > session_highest_score:
			session_highest_score = entry.final_score
			highest_entry = entry
		
		if entry.has_modifiers():
			summary.entries_with_modifiers += 1
		
		# Count category usage
		var category = entry.scorecard_category
		if not summary.category_counts.has(category):
			summary.category_counts[category] = 0
		summary.category_counts[category] += 1
		
		# Count modifier types
		if entry.powerups_applied.size() > 0:
			summary.modifier_usage.powerups += 1
		if entry.consumables_applied.size() > 0:
			summary.modifier_usage.consumables += 1
		if entry.dice_mods.size() > 0:
			summary.modifier_usage.mods += 1
	
	summary.average_score = total_score / float(logbook.size())
	summary.highest_score_entry = highest_entry
	
	# Find most common category
	var max_count = 0
	for category in summary.category_counts:
		if summary.category_counts[category] > max_count:
			max_count = summary.category_counts[category]
			summary.most_common_category = category
	
	return summary

## get_formatted_recent_logs()
## 
## Get formatted strings of recent log entries for ExtraInfo display.
func get_formatted_recent_logs(count: int = -1) -> String:
	var entries = get_recent_log_entries(count)
	var lines: Array[String] = []
	
	for entry in entries:
		lines.append(entry.formatted_log_line)
	
	return "\n".join(lines)

## clear_logbook()
## 
## Clear all logbook entries (useful for testing or reset).
func clear_logbook() -> void:
	logbook.clear()
	print("Logbook cleared")

## export_logbook_to_file()
## 
## Export the entire logbook to a JSON file in user://logs/
func export_logbook_to_file(filename: String = "") -> String:
	if filename.is_empty():
		var datetime = Time.get_datetime_dict_from_system()
		filename = "logbook_%04d%02d%02d_%02d%02d%02d.json" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute, datetime.second
		]
	
	var export_data = {
		"metadata": {
			"export_timestamp": Time.get_unix_time_from_system(),
			"game_version": "1.0", # TODO: Get from project settings
			"total_entries": logbook.size(),
			"session_stats": get_all_statistics()
		},
		"entries": []
	}
	
	for entry in logbook:
		export_data.entries.append(entry.to_dictionary())
	
	var dir_path = "user://logs/"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.open("user://").make_dir("logs")
	
	var file_path = dir_path + filename
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(export_data, "\t"))
		file.close()
		print("Logbook exported to: ", file_path)
		return file_path
	else:
		print("Failed to export logbook to: ", file_path)
		return ""

## _save_log_entry_to_file()
## 
## Internal method to save individual log entries if file saving is enabled.
func _save_log_entry_to_file(entry: LogEntry) -> void:
	if not save_logs_to_file:
		return
	
	var dir_path = "user://logs/"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.open("user://").make_dir("logs")
	
	var datetime = Time.get_datetime_dict_from_system()
	var filename = "session_%04d%02d%02d.log" % [datetime.year, datetime.month, datetime.day]
	var file_path = dir_path + filename
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line("[%s] %s" % [entry.get_timestamp_string(), entry.formatted_log_line])
		file.close()

## print_debug_logbook()
## 
## Debug function to print current logbook state to console.
func print_debug_logbook():
	print("\n=== LOGBOOK DEBUG ===")
	print("Total entries:", logbook.size())
	
	if logbook.is_empty():
		print("No logbook entries found")
		return
	
	for i in range(logbook.size()):
		var entry = logbook[i]
		print("\nEntry", i + 1, ":")
		print("  Category:", entry.scorecard_category)
		print("  Base Score:", entry.base_score, "→ Final Score:", entry.final_score)
		print("  PowerUps Applied:", entry.powerups_applied)
		print("  Consumables Applied:", entry.consumables_applied)
		print("  Has Modifiers:", entry.has_modifiers())
		print("  Formatted Line:", entry.formatted_log_line)
	
	print("=== END LOGBOOK DEBUG ===\n")

## _check_milestone(stat_name: String, value: int)
## 
## Check if a statistic has reached a milestone and emit signal if so.
func _check_milestone(stat_name: String, value: int):
	var milestones = [10, 25, 50, 100, 250, 500, 1000]
	
	if value in milestones:
		milestone_reached.emit(stat_name, value)
