extends Control

## ChoresManagerTest
##
## Test scene for the ChoresManager system.
## Tests task selection, progress tracking, task completion, and Mom trigger.

# Preloads for class references
const ChoreTasksLibraryScript = preload("res://Scripts/Managers/chore_tasks_library.gd")

@onready var chores_manager = $ChoresManager  # ChoresManager - duck typed
@onready var chore_ui = $ChoreUI  # ChoreUI - duck typed
@onready var mom_dialog = $MomDialogPopup  # MomCharacter - duck typed
@onready var output_label: RichTextLabel = $OutputLabel
@onready var progress_spinbox: SpinBox = $ControlPanel/ProgressSpinBox
@onready var task_option: OptionButton = $ControlPanel/TaskOption

var _output_lines: Array[String] = []

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_log("ChoresManager Test initialized")
	_log("Current task: %s" % (chores_manager.current_task.display_name if chores_manager.current_task else "None"))

func _setup_ui() -> void:
	# Populate task option button
	var tasks = ChoreTasksLibraryScript.get_all_tasks()
	for task in tasks:
		task_option.add_item(task.display_name)
	
	# Connect ChoreUI to ChoresManager
	chore_ui.set_chores_manager(chores_manager)

func _connect_signals() -> void:
	chores_manager.progress_changed.connect(_on_progress_changed)
	chores_manager.task_selected.connect(_on_task_selected)
	chores_manager.task_completed.connect(_on_task_completed)
	chores_manager.mom_triggered.connect(_on_mom_triggered)

func _on_progress_changed(new_value: int) -> void:
	_log("Progress changed: %d" % new_value)

func _on_task_selected(task) -> void:  # ChoreData - duck typed
	_log("Task selected: %s" % task.display_name)

func _on_task_completed(task) -> void:  # ChoreData - duck typed
	_log("[color=green]Task completed: %s (reward: $%d)[/color]" % [task.display_name, task.reward_value])
	_log("  Round rewards so far: $%d (%d chores)" % [chores_manager.get_chore_rewards_this_round(), chores_manager.get_chores_completed_this_round()])

func _on_mom_triggered() -> void:
	_log("[color=red]MOM TRIGGERED![/color]")
	# For testing, we'll show a simple dialog
	mom_dialog.show_dialog("neutral", "Just checking in on you sweetie! How are your chores going?")

func _on_increment_pressed() -> void:
	chores_manager.increment_progress(1)

func _on_increment_10_pressed() -> void:
	chores_manager.increment_progress(10)

func _on_complete_task_pressed() -> void:
	chores_manager.complete_current_task()

func _on_trigger_mom_pressed() -> void:
	chores_manager.set_progress(100)

func _on_reset_pressed() -> void:
	chores_manager.reset_progress()

func _on_set_progress_pressed() -> void:
	var value = int(progress_spinbox.value)
	chores_manager.set_progress(value)

func _on_select_task_pressed() -> void:
	var index = task_option.selected
	if index >= 0:
		var tasks = ChoreTasksLibraryScript.get_all_tasks()
		if index < tasks.size():
			chores_manager.current_task = tasks[index]
			chores_manager.task_selected.emit(tasks[index])

func _on_test_mom_neutral_pressed() -> void:
	mom_dialog.show_dialog("neutral", "Just checking in on you, sweetie! Everything looks good here.")

func _on_test_mom_upset_pressed() -> void:
	mom_dialog.show_dialog("upset", "[color=orange]Hmm...[/color] What's this? You know you're not old enough for this kind of thing. I'm taking it away.")

func _on_test_mom_furious_pressed() -> void:
	mom_dialog.show_dialog("upset", "[wave amp=50 freq=3][color=red]WHAT IS THIS?![/color][/wave] You are [shake rate=20 level=10]GROUNDED[/shake] young one!")

func _on_test_mom_happy_pressed() -> void:
	mom_dialog.show_dialog("happy", "[color=green]Great job![/color] You're being so responsible. Keep it up!")

func _on_show_rewards_pressed() -> void:
	_log("=== ALL CHORE REWARDS ===")
	var tasks = ChoreTasksLibraryScript.get_all_tasks()
	for task in tasks:
		var diff_str = "HARD" if task.difficulty == 1 else "EASY"
		_log("  %s | $%d | %s | %s" % [task.id, task.reward_value, diff_str, task.display_name])
	_log("Total: %d chores" % tasks.size())

func _on_test_rewards_pressed() -> void:
	_log("=== TESTING REWARD ACCUMULATION ===")
	chores_manager.reset_for_new_game()
	var tasks = ChoreTasksLibraryScript.get_all_tasks()
	var expected_total: int = 0
	# Complete a mix of $5, $15, $35, $65, and $100 chores
	var test_tasks = [
		_find_task_by_id(tasks, "score_ones"),       # $5
		_find_task_by_id(tasks, "score_any_upper"),  # $15
		_find_task_by_id(tasks, "score_full_house"), # $35
		_find_task_by_id(tasks, "roll_yahtzee"),     # $65
		_find_task_by_id(tasks, "yahtzee_sixes")     # $100
	]
	for task in test_tasks:
		if task:
			chores_manager.current_task = task
			chores_manager.complete_current_task()
			expected_total += task.reward_value
	var actual_total = chores_manager.get_chore_rewards_this_round()
	var passed = expected_total == actual_total
	_log("Expected: $%d | Actual: $%d | %s" % [expected_total, actual_total, "[color=green]PASS[/color]" if passed else "[color=red]FAIL[/color]"])
	# Test reset
	chores_manager.reset_round_tracking()
	var after_reset = chores_manager.get_chore_rewards_this_round()
	var reset_passed = after_reset == 0
	_log("After reset: $%d | %s" % [after_reset, "[color=green]PASS[/color]" if reset_passed else "[color=red]FAIL[/color]"])

func _find_task_by_id(tasks: Array, id: String):
	for task in tasks:
		if task.id == id:
			return task
	return null

func _log(message: String) -> void:
	_output_lines.append("[%s] %s" % [Time.get_time_string_from_system(), message])
	if _output_lines.size() > 20:
		_output_lines.pop_front()
	output_label.text = "\n".join(_output_lines)
