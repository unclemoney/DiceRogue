extends Debuff
class_name FasterChoresDebuff

## FasterChoresDebuff
##
## Causes the chore meter to increase by 3 points per roll instead of 1.
## Connects to GameController's dice_rolled signal and adds 2 extra progress
## (combined with the normal 1 progress = 3 total per roll).

var game_controller: Node
var chores_manager: Node

## apply(_target)
##
## Connects to dice_rolled signal and stores references for cleanup.
func apply(_target) -> void:
	print("[FasterChoresDebuff] Applied - Chore meter now increases 3 per roll")
	self.target = _target
	
	# Find GameController
	game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		push_error("[FasterChoresDebuff] Failed to find GameController")
		return
	
	# Find ChoresManager
	chores_manager = get_tree().get_first_node_in_group("chores_manager")
	if not chores_manager:
		push_error("[FasterChoresDebuff] Failed to find ChoresManager")
		return
	
	# Connect to dice_rolled signal from GameButtonUI (forwarded through game controller)
	if game_controller.game_button_ui and game_controller.game_button_ui.has_signal("dice_rolled"):
		if not game_controller.game_button_ui.is_connected("dice_rolled", _on_dice_rolled):
			game_controller.game_button_ui.dice_rolled.connect(_on_dice_rolled)
			print("[FasterChoresDebuff] Connected to GameButtonUI.dice_rolled")

## remove()
##
## Disconnects from dice_rolled signal.
func remove() -> void:
	print("[FasterChoresDebuff] Removed - Restoring normal chore progress rate")
	
	if game_controller and game_controller.game_button_ui:
		if game_controller.game_button_ui.is_connected("dice_rolled", _on_dice_rolled):
			game_controller.game_button_ui.dice_rolled.disconnect(_on_dice_rolled)
			print("[FasterChoresDebuff] Disconnected from dice_rolled")

## _on_dice_rolled(_dice_values)
##
## Called when dice are rolled. Adds 2 extra chore progress.
## Combined with default 1 progress = 3 total per roll.
func _on_dice_rolled(_dice_values) -> void:
	if chores_manager and chores_manager.has_method("increment_progress"):
		chores_manager.increment_progress(2)
		print("[FasterChoresDebuff] Added 2 extra chore progress")
