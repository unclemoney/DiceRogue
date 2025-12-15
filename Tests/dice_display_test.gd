extends Control

## DiceDisplayTest
##
## Test scene for the dice display refactoring.
## Tests centered positioning, multi-row support, varied entry/exit animations,
## and Roll button pulse effect.

@export var dice_hand_path: NodePath = ^"DiceHand"
@export var test_output_path: NodePath = ^"TestOutputPanel/TestOutput"

@onready var dice_hand: DiceHand = get_node(dice_hand_path)
@onready var test_output: RichTextLabel = get_node(test_output_path)

var test_results: Array[String] = []

func _ready() -> void:
	_log("=== Dice Display Refactoring Test ===")
	_log("Press number keys to test different dice counts:")
	_log("  1-8: Single row tests")
	_log("  9-0: Multi-row tests (9=9 dice, 0=16 dice)")
	_log("  E: Test exit animations")
	_log("  R: Respawn dice")
	_log("  P: Toggle Roll button pulse (simulated)")
	_log("")
	
	# Wait for dice_hand to be fully initialized
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Initial spawn with default dice count
	await get_tree().create_timer(0.5).timeout
	_log("Starting initial spawn test...")
	_test_spawn(5)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _test_spawn(1)
			KEY_2: _test_spawn(2)
			KEY_3: _test_spawn(3)
			KEY_4: _test_spawn(4)
			KEY_5: _test_spawn(5)
			KEY_6: _test_spawn(6)
			KEY_7: _test_spawn(7)
			KEY_8: _test_spawn(8)
			KEY_9: _test_spawn(9)
			KEY_0: _test_spawn(16)
			KEY_E: _test_exit()
			KEY_R: _test_respawn()
			KEY_P: _test_pulse()


func _test_spawn(count: int) -> void:
	_log("")
	_log("--- Testing spawn with " + str(count) + " dice ---")
	
	dice_hand.dice_count = count
	dice_hand.clear_dice()
	
	await get_tree().create_timer(0.2).timeout
	
	dice_hand.spawn_dice()
	
	await get_tree().create_timer(1.0).timeout
	
	# Verify positions
	_log("Spawned " + str(dice_hand.dice_list.size()) + " dice")
	
	if dice_hand.dice_list.size() > 0:
		var positions = []
		for die in dice_hand.dice_list:
			positions.append(str(die.position))
		
		# Check centering
		var sum_x = 0.0
		for die in dice_hand.dice_list:
			sum_x += die.position.x
		var avg_x = sum_x / dice_hand.dice_list.size()
		var center_offset = abs(avg_x - dice_hand.dice_area_center.x)
		
		if center_offset < 50:
			_log("[PASS] Dice are centered (avg_x: " + str(snapped(avg_x, 0.1)) + ")")
		else:
			_log("[FAIL] Dice not centered properly (avg_x: " + str(snapped(avg_x, 0.1)) + ", expected ~" + str(dice_hand.dice_area_center.x) + ")")
		
		# Check row distribution for multi-row
		if count > dice_hand.max_dice_per_row:
			var top_row_count = ceili(count / 2.0)
			var bottom_row_count = count - top_row_count
			_log("Expected distribution: " + str(top_row_count) + " top, " + str(bottom_row_count) + " bottom")
			
			# Count dice in each row based on Y position
			var y_positions = []
			for die in dice_hand.dice_list:
				y_positions.append(die.position.y)
			
			var unique_ys = []
			for y in y_positions:
				var found = false
				for uy in unique_ys:
					if abs(y - uy) < 10:
						found = true
						break
				if not found:
					unique_ys.append(y)
			
			_log("Found " + str(unique_ys.size()) + " rows")
			if unique_ys.size() == 2:
				_log("[PASS] Multi-row layout working")
			else:
				_log("[WARN] Expected 2 rows, found " + str(unique_ys.size()))


func _test_exit() -> void:
	_log("")
	_log("--- Testing exit animations ---")
	
	if dice_hand.dice_list.is_empty():
		_log("[SKIP] No dice to exit - spawn some first")
		return
	
	# Connect to exit signal
	if not dice_hand.is_connected("all_dice_exited", _on_all_dice_exited):
		dice_hand.all_dice_exited.connect(_on_all_dice_exited)
	
	dice_hand.animate_all_dice_exit()


func _on_all_dice_exited() -> void:
	_log("[PASS] All dice exit animations complete")


func _test_respawn() -> void:
	_log("")
	_log("--- Respawning dice ---")
	dice_hand.clear_dice()
	await get_tree().create_timer(0.2).timeout
	dice_hand.spawn_dice()
	_log("Respawned " + str(dice_hand.dice_count) + " dice with fresh animations")


func _test_pulse() -> void:
	_log("")
	_log("--- Roll button pulse test ---")
	_log("Note: Pulse is controlled by GameButtonUI")
	_log("This test simulates the effect description:")
	_log("  - Roll button should glow/pulse when waiting for first roll")
	_log("  - Pulse stops when Roll is pressed")
	_log("Run the full game scene to test this feature")


func _log(message: String) -> void:
	test_results.append(message)
	if test_output:
		test_output.text = "\n".join(test_results)
		# Auto-scroll to bottom
		test_output.scroll_to_line(test_output.get_line_count() - 1)
	print("[DiceDisplayTest] " + message)
