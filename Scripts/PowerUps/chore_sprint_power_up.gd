extends PowerUp
class_name ChoreSprintPowerUp

## ChoreSprintPowerUp
##
## Uncommon PowerUp that converts 50% of a completed chore's goof-off points
## into Rebellion Rep, rounded down. Tracks actual Rep gained after clamping.
## Price: $150, Rarity: Uncommon

const REP_CONVERSION_RATE: float = 0.5

var chores_manager_ref: Node = null
var total_rep_gained: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying ChoreSprintPowerUp ===")
	
	var tree = null
	if target is Node:
		tree = target.get_tree()
	elif is_inside_tree():
		tree = get_tree()
	
	if not tree:
		push_error("[ChoreSprintPowerUp] Cannot access scene tree")
		return
	
	chores_manager_ref = tree.get_first_node_in_group("chores_manager")
	if not chores_manager_ref:
		var game_controller = tree.get_first_node_in_group("game_controller")
		if game_controller and game_controller.has_node("../Managers/ChoresManager"):
			chores_manager_ref = game_controller.get_node("../Managers/ChoresManager")
	
	if not chores_manager_ref:
		push_error("[ChoreSprintPowerUp] ChoresManager not found")
		return
	
	# Connect to task_completed signal
	if not chores_manager_ref.is_connected("task_completed", _on_task_completed):
		chores_manager_ref.task_completed.connect(_on_task_completed)
		print("[ChoreSprintPowerUp] Connected to task_completed signal")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing ChoreSprintPowerUp ===")
	if chores_manager_ref and chores_manager_ref.is_connected("task_completed", _on_task_completed):
		chores_manager_ref.task_completed.disconnect(_on_task_completed)
	chores_manager_ref = null

func _on_task_completed(task) -> void:
	if task == null:
		return
	var chore_points: int = task.get_progress_reduction()
	var rep_gain: int = floori(chore_points * REP_CONVERSION_RATE)
	if rep_gain <= 0:
		return
	var old_rep: int = ProgressManager.get_rep()
	ProgressManager.adjust_rep(rep_gain)
	var actual_rep_gain: int = ProgressManager.get_rep() - old_rep
	total_rep_gained += actual_rep_gain
	print("[ChoreSprintPowerUp] Gained %d Rep from %d chore points (total: %d)" % [actual_rep_gain, chore_points, total_rep_gained])
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func get_current_description() -> String:
	return "Completed chores grant 50%% of their goof-off points as Rep (rounded down).\nTotal Rep gained: %d" % total_rep_gained

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("chore_sprint")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	if chores_manager_ref and chores_manager_ref.is_connected("task_completed", _on_task_completed):
		chores_manager_ref.task_completed.disconnect(_on_task_completed)
