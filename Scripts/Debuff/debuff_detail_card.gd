extends Control
class_name DebuffDetailCard

## DebuffDetailCard
##
## Rich info card displayed on the SpineFanOverlay when debuff_container is clicked.
## Built entirely in code — no .tscn dependency.
##
## Layout (top → bottom inside a styled PanelContainer):
##   Icon · Name · separator · Difficulty stars · Description
##
## Public API:
##   setup(data) — call once after add_child

const DebuffVisualConfigScript = preload("res://Scripts/Debuff/debuff_visual_config.gd")
const CARD_SIZE := Vector2(248, 340)
const PANEL_BG := Color(0.12, 0.10, 0.14, 0.98)
const PANEL_BORDER := Color(0.42, 0.18, 0.16, 1.0)
const PANEL_HIGHLIGHT := Color(1.0, 0.46, 0.14, 0.94)
const LARGE_GLYPH_SHADER: Shader = preload("res://Scripts/Shaders/debuff_glyph_glow.gdshader")
const CARD_GLOW_SHADER: Shader = preload("res://Scripts/Shaders/debuff_card_glow.gdshader")

var _data: DebuffData
var _panel: PanelContainer
var _glow_rect: ColorRect
var _icon_rect: TextureRect
var _name_label: Label
var _diff_label: Label
var _desc_label: Label
var _separator: HSeparator
var _content_vbox: VBoxContainer
var _card_glow_material: ShaderMaterial
var _icon_material: ShaderMaterial
var _difficulty_tint: Color = Color(1.0, 1.0, 1.0)
var _mouse_uv: Vector2 = Vector2(0.5, 0.5)
var _proximity_strength: float = 0.0
var _active_strength: float = 0.38
var _pulse_strength: float = 0.0
var _pulse_tween: Tween
var _visual_config = DebuffVisualConfigScript.new()


static func get_card_size() -> Vector2:
	var visual_config = DebuffVisualConfigScript.new()
	return visual_config.detail_card_size


func _ready() -> void:
	var card_size: Vector2 = _visual_config.detail_card_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = card_size
	size = card_size
	_build_ui()
	_apply_layout_from_config()
	_apply_visual_state()


func _process(delta: float) -> void:
	_update_mouse_response(delta)


func _build_ui() -> void:
	var card_size: Vector2 = _visual_config.detail_card_size
	_glow_rect = ColorRect.new()
	_glow_rect.name = "GlowRect"
	_glow_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_glow_material = ShaderMaterial.new()
	_card_glow_material.shader = CARD_GLOW_SHADER
	_glow_rect.material = _card_glow_material
	add_child(_glow_rect)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = card_size
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(_visual_config.detail_panel_border_width)
	style.set_corner_radius_all(_visual_config.detail_panel_corner_radius)
	style.corner_detail = 8
	style.content_margin_left = _visual_config.detail_panel_margin_h
	style.content_margin_top = _visual_config.detail_panel_margin_v
	style.content_margin_right = _visual_config.detail_panel_margin_h
	style.content_margin_bottom = _visual_config.detail_panel_margin_v
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 9
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.name = "ContentVBox"
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content_vbox.add_theme_constant_override("separation", _visual_config.detail_content_separation)
	scroll.add_child(_content_vbox)

	var vcr_font := load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile

	# Large icon
	_icon_rect = TextureRect.new()
	_icon_rect.name = "IconRect"
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon_rect.custom_minimum_size = _visual_config.detail_icon_size
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_material = ShaderMaterial.new()
	_icon_material.shader = LARGE_GLYPH_SHADER
	_icon_rect.material = _icon_material
	_content_vbox.add_child(_icon_rect)

	# Name label
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		_name_label.add_theme_font_override("font", vcr_font)
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.44, 1.0))
	_content_vbox.add_child(_name_label)

	_add_separator(_content_vbox)

	# Difficulty label
	_diff_label = Label.new()
	_diff_label.name = "DiffLabel"
	_diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		_diff_label.add_theme_font_override("font", vcr_font)
	_diff_label.add_theme_font_size_override("font_size", 11)
	_diff_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56, 1.0))
	_content_vbox.add_child(_diff_label)

	# Description label
	_desc_label = Label.new()
	_desc_label.name = "DescLabel"
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		_desc_label.add_theme_font_override("font", vcr_font)
	_desc_label.add_theme_font_size_override("font_size", 10)
	_desc_label.add_theme_color_override("font_color", Color(0.90, 0.84, 0.78, 1.0))
	_content_vbox.add_child(_desc_label)


