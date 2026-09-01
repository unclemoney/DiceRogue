extends RefCounted
class_name ChoreTasksLibrary

## ChoreTasksLibrary
##
## Static utility class that provides a library of predefined chore tasks.
## Tasks are randomly selected by the ChoresManager each turn.
## Completing a task reduces the Chore Progress bar by the task's per-chore
## reduction (EASY: 5-15, HARD: 20-60), scaled by actual task difficulty.

# Preload ChoreData to ensure it's available in static context
const ChoreDataScript = preload("res://Scripts/Managers/ChoreData.gd")
# Scorecard is the source of truth for dice-set-aware category names
# (d4: Evens/Odds/Even Odd Full House; d8+: sixth-slot names like Twenties).
const ScorecardScript = preload("res://Scenes/ScoreCard/score_card.gd")

# Task type constants (mirrors ChoreData.TaskType enum)
const TASK_SCORE_UPPER = 0
const TASK_SCORE_LOWER = 1
const TASK_SCORE_SPECIFIC = 2
const TASK_ROLL_YAHTZEE = 3
const TASK_USE_CONSUMABLE = 4
const TASK_LOCK_DICE = 5
const TASK_NO_SCORE_TURN = 6
const TASK_LOCK_CONSTRAINT = 7

## get_all_tasks()
##
## Returns an array of all predefined ChoreData tasks, adapted to the
## active dice set. Tasks range from simple EASY tasks (score upper section)
## to complex HARD tasks (specific Yahtzees). Each task has an assigned
## Difficulty (EASY or HARD) and a per-chore meter reduction within its
## difficulty range (EASY: 5-15, HARD: 20-60).
##
## Dice-set adaptation (see _adapt_tasks_to_dice_set):
## - d4: value-5/6 tasks are impossible and dropped; "Score Fives/Sixes"
##   become "Score Evens/Odds"; the Large Straight chore is renamed to
##   Even Odd Full House.
## - d8+: value-6 tasks are remapped to the max face value ("Yahtzee of
##   Sixes" -> "Yahtzee of Twenties" on d20); "Score Sixes" uses the
##   sixth-slot name.
## Task IDs are stable across sets so save/load keeps working.
##
## Parameters:
##   dice_sides: int - faces on the active dice set (4, 6, 8, 10, 12, 20)
##
## Returns: Array
static func get_all_tasks(dice_sides: int = 6) -> Array:
	var tasks: Array = []
	
	# Upper Section - Basic scoring tasks (EASY)
	tasks.append(_create_task("score_ones", "Score Ones", "Score in the Ones category",
		TASK_SCORE_UPPER, "ones", 0, 0, 0, 5, 5))
	tasks.append(_create_task("score_twos", "Score Twos", "Score in the Twos category",
		TASK_SCORE_UPPER, "twos", 0, 0, 0, 5, 5))
	tasks.append(_create_task("score_threes", "Score Threes", "Score in the Threes category",
		TASK_SCORE_UPPER, "threes", 0, 0, 0, 5, 5))
	tasks.append(_create_task("score_fours", "Score Fours", "Score in the Fours category",
		TASK_SCORE_UPPER, "fours", 0, 0, 0, 5, 5))
	tasks.append(_create_task("score_fives", "Score Fives", "Score in the Fives category",
		TASK_SCORE_UPPER, "fives", 0, 0, 0, 5, 5))
	tasks.append(_create_task("score_sixes", "Score Sixes", "Score in the Sixes category",
		TASK_SCORE_UPPER, "sixes", 0, 0, 0, 5, 5))
	
	# Upper Section - Generic (EASY)
	tasks.append(_create_task("score_any_upper", "Upper Score", "Score in any upper section category",
		TASK_SCORE_UPPER, "", 0, 0, 0, 5, 5))
	
	# Lower Section - Basic scoring tasks (EASY for generic/simple, HARD for specific)
	tasks.append(_create_task("score_three_kind", "Three of a Kind", "Score a Three of a Kind",
		TASK_SCORE_LOWER, "three_of_a_kind", 0, 0, 0, 10, 15))
	tasks.append(_create_task("score_four_kind", "Four of a Kind", "Score a Four of a Kind",
		TASK_SCORE_LOWER, "four_of_a_kind", 0, 0, 1, 25, 25))
	tasks.append(_create_task("score_full_house", "Full House", "Score a Full House",
		TASK_SCORE_LOWER, "full_house", 0, 0, 1, 20, 15))
	tasks.append(_create_task("score_small_straight", "Small Straight", "Score a Small Straight",
		TASK_SCORE_LOWER, "small_straight", 0, 0, 1, 25, 25))
	tasks.append(_create_task("score_large_straight", "Large Straight", "Score a Large Straight",
		TASK_SCORE_LOWER, "large_straight", 0, 0, 1, 25, 25))
	tasks.append(_create_task("score_chance", "Score Chance", "Score in the Chance category",
		TASK_SCORE_LOWER, "chance", 0, 0, 0, 5, 5))
	
	# Lower Section - Generic (EASY)
	tasks.append(_create_task("score_any_lower", "Lower Score", "Score in any lower section category",
		TASK_SCORE_LOWER, "", 0, 0, 0, 5, 5))
	
	# Yahtzee tasks (HARD)
	tasks.append(_create_task("roll_yahtzee", "Roll Yahtzee!", "Roll a Yahtzee (5 of a kind)",
		TASK_ROLL_YAHTZEE, "yahtzee", 0, 0, 1, 50, 165))
	
	# Specific combination tasks - Full House with specific triples (HARD)
	tasks.append(_create_task("full_house_ones", "Full House (Ones)", "Score Full House with three 1s",
		TASK_SCORE_SPECIFIC, "full_house", 1, 3, 1, 30, 55))
	tasks.append(_create_task("full_house_twos", "Full House (Twos)", "Score Full House with three 2s",
		TASK_SCORE_SPECIFIC, "full_house", 2, 3, 1, 30, 55))
	tasks.append(_create_task("full_house_threes", "Full House (Threes)", "Score Full House with three 3s",
		TASK_SCORE_SPECIFIC, "full_house", 3, 3, 1, 30, 55))
	tasks.append(_create_task("full_house_fours", "Full House (Fours)", "Score Full House with three 4s",
		TASK_SCORE_SPECIFIC, "full_house", 4, 3, 1, 30, 55))
	tasks.append(_create_task("full_house_fives", "Full House (Fives)", "Score Full House with three 5s",
		TASK_SCORE_SPECIFIC, "full_house", 5, 3, 1, 30, 55))
	tasks.append(_create_task("full_house_sixes", "Full House (Sixes)", "Score Full House with three 6s",
		TASK_SCORE_SPECIFIC, "full_house", 6, 3, 1, 30, 55))
	
	# Specific Yahtzee tasks (HARD)
	tasks.append(_create_task("yahtzee_ones", "Yahtzee of Ones", "Roll a Yahtzee with all 1s",
		TASK_SCORE_SPECIFIC, "yahtzee", 1, 5, 1, 60, 300))
	tasks.append(_create_task("yahtzee_twos", "Yahtzee of Twos", "Roll a Yahtzee with all 2s",
		TASK_SCORE_SPECIFIC, "yahtzee", 2, 5, 1, 60, 300))
	tasks.append(_create_task("yahtzee_threes", "Yahtzee of Threes", "Roll a Yahtzee with all 3s",
		TASK_SCORE_SPECIFIC, "yahtzee", 3, 5, 1, 60, 300))
	tasks.append(_create_task("yahtzee_fours", "Yahtzee of Fours", "Roll a Yahtzee with all 4s",
		TASK_SCORE_SPECIFIC, "yahtzee", 4, 5, 1, 60, 300))
	tasks.append(_create_task("yahtzee_fives", "Yahtzee of Fives", "Roll a Yahtzee with all 5s",
		TASK_SCORE_SPECIFIC, "yahtzee", 5, 5, 1, 60, 300))
	tasks.append(_create_task("yahtzee_sixes", "Yahtzee of Sixes", "Roll a Yahtzee with all 6s",
		TASK_SCORE_SPECIFIC, "yahtzee", 6, 5, 1, 60, 300))
	
	# Three of a Kind with specific values (HARD)
	tasks.append(_create_task("three_kind_sixes", "Triple Sixes", "Score Three of a Kind with 6s",
		TASK_SCORE_SPECIFIC, "three_of_a_kind", 6, 3, 1, 30, 60))
	tasks.append(_create_task("three_kind_fives", "Triple Fives", "Score Three of a Kind with 5s",
		TASK_SCORE_SPECIFIC, "three_of_a_kind", 5, 3, 1, 30, 60))
	tasks.append(_create_task("three_kind_ones", "Triple Ones", "Score Three of a Kind with 1s",
		TASK_SCORE_SPECIFIC, "three_of_a_kind", 1, 3, 1, 30, 60))
	
	# Four of a Kind with specific values (HARD)
	tasks.append(_create_task("four_kind_sixes", "Quad Sixes", "Score Four of a Kind with 6s",
		TASK_SCORE_SPECIFIC, "four_of_a_kind", 6, 4, 1, 35, 95))
	tasks.append(_create_task("four_kind_fives", "Quad Fives", "Score Four of a Kind with 5s",
		TASK_SCORE_SPECIFIC, "four_of_a_kind", 5, 4, 1, 35, 95))
	tasks.append(_create_task("four_kind_ones", "Quad Ones", "Score Four of a Kind with 1s",
		TASK_SCORE_SPECIFIC, "four_of_a_kind", 1, 4, 1, 35, 95))
	
	# Utility tasks (EASY)
	tasks.append(_create_task("use_consumable", "Use Item", "Use any consumable item",
		TASK_USE_CONSUMABLE, "", 0, 0, 0, 5, 5))
	# This task is a bit awkward since it requires player to intentionally scratch a category, which isn't a common strategy. It could be reworked to be more intuitive, but for now we'll include it as a niche challenge.
	#tasks.append(_create_task("scratch_score", "Take Zero", "Scratch a category (score 0)",
	#	TASK_NO_SCORE_TURN, "", 0, 0, 0, 5, 5))
	
	# Lock constraint tasks (score target over turn window with dice-lock limits)
	# Uses TASK_LOCK_CONSTRAINT (7) with additional_params for turn_window and max_locked_dice
	var soft_touch = _create_task("soft_touch", "Soft Touch", "Score 50 points over 3 turns while locking no more than 1 die",
		TASK_LOCK_CONSTRAINT, "", 50, 1, 0, 5, 5)
	soft_touch.additional_params = {"turn_window": 3, "max_locked_dice": 1}
	tasks.append(soft_touch)
	
	var steady_hand = _create_task("steady_hand", "Steady Hand", "Score 75 points over 3 turns without locking any dice",
		TASK_LOCK_CONSTRAINT, "", 75, 0, 0, 15, 25)
	steady_hand.additional_params = {"turn_window": 3, "max_locked_dice": 0}
	tasks.append(steady_hand)
	
	var controlled_risk = _create_task("controlled_risk", "Controlled Risk", "Score 100 points over 4 turns while locking no more than 2 dice",
		TASK_LOCK_CONSTRAINT, "", 100, 2, 0, 15, 55)
	controlled_risk.additional_params = {"turn_window": 4, "max_locked_dice": 2}
	tasks.append(controlled_risk)
	
	var iron_discipline = _create_task("iron_discipline", "Iron Discipline", "Score 150 points over 5 turns while locking no more than 1 die",
		TASK_LOCK_CONSTRAINT, "", 150, 1, 1, 40, 105)
	iron_discipline.additional_params = {"turn_window": 5, "max_locked_dice": 1}
	tasks.append(iron_discipline)
	
	var free_agent = _create_task("free_agent", "Free Agent", "Score 200 points over 6 turns without locking any dice",
		TASK_LOCK_CONSTRAINT, "", 200, 0, 1, 50, 165)
	free_agent.additional_params = {"turn_window": 6, "max_locked_dice": 0}
	tasks.append(free_agent)
	
	return _adapt_tasks_to_dice_set(tasks, dice_sides)


