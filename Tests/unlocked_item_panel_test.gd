extends Control

## UnlockedItemPanelTest
##
## Test scene for the UnlockedItemPanel UI component.
## Allows manual testing of the unlock panel with simulated unlocked items.

var unlocked_item_panel: Control = null
var test_item_ids: Array = []

# Test item data (uses REAL item IDs from ProgressManager)
var mock_items = [
	{"id": "extra_dice", "name": "Extra Dice", "type": "PowerUp"},
	{"id": "quick_cash", "name": "Quick Cash", "type": "Consumable"},
	{"id": "wild_card", "name": "Wild Card", "type": "Mod"},
	{"id": "evens_no_odds", "name": "Evens No Odds", "type": "PowerUp"},
	{"id": "step_by_step", "name": "Step By Step", "type": "PowerUp"},
]


func _ready() -> void:
	print("[UnlockedItemPanelTest] Initializing test scene")
	
	# Create the unlock panel
	var panel_scene = preload("res://Scenes/UI/UnlockedItemPanel.tscn")
	unlocked_item_panel = panel_scene.instantiate()
	add_child(unlocked_item_panel)
	
	# Connect signals
	unlocked_item_panel.item_acknowledged.connect(_on_item_acknowledged)
	unlocked_item_panel.all_items_acknowledged.connect(_on_all_acknowledged)
	
	# Build test UI
	_build_test_ui()
	
	print("[UnlockedItemPanelTest] Ready - use buttons to test unlock panel")


func _build_test_ui() -> void:
	# Create control panel
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 20)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	
	# Title
	var title = Label.new()
	title.text = "Unlock Panel Test"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Click buttons to test unlock panel behavior"
	instructions.add_theme_font_size_override("font_size", 12)
	content.add_child(instructions)
	
	var sep = HSeparator.new()
	content.add_child(sep)
	
	# Test single item button
	var btn_single = Button.new()
	btn_single.text = "Test Single Unlock"
	btn_single.custom_minimum_size = Vector2(200, 35)
	btn_single.pressed.connect(_test_single_unlock)
	content.add_child(btn_single)
	
	# Test multiple items button
	var btn_multiple = Button.new()
	btn_multiple.text = "Test Multiple Unlocks (3)"
	btn_multiple.custom_minimum_size = Vector2(200, 35)
	btn_multiple.pressed.connect(_test_multiple_unlocks)
	content.add_child(btn_multiple)
	
	# Test all items button
	var btn_all = Button.new()
	btn_all.text = "Test All Unlocks (5)"
	btn_all.custom_minimum_size = Vector2(200, 35)
	btn_all.pressed.connect(_test_all_unlocks)
	content.add_child(btn_all)
	
	# Debug unlock a real item
	var btn_debug = Button.new()
	btn_debug.text = "Debug: Unlock 'extra_dice'"
	btn_debug.custom_minimum_size = Vector2(200, 35)
	btn_debug.pressed.connect(_debug_unlock_item)
	content.add_child(btn_debug)
	
	# Status label
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Status: Waiting..."
	status_label.add_theme_font_size_override("font_size", 11)
	content.add_child(status_label)


func _test_single_unlock() -> void:
	print("[Test] Testing single unlock")
	_update_status("Testing single unlock...")
	unlocked_item_panel.queue_items([mock_items[0]["id"]])


func _test_multiple_unlocks() -> void:
	print("[Test] Testing multiple unlocks (3 items)")
	_update_status("Testing 3 unlocks...")
	var items = [mock_items[0]["id"], mock_items[1]["id"], mock_items[2]["id"]]
	unlocked_item_panel.queue_items(items)


func _test_all_unlocks() -> void:
	print("[Test] Testing all unlocks (5 items)")
	_update_status("Testing 5 unlocks...")
	var items: Array = []
	for item in mock_items:
		items.append(item["id"])
	unlocked_item_panel.queue_items(items)


func _debug_unlock_item() -> void:
	print("[Test] Debug unlocking 'extra_dice' via ProgressManager")
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager:
		progress_manager.debug_unlock_item("extra_dice")
		_update_status("Unlocked 'extra_dice' in ProgressManager")
	else:
		_update_status("ERROR: ProgressManager not found")


func _on_item_acknowledged() -> void:
	print("[Test] Item acknowledged")
	var remaining = unlocked_item_panel.get_remaining_count()
	_update_status("Item acknowledged. Remaining: %d" % remaining)


func _on_all_acknowledged() -> void:
	print("[Test] All items acknowledged!")
	_update_status("All items acknowledged! Panel closed.")


func _update_status(text: String) -> void:
	var status_label = get_node_or_null("PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/StatusLabel")
	if status_label:
		status_label.text = "Status: " + text