func set_visual_config(visual_config) -> void:
	if visual_config == null:
		return
	_visual_config = visual_config
	if _data:
		var tier: int = clamp(_data.difficulty_rating, 0, 5)
		_difficulty_tint = _visual_config.difficulty_tints[tier]
	if is_node_ready():
		_apply_layout_from_config()
		_apply_visual_state()


func _apply_layout_from_config() -> void:
	var card_size: Vector2 = _visual_config.detail_card_size
	custom_minimum_size = card_size
	size = card_size
	if _panel:
		_panel.custom_minimum_size = card_size
		var panel_style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
		if panel_style:
			panel_style.set_border_width_all(_visual_config.detail_panel_border_width)
			panel_style.set_corner_radius_all(_visual_config.detail_panel_corner_radius)
			panel_style.content_margin_left = _visual_config.detail_panel_margin_h
			panel_style.content_margin_top = _visual_config.detail_panel_margin_v
			panel_style.content_margin_right = _visual_config.detail_panel_margin_h
			panel_style.content_margin_bottom = _visual_config.detail_panel_margin_v
	if _content_vbox:
		_content_vbox.add_theme_constant_override("separation", _visual_config.detail_content_separation)
	if _icon_rect:
		_icon_rect.custom_minimum_size = _visual_config.detail_icon_size


func _add_separator(parent: VBoxContainer) -> void:
	_separator = HSeparator.new()
	_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = PANEL_HIGHLIGHT
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	_separator.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(_separator)


## setup(data)
##
## Populates the detail card with debuff data. Call once after add_child.
func setup(data: DebuffData) -> void:
	_data = data
	if not _panel:
		return

	var tier: int = clamp(data.difficulty_rating, 0, 5)
	_difficulty_tint = _visual_config.difficulty_tints[tier]

	if _icon_rect and data.icon:
		_icon_rect.texture = data.icon

	if _name_label:
		_name_label.text = data.display_name if data.display_name else data.id

	if _diff_label:
		_diff_label.text = "%s  Difficulty %d/5" % [_build_star_string(data.difficulty_rating), data.difficulty_rating]

	if _desc_label:
		_desc_label.text = data.description if data.description else ""

	_apply_visual_state()


func set_active_visual(active: bool) -> void:
	_active_strength = _visual_config.detail_active_glow if active else _visual_config.detail_inactive_glow
	_apply_visual_state()


