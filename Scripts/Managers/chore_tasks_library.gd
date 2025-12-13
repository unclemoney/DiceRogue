extends RefCounted
class_name ChoreTasksLibrary

## ChoreTasksLibrary
##
## Static utility class that provides a library of predefined chore tasks.
## Tasks are randomly selected by the ChoresManager each turn.
## Completing a task reduces the Chore Progress bar by 20.

# Preload ChoreData to ensure it's available in static context
const ChoreDataScript = preload("res://Scripts/Managers/ChoreData.gd")

# Task type constants (mirrors ChoreData.TaskType enum)
const TASK_SCORE_UPPER = 0
const TASK_SCORE_LOWER = 1
const TASK_SCORE_SPECIFIC = 2
const TASK_ROLL_YAHTZEE = 3
const TASK_USE_CONSUMABLE = 4
const TASK_LOCK_DICE = 5
const TASK_NO_SCORE_TURN = 6

## get_all_tasks()
##
## Returns an array of all predefined ChoreData tasks.
## These tasks range from simple (score Ones) to complex (Yahtzee with Fives).
##
## Returns: Array
static func get_all_tasks() -> Array:
	var tasks: Array = []
	
	# Upper Section - Basic scoring tasks
	tasks.append(_create_task("score_ones", "Score Ones", "Score in the Ones category", 
		TASK_SCORE_UPPER, "ones"))
	tasks.append(_create_task("score_twos", "Score Twos", "Score in the Twos category", 
		TASK_SCORE_UPPER, "twos"))
	tasks.append(_create_task("score_threes", "Score Threes", "Score in the Threes category", 
		TASK_SCORE_UPPER, "threes"))
	tasks.append(_create_task("score_fours", "Score Fours", "Score in the Fours category", 
		TASK_SCORE_UPPER, "fours"))
	tasks.append(_create_task("score_fives", "Score Fives", "Score in the Fives category", 
		TASK_SCORE_UPPER, "fives"))
	tasks.append(_create_task("score_sixes", "Score Sixes", "Score in the Sixes category", 
		TASK_SCORE_UPPER, "sixes"))
	
	# Upper Section - Generic
	tasks.append(_create_task("score_any_upper", "Upper Score", "Score in any upper section category", 
		TASK_SCORE_UPPER, ""))
	
	# Lower Section - Basic scoring tasks
	tasks.append(_create_task("score_three_kind", "Three of a Kind", "Score a Three of a Kind", 
		TASK_SCORE_LOWER, "three_of_a_kind"))
	tasks.append(_create_task("score_four_kind", "Four of a Kind", "Score a Four of a Kind", 
		TASK_SCORE_LOWER, "four_of_a_kind"))
	tasks.append(_create_task("score_full_house", "Full House", "Score a Full House", 
		TASK_SCORE_LOWER, "full_house"))
	tasks.append(_create_task("score_small_straight", "Small Straight", "Score a Small Straight", 
		TASK_SCORE_LOWER, "small_straight"))
	tasks.append(_create_task("score_large_straight", "Large Straight", "Score a Large Straight", 
		TASK_SCORE_LOWER, "large_straight"))
	tasks.append(_create_task("score_chance", "Score Chance", "Score in the Chance category", 
		TASK_SCORE_LOWER, "chance"))
	
	# Lower Section - Generic
	tasks.append(_create_task("score_any_lower", "Lower Score", "Score in any lower section category", 
		TASK_SCORE_LOWER, ""))
	
	# Yahtzee tasks
	tasks.append(_create_task("roll_yahtzee", "Roll Yahtzee!", "Roll a Yahtzee (5 of a kind)", 
		TASK_ROLL_YAHTZEE, "yahtzee"))
	
	# Specific combination tasks - Full House with specific triples
	tasks.append(_create_task("full_house_ones", "Full House (Ones)", "Score Full House with three 1s", 
		TASK_SCORE_SPECIFIC, "full_house", 1, 3))
	tasks.append(_create_task("full_house_twos", "Full House (Twos)", "Score Full House with three 2s", 
		TASK_SCORE_SPECIFIC, "full_house", 2, 3))
	tasks.append(_create_task("full_house_threes", "Full House (Threes)", "Score Full House with three 3s", 
		TASK_SCORE_SPECIFIC, "full_house", 3, 3))
	tasks.append(_create_task("full_house_fours", "Full House (Fours)", "Score Full House with three 4s", 
		TASK_SCORE_SPECIFIC, "full_house", 4, 3))
	tasks.append(_create_task("full_house_fives", "Full House (Fives)", "Score Full House with three 5s", 
		TASK_SCORE_SPECIFIC, "full_house", 5, 3))
	tasks.append(_create_task("full_house_sixes", "Full House (Sixes)", "Score Full House with three 6s", 
		TASK_SCORE_SPECIFIC, "full_house", 6, 3))
	
	# Specific Yahtzee tasks
	tasks.append(_create_task("yahtzee_ones", "Yahtzee of Ones", "Roll a Yahtzee with all 1s", 
		TASK_SCORE_SPECIFIC, "yahtzee", 1, 5))
	tasks.append(_create_task("yahtzee_twos", "Yahtzee of Twos", "Roll a Yahtzee with all 2s", 
		TASK_SCORE_SPECIFIC, "yahtzee", 2, 5))
	tasks.append(_create_task("yahtzee_threes", "Yahtzee of Threes", "Roll a Yahtzee with all 3s", 
		TASK_SCORE_SPECIFIC, "yahtzee", 3, 5))
	tasks.append(_create_task("yahtzee_fours", "Yahtzee of Fours", "Roll a Yahtzee with all 4s", 
		TASK_SCORE_SPECIFIC, "yahtzee", 4, 5))
	tasks.append(_create_task("yahtzee_fives", "Yahtzee of Fives", "Roll a Yahtzee with all 5s", 
		TASK_SCORE_SPECIFIC, "yahtzee", 5, 5))
	tasks.append(_create_task("yahtzee_sixes", "Yahtzee of Sixes", "Roll a Yahtzee with all 6s", 
		TASK_SCORE_SPECIFIC, "yahtzee", 6, 5))
	
	# Three of a Kind with specific values
	tasks.append(_create_task("three_kind_sixes", "Triple Sixes", "Score Three of a Kind with 6s", 
		TASK_SCORE_SPECIFIC, "three_of_a_kind", 6, 3))
	tasks.append(_create_task("three_kind_fives", "Triple Fives", "Score Three of a Kind with 5s", 
		TASK_SCORE_SPECIFIC, "three_of_a_kind", 5, 3))
	tasks.append(_create_task("three_kind_ones", "Triple Ones", "Score Three of a Kind with 1s", 
		TASK_SCORE_SPECIFIC, "three_of_a_kind", 1, 3))
	
	# Four of a Kind with specific values
	tasks.append(_create_task("four_kind_sixes", "Quad Sixes", "Score Four of a Kind with 6s", 
		TASK_SCORE_SPECIFIC, "four_of_a_kind", 6, 4))
	tasks.append(_create_task("four_kind_fives", "Quad Fives", "Score Four of a Kind with 5s", 
		TASK_SCORE_SPECIFIC, "four_of_a_kind", 5, 4))
	tasks.append(_create_task("four_kind_ones", "Quad Ones", "Score Four of a Kind with 1s", 
		TASK_SCORE_SPECIFIC, "four_of_a_kind", 1, 4))
	
	# Utility tasks
	tasks.append(_create_task("use_consumable", "Use Item", "Use any consumable item", 
		TASK_USE_CONSUMABLE, ""))
	tasks.append(_create_task("scratch_score", "Take Zero", "Scratch a category (score 0)", 
		TASK_NO_SCORE_TURN, ""))
	
	# Dice locking tasks
	tasks.append(_create_task("lock_three_dice", "Lock Three", "Lock at least 3 dice", 
		TASK_LOCK_DICE, "", 0, 3))
	tasks.append(_create_task("lock_four_dice", "Lock Four", "Lock at least 4 dice", 
		TASK_LOCK_DICE, "", 0, 4))
	tasks.append(_create_task("lock_all_dice", "Full Lock", "Lock all 5 dice", 
		TASK_LOCK_DICE, "", 0, 5))
	
	return tasks

