extends Label
class_name TitleLetter

## Individual animated title letter with sine wave motion,
## shader effects, perspective tilt on hover, and randomized click feedback.

# ─── Sine Wave Constants ───────────────────────────────────────────
const SINE_AMPLITUDE := 8.0
const SINE_FREQUENCY := 1.5
const SINE_SPEED := 0.4
const BASE_PHASE_OFFSET := 0.4

# ─── Click Effect Types ────────────────────────────────────────────
enum ClickEffect {
	GLOW,
	SCALE,
	BOUNCE,
	RIPPLE
}

var _phase_offset: float = 0.0
var _base_y: float = 0.0
var _bounce_offset: float = 0.0
var _hover_tween: Tween
var _click_tween: Tween
var _is_hovering := false

var _shader_material: ShaderMaterial
var _audio_manager: Node = null


func _ready() -> void:
	_base_y = position.y
	_audio_manager = get_node_or_null("/root/AudioManager")

	# Set up shader
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload("res://Scripts/Shaders/title_letter.gdshader")
	_shader_material.set_shader_parameter("glow_strength", 0.0)
	_shader_material.set_shader_parameter("x_rot", 0.0)
	_shader_material.set_shader_parameter("y_rot", 0.0)
	_shader_material.set_shader_parameter("flash_strength", 0.0)
	material = _shader_material

	# Connect input
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	mouse_filter = MOUSE_FILTER_STOP


## set_phase_offset(offset)
##
## Sets the phase offset for this letter's sine wave (0.0-1.0).
func set_phase_offset(offset: float) -> void:
	_phase_offset = offset


func _process(_delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0
	var sine_value = sin(time * SINE_SPEED * TAU + _phase_offset * TAU * SINE_FREQUENCY)
	position.y = _base_y + sine_value * SINE_AMPLITUDE + _bounce_offset


func _on_mouse_entered() -> void:
	_is_hovering = true
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = get_tree().create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_glow_strength, 0.0, 0.6, 0.2)


func _on_mouse_exited() -> void:
	_is_hovering = false
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = get_tree().create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_glow_strength, 0.6, 0.0, 0.2)
	_shader_material.set_shader_parameter("x_rot", 0.0)
	_shader_material.set_shader_parameter("y_rot", 0.0)


func _set_glow_strength(strength: float) -> void:
	_shader_material.set_shader_parameter("glow_strength", strength)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _is_hovering:
		_handle_mouse_tilt(event.position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_click_effect()


func _handle_mouse_tilt(mouse_pos: Vector2) -> void:
	if not _shader_material:
		return

	var size_vec = size
	if size_vec.x <= 0 or size_vec.y <= 0:
		return

	var lerp_val_x = clampf(mouse_pos.x / size_vec.x, 0.0, 1.0)
	var lerp_val_y = clampf(mouse_pos.y / size_vec.y, 0.0, 1.0)

	var rot_x = lerp(-15.0, 15.0, lerp_val_x)
	var rot_y = lerp(15.0, -15.0, lerp_val_y)

	_shader_material.set_shader_parameter("x_rot", rot_y)
	_shader_material.set_shader_parameter("y_rot", rot_x)


func _play_click_effect() -> void:
	# Play sound
	if _audio_manager:
		_audio_manager.play_button_click()

	var effect = randi() % 4
	match effect:
		ClickEffect.GLOW:
			_effect_glow()
		ClickEffect.SCALE:
			_effect_scale()
		ClickEffect.BOUNCE:
			_effect_bounce()
		ClickEffect.RIPPLE:
			_effect_ripple()


func _effect_glow() -> void:
	if _click_tween and _click_tween.is_valid():
		_click_tween.kill()
	_click_tween = get_tree().create_tween()
	_click_tween.tween_method(_set_flash_strength, 0.0, 1.0, 0.1)
	_click_tween.tween_method(_set_flash_strength, 1.0, 0.0, 0.3)


func _set_flash_strength(strength: float) -> void:
	_shader_material.set_shader_parameter("flash_strength", strength)


func _effect_scale() -> void:
	if _click_tween and _click_tween.is_valid():
		_click_tween.kill()
	_click_tween = get_tree().create_tween()
	_click_tween.tween_property(self, "scale", Vector2(1.4, 0.6), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_click_tween.tween_property(self, "scale", Vector2(0.8, 1.3), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_click_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _effect_bounce() -> void:
	if _click_tween and _click_tween.is_valid():
		_click_tween.kill()
	_click_tween = get_tree().create_tween()
	_click_tween.tween_property(self, "_bounce_offset", -30.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_click_tween.tween_property(self, "_bounce_offset", 10.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_click_tween.tween_property(self, "_bounce_offset", 0.0, 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _effect_ripple() -> void:
	var parent = get_parent()
	if not parent:
		return
	for i in range(parent.get_child_count()):
		var child = parent.get_child(i)
		if child is TitleLetter and child != self:
			child._trigger_delayed_bounce(i * 0.05)


## _trigger_delayed_bounce(delay)
##
## Called by ripple effect. Triggers a bounce after a delay.
func _trigger_delayed_bounce(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_effect_bounce()
