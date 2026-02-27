extends Control

## tween_fx_test.gd
##
## Visual test scene for TweenFXHelper effects.
## Creates a grid of interactive elements to verify all TweenFX patterns.
## Run: & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/TweenFXTest.tscn

var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# Test elements
var _alarm_active := false
var _flicker_active := false
var _status_label: RichTextLabel
var _tfx: Node = null

func _ready() -> void:
	print("\n=== TWEENFX TEST ===")
	_tfx = get_node_or_null("/root/TweenFXHelper")
	
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Main layout
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "TweenFX Visual Test"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if vcr_font:
		title.add_theme_font_override("font", vcr_font)
		title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.32, 1.0))
	vbox.add_child(title)
	
	# Float the title
	_tfx.idle_float(title, 6.0)
	
	# Status label
	_status_label = RichTextLabel.new()
	_status_label.bbcode_enabled = true
	_status_label.fit_content = true
	_status_label.scroll_active = false
	_status_label.custom_minimum_size = Vector2(0, 30)
	if vcr_font:
		_status_label.add_theme_font_override("normal_font", vcr_font)
		_status_label.add_theme_font_size_override("normal_font_size", 14)
	_update_status("Hover over buttons, click to test effects")
	vbox.add_child(_status_label)
	
	# === ROW 1: Button Effects ===
	var row1_label = _create_section_label("BUTTON EFFECTS")
	vbox.add_child(row1_label)
	
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	vbox.add_child(row1)
	
	var btn_normal = _create_test_button("HOVER ME", Color(0.2, 0.5, 0.8))
	row1.add_child(btn_normal)
	btn_normal.mouse_entered.connect(_tfx.button_hover.bind(btn_normal))
	btn_normal.mouse_exited.connect(_tfx.button_unhover.bind(btn_normal))
	btn_normal.pressed.connect(_tfx.button_press.bind(btn_normal))
	btn_normal.pressed.connect(func(): _update_status("button_press fired!"))
	
	var btn_denied = _create_test_button("DENIED", Color(0.7, 0.2, 0.2))
	row1.add_child(btn_denied)
	btn_denied.mouse_entered.connect(_tfx.button_hover.bind(btn_denied))
	btn_denied.mouse_exited.connect(_tfx.button_unhover.bind(btn_denied))
	btn_denied.pressed.connect(func(): _tfx.button_denied(btn_denied); _update_status("button_denied fired!"))
	
	# === ROW 2: Idle Looping Effects ===
	var row2_label = _create_section_label("IDLE EFFECTS (always looping)")
	vbox.add_child(row2_label)
	
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 15)
	vbox.add_child(row2)
	
	var pulse_panel = _create_test_panel("PULSE", Color(0.3, 0.6, 0.3))
	row2.add_child(pulse_panel)
	_tfx.idle_pulse(pulse_panel, 0.06)
	
	var float_label = _create_test_label("FLOAT")
	row2.add_child(float_label)
	_tfx.idle_float(float_label, 8.0)
	
	var sway_panel = _create_test_panel("SWAY", Color(0.6, 0.3, 0.6))
	row2.add_child(sway_panel)
	_tfx.idle_sway(sway_panel, 5.0)
	
	var wiggle_panel = _create_test_panel("WIGGLE", Color(0.6, 0.6, 0.2))
	row2.add_child(wiggle_panel)
	_tfx.idle_wiggle(wiggle_panel)
	
	# === ROW 3: One-Shot Event Effects ===
	var row3_label = _create_section_label("EVENT EFFECTS (click to trigger)")
	vbox.add_child(row3_label)
	
	var row3 = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	vbox.add_child(row3)
	
	var hit_target = _create_test_panel("NEG HIT", Color(0.8, 0.3, 0.3))
	row3.add_child(hit_target)
	var hit_btn = _create_test_button("Fire", Color(0.5, 0.15, 0.15))
	row3.add_child(hit_btn)
	hit_btn.pressed.connect(func(): _tfx.negative_hit(hit_target); _update_status("negative_hit fired!"))
	
	var reward_target = _create_test_panel("REWARD", Color(0.8, 0.7, 0.2))
	row3.add_child(reward_target)
	var reward_btn = _create_test_button("Fire", Color(0.5, 0.4, 0.1))
	row3.add_child(reward_btn)
	reward_btn.pressed.connect(func(): _tfx.positive_reward(reward_target); _update_status("positive_reward fired!"))
	
	var celeb_target = _create_test_panel("TADA", Color(0.3, 0.7, 0.8))
	row3.add_child(celeb_target)
	var celeb_btn = _create_test_button("Fire", Color(0.15, 0.4, 0.5))
	row3.add_child(celeb_btn)
	celeb_btn.pressed.connect(func(): _tfx.celebration(celeb_target); _update_status("celebration fired!"))
	
	# === ROW 4: Spine-like Effects ===
	var row4_label = _create_section_label("SPINE EFFECTS (hover panels)")
	vbox.add_child(row4_label)
	
	var row4 = HBoxContainer.new()
	row4.add_theme_constant_override("separation", 15)
	vbox.add_child(row4)
	
	for spine_name in ["PowerUp", "Consumable", "Debuff", "Challenge"]:
		var spine_panel = _create_test_panel(spine_name, _get_spine_color(spine_name))
		spine_panel.custom_minimum_size = Vector2(80, 100)
		row4.add_child(spine_panel)
		
		spine_panel.mouse_entered.connect(func(): _tfx.spine_hover(spine_panel); _update_status("spine_hover: " + spine_name))
		spine_panel.mouse_exited.connect(func(): _tfx.spine_unhover(spine_panel); _update_status("spine_unhover: " + spine_name))
	
	# === ROW 5: Threat Effects ===
	var row5_label = _create_section_label("THREAT EFFECTS (click to start, click again to stop)")
	vbox.add_child(row5_label)
	
	var row5 = HBoxContainer.new()
	row5.add_theme_constant_override("separation", 10)
	vbox.add_child(row5)
	
	var alarm_panel = _create_test_panel("ALARM", Color(0.6, 0.15, 0.15))
	row5.add_child(alarm_panel)
	var alarm_btn = _create_test_button("Toggle", Color(0.4, 0.1, 0.1))
	row5.add_child(alarm_btn)
	alarm_btn.pressed.connect(func():
		_alarm_active = !_alarm_active
		if _alarm_active:
			_tfx.threat_alarm(alarm_panel)
			_update_status("threat_alarm started")
		else:
			_tfx.stop_effect(alarm_panel)
			_update_status("threat_alarm stopped")
	)
	
	var flicker_panel = _create_test_panel("FLICKER", Color(0.5, 0.5, 0.5))
	row5.add_child(flicker_panel)
	var flicker_btn = _create_test_button("Toggle", Color(0.3, 0.3, 0.3))
	row5.add_child(flicker_btn)
	flicker_btn.pressed.connect(func():
		_flicker_active = !_flicker_active
		if _flicker_active:
			_tfx.threat_flicker(flicker_panel)
			_update_status("threat_flicker started")
		else:
			_tfx.stop_effect(flicker_panel)
			_update_status("threat_flicker stopped")
	)
	
	print("[TweenFXTest] All test elements created")


func _create_test_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 40)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate() as StyleBoxFlat
	hover_style.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	if vcr_font:
		btn.add_theme_font_override("font", vcr_font)
		btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color.WHITE)
	
	return btn


func _create_test_panel(text: String, color: Color) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(90, 60)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
		label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	
	return panel


func _create_test_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(80, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
		label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	return label


func _create_section_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
		label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	return label


func _update_status(text: String) -> void:
	if _status_label:
		_status_label.text = "[color=cyan]> " + text + "[/color]"
	print("[TweenFXTest] ", text)


func _get_spine_color(spine_name: String) -> Color:
	match spine_name:
		"PowerUp":
			return Color(0.2, 0.5, 0.8)  # Blue
		"Consumable":
			return Color(0.3, 0.7, 0.3)  # Green
		"Debuff":
			return Color(0.7, 0.2, 0.2)  # Red
		"Challenge":
			return Color(0.8, 0.7, 0.2)  # Gold
		_:
			return Color(0.5, 0.5, 0.5)


func _exit_tree() -> void:
	# Let TweenFX clean up all looping effects
	for child in get_children():
		if child is CanvasItem:
			_tfx.stop_effect(child)
