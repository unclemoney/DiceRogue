extends Label
class_name GameplayTitleLetter

## GameplayTitleLetter
##
## Bounded in-game title letter that supports hover tilt, click feedback,
## and lightweight event animations without leaving its container.

const DEFAULT_WAVE_SPEED := 0.55
const DEFAULT_WAVE_FREQUENCY := 1.15

var _phase_offset: float = 0.0
var _wave_amplitude: float = 3.0
var _wave_speed: float = DEFAULT_WAVE_SPEED
var _wave_frequency: float = DEFAULT_WAVE_FREQUENCY
var _hover_scale: float = 1.12
var _hover_glow_strength: float = 0.45
var _max_tilt_degrees: float = 10.0
var _max_event_offset: float = 18.0
var _base_position: Vector2 = Vector2.ZERO
var _event_offset: Vector2 = Vector2.ZERO
var _shader_material: ShaderMaterial
var _audio_manager: Node = null
var _hover_tween: Tween
var _move_tween: Tween
var _visual_tween: Tween
var _transform_tween: Tween
var _is_hovering: bool = false


func _ready() -> void:
	_audio_manager = get_node_or_null("/root/AudioManager")
	_setup_shader()
	mouse_filter = MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	call_deferred("capture_base_position")


## apply_style(font, font_size, font_color, outline_color, shadow_color)
##
## Applies the shared title styling for this letter.
func apply_style(font: Font, font_size: int, font_color: Color, outline_color: Color, shadow_color: Color) -> void:
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", font_color)
	add_theme_color_override("font_outline_color", outline_color)
	add_theme_color_override("font_shadow_color", shadow_color)
	add_theme_constant_override("outline_size", maxi(2, int(round(font_size * 0.055))))
	add_theme_constant_override("shadow_offset_x", maxi(1, int(round(font_size * 0.04))))
	add_theme_constant_override("shadow_offset_y", maxi(1, int(round(font_size * 0.04))))
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2.ZERO


## set_phase_offset(offset)
##
## Staggers the idle wave so letters do not move in lockstep.
func set_phase_offset(offset: float) -> void:
	_phase_offset = offset


## set_motion_profile(wave_amplitude, max_event_offset, hover_scale, max_tilt_degrees)
##
## Updates movement limits based on the container size and computed font size.
func set_motion_profile(wave_amplitude: float, max_event_offset: float, hover_scale: float, max_tilt_degrees: float) -> void:
	_wave_amplitude = wave_amplitude
	_max_event_offset = max_event_offset
	_hover_scale = hover_scale
	_max_tilt_degrees = max_tilt_degrees


## capture_base_position()
##
## Re-captures the container-assigned resting position after layout changes.
func capture_base_position() -> void:
	_base_position = position


func _process(_delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0
	var wave := sin(time * _wave_speed * TAU + _phase_offset * TAU * _wave_frequency) * _wave_amplitude
	position = _base_position + Vector2(_event_offset.x, _event_offset.y + wave)


func _setup_shader() -> void:
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload("res://Scripts/Shaders/title_letter.gdshader")
	_shader_material.set_shader_parameter("glow_strength", 0.0)
	_shader_material.set_shader_parameter("x_rot", 0.0)
	_shader_material.set_shader_parameter("y_rot", 0.0)
	_shader_material.set_shader_parameter("flash_strength", 0.0)
	material = _shader_material


func _on_mouse_entered() -> void:
	_is_hovering = true
	_kill_tween(_hover_tween)
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "scale", Vector2(_hover_scale, _hover_scale), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_glow_strength, _get_glow_strength(), _hover_glow_strength, 0.18)


