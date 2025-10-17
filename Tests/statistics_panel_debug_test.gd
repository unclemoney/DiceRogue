extends Control
class_name StatisticsPanelDebugTest

## StatisticsPanelDebugTest
## 
## Debug test to verify StatisticsPanel integration issues.

var game_controller: GameController

func _ready():
	print("\n=== STATISTICS PANEL DEBUG TEST ===")
	_test_scene_structure()
	_test_game_controller()
	_test_statistics_panel_direct()
	_test_f10_simulation()
	print("=== DEBUG TEST COMPLETE ===\n")

## _test_scene_structure()
## 
## Test the scene tree structure for StatisticsPanel.
func _test_scene_structure():
	print("\n--- Scene Structure Test ---")
	
	# Find root node
	var root = get_tree().current_scene
	print("Root scene: ", root.name, " (", root.get_class(), ")")
	
	# Look for StatisticsPanel in various locations
	var stats_panel_paths = [
		"StatisticsPanel",
		"./StatisticsPanel", 
		"../StatisticsPanel",
		"/root/Node2D/StatisticsPanel"
	]
	
	for path in stats_panel_paths:
		var node = get_node_or_null(path)
		if node:
			print("✓ Found StatisticsPanel at: ", path)
			print("  - Class: ", node.get_class())
			print("  - Visible: ", node.visible)
			print("  - Z-Index: ", node.z_index if node.has_method("get") else "N/A")
			break
		else:
			print("✗ No StatisticsPanel at: ", path)
	
	# List all children of root
	print("\nRoot children:")
	for child in root.get_children():
		print("  - ", child.name, " (", child.get_class(), ")")

## _test_game_controller()
## 
## Test GameController integration with StatisticsPanel.
func _test_game_controller():
	print("\n--- GameController Test ---")
	
	# Find GameController
	game_controller = get_node_or_null("../GameController")
	if not game_controller:
		game_controller = get_node_or_null("GameController")
	
	if game_controller:
		print("✓ Found GameController: ", game_controller.name)
		
		# Check if statistics_panel reference exists
		if game_controller.has_method("get") and "statistics_panel" in game_controller:
			var stats_ref = game_controller.statistics_panel
			if stats_ref:
				print("✓ GameController has StatisticsPanel reference")
				print("  - Panel visible: ", stats_ref.visible)
				print("  - Panel class: ", stats_ref.get_class())
			else:
				print("✗ GameController has null StatisticsPanel reference")
		else:
			print("✗ GameController missing statistics_panel property")
		
		# Check if toggle method exists
		if game_controller.has_method("_toggle_statistics_panel"):
			print("✓ GameController has _toggle_statistics_panel method")
		else:
			print("✗ GameController missing _toggle_statistics_panel method")
	else:
		print("✗ GameController not found")

## _test_statistics_panel_direct()
## 
## Test StatisticsPanel directly.
func _test_statistics_panel_direct():
	print("\n--- Direct StatisticsPanel Test ---")
	
	# Try to find StatisticsPanel directly
	var stats_panel = get_node_or_null("../StatisticsPanel")
	if not stats_panel:
		stats_panel = get_node_or_null("StatisticsPanel")
	
	if stats_panel:
		print("✓ Found StatisticsPanel directly: ", stats_panel.name)
		print("  - Initial visibility: ", stats_panel.visible)
		print("  - Has toggle_visibility method: ", stats_panel.has_method("toggle_visibility"))
		
		# Try to toggle it
		if stats_panel.has_method("toggle_visibility"):
			print("  - Attempting to toggle visibility...")
			stats_panel.toggle_visibility()
			print("  - After toggle visibility: ", stats_panel.visible)
			
			# Toggle back
			await get_tree().process_frame
			stats_panel.toggle_visibility()
			print("  - After second toggle: ", stats_panel.visible)
		
	else:
		print("✗ StatisticsPanel not found directly")

## _test_f10_simulation()
## 
## Test F10 key simulation.
func _test_f10_simulation():
	print("\n--- F10 Key Simulation Test ---")
	
	if game_controller:
		print("Simulating F10 key press...")
		
		# Create F10 key event
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_F10
		key_event.pressed = true
		
		# Send to GameController directly
		game_controller._unhandled_input(key_event)
		print("F10 event sent to GameController")
		
		# Check result
		await get_tree().process_frame
		if game_controller.statistics_panel:
			print("Panel visible after F10: ", game_controller.statistics_panel.visible)
		else:
			print("No statistics_panel reference in GameController")
	else:
		print("✗ Cannot test F10 - GameController not found")

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			print("\n[MANUAL] Space pressed - running tests again...")
			call_deferred("_ready")
		elif event.keycode == KEY_F10:
			print("\n[MANUAL] F10 pressed - detected in test scene")