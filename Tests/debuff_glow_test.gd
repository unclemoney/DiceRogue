extends Control
class_name DebuffGlowTest

const TEST_DEBUFF_PATHS: Array[String] = [
	"res://Scripts/Debuff/CostlyRollDebuff.tres",
	"res://Scripts/Debuff/TheDivisionDebuff.tres",
	"res://Scripts/Debuff/TooGreedyDebuff.tres",
	"res://Scripts/Debuff/DisabledTwosDebuff.tres",
	"res://Scripts/Debuff/LockDice.tres",
]
const DebuffVisualConfigScript = preload("res://Scripts/Debuff/debuff_visual_config.gd")

const RANGE_FIELDS: Dictionary = {
	"compact_icon_size": {"type": "vector2", "min": 16.0, "max": 96.0, "step": 1.0},
	"compact_proximity_distance_multiplier": {"type": "float", "min": 0.5, "max": 4.0, "step": 0.01},
	"compact_proximity_lerp_speed": {"type": "float", "min": 1.0, "max": 30.0, "step": 0.1},
	"compact_bg_tint_strength": {"type": "float", "min": 0.0, "max": 0.5, "step": 0.005},
	"compact_bg_alpha_gain": {"type": "float", "min": 0.0, "max": 0.5, "step": 0.005},
	"compact_glow_intensity_base": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"compact_glow_intensity_tier_gain": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"compact_fill_brightness": {"type": "float", "min": 0.0, "max": 2.0, "step": 0.01},
	"compact_fill_expand_scale": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"compact_spread_plateau_scale": {"type": "float", "min": 0.0, "max": 2.5, "step": 0.01},
	"compact_glyph_tint_base": {"type": "float", "min": 0.0, "max": 1.0, "step": 0.01},
	"compact_glyph_tint_tier_gain": {"type": "float", "min": 0.0, "max": 1.0, "step": 0.01},
	"compact_bg_proximity_weight": {"type": "float", "min": 0.0, "max": 2.0, "step": 0.01},
	"compact_bg_active_weight": {"type": "float", "min": 0.0, "max": 2.0, "step": 0.01},
	"compact_bg_pulse_weight": {"type": "float", "min": 0.0, "max": 2.0, "step": 0.01},
	"compact_active_glow": {"type": "float", "min": 0.0, "max": 2.0, "step": 0.01},
	"compact_active_pulse_strength": {"type": "float", "min": 0.0, "max": 2.0, "step": 0.01},
	"compact_active_pulse_duration": {"type": "float", "min": 0.05, "max": 2.0, "step": 0.01},
	"compact_glyph_inner_ring": {"type": "float", "min": 0.0, "max": 8.0, "step": 0.01},
	"compact_glyph_mid_ring": {"type": "float", "min": 0.0, "max": 12.0, "step": 0.01},
	"compact_glyph_outer_ring": {"type": "float", "min": 0.0, "max": 16.0, "step": 0.01},
	"compact_glyph_outer_scale": {"type": "float", "min": 0.0, "max": 4.0, "step": 0.01},
	"compact_glyph_rim_scale": {"type": "float", "min": 0.0, "max": 4.0, "step": 0.01},
	"compact_glyph_pointer_falloff": {"type": "float", "min": 0.1, "max": 30.0, "step": 0.1},
	"compact_glyph_pointer_scale": {"type": "float", "min": 0.0, "max": 4.0, "step": 0.01},
	"compact_glyph_pulse_speed": {"type": "float", "min": 0.0, "max": 20.0, "step": 0.1},
	"compact_glyph_pulse_wobble": {"type": "float", "min": 0.0, "max": 0.5, "step": 0.005},
	"compact_glyph_final_alpha_scale": {"type": "float", "min": 0.0, "max": 2.5, "step": 0.01},
	"detail_card_size": {"type": "vector2", "min": 160.0, "max": 420.0, "step": 1.0},
	"detail_icon_size": {"type": "vector2", "min": 48.0, "max": 260.0, "step": 1.0},
	"detail_content_separation": {"type": "int", "min": 0, "max": 32, "step": 1},
	"detail_proximity_distance_multiplier": {"type": "float", "min": 0.5, "max": 5.0, "step": 0.01},
	"detail_proximity_lerp_speed": {"type": "float", "min": 1.0, "max": 20.0, "step": 0.1},
	"detail_glow_intensity_base": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"detail_glow_intensity_tier_gain": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"detail_fill_brightness": {"type": "float", "min": 0.0, "max": 2.0, "step": 0.01},
	"detail_fill_expand_scale": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"detail_spread_plateau_scale": {"type": "float", "min": 0.0, "max": 2.5, "step": 0.01},
	"detail_glyph_tint_base": {"type": "float", "min": 0.0, "max": 1.0, "step": 0.01},
	"detail_glyph_tint_tier_gain": {"type": "float", "min": 0.0, "max": 1.0, "step": 0.01},
	"detail_active_glow": {"type": "float", "min": 0.0, "max": 2.0, "step": 0.01},
	"detail_inactive_glow": {"type": "float", "min": 0.0, "max": 1.0, "step": 0.01},
	"detail_panel_border_width": {"type": "int", "min": 1, "max": 16, "step": 1},
	"detail_panel_corner_radius": {"type": "int", "min": 0, "max": 48, "step": 1},
	"detail_panel_margin_h": {"type": "int", "min": 0, "max": 48, "step": 1},
	"detail_panel_margin_v": {"type": "int", "min": 0, "max": 48, "step": 1},
	"detail_fan_spacing": {"type": "float", "min": 120.0, "max": 420.0, "step": 1.0},
	"detail_viewport_padding": {"type": "float", "min": 0.0, "max": 160.0, "step": 1.0},
	"detail_entry_offset_y": {"type": "float", "min": 0.0, "max": 600.0, "step": 1.0},
	"detail_overlay_dim_alpha": {"type": "float", "min": 0.0, "max": 1.0, "step": 0.01},
	"detail_card_glow_base": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"detail_card_glow_tier_gain": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"detail_card_spread": {"type": "float", "min": 0.0, "max": 80.0, "step": 0.1},
	"detail_card_corner_radius": {"type": "float", "min": 0.0, "max": 64.0, "step": 0.1},
	"detail_card_rim_width": {"type": "float", "min": 0.0, "max": 24.0, "step": 0.1},
	"detail_card_outer_halo_scale": {"type": "float", "min": 0.0, "max": 2.5, "step": 0.01},
	"detail_card_rim_halo_scale": {"type": "float", "min": 0.0, "max": 2.5, "step": 0.01},
	"detail_card_pointer_scale": {"type": "float", "min": 0.0, "max": 2.0, "step": 0.01},
	"detail_card_pulse_speed": {"type": "float", "min": 0.0, "max": 20.0, "step": 0.1},
	"detail_card_pulse_wobble": {"type": "float", "min": 0.0, "max": 0.5, "step": 0.005},
	"detail_screen_glow_strength": {"type": "float", "min": 0.0, "max": 8.0, "step": 0.01},
	"detail_screen_glow_threshold": {"type": "float", "min": 0.0, "max": 1.5, "step": 0.01},
	"detail_screen_glow_saturation_threshold": {"type": "float", "min": 0.0, "max": 1.0, "step": 0.01},
	"detail_screen_glow_radius_steps": {"type": "int", "min": 1, "max": 16, "step": 1},
	"detail_screen_glow_spread": {"type": "float", "min": 0.0, "max": 32.0, "step": 0.1},
	"detail_screen_glow_lod_bias_scale": {"type": "float", "min": 0.0, "max": 1.5, "step": 0.01},
	"detail_screen_glow_source_boost": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"detail_screen_glow_alpha_strength": {"type": "float", "min": 0.0, "max": 3.0, "step": 0.01},
	"detail_glyph_inner_ring": {"type": "float", "min": 0.0, "max": 8.0, "step": 0.01},
	"detail_glyph_mid_ring": {"type": "float", "min": 0.0, "max": 12.0, "step": 0.01},
	"detail_glyph_outer_ring": {"type": "float", "min": 0.0, "max": 16.0, "step": 0.01},
	"detail_glyph_outer_scale": {"type": "float", "min": 0.0, "max": 4.0, "step": 0.01},
	"detail_glyph_rim_scale": {"type": "float", "min": 0.0, "max": 4.0, "step": 0.01},
	"detail_glyph_pointer_falloff": {"type": "float", "min": 0.1, "max": 30.0, "step": 0.1},
	"detail_glyph_pointer_scale": {"type": "float", "min": 0.0, "max": 4.0, "step": 0.01},
	"detail_glyph_pulse_speed": {"type": "float", "min": 0.0, "max": 20.0, "step": 0.1},
	"detail_glyph_pulse_wobble": {"type": "float", "min": 0.0, "max": 0.5, "step": 0.005},
	"detail_glyph_final_alpha_scale": {"type": "float", "min": 0.0, "max": 2.5, "step": 0.01},
}