func _on_mouse_exited() -> void:
	_is_hovering = false
	_kill_tween(_hover_tween)
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_glow_strength, _get_glow_strength(), 0.0, 0.18)
	_shader_material.set_shader_parameter("x_rot", 0.0)
	_shader_material.set_shader_parameter("y_rot", 0.0)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _is_hovering:
		_handle_mouse_tilt(event.position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		play_click_effect(0.55)


func _handle_mouse_tilt(mouse_pos: Vector2) -> void:
	if _shader_material == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var lerp_val_x = clampf(mouse_pos.x / size.x, 0.0, 1.0)
	var lerp_val_y = clampf(mouse_pos.y / size.y, 0.0, 1.0)
	var rot_x = lerp(-_max_tilt_degrees, _max_tilt_degrees, lerp_val_x)
	var rot_y = lerp(_max_tilt_degrees, -_max_tilt_degrees, lerp_val_y)

	_shader_material.set_shader_parameter("x_rot", rot_y)
	_shader_material.set_shader_parameter("y_rot", rot_x)


## play_click_effect(intensity)
##
## Plays a random lightweight interaction effect when the player clicks a letter.
func play_click_effect(intensity: float = 0.5) -> void:
	if _audio_manager and _audio_manager.has_method("play_button_click"):
		_audio_manager.play_button_click()

	match randi() % 4:
		0:
			play_glow_burst(lerpf(0.45, 0.85, intensity), 0.24)
		1:
			play_squash_stretch(intensity)
		2:
			play_bounce(lerpf(8.0, 18.0, intensity), lerpf(2.0, 6.0, intensity), 0.32)
		_:
			play_shake(lerpf(2.0, 7.0, intensity), 4, 0.16)


## play_glow_burst(max_strength, duration)
##
## Pulses the glow shader parameter for positive or curious events.
func play_glow_burst(max_strength: float = 0.55, duration: float = 0.24) -> void:
	_kill_tween(_visual_tween)
	_visual_tween = create_tween()
	_visual_tween.tween_method(_set_glow_strength, _get_glow_strength(), max_strength, duration * 0.35)
	_visual_tween.tween_method(_set_glow_strength, max_strength, 0.0, duration * 0.65)


## play_flash_burst(max_strength, duration)
##
## Fires a brighter one-shot flash for high-value events.
func play_flash_burst(max_strength: float = 0.9, duration: float = 0.24) -> void:
	_kill_tween(_visual_tween)
	_visual_tween = create_tween()
	_visual_tween.tween_method(_set_flash_strength, 0.0, max_strength, duration * 0.28)
	_visual_tween.tween_method(_set_flash_strength, max_strength, 0.0, duration * 0.72)


## play_bounce(height, settle_height, duration)
##
## Kicks the letter upward, then settles it back inside its motion bounds.
func play_bounce(height: float = 10.0, settle_height: float = 3.0, duration: float = 0.3) -> void:
	_kill_tween(_move_tween)
	_move_tween = create_tween()
	var capped_height = clampf(height, 0.0, _max_event_offset)
	var settle = clampf(settle_height, 0.0, _max_event_offset * 0.5)
	_move_tween.tween_method(_set_event_offset_y, _event_offset.y, -capped_height, duration * 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_method(_set_event_offset_y, -capped_height, settle, duration * 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_move_tween.tween_method(_set_event_offset_y, settle, 0.0, duration * 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## play_shake(strength, steps, total_duration)
##
## Applies a brief horizontal jitter for rolls, glitches, or debuffs.
func play_shake(strength: float = 4.0, steps: int = 4, total_duration: float = 0.14) -> void:
	_kill_tween(_move_tween)
	_move_tween = create_tween()
	var step_count = maxi(steps, 2)
	var step_duration = total_duration / float(step_count + 1)
	var current_x = _event_offset.x
	for i in range(step_count):
		var target_x = randf_range(-strength, strength)
		_move_tween.tween_method(_set_event_offset_x, current_x, clampf(target_x, -_max_event_offset, _max_event_offset), step_duration)
		current_x = target_x
	_move_tween.tween_method(_set_event_offset_x, current_x, 0.0, step_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## play_squash_stretch(intensity)
##
## Adds an elastic squash and recovery without affecting the container.
func play_squash_stretch(intensity: float = 0.5) -> void:
	_kill_tween(_transform_tween)
	_transform_tween = create_tween()
	var wide_scale = Vector2(1.0 + intensity * 0.32, 1.0 - intensity * 0.18)
	var tall_scale = Vector2(1.0 - intensity * 0.15, 1.0 + intensity * 0.24)
	_transform_tween.tween_property(self, "scale", wide_scale, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transform_tween.tween_property(self, "scale", tall_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transform_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## play_tilt(angle, duration)
##
## Rotates the letter briefly, then settles it flat.
func play_tilt(angle: float = 8.0, duration: float = 0.22) -> void:
	_kill_tween(_transform_tween)
	_transform_tween = create_tween()
	var capped_angle = clampf(angle, -18.0, 18.0)
	_transform_tween.tween_property(self, "rotation_degrees", capped_angle, duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transform_tween.tween_property(self, "rotation_degrees", 0.0, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## play_tint_pulse(tint, duration)
##
## Temporarily tints the letter, then restores its default modulation.
func play_tint_pulse(tint: Color, duration: float = 0.28) -> void:
	_kill_tween(_visual_tween)
	_visual_tween = create_tween()
	modulate = Color.WHITE
	_visual_tween.tween_property(self, "modulate", tint, duration * 0.35)
	_visual_tween.tween_property(self, "modulate", Color.WHITE, duration * 0.65)


func _set_event_offset_x(value: float) -> void:
	_event_offset.x = clampf(value, -_max_event_offset, _max_event_offset)


func _set_event_offset_y(value: float) -> void:
	_event_offset.y = clampf(value, -_max_event_offset, _max_event_offset)


func _set_glow_strength(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("glow_strength", value)


func _get_glow_strength() -> float:
	if _shader_material:
		return float(_shader_material.get_shader_parameter("glow_strength"))
	return 0.0


func _set_flash_strength(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("flash_strength", value)


func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()