extends Mod
class_name HighRollerMod

var _attached_die: Dice = null
var _fibonacci_sequence: Array[int] = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610]
var _current_cost_index: int = 0
var _game_button_ui: Node = null

func _ready() -> void:
	add_to_group("mods")
	print("[HighRollerMod] Ready")

## apply(dice_target)
##
## Applies the HighRoller mod to a dice. This mod disables locking and allows
## click-to-reroll with increasing Fibonacci costs.
func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		print("[HighRollerMod] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target  # Store in base class target variable
		
		# Find the GameButtonUI for listening to normal rolls
		_find_game_button_ui()
		
		# Connect to dice signals - we need to use CONNECT_DEFERRED to ensure
		# our handler runs after the dice's built-in handler
		if not _attached_die.clicked.is_connected(_on_die_clicked):
			_attached_die.clicked.connect(_on_die_clicked, CONNECT_DEFERRED)
		if not _attached_die.selected.is_connected(_on_die_selected):
			_attached_die.selected.connect(_on_die_selected, CONNECT_DEFERRED)
		if not _attached_die.rolled.is_connected(_on_die_rolled):
			_attached_die.rolled.connect(_on_die_rolled)
			
		# Connect to GameButtonUI for normal roll tracking
		if _game_button_ui:
			if not _game_button_ui.is_connected("dice_rolled", _on_normal_dice_rolled):
				_game_button_ui.connect("dice_rolled", _on_normal_dice_rolled)
		
		# Disable locking functionality on this die
		_disable_die_locking()
		
		emit_signal("mod_applied")
	else:
		push_error("[HighRollerMod] Invalid target passed to apply()")

## remove()
##
## Removes the HighRoller mod from the attached dice and restores normal functionality.
func remove() -> void:
	if _attached_die:
		# Disconnect all signals
		if _attached_die.clicked.is_connected(_on_die_clicked):
			_attached_die.clicked.disconnect(_on_die_clicked)
		if _attached_die.selected.is_connected(_on_die_selected):
			_attached_die.selected.disconnect(_on_die_selected)
		if _attached_die.rolled.is_connected(_on_die_rolled):
			_attached_die.rolled.disconnect(_on_die_rolled)
			
		# Restore normal locking functionality
		_restore_die_locking()
		
		_attached_die = null
	
	# Disconnect from GameButtonUI
	if _game_button_ui and _game_button_ui.is_connected("dice_rolled", _on_normal_dice_rolled):
		_game_button_ui.disconnect("dice_rolled", _on_normal_dice_rolled)
	
	emit_signal("mod_removed")

## _find_game_button_ui()
##
## Locates the GameButtonUI to listen for normal roll events.
func _find_game_button_ui() -> void:
	# Try to find GameButtonUI in the scene tree
	_game_button_ui = get_tree().get_first_node_in_group("game_button_ui")
	if not _game_button_ui:
		_game_button_ui = get_tree().get_root().find_child("GameButtonUI", true, false)
	
	if _game_button_ui:
		print("[HighRollerMod] Found GameButtonUI:", _game_button_ui)
	else:
		print("[HighRollerMod] Could not find GameButtonUI - normal roll tracking disabled")

## _disable_die_locking()
##
## Prevents the attached die from being locked and ensures it stays unlocked.
func _disable_die_locking() -> void:
	if not _attached_die:
		return
		
	# Force unlock if currently locked
	_attached_die.is_locked = false
	_attached_die.update_visual()
	
	print("[HighRollerMod] Locking disabled for die: %s" % _attached_die.name)

## _restore_die_locking()
##
## Restores normal locking functionality to the die.
func _restore_die_locking() -> void:
	if not _attached_die:
		return
		
	print("[HighRollerMod] Locking functionality restored for die: %s" % _attached_die.name)

## _on_die_selected(dice: Dice)
##
## Intercepts the die selection to prevent normal lock/unlock behavior and handle rerolling.
## This is connected with CONNECT_DEFERRED so it runs after the original dice handler.
func _on_die_selected(dice: Dice) -> void:
	print("[HighRollerMod] Die selected for manual reroll")
	
	# First, immediately force unlock since this die cannot be locked
	if dice.is_locked:
		dice.is_locked = false
		dice.update_visual()
	
	# Now handle the reroll with cost
	_handle_manual_reroll()

## _on_die_clicked()
##
## Handles manual die clicks for rerolling with cost.
## This may be called independently or as part of the selection process.
func _on_die_clicked() -> void:
	print("[HighRollerMod] Die clicked signal received")
	# The main logic is now in _handle_manual_reroll()

## _handle_manual_reroll()
##
## Core logic for handling manual rerolls with Fibonacci cost progression.
func _handle_manual_reroll() -> void:
	print("[HighRollerMod] Processing manual reroll request")
	
	# Get current cost from Fibonacci sequence
	var current_cost = _get_current_cost()
	
	# Check if player can afford the reroll
	if not PlayerEconomy.can_afford(current_cost):
		print("[HighRollerMod] Player cannot afford reroll cost of $%d" % current_cost)
		_attached_die.shake_denied()  # Visual feedback for denied action
		return
	
	# Charge the player for the reroll
	if current_cost > 0:
		PlayerEconomy.remove_money(current_cost, "mod")
		print("[HighRollerMod] Charged player $%d for manual reroll" % current_cost)
	else:
		print("[HighRollerMod] Free reroll (cost: $0)")
	
	# Perform the reroll
	_attached_die.roll()
	
	# Increment cost for next reroll
	_increment_cost()

## _on_die_rolled(value: int)
##
## Called whenever the die rolls (either manually or from normal game rolls).
## We use this to track the die's behavior but don't charge money here.
func _on_die_rolled(value: int) -> void:
	print("[HighRollerMod] Die rolled value: %d" % value)
	# No additional logic needed here - cost tracking is handled elsewhere

## _on_normal_dice_rolled(_dice_values: Array)
##
## Called when normal dice rolls occur (from Roll button).
## Increments cost but doesn't charge money.
func _on_normal_dice_rolled(_dice_values: Array) -> void:
	print("[HighRollerMod] Normal dice roll detected, incrementing cost")
	_increment_cost()

## _get_current_cost() -> int
##
## Returns the current cost based on the Fibonacci sequence.
func _get_current_cost() -> int:
	if _current_cost_index >= _fibonacci_sequence.size():
		# If we exceed our precomputed sequence, extend it
		_extend_fibonacci_sequence()
	
	return _fibonacci_sequence[_current_cost_index]

## _increment_cost()
##
## Moves to the next cost in the Fibonacci sequence.
func _increment_cost() -> void:
	_current_cost_index += 1
	var new_cost = _get_current_cost()
	print("[HighRollerMod] Cost incremented to $%d (index: %d)" % [new_cost, _current_cost_index])

## _extend_fibonacci_sequence()
##
## Extends the Fibonacci sequence if we need more values.
func _extend_fibonacci_sequence() -> void:
	var current_size = _fibonacci_sequence.size()
	var last_two = [_fibonacci_sequence[current_size - 2], _fibonacci_sequence[current_size - 1]]
	
	# Add a few more values
	for i in range(5):
		var next_value = last_two[0] + last_two[1]
		_fibonacci_sequence.append(next_value)
		last_two = [last_two[1], next_value]
	
	print("[HighRollerMod] Extended Fibonacci sequence to %d values" % _fibonacci_sequence.size())

## get_current_cost_display() -> String
##
## Returns a string showing the current and next costs for UI display.
func get_current_cost_display() -> String:
	var current = _get_current_cost()
	var next_index = _current_cost_index + 1
	if next_index >= _fibonacci_sequence.size():
		_extend_fibonacci_sequence()
	var next_cost = _fibonacci_sequence[next_index]
	
	return "Current: $%d, Next: $%d" % [current, next_cost]