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
var _autorun_layout_repro := false
var _quit_after_run := false

# Mock GameController for Dice Surge to use
var mock_game_controller: Node = null


func _ready() -> void:
	print("\n=== DICE SURGE EXPIRY TEST ===")
	_parse_cmdline_args()
	_setup_mock_game_controller()
	_connect_signals()
	_update_status()
	_log_message("[color=yellow]Test Ready - Use buttons to test Dice Surge expiry[/color]")
	if _autorun_layout_repro:
		call_deferred("_autorun_layout_repro_test")


func _parse_cmdline_args() -> void:
	var user_args := OS.get_cmdline_user_args()
	_autorun_layout_repro = user_args.has("--layout-repro")
	_quit_after_run = user_args.has("--quit-after")


func _autorun_layout_repro_test() -> void:
	var layout_passed = await _run_layout_repro_test()
	var reset_passed = await _run_round_reset_expiry_test()
	var passed = layout_passed and reset_passed
	if _quit_after_run:
		get_tree().quit(0 if passed else 1)


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


func _on_run_layout_repro_pressed() -> void:
	await _run_layout_repro_test()


func _on_round_reset_expiry_pressed() -> void:
	await _run_round_reset_expiry_test()


## _run_round_reset_expiry_test() -> bool
##
## Regression test: DiceSurge used late in a round must not persist after the
## round rolls over. RoundManager.start_round() calls TurnTracker.reset(),
## which previously cleared dice_bonus_stacks silently, stranding the bonus
## dice in the hand forever. Verifies reset() now expires the stack and the
## hand returns to the base 5 dice.
func _run_round_reset_expiry_test() -> bool:
	_log_message("--- Running Round Reset Expiry Test ---")

	# Simulate a Dice Surge applied on a late turn of the round
	var stack_id = turn_tracker.add_dice_bonus_stack(2, 3)
	dice_hand.dice_count = turn_tracker.get_total_dice_count()
	dice_hand.update_dice_count()
	_log_message("Applied stack #%d: +2 dice (total %d)" % [stack_id, dice_hand.dice_count])

	# Round rollover: RoundManager calls turn_tracker.reset()
	turn_tracker.reset()
	await get_tree().create_timer(0.1).timeout

	var stacks_cleared = turn_tracker.dice_bonus_stacks.is_empty()
	var hand_reset = dice_hand.dice_count == 5
	var passed = stacks_cleared and hand_reset

	if passed:
		_log_message("[color=green]✓ PASS: Round reset expired Dice Surge, hand back to 5[/color]")
	else:
		_log_message("[color=red]✗ FAIL: After reset, dice_count=%d (expected 5), active stacks=%d (expected 0)[/color]" % [dice_hand.dice_count, turn_tracker.dice_bonus_stacks.size()])

	_update_status()
	return passed


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


## _run_layout_repro_test() -> bool
##
## Reproduces mid-turn hand growth while dice are idling, then verifies that
## the visible dice positions still match their assigned home positions.
func _run_layout_repro_test() -> bool:
	_log_message("--- Running Mid-Turn Layout Repro ---")
	await get_tree().process_frame
	await _reset_and_spawn_layout_repro_hand()

	dice_hand.roll_all()
	await dice_hand.roll_complete
	await get_tree().create_timer(0.45).timeout

	var first_pass = await _add_surge_and_verify_layout(2, 3, 7, "After first Dice Surge")
	var second_pass = await _add_surge_and_verify_layout(2, 3, 9, "After stacked Dice Surge")

	_expire_all_dice_bonus_stacks()
	await get_tree().create_timer(0.45).timeout
	var expiry_pass = _verify_layout_state(5, "After forced expiry")

	var passed = first_pass and second_pass and expiry_pass
	if passed:
		_log_message("[color=green]✓ PASS: Mid-turn Dice Surge layout stayed stable[/color]")
	else:
		_log_message("[color=red]✗ FAIL: Mid-turn Dice Surge layout drifted or overlapped[/color]")
	return passed


func _reset_and_spawn_layout_repro_hand() -> void:
	turn_tracker.reset()
	turn_tracker.is_active = false
	turn_tracker.current_turn = 0
	turn_tracker.rolls_left = 0
	dice_hand.reset_roll_count()
	dice_hand.dice_count = 5
	await dice_hand.spawn_dice()
	var spawn_wait = dice_hand.entry_duration + dice_hand.animation_stagger * max(0, dice_hand.dice_count - 1) + 0.2
	await get_tree().create_timer(spawn_wait).timeout
	_update_status()