const COLOR_FIELDS: Array[String] = [
	"compact_bg_base_color",
]

var _debuff_ui: DebuffUI
var _status_label: Label
var _demo_timer: Timer
var _test_ids: Array[String] = []
var _test_debuffs: Dictionary = {}
var _demo_index: int = 0
var _visual_config = DebuffVisualConfigScript.new()
var _control_panel: PanelContainer
var _control_list: VBoxContainer


func _ready() -> void:
	_build_ui()
	await get_tree().process_frame
	_populate_test_debuffs()
	_start_demo_cycle()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.04, 0.05, 0.08, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_preset(Control.PRESET_CENTER)
	layout.offset_left = -280
	layout.offset_top = -190
	layout.offset_right = 280
	layout.offset_bottom = 190
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 16)
	add_child(layout)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Debuff Glow Test"
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)

	var instructions := Label.new()
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.text = "Click the debuff row to open the fan-out cards. Move the mouse near chips and cards to test proximity glow. The timer will pulse one debuff at a time."
	instructions.custom_minimum_size = Vector2(520, 0)
	layout.add_child(instructions)

	var content_row := HBoxContainer.new()
	content_row.name = "ContentRow"
	content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_row.add_theme_constant_override("separation", 20)
	layout.add_child(content_row)

	var preview_column := VBoxContainer.new()
	preview_column.name = "PreviewColumn"
	preview_column.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_column.add_theme_constant_override("separation", 16)
	content_row.add_child(preview_column)

	_debuff_ui = DebuffUI.new()
	_debuff_ui.custom_minimum_size = Vector2(360, 86)
	_debuff_ui.size = Vector2(360, 86)
	_debuff_ui.set_visual_config(_visual_config)
	preview_column.add_child(_debuff_ui)

	_control_panel = _create_control_panel()
	content_row.add_child(_control_panel)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10)
	preview_column.add_child(button_row)

	button_row.add_child(_create_button("Pulse All", _pulse_all_debuffs))
	button_row.add_child(_create_button("Pulse Costly", _pulse_costly_roll))
	button_row.add_child(_create_button("Reset Demo", _reset_demo_cycle))
	button_row.add_child(_create_button("Toggle Fan", _toggle_fan))

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(520, 0)
	_status_label.text = "Waiting for debuffs..."
	preview_column.add_child(_status_label)

	_demo_timer = Timer.new()
	_demo_timer.wait_time = 1.5
	_demo_timer.autostart = false
	_demo_timer.one_shot = false
	_demo_timer.timeout.connect(_on_demo_timer_timeout)
	add_child(_demo_timer)

	_build_live_controls()


