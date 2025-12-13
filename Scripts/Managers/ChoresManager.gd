extends Node
class_name ChoresManager

## ChoresManager
##
## Manages the chore system that tracks player behavior via tasks.
## Progress increases by 1 each dice roll and decreases by 20 when tasks are completed.
## When progress reaches 100, Mom appears to check on the player.

# Preload for type safety in static context
const ChoreDataScript = preload("res://Scripts/Managers/ChoreData.gd")

signal progress_changed(new_value: int)
signal task_selected(task)
signal task_completed(task)
signal mom_triggered

const MAX_PROGRESS: int = 100
const PROGRESS_PER_ROLL: int = 1
const PROGRESS_REDUCTION: int = 20

var current_progress: int = 0
var current_task = null  # ChoreData instance
var tasks_completed: int = 0
var is_mom_active: bool = false
var _task_history: Array[String] = []  # Track recent tasks to avoid repetition

func _ready() -> void:
	print("[ChoresManager] Initialized")
	select_new_task()

## increment_progress()
##
## Increases the chore progress by the specified amount.
## Called when the player rolls dice.
## Triggers Mom appearance if progress reaches 100.
##
## Parameters:
##   amount: int - the amount to increase (default: 1)
func increment_progress(amount: int = PROGRESS_PER_ROLL) -> void:
	if is_mom_active:
		return
	
	current_progress = mini(current_progress + amount, MAX_PROGRESS)
	progress_changed.emit(current_progress)
	print("[ChoresManager] Progress: %d/%d" % [current_progress, MAX_PROGRESS])
	
	if current_progress >= MAX_PROGRESS:
		_trigger_mom()

## complete_current_task()
##
## Marks the current task as complete and reduces progress by 20.
## Selects a new task after completion.
func complete_current_task() -> void:
	if current_task == null:
		return
	
	print("[ChoresManager] Task completed: %s" % current_task.display_name)
	task_completed.emit(current_task)
	tasks_completed += 1
	
	# Reduce progress
	current_progress = maxi(current_progress - PROGRESS_REDUCTION, 0)
	progress_changed.emit(current_progress)
	print("[ChoresManager] Progress reduced to: %d" % current_progress)
	
	# Select new task
	select_new_task()

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
## Resets the chore progress to 0.
## Called after Mom leaves.
func reset_progress() -> void:
	current_progress = 0
	is_mom_active = false
	progress_changed.emit(current_progress)
	print("[ChoresManager] Progress reset to 0")

## get_progress_percent()
##
## Returns the current progress as a percentage (0.0 to 1.0).
##
## Returns: float
func get_progress_percent() -> float:
	return float(current_progress) / float(MAX_PROGRESS)

## set_progress()
##
## Sets the progress to a specific value (for debugging).
##
## Parameters:
##   value: int - the new progress value (clamped to 0-100)
func set_progress(value: int) -> void:
	current_progress = clampi(value, 0, MAX_PROGRESS)
	progress_changed.emit(current_progress)
	
	if current_progress >= MAX_PROGRESS and not is_mom_active:
		_trigger_mom()

## _trigger_mom()
##
## Internal function to trigger Mom's appearance.
## Emits the mom_triggered signal for GameController to handle.
func _trigger_mom() -> void:
	if is_mom_active:
		return
	
	is_mom_active = true
	print("[ChoresManager] Mom triggered! Progress at 100!")
	mom_triggered.emit()
