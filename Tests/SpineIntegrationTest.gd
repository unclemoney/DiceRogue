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

	# Add mock spines and verify positioning
	var power_up_ui = game_ui.find_child("PowerUpUI", true, false)
	if power_up_ui:
		var mock_pu_data := PowerUpData.new()
		mock_pu_data.id = "test_power_up"
		mock_pu_data.display_name = "Test Power Up"
		mock_pu_data.description = "A test power up"
		mock_pu_data.rarity = "common"
		mock_pu_data.rating = "G"
		var spine = power_up_ui.add_power_up(mock_pu_data)
		await get_tree().create_timer(0.6).timeout
		if spine:
			# Compute axis-aligned bounding box of the rotated + scaled spine in parent space
			var sz: Vector2 = spine.size
			var pivot: Vector2 = spine.pivot_offset
			var pos: Vector2 = spine.position
			var sc: Vector2 = spine.scale
			var rot: Transform2D = Transform2D(deg_to_rad(spine.rotation_degrees), Vector2.ZERO)
			var corners: Array[Vector2] = [
				pos + rot * (sc * (Vector2(0, 0) - pivot)) + pivot,
				pos + rot * (sc * (Vector2(sz.x, 0) - pivot)) + pivot,
				pos + rot * (sc * (Vector2(0, sz.y) - pivot)) + pivot,
				pos + rot * (sc * (Vector2(sz.x, sz.y) - pivot)) + pivot,
			]
			var min_x := corners[0].x
			var max_x := corners[0].x
			var min_y := corners[0].y
			var max_y := corners[0].y
			for c in corners:
				min_x = min(min_x, c.x)
				max_x = max(max_x, c.x)
				min_y = min(min_y, c.y)
				max_y = max(max_y, c.y)
			var container_size: Vector2 = power_up_ui.size
			var in_bounds := min_x >= 0 and min_y >= 0 and max_x <= container_size.x and max_y <= container_size.y
			if in_bounds:
				print("[SpineIntegrationTest] ✓ PowerUp spine positioned inside container (AABB: (%s,%s)-(%s,%s) in %s)" % [min_x, min_y, max_x, max_y, container_size])
			else:
				# Allow small overflow for rotated spines
				var mostly_inside := min_x > -20 and min_y > -20 and max_x < container_size.x + 20 and max_y < container_size.y + 20
				if mostly_inside:
					print("[SpineIntegrationTest] ⚠ PowerUp spine slightly clipped (AABB: (%s,%s)-(%s,%s) in %s)" % [min_x, min_y, max_x, max_y, container_size])
				else:
					push_error("[SpineIntegrationTest] ✗ PowerUp spine OUT OF BOUNDS: AABB=(%s,%s)-(%s,%s) container=%s" % [min_x, min_y, max_x, max_y, container_size])
					all_passed = false
		else:
			push_error("[SpineIntegrationTest] ✗ PowerUp spine not created")
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
