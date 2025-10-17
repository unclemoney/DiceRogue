extends Control

## DebugPanelTabsTest
##
## Test scene to verify the new tabbed debug panel layout works correctly.
## Run this scene to test the debug panel's tabbed organization.

func _ready() -> void:
	print("[DebugPanelTabsTest] Starting debug panel tabs test")
	
	# Create debug panel instance for testing
	var debug_panel = preload("res://Scenes/UI/DebugPanel.tscn").instantiate()
	add_child(debug_panel)
	
	# Show the panel immediately for testing
	debug_panel.show_debug_panel()
	
	# Log test information
	print("[DebugPanelTabsTest] Debug panel created and shown")
	print("[DebugPanelTabsTest] Press F12 to toggle panel")
	print("[DebugPanelTabsTest] Verify the following tabs exist:")
	print("  - Economy")
	print("  - Items") 
	print("  - Dice Control")
	print("  - Dice Colors")
	print("  - Testing")
	print("  - Game State")
	print("  - Utilities")
	
	# Test tab switching after a short delay
	await get_tree().create_timer(1.0).timeout
	_test_tab_accessibility(debug_panel)

func _test_tab_accessibility(debug_panel: DebugPanel) -> void:
	if not debug_panel.tab_container:
		print("[DebugPanelTabsTest] ERROR: TabContainer not found!")
		return
		
	var tab_count = debug_panel.tab_container.get_tab_count()
	print("[DebugPanelTabsTest] Found %d tabs" % tab_count)
	
	# Test each tab
	for i in range(tab_count):
		var tab_name = debug_panel.tab_container.get_tab_title(i)
		print("[DebugPanelTabsTest] Tab %d: %s" % [i, tab_name])
		
		# Switch to tab
		debug_panel.tab_container.current_tab = i
		await get_tree().process_frame
		
		# Check for buttons in this tab
		var tab_control = debug_panel.tab_container.get_tab_control(i)
		var button_count = _count_buttons_in_container(tab_control)
		print("[DebugPanelTabsTest]   - Contains %d buttons" % button_count)
	
	print("[DebugPanelTabsTest] Tab accessibility test completed")

func _count_buttons_in_container(container: Control) -> int:
	var count = 0
	for child in container.get_children():
		if child is Button:
			count += 1
		elif child.get_child_count() > 0:
			count += _count_buttons_in_container(child)
	return count

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				print("[DebugPanelTabsTest] Test completed, exiting...")
				get_tree().quit()
			KEY_F12:
				print("[DebugPanelTabsTest] F12 detected - debug panel should toggle")