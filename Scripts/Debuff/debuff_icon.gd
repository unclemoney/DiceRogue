extends Control
class_name DebuffIcon

## DebuffIcon
##
## Compact chip-style UI for a single debuff displayed inside debuff_container.
## Shows: debuff icon art, name label, difficulty stars.
## All hover/shader/physics effects removed. mouse_filter = IGNORE so
## DebuffUI intercepts all input.

@warning_ignore("unused_signal")
signal debuff_selected(id: String)

@export var data: DebuffData

const COMPACT_GLYPH_SHADER: Shader = preload("res://Scripts/Shaders/debuff_glyph_glow.gdshader")
const DebuffVisualConfigScript = preload("res://Scripts/Debuff/debuff_visual_config.gd")
const CHIP_SIZE := Vector2(60, 64)

var _bg_rect: ColorRect
var _icon_rect: TextureRect
var _name_label: Label
var _diff_label: Label
var _icon_material: ShaderMaterial
var _difficulty_tint: Color = Color(1.0, 1.0, 1.0)
var _base_bg_color: Color = Color(0.14, 0.12, 0.18, 0.85)
var _mouse_uv: Vector2 = Vector2(0.5, 0.5)
var _proximity_strength: float = 0.0
var _active_strength: float = 0.0
var _pulse_strength: float = 0.0
var _visual_config = DebuffVisualConfigScript.new()

var is_active := false
var _current_tween: Tween

func _ready() -> void:
	custom_minimum_size = CHIP_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color.WHITE
	_build_ui()
	_apply_data_to_ui()
	_apply_shader_state()
	_apply_background_state()


func _process(delta: float) -> void:
	_update_mouse_response(delta)


func _build_ui() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.name = "BgRect"
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color(0.10, 0.08, 0.14, 0.85)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4
	vbox.offset_top = 4
	vbox.offset_right = -4
	vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var vcr_font := load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile

	_icon_rect = TextureRect.new()
	_icon_rect.name = "IconRect"
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_rect.custom_minimum_size = _visual_config.compact_icon_size
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_material = ShaderMaterial.new()
	_icon_material.shader = COMPACT_GLYPH_SHADER
	_icon_rect.material = _icon_material
	vbox.add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vcr_font:
		_name_label.add_theme_font_override("font", vcr_font)
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	_name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	#vbox.add_child(_name_label)
	# Temporarily hide the name label to reduce visual clutter. Can be re-enabled if needed.

	_diff_label = Label.new()
	_diff_label.name = "DiffLabel"
	_diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_diff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vcr_font:
		_diff_label.add_theme_font_override("font", vcr_font)
	_diff_label.add_theme_font_size_override("font_size", 9)
	_diff_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	vbox.add_child(_diff_label)


func _apply_data_to_ui() -> void:
	if not data:
		return

	if _name_label:
		_name_label.text = data.display_name if data.display_name else data.id

	if _diff_label:
		_diff_label.text = _build_star_string(data.difficulty_rating)

	if _icon_rect:
		if data.icon:
			_icon_rect.texture = data.icon

	if _bg_rect:
		var tier: int = clamp(data.difficulty_rating, 0, 5)
		_difficulty_tint = _visual_config.difficulty_tints[tier]
		_base_bg_color = _visual_config.compact_bg_base_color
		_apply_shader_state()
		_apply_background_state()


func _build_star_string(difficulty: int) -> String:
	var clamped: int = clamp(difficulty, 0, 5)
	var result := ""
	for i in range(5):
		if i < clamped:
			result += "★"
		else:
			result += "☆"
	return result


## set_data(new_data)
##
## Updates the icon with a new DebuffData resource.
func set_data(new_data: DebuffData) -> void:
	data = new_data
	_apply_data_to_ui()
	_apply_shader_state()