## _adapt_tasks_to_dice_set(tasks, dice_sides) -> Array
##
## Drops or remaps tasks that don't fit the active dice set. Keeps task IDs
## stable so save/load by ID keeps working. d6 returns tasks unchanged.
static func _adapt_tasks_to_dice_set(tasks: Array, dice_sides: int) -> Array:
	if dice_sides == 6:
		return tasks
	# Scorecard instance resolves dice-set-aware display names (pure data
	# lookups; never added to the scene tree).
	var names_scorecard = ScorecardScript.new()
	names_scorecard.set_dice_type(dice_sides)
	var adapted: Array = []
	for task in tasks:
		var adapted_task = _adapt_task_to_dice_set(task, dice_sides, names_scorecard)
		if adapted_task:
			adapted.append(adapted_task)
	names_scorecard.free()
	return adapted


## _adapt_task_to_dice_set(task, dice_sides, names_scorecard)
##
## Adapts a single task. Returns the task (possibly renamed/remapped), or
## null when the task is impossible on the active dice set.
static func _adapt_task_to_dice_set(task, dice_sides: int, names_scorecard):
	# Value-specific chores (Yahtzee of Xs, Full House (X), Triple/Quad X)
	if task.task_type == TASK_SCORE_SPECIFIC and task.target_value > 0:
		if task.target_value > dice_sides:
			# Impossible on this set (e.g. any 5s/6s chore on d4)
			return null
		if dice_sides > 6 and task.target_value == 6:
			# The top-face chore should target the set's max value
			task.target_value = dice_sides
			_rename_value_task(task, dice_sides, names_scorecard)
		return task

	# Category chores that changed meaning on this set
	if task.id == "score_fives" and dice_sides == 4:
		task.display_name = "Score Evens"
		task.description = "Score in the Evens category"
	elif task.id == "score_sixes":
		if dice_sides == 4:
			task.display_name = "Score Odds"
			task.description = "Score in the Odds category"
		elif dice_sides > 6:
			var slot_name: String = names_scorecard.get_sixth_slot_display_name()
			task.display_name = "Score %s" % slot_name
			task.description = "Score in the %s category" % slot_name
	elif task.id == "score_large_straight" and dice_sides == 4:
		var eo_name: String = names_scorecard.get_category_display_name("large_straight")
		task.display_name = eo_name
		task.description = "Score an %s" % eo_name
	return task


