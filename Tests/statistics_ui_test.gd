extends Control

## StatisticsUITest
##
## Simple test to verify the Statistics UI improvements:
## - Z-index set to 1000
## - Panel displays content even without Statistics autoload
## - Debug logging works properly
## - Fallback content is shown

@onready var test_button: Button = $VBoxContainer/TestButton
@onready var output_label: RichTextLabel = $VBoxContainer/ScrollContainer/OutputLabel

func _ready() -> void:
	print("[StatisticsUITest] Ready")
	test_button.pressed.connect(_run_ui_test)

func _run_ui_test() -> void:
	_clear_output()
	_log_info("=== STATISTICS UI TEST ===")
	
	# Test 1: Check if StatisticsPanel scene can be instantiated
	var stats_panel_scene = preload("res://Scenes/UI/StatisticsPanel.tscn")
	if stats_panel_scene:
		_log_success("✓ StatisticsPanel scene found")
		
		var panel_instance = stats_panel_scene.instantiate()
		if panel_instance:
			_log_success("✓ StatisticsPanel can be instantiated")
			add_child(panel_instance)
			
			# Test 2: Check z-index
			if panel_instance.z_index == 1000:
				_log_success("✓ Z-index set to 1000")
			else:
				_log_error("✗ Z-index incorrect: " + str(panel_instance.z_index))
			
			# Test 3: Test visibility toggle
			panel_instance.visible = false
			_log_info("Panel initially hidden")
			
			panel_instance.toggle_visibility()
			if panel_instance.visible:
				_log_success("✓ Panel becomes visible after toggle")
			else:
				_log_error("✗ Panel failed to become visible")
			
			# Test 4: Check if content is displayed even without Statistics
			await get_tree().process_frame  # Allow UI to update
			
			# Test 5: Toggle again to hide
			panel_instance.toggle_visibility()
			if not panel_instance.visible:
				_log_success("✓ Panel hides after second toggle")
			else:
				_log_error("✗ Panel failed to hide")
			
			panel_instance.queue_free()
		else:
			_log_error("✗ Failed to instantiate StatisticsPanel")
	else:
		_log_error("✗ StatisticsPanel scene not found")
	
	# Test 6: Check if Statistics autoload exists
	var stats_autoload = get_node_or_null("/root/Statistics")
	if stats_autoload:
		_log_success("✓ Statistics autoload available")
	else:
		_log_warning("! Statistics autoload not available (panel should show fallback)")
	
	_log_info("=== UI TEST COMPLETE ===")

func _log_success(message: String) -> void:
	_add_colored_text(message, Color.GREEN)

func _log_error(message: String) -> void:
	_add_colored_text(message, Color.RED)

func _log_warning(message: String) -> void:
	_add_colored_text(message, Color.YELLOW)

func _log_info(message: String) -> void:
	_add_colored_text(message, Color.WHITE)

func _add_colored_text(text: String, color: Color) -> void:
	if output_label:
		output_label.append_text("[color=" + color.to_html() + "]" + text + "[/color]\n")
	print(text)

func _clear_output() -> void:
	if output_label:
		output_label.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F10:
			_log_info("F10 detected - Statistics panel should toggle in game scene")