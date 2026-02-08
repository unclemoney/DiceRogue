extends PowerUp
class_name ChoreSprintPowerUp

## ChoreSprintPowerUp
##
## Uncommon PowerUp that increases chore effectiveness by 50%.
## Completing chores reduces goof-off meter by 30 instead of 20.
## Stacks with ChoreChampion (which doubles): Sprint applies first, then Champion doubles.
## Price: $150, Rarity: Uncommon

const BONUS_REDUCTION: int = 10  # Extra 10 on top of base 20 = 30 total

var chores_manager_ref: Node = null
var total_bonus_reductions: int = 0

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
		if game_controller and game_controller.has_node("../ChoresManager"):
			chores_manager_ref = game_controller.get_node("../ChoresManager")
	
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

func _on_task_completed(_task) -> void:
	# Apply bonus reduction to goof-off meter
	if chores_manager_ref:
		chores_manager_ref.current_progress = maxi(0, chores_manager_ref.current_progress - BONUS_REDUCTION)
		chores_manager_ref.progress_changed.emit(chores_manager_ref.current_progress)
		total_bonus_reductions += BONUS_REDUCTION
		print("[ChoreSprintPowerUp] Applied extra -%d to goof-off meter (total bonus: %d)" % [BONUS_REDUCTION, total_bonus_reductions])
		emit_signal("description_updated", id, get_current_description())
		_update_power_up_icons()

func get_current_description() -> String:
	return "Chores reduce goof-off meter by 30 instead of 20 (+50%%).\nTotal bonus reduction: %d" % total_bonus_reductions

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
