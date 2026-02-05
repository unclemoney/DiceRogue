extends Control

## dice_surge_expiry_test.gd
##
## Test scene to verify that Dice Surge properly expires and removes dice after 3 turns.
## Includes edge case testing for multiple stacks and rapid turn advancement.

@onready var turn_tracker: TurnTracker = $TurnTracker
@onready var dice_hand: DiceHand = $DiceHand
@onready var results_label: RichTextLabel = $UIPanel/VBoxContainer/ResultsLabel
@onready var status_label: Label = $UIPanel/VBoxContainer/StatusLabel

var test_log: Array[String] = []

# Mock GameController for Dice Surge to use
var mock_game_controller: Node = null


func _ready() -> void:
	print("\n=== DICE SURGE EXPIRY TEST ===")
	_setup_mock_game_controller()
	_connect_signals()
	_update_status()
	_log_message("[color=yellow]Test Ready - Use buttons to test Dice Surge expiry[/color]")


func _setup_mock_game_controller() -> void:
	# Create a simple mock that provides what DiceSurgeConsumable needs
	mock_game_controller = Node.new()
	mock_game_controller.name = "MockGameController"
	mock_game_controller.set_script(null)
	
	# Add properties that DiceSurgeConsumable checks
	mock_game_controller.set_meta("turn_tracker", turn_tracker)
	mock_game_controller.set_meta("dice_hand", dice_hand)
	add_child(mock_game_controller)


func _connect_signals() -> void:
	# Connect turn tracker signals
	turn_tracker.dice_stack_expired.connect(_on_dice_stack_expired)
	turn_tracker.dice_bonus_changed.connect(_on_dice_bonus_changed)
	turn_tracker.turn_started.connect(_on_turn_started)
	turn_tracker.temporary_effect_expired.connect(_on_temporary_effect_expired)


func _on_dice_stack_expired(stack_id: int, dice_removed: int) -> void:
	_log_message("[color=red]STACK EXPIRED: Stack #%d removed %d dice[/color]" % [stack_id, dice_removed])
	# Mimic game_controller._on_dice_stack_expired
	var new_count = turn_tracker.get_total_dice_count()
	dice_hand.dice_count = new_count
	dice_hand.update_dice_count()
	_log_message("Dice count adjusted to %d" % new_count)
	_update_status()


func _on_dice_bonus_changed(new_bonus: int) -> void:
	_log_message("[color=cyan]BONUS CHANGED: Total bonus now +%d[/color]" % new_bonus)
	_update_status()


func _on_turn_started() -> void:
	_log_message("[color=green]TURN STARTED: Turn %d[/color]" % turn_tracker.current_turn)
	_update_status()


func _on_temporary_effect_expired(effect_type: String) -> void:
	_log_message("[color=orange]EFFECT EXPIRED: %s[/color]" % effect_type)


func _update_status() -> void:
	if not status_label:
		return
	
	var physical_dice = dice_hand.dice_list.size()
	var logical_count = dice_hand.dice_count
	var tracker_count = turn_tracker.get_total_dice_count()
	var active_stacks = turn_tracker.dice_bonus_stacks.size()
	var total_bonus = turn_tracker.temporary_dice_bonus
	
	var status_text = "Turn: %d | Rolls Left: %d | Active: %s\n" % [turn_tracker.current_turn, turn_tracker.rolls_left, str(turn_tracker.is_active)]
	status_text += "Physical Dice: %d | Logical Count: %d | Tracker Count: %d\n" % [physical_dice, logical_count, tracker_count]
	status_text += "Active Stacks: %d | Total Bonus: +%d" % [active_stacks, total_bonus]
	
	# Show individual stacks
	if active_stacks > 0:
		status_text += "\n--- Active Stacks ---"
		for stack in turn_tracker.dice_bonus_stacks:
			status_text += "\n  Stack #%d: +%d dice, %d turns left" % [stack.id, stack.dice, stack.turns_remaining]
	
	status_label.text = status_text
	
	# Highlight mismatches in red
	if physical_dice != logical_count or logical_count != tracker_count:
		_log_message("[color=red]WARNING: Dice count mismatch! Physical=%d, Logical=%d, Tracker=%d[/color]" % [physical_dice, logical_count, tracker_count])


func _log_message(msg: String) -> void:
	var timestamp = "%.2f" % (Time.get_ticks_msec() / 1000.0)
	test_log.append("[%s] %s" % [timestamp, msg])
	print("[DiceSurgeTest] %s" % msg.replace("[color=", "").replace("[/color]", "").replace("]", ""))
	_update_log_display()


func _update_log_display() -> void:
	if not results_label:
		return
	
	# Show last 20 messages
	var display_log = test_log.slice(-20)
	results_label.text = "\n".join(display_log)


