extends TextureButton
class_name ConsumableIcon

@export var data: ConsumableData
@export var glow_intensity: float = 0.5

@onready var hover_label: Label = $LabelBg/HoverLabel
@onready var label_bg: PanelContainer = $LabelBg

var _shader_material: ShaderMaterial
var is_active := false

signal consumable_used(consumable_id: String)

func _ready() -> void:
	if not has_node("LabelBg/HoverLabel"):
		push_error("Missing HoverLabel")
		return

	label_bg.visible = false
	
	if data:
		_apply_data()
	else:
		texture_normal = preload("res://icon.svg")

	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	connect("pressed", Callable(self, "_on_pressed"))

	# Setup shader material
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload("res://Scripts/Shaders/power_up_ui_highlight.gdshader")
	_shader_material.set_shader_parameter("glow_intensity", 0.0)
	material = _shader_material

func set_data(new_data: ConsumableData) -> void:
	data = new_data
	if data and data.icon:
		texture_normal = data.icon
	else:
		push_warning("ConsumableIcon: No icon texture provided")
		texture_normal = preload("res://icon.svg")
	
	if hover_label and data:
		hover_label.text = data.display_name

func _apply_data() -> void:
	if not data:
		push_warning("ConsumableIcon: No data set during _apply_data()")
		texture_normal = preload("res://icon.svg")
		if hover_label:
			hover_label.text = "No Name"
		return
		
	if data.icon:
		texture_normal = data.icon
	else:
		push_warning("ConsumableIcon: No icon texture in data")
		texture_normal = preload("res://icon.svg")
		
	if hover_label:
		hover_label.text = data.display_name

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
	if not is_active:
		emit_signal("consumable_used", data.id)
		# Don't queue_free here - wait for reroll_completed signal
		disabled = true  # Prevent multiple activations while waiting for score selection
	else:
		push_warning("Consumable already active")

func _on_reroll_activated() -> void:
	is_active = true
	_shader_material.set_shader_parameter("glow_intensity", glow_intensity)
	modulate = Color(1.5, 1.5, 1.5)  # Brighten the icon

func _on_reroll_completed() -> void:
	is_active = false
	_shader_material.set_shader_parameter("glow_intensity", 0.0)
	modulate = Color.WHITE
	queue_free()  # Remove the icon
