extends Node
class_name ChoresManager

## ChoresManager
##
## Manages the chore system that tracks player behavior via tasks.
## Progress increases by 1 each dice roll and decreases by 20 when tasks are completed.
## When progress reaches 100, Mom appears to check on the player.
## Mom's mood ranges from 1 (happy) to 10 (angry), starting at 5 (neutral).

# Preload for type safety in static context
const ChoreDataScript = preload("res://Scripts/Managers/ChoreData.gd")

signal progress_changed(new_value: int)
signal task_selected(task)
signal task_completed(task)
signal task_rotated(task)  # Emitted when chore auto-rotates every 20 rolls
signal mom_triggered
signal mom_mood_changed(new_mood: int)
signal request_chore_selection  # Emitted when player needs to choose next chore (EASY/HARD)

const MAX_PROGRESS: int = 100
const PROGRESS_PER_ROLL: int = 1
const ROLLS_PER_ROTATION: int = 20  # Chores rotate every 20 rolls
const CHORE_REWARD_MONEY: int = 50  # Reward per chore completed

# Mom's mood system: 1 = very happy, 5 = neutral, 10 = extremely angry
const MIN_MOOD: int = 1
const MAX_MOOD: int = 10
const DEFAULT_MOOD: int = 5

var current_progress: int = 0
var chores_completed_this_round: int = 0  # Track chores completed in current round
var current_task = null  # ChoreData instance
var tasks_completed: int = 0
var total_rolls_tracked: int = 0  # Track total rolls for chore rotation
var is_mom_active: bool = false
var _task_history: Array[String] = []  # Track recent tasks to avoid repetition
var pending_chore_selection: bool = false  # True when waiting to show chore selection popup
var _pending_easy_task = null  # Cached EASY task option for popup
var _pending_hard_task = null  # Cached HARD task option for popup

# Round-based scaling for goof-off meter
# Round 1 uses base value (100), each subsequent round scales down by 5%
var current_round_number: int = 1

# Mom's mood tracking
var mom_mood: int = DEFAULT_MOOD
var completed_chores: Array = []  # List of completed ChoreData for display

func _ready() -> void:
	add_to_group("chores_manager")
	print("[ChoresManager] Initialized with Mom mood: %d" % mom_mood)
	select_new_task()

## increment_progress()
##
## Increases the chore progress by the specified amount.
## Called when the player rolls dice.
## Triggers Mom appearance if progress reaches 100.
## Rotates chores every 20 rolls regardless of completion.
##
## Parameters:
##   amount: int - the amount to increase (default: 1)
func increment_progress(amount: int = PROGRESS_PER_ROLL) -> void:
	if is_mom_active:
		return
	
	var scaled_max = get_scaled_max_progress()
	current_progress = mini(current_progress + amount, scaled_max)
	progress_changed.emit(current_progress)
	print("[ChoresManager] Progress: %d/%d" % [current_progress, scaled_max])
	
	# Track total rolls for chore rotation
	total_rolls_tracked += amount
	if total_rolls_tracked >= ROLLS_PER_ROTATION:
		total_rolls_tracked = 0
		_rotate_current_task()
	
	if current_progress >= scaled_max:
		_trigger_mom()

## _rotate_current_task()
##
## Rotates to a new random chore task.
## Called every 20 rolls regardless of completion status.
func _rotate_current_task() -> void:
	print("[ChoresManager] Chore expired (every %d rolls) - queuing selection popup" % ROLLS_PER_ROTATION)
	task_rotated.emit(current_task)
	# Queue chore selection popup instead of auto-selecting
	_queue_chore_selection()