# === BUTTON HANDLERS ===

func _on_start_turn_pressed() -> void:
	_log_message("--- Starting New Turn ---")
	turn_tracker.start_new_turn()


func _on_grant_dice_surge_pressed() -> void:
	_log_message("--- Granting Dice Surge (+2 dice for 3 turns) ---")
	
	# Apply using TurnTracker directly (mimicking what consumable does)
	var current_count = dice_hand.dice_count
	var space_available = 16 - current_count
	var dice_to_add = mini(2, space_available)
	
	if dice_to_add <= 0:
		_log_message("[color=yellow]Already at max dice (16)[/color]")
		return
	
	# Add the stack
	var stack_id = turn_tracker.add_dice_bonus_stack(dice_to_add, 3)
	_log_message("Added stack #%d: +%d dice for 3 turns" % [stack_id, dice_to_add])
	
	# Update dice hand
	var new_count = turn_tracker.get_total_dice_count()
	dice_hand.dice_count = new_count
	dice_hand.update_dice_count()
	_log_message("Dice count now: %d" % new_count)
	_update_status()


func _on_grant_multiple_surges_pressed() -> void:
	_log_message("--- Granting 3x Dice Surge (edge case test) ---")
	
	for i in range(3):
		var current_count = dice_hand.dice_count
		var space_available = 16 - current_count
		var dice_to_add = mini(2, space_available)
		
		if dice_to_add <= 0:
			_log_message("[color=yellow]Reached max dice at stack %d[/color]" % i)
			break
		
		var stack_id = turn_tracker.add_dice_bonus_stack(dice_to_add, 3)
		var new_count = turn_tracker.get_total_dice_count()
		dice_hand.dice_count = new_count
		dice_hand.update_dice_count()
		_log_message("Stack #%d added: +%d dice" % [stack_id, dice_to_add])
	
	_update_status()


func _on_rapid_advance_pressed() -> void:
	_log_message("--- Rapid Turn Advance (5 turns) ---")
	
	for i in range(5):
		await get_tree().create_timer(0.3).timeout
		turn_tracker.start_new_turn()
	
	_log_message("Rapid advance complete")
	_update_status()


func _on_reset_test_pressed() -> void:
	_log_message("--- Resetting Test ---")
	
	# Reset turn tracker
	turn_tracker.reset()
	turn_tracker.is_active = false
	turn_tracker.current_turn = 0
	turn_tracker.rolls_left = 0
	
	# Reset dice hand to base 5
	dice_hand.dice_count = 5
	dice_hand.update_dice_count()
	
	test_log.clear()
	_log_message("[color=yellow]Test Reset - Ready for new test[/color]")
	_update_status()


func _on_force_expire_all_pressed() -> void:
	_log_message("--- Force Expiring All Stacks ---")
	
	var stacks_to_expire = turn_tracker.dice_bonus_stacks.duplicate()
	for stack in stacks_to_expire:
		turn_tracker.dice_bonus_stacks.erase(stack)
		turn_tracker.emit_signal("dice_stack_expired", stack.id, stack.dice)
	
	if stacks_to_expire.size() > 0:
		turn_tracker.emit_signal("dice_bonus_changed", 0)
		turn_tracker.emit_signal("temporary_effect_expired", "dice_bonus")
	
	_update_status()


func _on_verify_counts_pressed() -> void:
	_log_message("--- Verifying Dice Counts ---")
	
	var physical = dice_hand.dice_list.size()
	var logical = dice_hand.dice_count
	var tracker = turn_tracker.get_total_dice_count()
	var expected_base = 5
	var expected_bonus = turn_tracker.temporary_dice_bonus
	var expected_total = expected_base + expected_bonus
	
	_log_message("Physical dice in scene: %d" % physical)
	_log_message("DiceHand.dice_count: %d" % logical)
	_log_message("TurnTracker.get_total_dice_count(): %d" % tracker)
	_log_message("Expected (5 + %d bonus): %d" % [expected_bonus, expected_total])
	
	var all_match = (physical == logical) and (logical == tracker) and (tracker == expected_total)
	
	if all_match:
		_log_message("[color=green]✓ PASS: All dice counts match![/color]")
	else:
		_log_message("[color=red]✗ FAIL: Dice count mismatch detected![/color]")
		if physical != logical:
			_log_message("[color=red]  - Physical (%d) != Logical (%d)[/color]" % [physical, logical])
		if logical != tracker:
			_log_message("[color=red]  - Logical (%d) != Tracker (%d)[/color]" % [logical, tracker])
		if tracker != expected_total:
			_log_message("[color=red]  - Tracker (%d) != Expected (%d)[/color]" % [tracker, expected_total])
