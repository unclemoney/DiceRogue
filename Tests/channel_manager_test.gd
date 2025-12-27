extends Control

## ChannelManagerTest
##
## Test scene to verify ChannelManager functionality:
## - Difficulty multiplier calculation (quadratic formula)
## - Channel selection UI
## - RoundWinnerPanel display
## - Target score scaling

const ChannelManagerScript = preload("res://Scripts/Managers/channel_manager.gd")
const ChannelManagerUIScript = preload("res://Scripts/Managers/channel_manager_ui.gd")
const RoundWinnerPanelScript = preload("res://Scripts/UI/round_winner_panel.gd")

var channel_manager: Node
var channel_manager_ui: Control
var round_winner_panel: Control

var output_label: RichTextLabel
var test_results: Array[String] = []


func _ready() -> void:
	print("[ChannelManagerTest] Starting tests...")
	_build_test_ui()
	_create_channel_manager()
	_run_tests()


func _build_test_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 20)
	add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Channel Manager Test Suite"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(title)
	
	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Output area
	output_label = RichTextLabel.new()
	output_label.bbcode_enabled = true
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.add_theme_font_size_override("normal_font_size", 16)
	vbox.add_child(output_label)
	
	# Button container
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)
	
	# Test buttons
	var btn_show_selector = Button.new()
	btn_show_selector.text = "Show Channel Selector"
	btn_show_selector.pressed.connect(_on_show_selector_pressed)
	btn_hbox.add_child(btn_show_selector)
	
	var btn_show_winner = Button.new()
	btn_show_winner.text = "Show Winner Panel"
	btn_show_winner.pressed.connect(_on_show_winner_pressed)
	btn_hbox.add_child(btn_show_winner)
	
	var btn_run_tests = Button.new()
	btn_run_tests.text = "Run All Tests"
	btn_run_tests.pressed.connect(_run_tests)
	btn_hbox.add_child(btn_run_tests)


func _create_channel_manager() -> void:
	# Create ChannelManager
	channel_manager = ChannelManagerScript.new()
	channel_manager.name = "ChannelManager"
	add_child(channel_manager)
	
	# Create ChannelManagerUI
	var ui_scene = preload("res://Scenes/Managers/ChannelManagerUI.tscn")
	channel_manager_ui = ui_scene.instantiate()
	channel_manager_ui.set_channel_manager(channel_manager)
	channel_manager_ui.start_pressed.connect(_on_channel_start)
	add_child(channel_manager_ui)
	
	# Create RoundWinnerPanel
	var winner_scene = preload("res://Scenes/UI/RoundWinnerPanel.tscn")
	round_winner_panel = winner_scene.instantiate()
	round_winner_panel.set_channel_manager(channel_manager)
	round_winner_panel.next_channel_pressed.connect(_on_next_channel)
	add_child(round_winner_panel)


func _run_tests() -> void:
	test_results.clear()
	_log("[color=yellow]═══ Running Channel Manager Tests ═══[/color]\n")
	
	# Test 1: Difficulty multiplier formula
	_test_difficulty_multipliers()
	
	# Test 2: Channel clamping
	_test_channel_clamping()
	
	# Test 3: Target score scaling
	_test_target_score_scaling()
	
	# Test 4: Channel display text
	_test_display_text()
	
	# Summary
	_log("\n[color=yellow]═══ Test Summary ═══[/color]")
	var passed = test_results.filter(func(r): return r == "PASS").size()
	var total = test_results.size()
	_log("Passed: %d / %d" % [passed, total])
	
	if passed == total:
		_log("[color=green]All tests passed![/color]")
	else:
		_log("[color=red]Some tests failed.[/color]")


func _test_difficulty_multipliers() -> void:
	_log("\n[color=cyan]Test: Difficulty Multipliers (Quadratic Formula)[/color]")
	
	# Expected values based on formula: 1.0 + pow((channel - 1) / 98.0, 2) * 99.0
	var test_cases = [
		[1, 1.0],      # Channel 1: 1.0x
		[2, 1.0103],   # Channel 2: ~1.01x
		[10, 1.0836],  # Channel 10: ~1.08x
		[25, 6.0153],  # Channel 25: ~6.02x
		[50, 25.505],  # Channel 50: ~25.51x
		[75, 55.766],  # Channel 75: ~55.77x
		[99, 100.0]    # Channel 99: 100x
	]
	
	for test in test_cases:
		var channel = test[0] as int
		var expected = test[1] as float
		var actual = channel_manager.get_difficulty_multiplier(channel)
		var diff = abs(actual - expected)
		var passed = diff < 0.1
		
		var status = "[color=green]PASS[/color]" if passed else "[color=red]FAIL[/color]"
		test_results.append("PASS" if passed else "FAIL")
		_log("  Channel %2d: expected %.2fx, got %.2fx - %s" % [channel, expected, actual, status])


