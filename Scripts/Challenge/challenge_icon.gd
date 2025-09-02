extends TextureButton
class_name ChallengeIcon

@export var data: ChallengeData
@export var glow_intensity: float = 0.5

@onready var hover_label: Label = $LabelBg/HoverLabel
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label_bg: PanelContainer = $LabelBg

var _shader_material: ShaderMaterial
var is_active := false
var _is_hovering := false
var _current_tween: Tween

func _ready() -> void:
	if not has_node("LabelBg/HoverLabel"):
		push_error("[ChallengeIcon] Missing HoverLabel")
		return

	if not has_node("ProgressBar"):
		push_error("[ChallengeIcon] Missing ProgressBar")
		return

	label_bg.visible = false
	progress_bar.value = 0
	
	if data:
		_apply_data()

	# Setup shader material
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload("res://Scripts/Shaders/debuff_ui_highlight.gdshader") # Reuse same shader
	_shader_material.set_shader_parameter("glow_intensity", 0.0)
	material = _shader_material
	_reset_visual_state()

func _reset_visual_state() -> void:
	# Cancel any running tweens
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	# Reset shader
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", 0.0)
	
	# Reset label
	if label_bg:
		label_bg.visible = _is_hovering
		label_bg.modulate.a = 1.0 if _is_hovering else 0.0
		label_bg.scale = Vector2.ONE

func set_data(new_data: ChallengeData) -> void:
	data = new_data
	_apply_data()

func _apply_data() -> void:
	if data:
		texture_normal = data.icon
		if hover_label:
			hover_label.text = "%s\n%s" % [data.display_name, data.description]

func set_active(active: bool) -> void:
	is_active = active
	# Visual feedback for active state
	modulate = Color.GREEN if active else Color.WHITE
	_shader_material.set_shader_parameter("glow_intensity", 0.5 if active else 0.0)
	
	# Optional tween for smooth transition
	var tween = create_tween()
	if active:
		tween.tween_property(self, "modulate", Color(0.5, 1.2, 0.5), 0.3)
	else:
		tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func set_progress(value: float) -> void:
	if progress_bar:
		# Create a smooth tween for progress updates
		var tween = create_tween()
		tween.tween_property(progress_bar, "value", value * 100, 0.2)

func _on_mouse_entered() -> void:
	_is_hovering = true
	
	# Cancel any existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	# 1. Show label immediately
	label_bg.visible = true
	label_bg.modulate.a = 0.0
	label_bg.scale = Vector2(0.8, 0.8)

	# 2. Create new tween
	_current_tween = get_tree().create_tween()

	# 3. Fade in (faster)
	_current_tween.tween_property(
		label_bg, "modulate:a", 1.0, 0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 4. Bounce scale (faster)
	_current_tween.tween_property(
		label_bg, "scale", Vector2(1.1, 1.1), 0.1
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 5. Settle scale (faster)
	_current_tween.tween_property(
		label_bg, "scale", Vector2.ONE, 0.05
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 6. Shader highlight (immediate)
	_shader_material.set_shader_parameter("glow_intensity", 0.5)

func _on_mouse_exited() -> void:
	_is_hovering = false
	
	# Cancel any existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = get_tree().create_tween()
	
	# Faster fade out
	_current_tween.tween_property(
		label_bg, "modulate:a", 0.0, 0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Immediate shader reset
	_shader_material.set_shader_parameter("glow_intensity", 0.0)
