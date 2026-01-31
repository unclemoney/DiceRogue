extends Debuff
class_name FasterChoresDebuff

## FasterChoresDebuff
##
## Causes the chore meter to increase faster per roll.
## Connects to GameController's dice_rolled signal and adds extra progress.
## Intensity scaling: At 1.0 = +2 extra (3 total), at 2.0 = +4 extra (5 total).

var game_controller: Node
var chores_manager: Node
var _extra_progress: int = 2  ## Extra progress per roll after intensity scaling


## apply(_target)
##
## Connects to dice_rolled signal and stores references for cleanup.
func apply(_target) -> void:
	# Calculate extra progress based on intensity
	_extra_progress = int(round(2.0 * intensity))
	print("[FasterChoresDebuff] Applied - Chore meter increases by", 1 + _extra_progress, "per roll (intensity:", intensity, ")")
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
## Called when dice are rolled. Adds extra chore progress based on intensity.
func _on_dice_rolled(_dice_values) -> void:
	if chores_manager and chores_manager.has_method("increment_progress"):
		chores_manager.increment_progress(_extra_progress)
		print("[FasterChoresDebuff] Added", _extra_progress, "extra chore progress")