func _test_channel_clamping() -> void:
	_log("\n[color=cyan]Test: Channel Clamping[/color]")
	
	# Test lower bound
	channel_manager.set_channel(0)
	var lower_passed = channel_manager.current_channel == 1
	test_results.append("PASS" if lower_passed else "FAIL")
	_log("  set_channel(0): expected 1, got %d - %s" % [channel_manager.current_channel, _status(lower_passed)])
	
	# Test upper bound
	channel_manager.set_channel(150)
	var upper_passed = channel_manager.current_channel == 99
	test_results.append("PASS" if upper_passed else "FAIL")
	_log("  set_channel(150): expected 99, got %d - %s" % [channel_manager.current_channel, _status(upper_passed)])
	
	# Test valid value
	channel_manager.set_channel(42)
	var valid_passed = channel_manager.current_channel == 42
	test_results.append("PASS" if valid_passed else "FAIL")
	_log("  set_channel(42): expected 42, got %d - %s" % [channel_manager.current_channel, _status(valid_passed)])
	
	# Reset
	channel_manager.reset()


func _test_target_score_scaling() -> void:
	_log("\n[color=cyan]Test: Target Score Scaling[/color]")
	
	var base_score = 100
	
	var test_cases = [
		[1, 100],     # Channel 1: 100 * 1.0 = 100
		[10, 108],    # Channel 10: 100 * 1.08 = 108
		[50, 2551],   # Channel 50: 100 * 25.51 = 2551
		[99, 10000]   # Channel 99: 100 * 100 = 10000
	]
	
	for test in test_cases:
		var channel = test[0] as int
		var expected = test[1] as int
		var actual = channel_manager.get_scaled_target_score(base_score, channel)
		var diff = abs(actual - expected)
		var passed = diff <= 1  # Allow rounding difference
		
		test_results.append("PASS" if passed else "FAIL")
		_log("  Base %d @ Ch %2d: expected %d, got %d - %s" % [base_score, channel, expected, actual, _status(passed)])


func _test_display_text() -> void:
	_log("\n[color=cyan]Test: Channel Display Text[/color]")
	
	channel_manager.set_channel(1)
	var text1 = channel_manager.get_channel_display_text()
	var passed1 = text1 == "01"
	test_results.append("PASS" if passed1 else "FAIL")
	_log("  Channel 1: expected '01', got '%s' - %s" % [text1, _status(passed1)])
	
	channel_manager.set_channel(42)
	var text42 = channel_manager.get_channel_display_text()
	var passed42 = text42 == "42"
	test_results.append("PASS" if passed42 else "FAIL")
	_log("  Channel 42: expected '42', got '%s' - %s" % [text42, _status(passed42)])
	
	channel_manager.set_channel(99)
	var text99 = channel_manager.get_channel_display_text()
	var passed99 = text99 == "99"
	test_results.append("PASS" if passed99 else "FAIL")
	_log("  Channel 99: expected '99', got '%s' - %s" % [text99, _status(passed99)])
	
	# Reset
	channel_manager.reset()


func _status(passed: bool) -> String:
	return "[color=green]PASS[/color]" if passed else "[color=red]FAIL[/color]"


func _log(text: String) -> void:
	output_label.append_text(text + "\n")
	print(text.replace("[color=green]", "").replace("[color=red]", "").replace("[color=yellow]", "").replace("[color=cyan]", "").replace("[/color]", ""))


func _on_show_selector_pressed() -> void:
	_log("\n[color=yellow]Showing Channel Selector UI...[/color]")
	channel_manager.reset()
	channel_manager_ui.show_channel_selector()


func _on_show_winner_pressed() -> void:
	_log("\n[color=yellow]Showing Round Winner Panel...[/color]")
	var test_data = {
		"final_score": 350,
		"target_score": 300,
		"turns_used": 11,
		"current_channel": channel_manager.current_channel,
		"rounds_completed": 6
	}
	round_winner_panel.show_winner_panel(test_data)


func _on_channel_start(channel: int) -> void:
	_log("[color=green]Channel %d selected! Game would start now.[/color]" % channel)


func _on_next_channel() -> void:
	channel_manager.advance_to_next_channel()
	_log("[color=green]Advanced to Channel %d![/color]" % channel_manager.current_channel)
