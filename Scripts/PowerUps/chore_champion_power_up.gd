extends PowerUp
class_name ChoreChampionPowerUp

## ChoreChampionPowerUp
##
## Doubles the effectiveness of chore completion for reducing goof-off meter.
## When a chore is completed (normally -20 progress), applies an additional -20
## for a total of -40 reduction.
## Uses a multiplier approach to avoid conflicts with ChoresManager's internal logic.
## Common rarity, $50 price.

# Reference to chores manager
var chores_manager_ref: Node = null

# Multiplier for chore effectiveness (2.0 = double effectiveness)
const EFFECTIVENESS_MULTIPLIER: float = 2.0

# Track bonus reductions applied
var total_bonus_reductions: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying ChoreChampionPowerUp ===")
	
	# Get chores manager from the tree
	var tree = null
	if target is Node:
		tree = target.get_tree()
	elif is_inside_tree():
		tree = get_tree()
	
	if not tree:
		push_error("[ChoreChampionPowerUp] Cannot access scene tree")
		return
	
	# Find ChoresManager
	chores_manager_ref = tree.get_first_node_in_group("chores_manager")
	if not chores_manager_ref:
		# Fallback: try GameController reference
		var game_controller = tree.get_first_node_in_group("game_controller")
		if game_controller and game_controller.has_node("../ChoresManager"):
			chores_manager_ref = game_controller.get_node("../ChoresManager")
	
	if not chores_manager_ref:
		push_error("[ChoreChampionPowerUp] ChoresManager not found")
		return
	
	# Connect to task_completed signal
	if not chores_manager_ref.is_connected("task_completed", _on_task_completed):
		chores_manager_ref.task_completed.connect(_on_task_completed)
		print("[ChoreChampionPowerUp] Connected to task_completed signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_task_completed(task) -> void:
	if not chores_manager_ref:
		return
	
	# Calculate bonus reduction (the additional amount beyond the normal reduction)
	# Base reduction depends on task difficulty: EASY=10, HARD=30
	# Multiplier 2.0 means we apply an additional 1.0x the base reduction
	var base_reduction = task.get_progress_reduction() if task else 10
	var bonus_reduction = int(base_reduction * (EFFECTIVENESS_MULTIPLIER - 1.0))
	
	# Apply the bonus reduction
	if bonus_reduction > 0:
		# Use negative value to reduce progress
		chores_manager_ref.current_progress = maxi(chores_manager_ref.current_progress - bonus_reduction, 0)
		chores_manager_ref.progress_changed.emit(chores_manager_ref.current_progress)
		total_bonus_reductions += bonus_reduction
		print("[ChoreChampionPowerUp] Applied bonus reduction of %d (total now: %d)" % [bonus_reduction, total_bonus_reductions])
		
		# Update description
		emit_signal("description_updated", id, get_current_description())
		
		if is_inside_tree():
			_update_power_up_icons()

func get_current_description() -> String:
	# Show example with EASY task (10 base reduction)
	var example_base = 10
	var example_total = int(example_base * EFFECTIVENESS_MULTIPLIER)
	var base_desc = "Chores are %.0fx more effective (EASY: -%d, HARD: -%d)" % [EFFECTIVENESS_MULTIPLIER, example_total, int(30 * EFFECTIVENESS_MULTIPLIER)]
	
	if total_bonus_reductions > 0:
		base_desc += "\nBonus reduction applied: %d total" % total_bonus_reductions
	
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("chore_champion")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing ChoreChampionPowerUp ===")
	
	if chores_manager_ref:
		if chores_manager_ref.is_connected("task_completed", _on_task_completed):
			chores_manager_ref.task_completed.disconnect(_on_task_completed)
			print("[ChoreChampionPowerUp] Disconnected from task_completed signal")
	
	chores_manager_ref = null

func _on_tree_exiting() -> void:
	if chores_manager_ref:
		if chores_manager_ref.is_connected("task_completed", _on_task_completed):
			chores_manager_ref.task_completed.disconnect(_on_task_completed)