## _rename_value_task(task, dice_sides, names_scorecard)
##
## Renames a value-specific chore after its target_value was remapped to the
## set's max face value (d8+), e.g. "Yahtzee of Sixes" -> "Yahtzee of
## Twenties" on d20. Called after target_value is updated.
static func _rename_value_task(task, dice_sides: int, names_scorecard) -> void:
	var value_name := _value_display_name(task.target_value, names_scorecard)
	if task.id.begins_with("yahtzee_"):
		task.display_name = "Yahtzee of %s" % value_name
		task.description = "Roll a Yahtzee with all %ds" % task.target_value
	elif task.id.begins_with("full_house_"):
		task.display_name = "Full House (%s)" % value_name
		task.description = "Score Full House with three %ds" % task.target_value
	elif task.id.begins_with("three_kind_"):
		task.display_name = "Triple %s" % value_name
		task.description = "Score Three of a Kind with %ds" % task.target_value
	elif task.id.begins_with("four_kind_"):
		task.display_name = "Quad %s" % value_name
		task.description = "Score Four of a Kind with %ds" % task.target_value


## _value_display_name(value, names_scorecard) -> String
##
## Human-readable plural for a die face value on the active set. Values 1-5
## are fixed; higher values use the scorecard's sixth-slot name (d20 -> 20
## becomes "Twenties").
static func _value_display_name(value: int, names_scorecard) -> String:
	match value:
		1: return "Ones"
		2: return "Twos"
		3: return "Threes"
		4: return "Fours"
		5: return "Fives"
		_: return names_scorecard.get_sixth_slot_display_name()

