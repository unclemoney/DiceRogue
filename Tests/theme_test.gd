extends Control

## theme_test.gd
## Simple test to verify themes are loading and applying correctly

func _ready() -> void:
	_test_hover_theme()
	_test_button_theme()

func _test_hover_theme() -> void:
	print("[ThemeTest] Testing hover theme...")
	
	# Create a test tooltip
	var tooltip = PanelContainer.new()
	var label = Label.new()
	label.text = "Test Hover Tooltip with Thick Border and Padding"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(200, 0)
	
	# Load and apply hover theme
	var hover_theme_path = "res://Resources/UI/powerup_hover_theme.tres"
	var hover_theme = load(hover_theme_path) as Theme
	if hover_theme:
		tooltip.theme = hover_theme
		print("[ThemeTest] Hover theme loaded successfully")
	else:
		print("[ThemeTest] ERROR: Could not load hover theme")
		
	tooltip.add_child(label)
	add_child(tooltip)
	tooltip.position = Vector2(50, 50)

func _test_button_theme() -> void:
	print("[ThemeTest] Testing button theme...")
	
	# Create test buttons
	var button1 = Button.new()
	button1.text = "SELL"
	button1.size = Vector2(80, 40)
	button1.position = Vector2(50, 150)
	
	var button2 = Button.new()
	button2.text = "USE"
	button2.size = Vector2(80, 40)
	button2.position = Vector2(150, 150)
	
	# Load and apply button theme
	var button_theme_path = "res://Resources/UI/action_button_theme.tres"
	var button_theme = load(button_theme_path) as Theme
	if button_theme:
		button1.theme = button_theme
		button2.theme = button_theme
		print("[ThemeTest] Button theme loaded successfully")
	else:
		print("[ThemeTest] ERROR: Could not load button theme")
	
	add_child(button1)
	add_child(button2)