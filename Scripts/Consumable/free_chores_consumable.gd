extends Consumable
class_name FreeChoresConsumable

## FreeChoresConsumable
##
## Reduces the goof-off meter by 30 points, simulating completing one chore.
## Does not trigger actual chore completion logic (no mood change, no task tracking).
## Always usable as long as player owns it.

const PROGRESS_REDUCTION: int = 30

func _ready() -> void:
	add_to_group("consumables")
	print("[FreeChoresConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[FreeChoresConsumable] Invalid target passed to apply()")
		return
	
	# Find ChoresManager via group
	var chores_manager = get_tree().get_first_node_in_group("chores_manager")
	if not chores_manager:
		push_error("[FreeChoresConsumable] ChoresManager not found in group 'chores_manager'")
		return
	
	var old_progress = chores_manager.current_progress
	chores_manager.current_progress = maxi(chores_manager.current_progress - PROGRESS_REDUCTION, 0)
	chores_manager.progress_changed.emit(chores_manager.current_progress)
	
	print("[FreeChoresConsumable] Reduced goof-off meter: %d -> %d (-%d)" % [old_progress, chores_manager.current_progress, PROGRESS_REDUCTION])
