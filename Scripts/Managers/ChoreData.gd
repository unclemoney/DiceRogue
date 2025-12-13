extends Resource
class_name ChoreData

## ChoreData
##
## Resource class for defining chore tasks that the player must complete.
## Tasks are randomly selected each turn and reduce chore progress when completed.

enum TaskType {
	SCORE_UPPER,       # Score in upper section (Ones, Twos, etc.)
	SCORE_LOWER,       # Score in lower section (Three of a Kind, Full House, etc.)
	SCORE_SPECIFIC,    # Score a specific combination (e.g., Full House with 3 sixes)
	ROLL_YAHTZEE,      # Roll a Yahtzee
	USE_CONSUMABLE,    # Use any consumable
	LOCK_DICE,         # Lock a specific number of dice
	NO_SCORE_TURN,     # Finish a turn without scoring (scratch)
}

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var task_type: TaskType = TaskType.SCORE_UPPER
@export var progress_reduction: int = 20  # Always reduces by 20

## Optional parameters for specific task requirements
@export var target_category: String = ""  # e.g., "ones", "full_house"
@export var target_value: int = 0  # e.g., specific die value required
@export var target_count: int = 0  # e.g., number of dice to lock

## check_completion()
##
## Validates whether the task has been completed based on the scoring context.
## This is called by ChoresManager when a score is submitted.
##
## Parameters:
##   context: Dictionary containing scoring information:
##     - category: String (the scored category)
##     - dice_values: Array[int] (the dice values used)
##     - score: int (the score achieved)
##     - was_yahtzee: bool (true if a yahtzee was rolled)
##     - consumable_used: bool (true if a consumable was used this turn)
##     - locked_count: int (number of dice locked)
##     - was_scratch: bool (true if the score was scratched/zero)
##
## Returns: bool - true if task is completed
func check_completion(context: Dictionary) -> bool:
	match task_type:
		TaskType.SCORE_UPPER:
			return _check_upper_score(context)
		TaskType.SCORE_LOWER:
			return _check_lower_score(context)
		TaskType.SCORE_SPECIFIC:
			return _check_specific_score(context)
		TaskType.ROLL_YAHTZEE:
			return context.get("was_yahtzee", false)
		TaskType.USE_CONSUMABLE:
			return context.get("consumable_used", false)
		TaskType.LOCK_DICE:
			return context.get("locked_count", 0) >= target_count
		TaskType.NO_SCORE_TURN:
			return context.get("was_scratch", false)
		_:
			return false

func _check_upper_score(context: Dictionary) -> bool:
	var category = context.get("category", "")
	var upper_categories = ["ones", "twos", "threes", "fours", "fives", "sixes"]
	
	# If we have a target category, check that specific one
	if target_category != "":
		return category == target_category
	
	# Otherwise, any upper section score counts
	return category in upper_categories

func _check_lower_score(context: Dictionary) -> bool:
	var category = context.get("category", "")
	var lower_categories = ["three_of_a_kind", "four_of_a_kind", "full_house", 
		"small_straight", "large_straight", "yahtzee", "chance"]
	
	# If we have a target category, check that specific one
	if target_category != "":
		return category == target_category
	
	# Otherwise, any lower section score counts
	return category in lower_categories

func _check_specific_score(context: Dictionary) -> bool:
	var category = context.get("category", "")
	var dice_values = context.get("dice_values", [])
	
	# Must match the target category
	if category != target_category:
		return false
	
	# If we need a specific die value in the combination
	if target_value > 0 and target_count > 0:
		var count = dice_values.count(target_value)
		return count >= target_count
	
	return true