## get_random_task()
##
## Returns a random task from the library.
##
## Returns: ChoreData
static func get_random_task():
	var tasks = get_all_tasks()
	return tasks[randi() % tasks.size()]

## get_task_by_id()
##
## Returns a specific task by its ID.
##
## Parameters:
##   id: String - the task ID to find
##
## Returns: ChoreData or null if not found
static func get_task_by_id(id: String):
	var tasks = get_all_tasks()
	for task in tasks:
		if task.id == id:
			return task
	return null

## get_tasks_by_type()
##
## Returns all tasks of a specific type.
##
## Parameters:
##   task_type: int - the type of tasks to filter (use TASK_* constants)
##
## Returns: Array
static func get_tasks_by_type(task_type: int) -> Array:
	var tasks = get_all_tasks()
	var filtered: Array = []
	for task in tasks:
		if task.task_type == task_type:
			filtered.append(task)
	return filtered

## get_easy_tasks()
##
## Returns tasks that are relatively easy to complete (upper section, generic lower).
##
## Returns: Array
static func get_easy_tasks() -> Array:
	var easy_ids = [
		"score_ones", "score_twos", "score_threes", "score_fours", "score_fives", "score_sixes",
		"score_any_upper", "score_any_lower", "score_chance", "score_three_kind"
	]
	var tasks = get_all_tasks()
	var filtered: Array = []
	for task in tasks:
		if task.id in easy_ids:
			filtered.append(task)
	return filtered

## get_hard_tasks()
##
## Returns tasks that are difficult to complete (specific combos, yahtzees).
##
## Returns: Array
static func get_hard_tasks() -> Array:
	var hard_ids = [
		"roll_yahtzee", "yahtzee_ones", "yahtzee_twos", "yahtzee_threes",
		"yahtzee_fours", "yahtzee_fives", "yahtzee_sixes",
		"score_large_straight", "four_kind_sixes", "four_kind_fives"
	]
	var tasks = get_all_tasks()
	var filtered: Array = []
	for task in tasks:
		if task.id in hard_ids:
			filtered.append(task)
	return filtered

## _create_task()
##
## Helper function to create a ChoreData resource with specified parameters.
static func _create_task(id: String, display_name: String, description: String, 
		task_type: int, target_category: String = "", 
		target_value: int = 0, target_count: int = 0):
	var task = ChoreDataScript.new()
	task.id = id
	task.display_name = display_name
	task.description = description
	task.task_type = task_type
	task.target_category = target_category
	task.target_value = target_value
	task.target_count = target_count
	task.progress_reduction = 20
	return task
