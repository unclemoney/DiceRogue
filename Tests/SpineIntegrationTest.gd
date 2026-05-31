extends Node2D

## SpineIntegrationTest
##
## Test scene for verifying spine UIs integrate into GameUI containers.
## Checks that PowerUpUI, ChallengeUI, DebuffUI, ConsumableUI, and GamingConsoleUI
## are present inside their respective containers.

const SCREEN_WIDTH: float = 1280.0
const SCREEN_HEIGHT: float = 720.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	add_child(bg)

	var canvas := CanvasLayer.new()
	canvas.name = "UICanvasLayer"
	add_child(canvas)

	var game_ui := preload("res://Scenes/UI/GameUI.tscn").instantiate()
	game_ui.name = "GameUI"
	canvas.add_child(game_ui)

	# Verify all spine UIs exist by name search
	var checks := {
		"PowerUpUI": "PowerUpUI",
		"ChallengeUI": "ChallengeUI",
		"DebuffUI": "DebuffUI",
		"ConsumableUI": "ConsumableUI",
		"GamingConsoleUI": "GamingConsoleUI",
	}

	# Wait one frame for container layout to finish before checking
	await get_tree().process_frame

	var all_passed := true
	for node_name in checks.keys():
		var node = game_ui.find_child(node_name, true, false)
		if node:
			print("[SpineIntegrationTest] ✓ %s found (size: %s, visible: %s)" % [checks[node_name], node.size, node.visible])
		else:
			push_error("[SpineIntegrationTest] ✗ %s NOT FOUND" % checks[node_name])
			all_passed = false

	# Add mock power-ups and verify compact-row behavior
	var power_up_ui = game_ui.find_child("PowerUpUI", true, false) as PowerUpUI
	if power_up_ui:
		var click_event := InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		click_event.position = power_up_ui.size / 2.0
		click_event.global_position = power_up_ui.get_global_rect().get_center()

		power_up_ui._gui_input(click_event)
		await get_tree().process_frame
		if power_up_ui.get("_current_state") == PowerUpUI.State.SPINES:
			print("[SpineIntegrationTest] ✓ Empty PowerUp area does not fan out")
		else:
			push_error("[SpineIntegrationTest] ✗ Empty PowerUp area incorrectly fanned out")
			all_passed = false

		power_up_ui.max_power_ups = PowerUpUI.ABSOLUTE_MAX_POWER_UPS
		for i in range(6):
			var mock_pu_data := PowerUpData.new()
			mock_pu_data.id = "test_power_up_%d" % i
			mock_pu_data.display_name = "Test Power Up %d" % i
			mock_pu_data.description = "A test power up"
			mock_pu_data.rarity = "common"
			mock_pu_data.rating = "G"
			var mock_spine = power_up_ui.add_power_up(mock_pu_data)
			if not mock_spine:
				push_error("[SpineIntegrationTest] ✗ Failed to create mock PowerUp spine %d" % i)
				all_passed = false

		await get_tree().create_timer(0.8).timeout

		var owned_ids: Array[String] = power_up_ui.get_owned_power_up_ids()
		if owned_ids.size() == 6:
			print("[SpineIntegrationTest] ✓ PowerUpUI accepted 6 owned PowerUps after cap upgrade")
		else:
			push_error("[SpineIntegrationTest] ✗ Expected 6 owned PowerUps, got %d" % owned_ids.size())
			all_passed = false

		var spines_dict = power_up_ui.get("_spines")
		var visible_spines := 0
		var hidden_spines := 0
		for power_up_id in owned_ids:
			var spine: PowerUpSpine = spines_dict.get(power_up_id)
			if spine and spine.visible:
				visible_spines += 1
			elif spine:
				hidden_spines += 1

		if visible_spines == 5 and hidden_spines == 1:
			print("[SpineIntegrationTest] ✓ Compact row shows 5 visible PowerUps with overflow hidden behind slot 6")
		else:
			push_error("[SpineIntegrationTest] ✗ Unexpected compact row visibility counts: visible=%d hidden=%d" % [visible_spines, hidden_spines])
			all_passed = false

		var overflow_label = power_up_ui.find_child("OverflowLabel", true, false) as Label
		if overflow_label and overflow_label.visible and overflow_label.text == "+MORE":
			print("[SpineIntegrationTest] ✓ Overflow slot shows +MORE when owned PowerUps exceed 5")
		else:
			push_error("[SpineIntegrationTest] ✗ Overflow slot did not show +MORE correctly")
			all_passed = false

		power_up_ui._gui_input(click_event)
		await get_tree().create_timer(0.25).timeout
		if power_up_ui.get("_current_state") == PowerUpUI.State.FANNED:
			print("[SpineIntegrationTest] ✓ Owned PowerUp area fans out on click")
		else:
			push_error("[SpineIntegrationTest] ✗ Owned PowerUp area failed to fan out")
			all_passed = false

		power_up_ui.fold_back()
		await get_tree().create_timer(0.4).timeout
		if power_up_ui.get("_current_state") == PowerUpUI.State.SPINES:
			print("[SpineIntegrationTest] ✓ Fold-back returned PowerUpUI to compact row state")
		else:
			push_error("[SpineIntegrationTest] ✗ Fold-back did not restore compact row state")
			all_passed = false

	var consumable_ui = game_ui.find_child("ConsumableUI", true, false)
	if consumable_ui:
		var mock_con_data := ConsumableData.new()
		mock_con_data.id = "test_consumable"
		mock_con_data.display_name = "Test Consumable"
		mock_con_data.description = "A test consumable"
		var con_spine = consumable_ui.add_consumable(mock_con_data)
		await get_tree().create_timer(0.6).timeout
		if con_spine:
			var spine_pos: Vector2 = con_spine.position
			var container_size: Vector2 = consumable_ui.size
			var in_bounds: bool = spine_pos.x >= 0 and spine_pos.y >= 0 and spine_pos.x + con_spine.size.x <= container_size.x and spine_pos.y + con_spine.size.y <= container_size.y
			if in_bounds:
				print("[SpineIntegrationTest] ✓ Consumable spine positioned inside container (pos: %s size: %s in %s)" % [spine_pos, con_spine.size, container_size])
			else:
				push_error("[SpineIntegrationTest] ✗ Consumable spine OUT OF BOUNDS: pos=%s size=%s container=%s" % [spine_pos, con_spine.size, container_size])
				all_passed = false
		else:
			push_error("[SpineIntegrationTest] ✗ Consumable spine not created")
			all_passed = false

	if all_passed:
		print("[SpineIntegrationTest] All spine UIs integrated successfully.")
	else:
		push_error("[SpineIntegrationTest] Some spine UIs are missing or out of bounds!")

	# Auto-quit after 2 seconds so test can be run headless
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		print("[SpineIntegrationTest] Test complete - exiting.")
		get_tree().quit()
	)