func _create_control_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 520)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.09, 0.12, 0.92)
	panel_style.border_color = Color(0.44, 0.28, 0.18, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Live Glow Config"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var help := Label.new()
	help.text = "Adjust values live. Use Toggle Fan to compare compact and fan-out states."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(help)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(396, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_control_list = VBoxContainer.new()
	_control_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_control_list)
	return panel


func _build_live_controls() -> void:
	for field_name in COLOR_FIELDS:
		_control_list.add_child(_build_color_control(field_name))
	for field_name in RANGE_FIELDS.keys():
		_control_list.add_child(_build_numeric_control(field_name, RANGE_FIELDS[field_name]))


func _build_numeric_control(field_name: String, meta: Dictionary) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.text = field_name
	name_label.add_theme_font_size_override("font_size", 12)
	wrapper.add_child(name_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrapper.add_child(row)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(92, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = meta.min
	slider.max_value = meta.max
	slider.step = meta.step
	row.add_child(slider)

	if meta.type == "vector2":
		var current_vec: Vector2 = _visual_config.get(field_name)
		slider.value = current_vec.x
		value_label.text = "%.0f, %.0f" % [current_vec.x, current_vec.y]
		slider.value_changed.connect(func(new_value: float):
			var next_vec := Vector2(new_value, new_value)
			_visual_config.set(field_name, next_vec)
			value_label.text = "%.0f, %.0f" % [next_vec.x, next_vec.y]
			_apply_live_config_changes()
		)
	elif meta.type == "int":
		slider.value = int(_visual_config.get(field_name))
		value_label.text = str(int(slider.value))
		slider.value_changed.connect(func(new_value: float):
			var next_value := int(round(new_value))
			_visual_config.set(field_name, next_value)
			value_label.text = str(next_value)
			_apply_live_config_changes()
		)
	else:
		slider.value = float(_visual_config.get(field_name))
		value_label.text = _format_float(slider.value)
		slider.value_changed.connect(func(new_value: float):
			_visual_config.set(field_name, new_value)
			value_label.text = _format_float(new_value)
			_apply_live_config_changes()
		)

	return wrapper


func _build_color_control(field_name: String) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.text = field_name
	name_label.add_theme_font_size_override("font_size", 12)
	wrapper.add_child(name_label)

	var color_value: Color = _visual_config.get(field_name)
	for component_name in ["r", "g", "b", "a"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		wrapper.add_child(row)

		var component_label := Label.new()
		component_label.text = component_name.to_upper()
		component_label.custom_minimum_size = Vector2(20, 0)
		row.add_child(component_label)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(56, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)

		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = _get_color_component(color_value, component_name)
		value_label.text = _format_float(slider.value)
		row.add_child(slider)

		slider.value_changed.connect(func(new_value: float):
			var next_color: Color = _visual_config.get(field_name)
			next_color = _set_color_component(next_color, component_name, new_value)
			_visual_config.set(field_name, next_color)
			value_label.text = _format_float(new_value)
			_apply_live_config_changes()
		)

	return wrapper


func _format_float(value: float) -> String:
	return "%.2f" % value


func _get_color_component(color_value: Color, component_name: String) -> float:
	match component_name:
		"r":
			return color_value.r
		"g":
			return color_value.g
		"b":
			return color_value.b
		"a":
			return color_value.a
	return 0.0


func _set_color_component(color_value: Color, component_name: String, value: float) -> Color:
	match component_name:
		"r":
			color_value.r = value
		"g":
			color_value.g = value
		"b":
			color_value.b = value
		"a":
			color_value.a = value
	return color_value


func _apply_live_config_changes() -> void:
	if _debuff_ui:
		_debuff_ui.set_visual_config(_visual_config)
	if _status_label:
		_status_label.text = "Updated live config"


func _toggle_fan() -> void:
	if _debuff_ui:
		_debuff_ui.toggle_fan_out()


func _create_button(text: String, pressed_callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed_callable)
	return button


func _populate_test_debuffs() -> void:
	for resource_path in TEST_DEBUFF_PATHS:
		var data := load(resource_path) as DebuffData
		if not data:
			push_error("[DebuffGlowTest] Failed to load DebuffData at %s" % resource_path)
			continue
		var debuff_instance: Debuff = null
		if data.scene:
			debuff_instance = data.scene.instantiate() as Debuff
		var icon := _debuff_ui.add_debuff(data, debuff_instance)
		if icon:
			if debuff_instance:
				_test_debuffs[data.id] = debuff_instance
				debuff_instance.emit_signal("debuff_started")
			else:
				icon.set_active(true)
			_test_ids.append(data.id)

	if _test_ids.is_empty():
		_status_label.text = "Failed to load test debuffs."
	else:
		_status_label.text = "Loaded debuffs: %s" % ", ".join(_test_ids)


func _start_demo_cycle() -> void:
	if _test_ids.is_empty():
		return
	_demo_index = 0
	_demo_timer.start()
	_on_demo_timer_timeout()


func _reset_demo_cycle() -> void:
	_status_label.text = "Resetting pulse cycle"
	_start_demo_cycle()


func _pulse_all_debuffs() -> void:
	if _test_ids.is_empty():
		return
	for debuff_id in _test_ids:
		_request_test_pulse(debuff_id, 1.0, 0.55)
	_status_label.text = "Pulsed all debuffs"


func _pulse_costly_roll() -> void:
	if not _test_ids.has("costly_roll"):
		_status_label.text = "Costly Roll debuff not loaded"
		return
	_request_test_pulse("costly_roll", 1.12, 0.6)
	_status_label.text = "Pulsed costly_roll"


func _on_demo_timer_timeout() -> void:
	if _test_ids.is_empty():
		_demo_timer.stop()
		return
	var debuff_id: String = _test_ids[_demo_index % _test_ids.size()]
	_request_test_pulse(debuff_id, 0.92, 0.52)
	_status_label.text = "Demo pulse: %s" % debuff_id
	_demo_index += 1


func _request_test_pulse(debuff_id: String, strength: float, duration: float) -> void:
	var debuff_instance := _test_debuffs.get(debuff_id) as Debuff
	if debuff_instance:
		debuff_instance.request_visual_pulse(strength, duration)
		return
	_debuff_ui.trigger_debuff_visual_pulse(debuff_id, strength, duration)