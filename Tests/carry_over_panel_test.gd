extends Control

## CarryOverPanel Test
##
## Standalone test scene for verifying CarryOverPanel display, animations,
## checkbox selection logic, and signal emission.
## Run via: Godot editor or command line with this scene.

var carry_over_panel: CarryOverPanel
var output: RichTextLabel
var btn_container: HBoxContainer

# Preload the scene
const CARRY_OVER_SCENE = preload("res://Scenes/UI/CarryOverPanel.tscn")


func _ready() -> void:
	print("[CarryOverPanelTest] Starting tests...")
	_build_test_ui()
	_setup_carry_over_panel()


## _build_test_ui()
##
## Creates the test control buttons and output log.
func _build_test_ui() -> void:
	var vcr_font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Title margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	vbox.add_child(margin)

	var title_box = VBoxContainer.new()
	margin.add_child(title_box)

	var title = Label.new()
	title.text = "CARRYOVER PANEL TEST"
	title.add_theme_font_override("font", vcr_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	title_box.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Click a button to test different carry-over configurations"
	subtitle.add_theme_font_override("font", vcr_font)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	title_box.add_child(subtitle)

	# Button rows
	var btn_margin = MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_left", 20)
	btn_margin.add_theme_constant_override("margin_right", 20)
	vbox.add_child(btn_margin)

	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 6)
	btn_margin.add_child(btn_vbox)

	# Row 1 — main scenarios
	btn_container = HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 10)
	btn_vbox.add_child(btn_container)

	_add_button("5 of 7 (Ch2)", _test_full_selections, Color(0.3, 0.7, 0.3))
	_add_button("3 of 5 (Ch9)", _test_medium_selections, Color(0.3, 0.5, 0.8))
	_add_button("1 of 2 (Ch17)", _test_minimal_selections, Color(0.8, 0.6, 0.2))
	_add_button("0 / None (Ch18)", _test_zero_selections, Color(0.8, 0.3, 0.3))

	# Row 2 — edge cases
	var btn_container2 = HBoxContainer.new()
	btn_container2.add_theme_constant_override("separation", 10)
	btn_vbox.add_child(btn_container2)

	_add_button_to("2 of 7 (All Types)", _test_two_of_all, Color(0.6, 0.4, 0.8), btn_container2)
	_add_button_to("1 of 1 (Single)", _test_single_type, Color(0.4, 0.7, 0.7), btn_container2)

	# Output log
	var log_margin = MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 20)
	log_margin.add_theme_constant_override("margin_right", 20)
	log_margin.add_theme_constant_override("margin_bottom", 15)
	log_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(log_margin)

	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.scroll_following = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.add_theme_font_override("normal_font", vcr_font)
	output.add_theme_font_size_override("normal_font_size", 14)
	log_margin.add_child(output)

	_log("[color=gray]Ready. Click a test button above.[/color]")


## _setup_carry_over_panel()
##
## Instantiates the CarryOverPanel and wires up its signals.
func _setup_carry_over_panel() -> void:
	carry_over_panel = CARRY_OVER_SCENE.instantiate()
	add_child(carry_over_panel)
	carry_over_panel.carryover_confirmed.connect(_on_carryover_confirmed)
	carry_over_panel.panel_closed.connect(_on_panel_closed)
	_log("[color=green]CarryOverPanel instantiated and signals connected.[/color]")


func _on_carryover_confirmed(selected_types: Array[String]) -> void:
	if selected_types.size() == 0:
		_log("[color=yellow]CONFIRMED with no selections (full reset).[/color]")
	else:
		_log("[color=cyan]CONFIRMED carry-overs: %s[/color]" % str(selected_types))
	_log("[color=gray]---[/color]")


func _on_panel_closed() -> void:
	_log("[color=gray]Panel closed signal received.[/color]")


# ============ TEST SCENARIOS ============

func _test_full_selections() -> void:
	_log("\n[color=white]TEST: Channel 2 — 5 of 7 types available[/color]")
	var types: Array[String] = ["power_ups", "consumables", "colored_dice", "mods", "consoles", "money", "scorecard_levels"]
	carry_over_panel.show_panel(5, types, 2)


func _test_medium_selections() -> void:
	_log("\n[color=white]TEST: Channel 9 — 3 of 5 types available[/color]")
	var types: Array[String] = ["power_ups", "consumables", "colored_dice", "mods", "money"]
	carry_over_panel.show_panel(3, types, 9)


func _test_minimal_selections() -> void:
	_log("\n[color=white]TEST: Channel 17 — 1 of 2 types available[/color]")
	var types: Array[String] = ["power_ups", "money"]
	carry_over_panel.show_panel(1, types, 17)


func _test_zero_selections() -> void:
	_log("\n[color=white]TEST: Channel 18 — 0 selections (no carry-over)[/color]")
	var types: Array[String] = []
	carry_over_panel.show_panel(0, types, 18)


func _test_two_of_all() -> void:
	_log("\n[color=white]TEST: Edge case — 2 of ALL 7 types[/color]")
	var types: Array[String] = ["power_ups", "consumables", "colored_dice", "mods", "consoles", "money", "scorecard_levels"]
	carry_over_panel.show_panel(2, types, 5)


func _test_single_type() -> void:
	_log("\n[color=white]TEST: Edge case — 1 of 1 type (money only)[/color]")
	var types: Array[String] = ["money"]
	carry_over_panel.show_panel(1, types, 20)


# ============ HELPERS ============

func _add_button(text: String, callback: Callable, color: Color) -> void:
	_add_button_to(text, callback, color, btn_container)


func _add_button_to(text: String, callback: Callable, color: Color, parent: Control) -> void:
	var vcr_font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 40)
	btn.add_theme_font_override("font", vcr_font)
	btn.add_theme_font_size_override("font_size", 14)

	var style = StyleBoxFlat.new()
	style.bg_color = color * 0.4
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color * 0.6
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.pressed.connect(callback)
	parent.add_child(btn)


func _log(msg: String) -> void:
	output.append_text(msg + "\n")
	print("[CarryOverPanelTest] " + msg.replace("[color=", "").replace("[/color]", "").replace("]", ""))
