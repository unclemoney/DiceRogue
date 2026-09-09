extends Consumable
class_name PaintJobConsumable

## PaintJobConsumable (id: "paint_job")
##
## On use, every die in the hand gets a random color (any of the six
## DiceColor.Type colors, ignoring purchase/unlock state) for the NEXT roll
## only. Each die's prior color is stored and restored when the hand's
## roll_complete signal fires. One-shot: the listener disconnects itself.
##
## Timing: usable any time during an active turn (mirrors how the debug color
## commands call Dice.force_color() with no timing gate). Best played after
## rolling, since dice that actually roll re-run their own random color
## assignment during roll() before the restore fires. Gated to rolled dice in
## ConsumableUI._can_use_consumable(), same as the Green Envy coupon.

signal paint_applied
signal paint_reverted

var _debug_enabled: bool = OS.is_debug_build()
var _saved_colors: Dictionary = {}  # Dice -> DiceColor.Type (stored as int)
var _roll_signal_owner: Object = null
var is_active: bool = false


func _ready() -> void:
	add_to_group("consumables")
	if _debug_enabled:
		print("[PaintJobConsumable] Ready")


## apply(target)
##
## Target must be the GameController. Paints all dice in the hand and arms
## the one-shot restore on DiceHand.roll_complete.
func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[PaintJobConsumable] Invalid target passed to apply()")
		return

	if not game_controller.dice_hand:
		push_error("[PaintJobConsumable] No dice_hand found on game_controller")
		return

	var dice = game_controller.dice_hand.dice_list
	if dice.is_empty():
		if _debug_enabled:
			print("[PaintJobConsumable] No dice available to paint")
		return

	paint_dice(dice)
	connect_restore(game_controller.dice_hand)


## paint_dice(dice_list: Array)
##
## Stores each die's current color, then forces a random color on it.
func paint_dice(dice_list: Array) -> void:
	_saved_colors.clear()
	for die in dice_list:
		if not die is Dice:
			continue
		if not is_instance_valid(die):
			continue
		_saved_colors[die] = die.color
		var new_color = GameRNG.random_choice(DiceColor.get_all_colors())
		die.force_color(new_color)
	is_active = not _saved_colors.is_empty()
	if is_active:
		paint_applied.emit()
	if _debug_enabled:
		print("[PaintJobConsumable] Painted %d dice with random colors" % _saved_colors.size())


## connect_restore(roll_signal_owner: Object)
##
## Connects the one-shot restore to the owner's roll_complete signal
## (DiceHand in game; a plain Node with add_user_signal works in tests).
func connect_restore(roll_signal_owner: Object) -> void:
	if not is_active:
		if _debug_enabled:
			print("[PaintJobConsumable] Not active - skipping restore hookup")
		return
	if not roll_signal_owner or not roll_signal_owner.has_signal("roll_complete"):
		push_error("[PaintJobConsumable] Owner has no roll_complete signal")
		return
	_roll_signal_owner = roll_signal_owner
	var callback := Callable(self, "_on_roll_complete")
	if not _roll_signal_owner.is_connected("roll_complete", callback):
		_roll_signal_owner.connect("roll_complete", callback)
		if _debug_enabled:
			print("[PaintJobConsumable] Connected to roll_complete for one-shot restore")


## _on_roll_complete()
##
## Fires on the next hand roll: restores every die's prior color, then
## disconnects itself (one-shot).
func _on_roll_complete() -> void:
	restore_colors()
	var callback := Callable(self, "_on_roll_complete")
	if _roll_signal_owner and is_instance_valid(_roll_signal_owner):
		if _roll_signal_owner.is_connected("roll_complete", callback):
			_roll_signal_owner.disconnect("roll_complete", callback)
	_roll_signal_owner = null
	is_active = false
	if _debug_enabled:
		print("[PaintJobConsumable] Roll resolved - colors reverted, listener disconnected")


## restore_colors()
##
## Forces every painted die back to the color it had before apply().
func restore_colors() -> void:
	for die in _saved_colors.keys():
		if is_instance_valid(die):
			die.force_color(_saved_colors[ die ])
	_saved_colors.clear()
	paint_reverted.emit()
