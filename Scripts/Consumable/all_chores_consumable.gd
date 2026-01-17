extends Consumable
class_name AllChoresConsumable

## AllChoresConsumable
##
## Completely clears the goof-off meter, setting it to 0.
## Does not trigger actual chore completion logic (no mood change, no task tracking).
## Always usable as long as player owns it.

func _ready() -> void:
	add_to_group("consumables")
	print("[AllChoresConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[AllChoresConsumable] Invalid target passed to apply()")
		return
	
	# Find ChoresManager via group
	var chores_manager = get_tree().get_first_node_in_group("chores_manager")
	if not chores_manager:
		push_error("[AllChoresConsumable] ChoresManager not found in group 'chores_manager'")
		return
	
	var old_progress = chores_manager.current_progress
	chores_manager.current_progress = 0
	chores_manager.progress_changed.emit(chores_manager.current_progress)
	
	print("[AllChoresConsumable] Cleared goof-off meter: %d -> 0" % old_progress)