## get_random_task()
##
## Returns a random task from the library, adapted to the active dice set.
##
## Parameters:
##   dice_sides: int - faces on the active dice set
##
## Returns: ChoreData
static func get_random_task(dice_sides: int = 6):
	var tasks = get_all_tasks(dice_sides)
	return tasks[GameRNG.random_index(tasks)]

## get_task_by_id()
##
## Returns a specific task by its ID, adapted to the active dice set.
## Returns null for IDs dropped by the set (e.g. yahtzee_sixes on d4) —
## callers should treat that as an expired/invalid chore and re-select.
##
## Parameters:
##   id: String - the task ID to find
##   dice_sides: int - faces on the active dice set
##
## Returns: ChoreData or null if not found
static func get_task_by_id(id: String, dice_sides: int = 6):
	var tasks = get_all_tasks(dice_sides)
	for task in tasks:
		if task.id == id:
			return task
	return null

## get_tasks_by_type()
##
## Returns all tasks of a specific type, adapted to the active dice set.
##
## Parameters:
##   task_type: int - the type of tasks to filter (use TASK_* constants)
##   dice_sides: int - faces on the active dice set
##
## Returns: Array
static func get_tasks_by_type(task_type: int, dice_sides: int = 6) -> Array:
	var tasks = get_all_tasks(dice_sides)
	var filtered: Array = []
	for task in tasks:
		if task.task_type == task_type:
			filtered.append(task)
	return filtered