## complete_current_task()
##
## Marks the current task as complete and reduces progress by 20.
## Improves Mom's mood by 1 and tracks completed chores.
## Selects a new task after completion.
func complete_current_task() -> void:
	if current_task == null:
		return
	
	print("[ChoresManager] Task completed: %s (difficulty: %s)" % [
		current_task.display_name,
		"HARD" if current_task.difficulty == ChoreData.Difficulty.HARD else "EASY"
	])
	
	# Track completed chore for display
	completed_chores.append(current_task)
	
	# Track chores completed this round for end-of-round rewards
	chores_completed_this_round += 1
	
	task_completed.emit(current_task)
	tasks_completed += 1
	
	# Track with ProgressManager for unlock conditions
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager and progress_manager.has_method("track_chore_completed"):
		progress_manager.track_chore_completed(current_task.difficulty)
	
	# Improve Mom's mood (lower = happier)
	adjust_mood(-1)
	
	# Reduce progress using dynamic difficulty-based reduction
	var reduction = current_task.get_progress_reduction()
	current_progress = maxi(current_progress - reduction, 0)
	progress_changed.emit(current_progress)
	print("[ChoresManager] Progress reduced by %d to: %d" % [reduction, current_progress])
	
	# Reset roll tracking for expiry timer
	total_rolls_tracked = 0
	
	# Queue chore selection popup instead of auto-selecting
	_queue_chore_selection()

## adjust_mood(delta)
##
## Adjusts Mom's mood by the specified amount.
## Positive delta = angrier, negative delta = happier.
## Emits mom_mood_changed signal when mood changes.
##
## Parameters:
##   delta: int - the amount to change mood by
func adjust_mood(delta: int) -> void:
	var old_mood = mom_mood
	mom_mood = clampi(mom_mood + delta, MIN_MOOD, MAX_MOOD)
	if mom_mood != old_mood:
		print("[ChoresManager] Mom's mood changed: %d -> %d" % [old_mood, mom_mood])
		mom_mood_changed.emit(mom_mood)


## get_mood_description()
##
## Returns a text description of Mom's current mood.
##
## Returns: String - mood description
func get_mood_description() -> String:
	if mom_mood <= 2:
		return "Very Happy"
	elif mom_mood <= 4:
		return "Happy"
	elif mom_mood == 5:
		return "Neutral"
	elif mom_mood <= 7:
		return "Annoyed"
	elif mom_mood <= 9:
		return "Angry"
	else:
		return "Furious"


## get_mood_emoji()
##
## Returns an emoji representing Mom's current mood.
##
## Returns: String - mood emoji
func get_mood_emoji() -> String:
	if mom_mood <= 2:
		return "😊"
	elif mom_mood <= 4:
		return "🙂"
	elif mom_mood == 5:
		return "😐"
	elif mom_mood <= 7:
		return "😒"
	elif mom_mood <= 9:
		return "😠"
	else:
		return "🤬"


## reset_for_new_game()
##
## Resets Mom's mood to neutral and clears completed chores.
## Should be called when starting a new game.
func reset_for_new_game() -> void:
	mom_mood = DEFAULT_MOOD
	completed_chores.clear()
	tasks_completed = 0
	current_progress = 0
	total_rolls_tracked = 0
	is_mom_active = false
	_task_history.clear()
	current_round_number = 1  # Reset round scaling
	reset_round_tracking()  # Reset round-specific tracking
	progress_changed.emit(current_progress)
	mom_mood_changed.emit(mom_mood)
	select_new_task()
	print("[ChoresManager] Reset for new game - mood: %d, round: %d" % [mom_mood, current_round_number])


## reset_round_tracking()
##
## Resets round-specific tracking variables.
## Called at the start of each new round.
func reset_round_tracking() -> void:
	chores_completed_this_round = 0
	print("[ChoresManager] Round tracking reset - chores_completed_this_round: 0")


## get_chores_completed_this_round() -> int
##
## Returns the number of chores completed in the current round.
##
## Returns: int - number of chores completed this round
func get_chores_completed_this_round() -> int:
	return chores_completed_this_round


## check_task_completion()
##
## Checks if the current task is completed based on the scoring context.
## Called after the player scores.
##
## Parameters:
##   context: Dictionary containing scoring information
##
## Returns: bool - true if task was completed
func check_task_completion(context: Dictionary) -> bool:
	if current_task == null:
		return false
	
	if current_task.check_completion(context):
		complete_current_task()
		return true
	
	return false

