extends Node

## chore_sprint_power_up_test.gd
##
## Verifies Chore Sprint's chore-point-to-Rep conversion, lifecycle cleanup,
## normal chore completion behavior, and user-facing descriptions.
## Run headless:
##   godot --headless --path . Tests/chore_sprint_power_up_test.tscn -- --quit-after

const CHORE_SPRINT_SCENE: PackedScene = preload("res://Scenes/PowerUp/ChoreSprintPowerUp.tscn")
const CHORE_SPRINT_DATA: PowerUpData = preload("res://Scripts/PowerUps/ChoreSprintPowerUp.tres")
const ChoreTasksLibraryScript = preload("res://Scripts/Managers/chore_tasks_library.gd")

var _failures: int = 0
var _original_rep: int = 0
var _rep_change_events: int = 0


func _ready() -> void:
	print("[ChoreSprintPowerUpTest] Starting")
	_original_rep = ProgressManager.get_rep()
	ProgressManager.cumulative_stats["rep"] = 0
	ProgressManager.rep_changed.connect(_on_rep_changed)

	var manager := ChoresManager.new()
	add_child(manager)
	var power_up = CHORE_SPRINT_SCENE.instantiate()
	add_child(power_up)
	power_up.apply(manager)
	power_up.apply(manager)

	var easy_task = ChoreTasksLibraryScript.get_task_by_id("score_any_upper")
	manager.current_progress = 50
	manager.mom_mood = ChoresManager.DEFAULT_MOOD
	_complete(manager, easy_task)
	_check("5-point EASY chore grants 2 Rep", ProgressManager.get_rep() == 2)
	_check("duplicate apply does not duplicate the award", power_up.total_rep_gained == 2)
	_check("base completion applies only its 5-point reduction", manager.current_progress == 45)
	_check("base completion improves Mom mood once", manager.mom_mood == ChoresManager.DEFAULT_MOOD - 1)
	_check("base completion tracks its money reward", manager.chore_rewards_this_round == easy_task.reward_value)
	_check("Rep change notification emitted", _rep_change_events == 1)

	var hard_task = ChoreTasksLibraryScript.get_task_by_id("yahtzee_ones")
	manager.current_progress = 100
	_complete(manager, hard_task)
	_check("60-point HARD chore grants 30 Rep", ProgressManager.get_rep() == 32)
	_check("total Rep accumulates actual awards", power_up.total_rep_gained == 32)
	_check("HARD base reduction remains unchanged", manager.current_progress == 40)

	var odd_task = ChoreTasksLibraryScript.get_task_by_id("steady_hand")
	manager.current_progress = 100
	_complete(manager, odd_task)
	_check("15-point chore rounds down to 7 Rep", ProgressManager.get_rep() == 39)
	_check("second odd award accumulates correctly", power_up.total_rep_gained == 39)
	_check("15-point base reduction remains unchanged", manager.current_progress == 85)

	var zero_task := ChoreData.new()
	zero_task.progress_reduction = 0
	_complete(manager, zero_task)
	power_up._on_task_completed(null)
	_check("zero and null chores grant no Rep", ProgressManager.get_rep() == 39)
	_check("zero and null chores do not change the total", power_up.total_rep_gained == 39)
	_check("zero and null chores emit no Rep change", _rep_change_events == 3)

	ProgressManager.cumulative_stats["rep"] = 99
	_complete(manager, easy_task)
	_check("Rep remains capped at MAX_REP", ProgressManager.get_rep() == ProgressManager.MAX_REP)
	_check("capped award tracks only actual Rep", power_up.total_rep_gained == 40)
	_complete(manager, easy_task)
	_check("award at the Rep cap adds nothing", ProgressManager.get_rep() == ProgressManager.MAX_REP and power_up.total_rep_gained == 40)

	_check("hover describes the new effect", "50%" in power_up.get_current_description() and "Total Rep gained: 40" in power_up.get_current_description())
	_check("resource description describes Rep", "50%" in CHORE_SPRINT_DATA.description and "Rep" in CHORE_SPRINT_DATA.description)
	_check("resource description drops old reduction text", "instead of 20" not in CHORE_SPRINT_DATA.description)

	power_up.remove(manager)
	ProgressManager.cumulative_stats["rep"] = 0
	manager.current_progress = 50
	_complete(manager, easy_task)
	_check("remove stops Rep awards", ProgressManager.get_rep() == 0)
	_check("remove preserves base chore completion", manager.current_progress == 45)

	var exiting_power_up = CHORE_SPRINT_SCENE.instantiate()
	add_child(exiting_power_up)
	exiting_power_up.apply(manager)
	exiting_power_up.queue_free()
	await get_tree().process_frame
	_complete(manager, easy_task)
	_check("tree exit stops Rep awards", ProgressManager.get_rep() == 0)

	power_up.queue_free()
	manager.queue_free()
	ProgressManager.rep_changed.disconnect(_on_rep_changed)
	ProgressManager.cumulative_stats["rep"] = _original_rep
	ProgressManager.save_progress()

	if _failures == 0:
		print("[ChoreSprintPowerUpTest] PASS - all checks passed")
	else:
		print("[ChoreSprintPowerUpTest] FAIL - %d check(s) failed" % _failures)
	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _complete(manager: ChoresManager, task: ChoreData) -> void:
	manager.current_task = task
	manager.complete_current_task()


func _on_rep_changed(_new_rep: int) -> void:
	_rep_change_events += 1


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[ChoreSprintPowerUpTest] OK: " + label)
	else:
		push_error("[ChoreSprintPowerUpTest] FAILED: " + label)
		_failures += 1