## get_easy_tasks()
##
## Returns tasks with EASY difficulty (upper section, generic lower, utility),
## adapted to the active dice set.
## Filters by the ChoreData.Difficulty.EASY enum value.
##
## Parameters:
##   dice_sides: int - faces on the active dice set
##
## Returns: Array
static func get_easy_tasks(dice_sides: int = 6) -> Array:
	var tasks = get_all_tasks(dice_sides)
	var filtered: Array = []
	for task in tasks:
		if task.difficulty == ChoreData.Difficulty.EASY:
			filtered.append(task)
	return filtered

## get_hard_tasks()
##
## Returns tasks with HARD difficulty (specific combos, yahtzees, lock
## constraints), adapted to the active dice set.
## Filters by the ChoreData.Difficulty.HARD enum value.
##
## Parameters:
##   dice_sides: int - faces on the active dice set
##
## Returns: Array
static func get_hard_tasks(dice_sides: int = 6) -> Array:
	var tasks = get_all_tasks(dice_sides)
	var filtered: Array = []
	for task in tasks:
		if task.difficulty == ChoreData.Difficulty.HARD:
			filtered.append(task)
	return filtered

## _create_task()
##
## Helper function to create a ChoreData resource with specified parameters.
## @param difficulty_int: 0 = EASY (meter -5 to -15), 1 = HARD (meter -20 to -60)
## @param reduction: per-chore goof-off meter reduction, within the difficulty range
static func _create_task(id: String, display_name: String, description: String,
		task_type: int, target_category: String = "",
		target_value: int = 0, target_count: int = 0,
		difficulty_int: int = 0, reduction: int = 10, reward_value: int = 50):
	var task = ChoreDataScript.new()
	task.id = id
	task.display_name = display_name
	task.description = description
	task.task_type = task_type
	task.target_category = target_category
	task.target_value = target_value
	task.target_count = target_count
	if difficulty_int == 1:
		task.difficulty = task.Difficulty.HARD
	else:
		task.difficulty = task.Difficulty.EASY
	task.progress_reduction = reduction
	task.reward_value = reward_value
	return task