## _queue_chore_selection()
##
## Queues a chore selection popup to appear at the next turn end.
## Pre-generates one EASY and one HARD task option for the player to choose from.
func _queue_chore_selection() -> void:
	pending_chore_selection = true
	# Pre-generate task options
	_pending_easy_task = _get_random_task_by_difficulty(0)  # EASY
	_pending_hard_task = _get_random_task_by_difficulty(1)  # HARD
	print("[ChoresManager] Chore selection queued: EASY=%s, HARD=%s" % [
		_pending_easy_task.display_name if _pending_easy_task else "None",
		_pending_hard_task.display_name if _pending_hard_task else "None"
	])
	request_chore_selection.emit()


## get_pending_tasks() -> Dictionary
##
## Returns the pending EASY and HARD task options for the selection popup.
## @return Dictionary: {"easy": ChoreData, "hard": ChoreData}
func get_pending_tasks() -> Dictionary:
	return {
		"easy": _pending_easy_task,
		"hard": _pending_hard_task
	}


## accept_chore_selection(is_hard: bool)
##
## Accepts the player's chore selection from the popup.
## @param is_hard: True if player chose the HARD chore, false for EASY
func accept_chore_selection(is_hard: bool) -> void:
	pending_chore_selection = false
	if is_hard and _pending_hard_task:
		current_task = _pending_hard_task
	elif _pending_easy_task:
		current_task = _pending_easy_task
	else:
		select_new_task()
		return
	
	_pending_easy_task = null
	_pending_hard_task = null
	total_rolls_tracked = 0  # Reset expiry timer for new task
	task_selected.emit(current_task)
	print("[ChoresManager] Player selected %s chore: %s" % [
		"HARD" if is_hard else "EASY", current_task.display_name])


## _get_random_task_by_difficulty(difficulty: int)
##
## Gets a random task from the library filtered by difficulty.
## @param difficulty: 0 = EASY, 1 = HARD
## @return ChoreData: A random task of the specified difficulty
func _get_random_task_by_difficulty(difficulty: int):
	var tasks: Array
	if difficulty == 1:
		tasks = ChoreTasksLibrary.get_hard_tasks()
	else:
		tasks = ChoreTasksLibrary.get_easy_tasks()
	
	if tasks.is_empty():
		return ChoreTasksLibrary.get_random_task()
	
	# Try to avoid recent tasks
	var attempts = 0
	var selected_task = null
	while attempts < 5:
		selected_task = tasks[randi() % tasks.size()]
		if selected_task.id not in _task_history:
			break
		attempts += 1
	
	return selected_task


## get_rolls_until_expiry() -> int
##
## Returns the number of rolls remaining before the current chore expires.
## @return int: Rolls remaining (0 to ROLLS_PER_ROTATION)
func get_rolls_until_expiry() -> int:
	return max(0, ROLLS_PER_ROTATION - total_rolls_tracked)


## select_new_task()
##
## Selects a new random task from the library.
## Tries to avoid repeating recent tasks.
func select_new_task() -> void:
	var attempts = 0
	var new_task = null
	
	# Try to get a task we haven't used recently
	while attempts < 5:
		new_task = ChoreTasksLibrary.get_random_task()
		if new_task.id not in _task_history:
			break
		attempts += 1
	
	# Update task history (keep last 5)
	if new_task:
		_task_history.append(new_task.id)
		if _task_history.size() > 5:
			_task_history.pop_front()
	
	current_task = new_task
	task_selected.emit(current_task)
	print("[ChoresManager] New task: %s" % (current_task.display_name if current_task else "None"))

## reset_progress()
##
## Resets the chore progress to 0 and tasks_completed counter.
## Called after Mom leaves.
func reset_progress() -> void:
	current_progress = 0
	tasks_completed = 0
	total_rolls_tracked = 0
	is_mom_active = false
	progress_changed.emit(current_progress)
	print("[ChoresManager] Progress reset to 0, tasks_completed reset")


