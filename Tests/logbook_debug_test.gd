extends Control

## LogbookDebugTest
## 
## Test scene to debug logbook recording and display functionality.

var stats_panel: StatisticsPanel

func _ready():
	print("[LogbookDebugTest] Starting logbook debug test")
	
	# Create a simple UI
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	var title = Label.new()
	title.text = "Logbook Debug Test"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var create_entry_btn = Button.new()
	create_entry_btn.text = "Create Test Logbook Entry"
	create_entry_btn.pressed.connect(_create_test_entry)
	vbox.add_child(create_entry_btn)
	
	var check_entries_btn = Button.new()
	check_entries_btn.text = "Check Logbook Entries"
	check_entries_btn.pressed.connect(_check_logbook_entries)
	vbox.add_child(check_entries_btn)
	
	var open_stats_btn = Button.new()
	open_stats_btn.text = "Open Statistics Panel"
	open_stats_btn.pressed.connect(_open_statistics_panel)
	vbox.add_child(open_stats_btn)
	
	var refresh_stats_btn = Button.new()
	refresh_stats_btn.text = "Refresh Statistics Panel"
	refresh_stats_btn.pressed.connect(_refresh_statistics_panel)
	vbox.add_child(refresh_stats_btn)
	
	var close_btn = Button.new()
	close_btn.text = "Close Test"
	close_btn.pressed.connect(get_tree().quit)
	vbox.add_child(close_btn)
	
	# Load the statistics panel
	var stats_panel_scene = preload("res://Scenes/UI/StatisticsPanel.tscn")
	stats_panel = stats_panel_scene.instantiate()
	add_child(stats_panel)
	
	print("[LogbookDebugTest] Test UI created")

func _create_test_entry():
	print("[LogbookDebugTest] Creating test logbook entry")
	
	# Check if Statistics autoload is available
	var stats = get_node_or_null("/root/Statistics")
	if not stats:
		print("[LogbookDebugTest] ERROR: Statistics autoload not found!")
		return
	
	print("[LogbookDebugTest] Statistics autoload found, creating entry...")
	
	# Create a test entry with proper typing
	var dice_values: Array[int] = [1, 2, 3, 4, 5]
	var dice_colors: Array[String] = ["white", "white", "white", "white", "white"]
	var dice_mods: Array[String] = []
	var category: String = "large_straight"
	var section: String = "lower"
	var consumables: Array[String] = []
	var powerups: Array[String] = []
	var base_score: int = 40
	var effects: Array[Dictionary] = []
	var final_score: int = 40
	
	stats.log_hand_scored(
		dice_values,
		dice_colors,
		dice_mods,
		category,
		section,
		consumables,
		powerups,
		base_score,
		effects,
		final_score
	)
	
	print("[LogbookDebugTest] Test entry creation requested")
	
	# Wait a moment then refresh the statistics panel
	await get_tree().create_timer(0.1).timeout
	if stats_panel:
		print("[LogbookDebugTest] Refreshing statistics panel after entry creation")
		stats_panel._refresh_logbook_display()

func _check_logbook_entries():
	print("[LogbookDebugTest] Checking logbook entries")
	
	var stats = get_node_or_null("/root/Statistics")
	if not stats:
		print("[LogbookDebugTest] ERROR: Statistics autoload not found!")
		return
	
	var entries = stats.get_logbook_entries()
	print("[LogbookDebugTest] Found %d logbook entries" % entries.size())
	
	for i in range(entries.size()):
		var entry = entries[i]
		print("[LogbookDebugTest] Entry %d: %s" % [i + 1, entry.formatted_log_line])

func _open_statistics_panel():
	print("[LogbookDebugTest] Opening statistics panel")
	
	if stats_panel:
		stats_panel.toggle_visibility()
		print("[LogbookDebugTest] Statistics panel toggled")
	else:
		print("[LogbookDebugTest] ERROR: Statistics panel not available")

func _refresh_statistics_panel():
	print("[LogbookDebugTest] Refreshing statistics panel")
	
	if stats_panel:
		stats_panel._refresh_logbook_display()
		print("[LogbookDebugTest] Statistics panel logbook refreshed")
	else:
		print("[LogbookDebugTest] ERROR: Statistics panel not available")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_F10:
			_open_statistics_panel()