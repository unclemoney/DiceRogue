extends TextureButton
class_name DebuffIcon

@export var data: DebuffData
@export var glow_intensity: float = 0.5

@onready var hover_label: Label = $LabelBg/HoverLabel
@onready var label_bg: PanelContainer = $LabelBg

var _shader_material: ShaderMaterial
var is_active := false

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
	label_bg.visible = true
	label_bg.modulate.a = 0.0
	label_bg.scale = Vector2(0.8, 0.8)

	var t = get_tree().create_tween()
	t.tween_property(label_bg, "modulate:a", 1.0, 0.15)
	t.tween_property(label_bg, "scale", Vector2(1.2, 1.2), 0.2)
	t.tween_property(label_bg, "scale", Vector2(1, 1), 0.1)
	t.parallel().tween_property(_shader_material, "shader_parameter/glow_intensity", 0.5, 0.1)

func _on_mouse_exited() -> void:
	var t = get_tree().create_tween()
	t.tween_property(label_bg, "modulate:a", 0.0, 0.15)
	t.parallel().tween_property(_shader_material, "shader_parameter/glow_intensity", 0.0, 0.1)

func _on_pressed() -> void:
	pass