func _add_surge_and_verify_layout(dice_to_add: int, turns: int, expected_count: int, label: String) -> bool:
	var previous_count = dice_hand.dice_list.size()
	var stack_id = turn_tracker.add_dice_bonus_stack(dice_to_add, turns)
	var new_count = turn_tracker.get_total_dice_count()
	dice_hand.dice_count = new_count
	dice_hand.update_dice_count()
	_log_message("Applied stack #%d: +%d dice (total %d)" % [stack_id, dice_to_add, new_count])
	await get_tree().create_timer(0.1).timeout
	await _roll_new_dice_from_index(previous_count)
	await get_tree().create_timer(0.45).timeout
	return _verify_layout_state(expected_count, label)


func _roll_new_dice_from_index(start_index: int) -> void:
	for i in range(start_index, dice_hand.dice_list.size()):
		if i >= dice_hand.dice_list.size():
			break
		var die = dice_hand.dice_list[i]
		if die is Dice:
			die.roll()
			await get_tree().create_timer(0.1).timeout


func _expire_all_dice_bonus_stacks() -> void:
	var stacks_to_expire = turn_tracker.dice_bonus_stacks.duplicate()
	for stack in stacks_to_expire:
		turn_tracker.dice_bonus_stacks.erase(stack)
		turn_tracker.emit_signal("dice_stack_expired", stack.id, stack.dice)

	if stacks_to_expire.size() > 0:
		turn_tracker.emit_signal("dice_bonus_changed", 0)
		turn_tracker.emit_signal("temporary_effect_expired", "dice_bonus")


func _verify_layout_state(expected_count: int, label: String) -> bool:
	var actual_count = dice_hand.dice_list.size()
	var expected_rows = _expected_row_count(expected_count)
	var visible_rows = _count_distinct_rows(false)
	var home_rows = _count_distinct_rows(true)
	var max_drift = _get_max_home_position_drift()
	var min_spacing = _get_min_die_spacing()
	var missing_data = _count_missing_dice_data()
	var passed = true

	if actual_count != expected_count:
		passed = false
		_log_message("[color=red]%s: expected %d dice, found %d[/color]" % [label, expected_count, actual_count])

	if visible_rows != expected_rows:
		passed = false
		_log_message("[color=red]%s: expected %d visible rows, found %d[/color]" % [label, expected_rows, visible_rows])

	if home_rows != expected_rows:
		passed = false
		_log_message("[color=red]%s: expected %d home rows, found %d[/color]" % [label, expected_rows, home_rows])

	if max_drift > 8.0:
		passed = false
		_log_message("[color=red]%s: max home-position drift %.2fpx exceeds tolerance[/color]" % [label, max_drift])

	if min_spacing < 40.0:
		passed = false
		_log_message("[color=red]%s: dice spacing collapsed to %.2fpx[/color]" % [label, min_spacing])

	if missing_data > 0:
		passed = false
		_log_message("[color=red]%s: %d dice were missing dice_data[/color]" % [label, missing_data])

	if passed:
		_log_message("[color=green]✓ %s: rows=%d drift=%.2f spacing=%.2f[/color]" % [label, visible_rows, max_drift, min_spacing])

	return passed


func _expected_row_count(count: int) -> int:
	if count <= dice_hand.max_dice_per_row:
		return 1
	if count <= dice_hand.max_dice_per_row * 2:
		return 2
	return 3


func _count_distinct_rows(use_home_position: bool) -> int:
	var row_values: Array[float] = []
	for die in dice_hand.dice_list:
		if not is_instance_valid(die):
			continue
		var sample_y = die.home_position.y if use_home_position else die.position.y
		row_values.append(sample_y)

	if row_values.is_empty():
		return 0

	row_values.sort()
	var row_count = 1
	var last_row_y = row_values[0]
	for i in range(1, row_values.size()):
		if absf(row_values[i] - last_row_y) > 10.0:
			row_count += 1
			last_row_y = row_values[i]
	return row_count


func _get_max_home_position_drift() -> float:
	var max_drift = 0.0
	for die in dice_hand.dice_list:
		if not is_instance_valid(die):
			continue
		max_drift = maxf(max_drift, die.position.distance_to(die.home_position))
	return max_drift


func _get_min_die_spacing() -> float:
	if dice_hand.dice_list.size() < 2:
		return 9999.0

	var min_spacing = 9999.0
	for i in range(dice_hand.dice_list.size()):
		var left_die = dice_hand.dice_list[i]
		if not is_instance_valid(left_die):
			continue
		for j in range(i + 1, dice_hand.dice_list.size()):
			var right_die = dice_hand.dice_list[j]
			if not is_instance_valid(right_die):
				continue
			min_spacing = minf(min_spacing, left_die.position.distance_to(right_die.position))
	return min_spacing


func _count_missing_dice_data() -> int:
	var missing_data = 0
	for die in dice_hand.dice_list:
		if is_instance_valid(die) and die.dice_data == null:
			missing_data += 1
	return missing_data