## trigger_visual_pulse(strength, duration)
##
## Fires a temporary neon pulse on the glyph while preserving the monochrome core art.
func trigger_visual_pulse(strength: float = 1.0, duration: float = 0.42) -> void:
	var clamped_strength := clampf(strength, 0.0, 1.4)
	_set_pulse_strength(clamped_strength)
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = create_tween()
	_current_tween.tween_method(_set_pulse_strength, clamped_strength, 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func get_difficulty_tint() -> Color:
	return _difficulty_tint


## set_active(active)
##
## Applies a red modulate tint when the debuff is active, white when inactive.
func set_active(active: bool) -> void:
	is_active = active
	var target_strength: float = 0.0
	if active:
		target_strength = _visual_config.compact_active_glow
	var start_strength := _active_strength
	var tween := create_tween()
	tween.tween_method(_set_active_strength, start_strength, target_strength, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if active:
		trigger_visual_pulse(_visual_config.compact_active_pulse_strength, _visual_config.compact_active_pulse_duration)


func _set_active_strength(value: float) -> void:
	_active_strength = clampf(value, 0.0, 1.0)
	_apply_shader_state()
	_apply_background_state()


func _set_pulse_strength(value: float) -> void:
	_pulse_strength = clampf(value, 0.0, 1.5)
	_apply_shader_state()
	_apply_background_state()


func _apply_shader_state() -> void:
	if not _icon_material:
		return
	var tier_strength := _get_tier_strength()
	_icon_material.set_shader_parameter("glow_color", _difficulty_tint)
	_icon_material.set_shader_parameter("glow_intensity", _visual_config.compact_glow_intensity_base + tier_strength * _visual_config.compact_glow_intensity_tier_gain)
	_icon_material.set_shader_parameter("proximity_strength", _proximity_strength)
	_icon_material.set_shader_parameter("active_strength", _active_strength)
	_icon_material.set_shader_parameter("pulse_strength", _pulse_strength)
	_icon_material.set_shader_parameter("fill_brightness", _visual_config.compact_fill_brightness)
	_icon_material.set_shader_parameter("fill_expand_scale", _visual_config.compact_fill_expand_scale)
	_icon_material.set_shader_parameter("spread_plateau_scale", _visual_config.compact_spread_plateau_scale)
	_icon_material.set_shader_parameter("glyph_tint_strength", _visual_config.compact_glyph_tint_base + tier_strength * _visual_config.compact_glyph_tint_tier_gain)
	_icon_material.set_shader_parameter("mouse_uv", _mouse_uv)
	_icon_material.set_shader_parameter("inner_ring_radius", _visual_config.compact_glyph_inner_ring)
	_icon_material.set_shader_parameter("mid_ring_radius", _visual_config.compact_glyph_mid_ring)
	_icon_material.set_shader_parameter("outer_ring_radius", _visual_config.compact_glyph_outer_ring)
	_icon_material.set_shader_parameter("outer_glow_scale", _visual_config.compact_glyph_outer_scale)
	_icon_material.set_shader_parameter("rim_glow_scale", _visual_config.compact_glyph_rim_scale)
	_icon_material.set_shader_parameter("pointer_focus_falloff", _visual_config.compact_glyph_pointer_falloff)
	_icon_material.set_shader_parameter("pointer_glow_scale", _visual_config.compact_glyph_pointer_scale)
	_icon_material.set_shader_parameter("pulse_speed", _visual_config.compact_glyph_pulse_speed)
	_icon_material.set_shader_parameter("pulse_wobble", _visual_config.compact_glyph_pulse_wobble)
	_icon_material.set_shader_parameter("final_alpha_scale", _visual_config.compact_glyph_final_alpha_scale)


func _apply_background_state() -> void:
	if not _bg_rect:
		return
	var emphasis := clampf(
		_proximity_strength * _visual_config.compact_bg_proximity_weight
		+ _active_strength * _visual_config.compact_bg_active_weight
		+ _pulse_strength * _visual_config.compact_bg_pulse_weight,
		0.0,
		1.0
	)
	var glow_target := Color(
		clampf(_base_bg_color.r + _difficulty_tint.r * _visual_config.compact_bg_tint_strength, 0.0, 1.0),
		clampf(_base_bg_color.g + _difficulty_tint.g * _visual_config.compact_bg_tint_strength * 0.65, 0.0, 1.0),
		clampf(_base_bg_color.b + _difficulty_tint.b * _visual_config.compact_bg_tint_strength * 0.35, 0.0, 1.0),
		clampf(_base_bg_color.a + _visual_config.compact_bg_alpha_gain, 0.0, 1.0)
	)
	_bg_rect.color = _base_bg_color.lerp(glow_target, emphasis)


func _update_mouse_response(delta: float) -> void:
	if not is_visible_in_tree() or size.x <= 0.0 or size.y <= 0.0:
		_proximity_strength = lerpf(_proximity_strength, 0.0, clampf(delta * _visual_config.compact_proximity_lerp_speed, 0.0, 1.0))
		_apply_shader_state()
		_apply_background_state()
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
	var max_distance: float = maxf(rect.size.x, rect.size.y) * _visual_config.compact_proximity_distance_multiplier
	var target_proximity := 1.0 - clampf(distance / max_distance, 0.0, 1.0)
	target_proximity = pow(target_proximity, 0.9)

	_mouse_uv = _mouse_uv.lerp(target_uv, clampf(delta * _visual_config.compact_proximity_lerp_speed, 0.0, 1.0))
	_proximity_strength = lerpf(_proximity_strength, target_proximity, clampf(delta * _visual_config.compact_proximity_lerp_speed, 0.0, 1.0))
	_apply_shader_state()
	_apply_background_state()


func _get_tier_strength() -> float:
	if not data:
		return 0.0
	return float(clamp(data.difficulty_rating, 0, 5)) / 5.0