## get_scaled_max_progress()
##
## Returns the max progress threshold scaled by round number and channel difficulty.
## Round 1 uses base value (100), each subsequent round scales down by 5%.
## Channel goof_off_multiplier further reduces the threshold (higher multiplier = Mom appears faster).
## Uses ceil() to ensure whole numbers.
##
## Returns: int - scaled max progress threshold
func get_scaled_max_progress() -> int:
	# Round 1 = base value, Round 2+ = 5% decrease per round
	var scale_factor = pow(0.95, max(0, current_round_number - 1))
	var base_scaled = MAX_PROGRESS * scale_factor
	
	# Apply channel goof-off multiplier (divides threshold - higher multiplier = faster fill)
	var goof_off_multiplier = _get_goof_off_multiplier()
	var final_threshold = base_scaled / goof_off_multiplier
	
	return int(ceil(max(10, final_threshold)))  # Minimum threshold of 10


## _get_goof_off_multiplier() -> float
##
## Gets the goof-off multiplier from ChannelManager.
## Higher multiplier = Mom appears faster (threshold is divided by this value).
## @return float: The multiplier (1.0 if ChannelManager is not found)
func _get_goof_off_multiplier() -> float:
	var channel_manager = _find_channel_manager()
	if channel_manager and channel_manager.has_method("get_goof_off_multiplier"):
		return channel_manager.get_goof_off_multiplier()
	return 1.0


## _find_channel_manager() -> Node
##
## Locates the ChannelManager in the scene tree.
## @return Node: The ChannelManager or null if not found
func _find_channel_manager():
	# Try to find via the chores_manager group's root
	var root = get_tree().current_scene
	if root:
		var channel_manager = root.get_node_or_null("ChannelManager")
		if channel_manager:
			return channel_manager
	
	# Try to find via game controller
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		var parent = game_controller.get_parent()
		if parent:
			var channel_manager = parent.get_node_or_null("ChannelManager")
			if channel_manager:
				return channel_manager
	
	return null


## update_round(round_number)
##
## Updates the current round number for scaling calculations.
## Called by GameController when a new round starts.
## Clamps current_progress if it exceeds or equals the new threshold.
##
## Parameters:
##   round_number: int - the current round number (1-based)
func update_round(round_number: int) -> void:
	current_round_number = round_number
	var new_threshold = get_scaled_max_progress()
	
	# Clamp progress if it exceeds or equals the new threshold
	if current_progress >= new_threshold:
		current_progress = max(0, new_threshold - 1)
		progress_changed.emit(current_progress)
		print("[ChoresManager] Progress clamped to %d (below new threshold %d)" % [current_progress, new_threshold])
	
	print("[ChoresManager] Round updated to %d - Max progress threshold: %d" % [current_round_number, new_threshold])


## get_progress_percent()
##
## Returns the current progress as a percentage (0.0 to 1.0).
## Uses scaled max progress based on current round.
##
## Returns: float
func get_progress_percent() -> float:
	return float(current_progress) / float(get_scaled_max_progress())

## set_progress()
##
## Sets the progress to a specific value (for debugging).
## Uses scaled max progress based on current round.
##
## Parameters:
##   value: int - the new progress value (clamped to 0-scaled_max)
func set_progress(value: int) -> void:
	var scaled_max = get_scaled_max_progress()
	current_progress = clampi(value, 0, scaled_max)
	progress_changed.emit(current_progress)
	
	if current_progress >= scaled_max and not is_mom_active:
		_trigger_mom()

## _trigger_mom()
##
## Internal function to trigger Mom's appearance.
## Adjusts mood based on chores completed (angrier if none done).
## Emits the mom_triggered signal for GameController to handle.
func _trigger_mom() -> void:
	if is_mom_active:
		return
	
	is_mom_active = true
	print("[ChoresManager] Mom triggered! Progress at 100!")
	
	# Mom gets angrier if no chores were completed this cycle
	if tasks_completed == 0:
		adjust_mood(2)  # Increase anger by 2 if no chores done
		print("[ChoresManager] No chores done - Mom is angrier!")
	
	mom_triggered.emit()