func trigger_visual_pulse(strength: float = 1.0, duration: float = 0.48) -> void:
	var clamped_strength := clampf(strength, 0.0, 1.4)
	_set_pulse_strength(clamped_strength)
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(_set_pulse_strength, clamped_strength, 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build_star_string(difficulty: int) -> String:
	var clamped: int = clamp(difficulty, 0, 5)
	var result := ""
	for i in range(5):
		if i < clamped:
			result += "★"
		else:
			result += "☆"
	return result


func _set_pulse_strength(value: float) -> void:
	_pulse_strength = clampf(value, 0.0, 1.5)
	_apply_visual_state()


func _apply_visual_state() -> void:
	if _card_glow_material:
		_card_glow_material.set_shader_parameter("glow_color", _difficulty_tint)
		_card_glow_material.set_shader_parameter("glow_intensity", _visual_config.detail_card_glow_base + _get_tier_strength() * _visual_config.detail_card_glow_tier_gain)
		_card_glow_material.set_shader_parameter("proximity_strength", _proximity_strength)
		_card_glow_material.set_shader_parameter("active_strength", _active_strength)
		_card_glow_material.set_shader_parameter("pulse_strength", _pulse_strength)
		_card_glow_material.set_shader_parameter("mouse_uv", _mouse_uv)
		_card_glow_material.set_shader_parameter("rect_size", _visual_config.detail_card_size)
		_card_glow_material.set_shader_parameter("spread", _visual_config.detail_card_spread)
		_card_glow_material.set_shader_parameter("corner_radius", _visual_config.detail_card_corner_radius)
		_card_glow_material.set_shader_parameter("rim_width", _visual_config.detail_card_rim_width)
		_card_glow_material.set_shader_parameter("outer_halo_scale", _visual_config.detail_card_outer_halo_scale)
		_card_glow_material.set_shader_parameter("rim_halo_scale", _visual_config.detail_card_rim_halo_scale)
		_card_glow_material.set_shader_parameter("pointer_scale", _visual_config.detail_card_pointer_scale)
		_card_glow_material.set_shader_parameter("pulse_speed", _visual_config.detail_card_pulse_speed)
		_card_glow_material.set_shader_parameter("pulse_wobble", _visual_config.detail_card_pulse_wobble)

	if _icon_material:
		_icon_material.set_shader_parameter("glow_color", _difficulty_tint)
		_icon_material.set_shader_parameter("glow_intensity", _visual_config.detail_glow_intensity_base + _get_tier_strength() * _visual_config.detail_glow_intensity_tier_gain)
		_icon_material.set_shader_parameter("proximity_strength", minf(1.0, _proximity_strength * 1.15))
		_icon_material.set_shader_parameter("active_strength", _active_strength)
		_icon_material.set_shader_parameter("pulse_strength", _pulse_strength)
		_icon_material.set_shader_parameter("fill_brightness", _visual_config.detail_fill_brightness)
		_icon_material.set_shader_parameter("fill_expand_scale", _visual_config.detail_fill_expand_scale)
		_icon_material.set_shader_parameter("spread_plateau_scale", _visual_config.detail_spread_plateau_scale)
		_icon_material.set_shader_parameter("glyph_tint_strength", _visual_config.detail_glyph_tint_base + _get_tier_strength() * _visual_config.detail_glyph_tint_tier_gain)
		_icon_material.set_shader_parameter("mouse_uv", _mouse_uv)
		_icon_material.set_shader_parameter("inner_ring_radius", _visual_config.detail_glyph_inner_ring)
		_icon_material.set_shader_parameter("mid_ring_radius", _visual_config.detail_glyph_mid_ring)
		_icon_material.set_shader_parameter("outer_ring_radius", _visual_config.detail_glyph_outer_ring)
		_icon_material.set_shader_parameter("outer_glow_scale", _visual_config.detail_glyph_outer_scale)
		_icon_material.set_shader_parameter("rim_glow_scale", _visual_config.detail_glyph_rim_scale)
		_icon_material.set_shader_parameter("pointer_focus_falloff", _visual_config.detail_glyph_pointer_falloff)
		_icon_material.set_shader_parameter("pointer_glow_scale", _visual_config.detail_glyph_pointer_scale)
		_icon_material.set_shader_parameter("pulse_speed", _visual_config.detail_glyph_pulse_speed)
		_icon_material.set_shader_parameter("pulse_wobble", _visual_config.detail_glyph_pulse_wobble)
		_icon_material.set_shader_parameter("final_alpha_scale", _visual_config.detail_glyph_final_alpha_scale)

	if _panel:
		var style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			var border_mix := clampf(_proximity_strength * 0.3 + _active_strength * 0.45 + _pulse_strength * 0.55, 0.0, 1.0)
			style.border_color = PANEL_BORDER.lerp(_difficulty_tint, border_mix * 0.72)

	if _separator:
		var sep_style := _separator.get_theme_stylebox("separator") as StyleBoxFlat
		if sep_style:
			var accent_mix := clampf(_active_strength * 0.35 + _pulse_strength * 0.8, 0.0, 1.0)
			sep_style.bg_color = PANEL_HIGHLIGHT.lerp(_difficulty_tint, accent_mix * 0.82)


func _update_mouse_response(delta: float) -> void:
	if not is_visible_in_tree() or size.x <= 0.0 or size.y <= 0.0:
		_proximity_strength = lerpf(_proximity_strength, 0.0, clampf(delta * _visual_config.detail_proximity_lerp_speed, 0.0, 1.0))
		_apply_visual_state()
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var rect := Rect2(global_position, size)
	var rect_end := rect.position + rect.size
	var clamped_mouse := Vector2(
		clampf(mouse_pos.x, rect.position.x, rect_end.x),
		clampf(mouse_pos.y, rect.position.y, rect_end.y)
	)
	var local_mouse := clamped_mouse - rect.position
	var target_uv := Vector2(
		local_mouse.x / maxf(rect.size.x, 1.0),
		local_mouse.y / maxf(rect.size.y, 1.0)
	)
	var distance := mouse_pos.distance_to(clamped_mouse)
	var max_distance: float = maxf(rect.size.x, rect.size.y) * _visual_config.detail_proximity_distance_multiplier
	var target_proximity := 1.0 - clampf(distance / max_distance, 0.0, 1.0)
	target_proximity = pow(target_proximity, 0.88)

	_mouse_uv = _mouse_uv.lerp(target_uv, clampf(delta * _visual_config.detail_proximity_lerp_speed, 0.0, 1.0))
	_proximity_strength = lerpf(_proximity_strength, target_proximity, clampf(delta * _visual_config.detail_proximity_lerp_speed, 0.0, 1.0))
	_apply_visual_state()


func _get_tier_strength() -> float:
	if not _data:
		return 0.0
	return float(clamp(_data.difficulty_rating, 0, 5)) / 5.0
