extends TextureButton
class_name DebuffIcon

@export var data: DebuffData
@export var glow_intensity: float = 0.5

@onready var hover_label: Label = $LabelBg/HoverLabel
@onready var label_bg: PanelContainer = $LabelBg

var _shader_material: ShaderMaterial
var is_active := false
var _is_hovering := false
var _current_tween: Tween
var _is_selected: bool = true

func _ready() -> void:
	if not has_node("LabelBg/HoverLabel"):
		push_error("Missing HoverLabel")
		return

	label_bg.visible = false
	
	if data:
		_apply_data()

	# Setup shader material
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload("res://Scripts/Shaders/debuff_ui_highlight.gdshader")
	_shader_material.set_shader_parameter("glow_intensity", 0.0)
	material = _shader_material
	_reset_visual_state()

func _reset_visual_state() -> void:
	# Cancel any running tweens
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	# Reset shader
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", 
			glow_intensity if _is_selected else 0.0)
	
	# Reset label
	if label_bg:
		label_bg.visible = _is_hovering or _is_selected
		label_bg.modulate.a = 1.0 if (_is_hovering or _is_selected) else 0.0
		label_bg.scale = Vector2.ONE

func set_data(new_data: DebuffData) -> void:
	data = new_data
	_apply_data()

func _apply_data() -> void:
	if data:
		texture_normal = data.icon
		if hover_label:
			hover_label.text = data.display_name

func set_active(active: bool) -> void:
	is_active = active
	# Visual feedback for active state
	modulate = Color.RED if active else Color.WHITE
	_shader_material.set_shader_parameter("glow_intensity", 0.5 if active else 0.0)
	
	# Optional tween for smooth transition
	var tween = create_tween()
	if active:
		tween.tween_property(self, "modulate", Color(1.2, 0.3, 0.3), 0.3)
	else:
		tween.tween_property(self, "modulate", Color.WHITE, 0.3)


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
	
	# Only handle hover effects if not selected
	if _is_selected:
		return

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

func _on_pressed() -> void:
	pass

# Add visibility change handler
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_is_hovering = false
				_reset_visual_state()
