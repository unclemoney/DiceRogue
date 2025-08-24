extends TextureButton
class_name PowerUpIcon

@export var data: PowerUpData
@export var glow_intensity: float = 0.5
@onready var hover_label: Label = $LabelBg/HoverLabel
@onready var label_bg: PanelContainer = $LabelBg
var _shader_material: ShaderMaterial
var _is_selected: bool = false
var _is_hovering := false
var _current_tween: Tween

signal power_up_selected(power_up_id: String)
signal power_up_deselected(power_up_id: String)

func _ready() -> void:
	print("  → get_script():", get_script().resource_path)
	#print("  → Filename:", filename)    # for PackedScene nodes
	if not has_node("LabelBg"):
		push_error("Missing LabelBg"); return
	if not has_node("LabelBg/HoverLabel"):
		push_error("Missing HoverLabel"); return

	label_bg    = $LabelBg
	hover_label = $LabelBg/HoverLabel

	label_bg.visible = false

	if not data:
		push_warning("data was null — assigning fallback icon")
		texture_normal = preload("res://icon.svg")
	_apply_data()  # always set texture & text now

	#print("   connected before?", is_connected("mouse_entered", self, "_on_mouse_entered"))
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited",  Callable(self, "_on_mouse_exited"))
	#print("   connected after? ", is_connected("mouse_entered", self, "_on_mouse_entered"))
	# Setup shader material
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload("res://Scripts/Shaders/power_up_ui_highlight.gdshader")
	_shader_material.set_shader_parameter("glow_intensity", 0.0)
	material = _shader_material
	# Add pressed connection
	connect("pressed", Callable(self, "_on_pressed"))
	_reset_visual_state()

func set_data(new_data: PowerUpData) -> void:
	data = new_data
	if data.icon != null:
		texture_normal = data.icon
	else:
		push_warning("PowerUpIcon: icon is null, using fallback")
		texture_normal = preload("res://icon.svg")

	#tooltip_text = "%s\n%s" % [data.display_name, data.description]

func _apply_data() -> void:
	texture_normal = data.icon
	hover_label.text   = data.display_name


func _on_mouse_entered() -> void:
	_is_hovering = true
	
	# Only show hover effects if not selected
	if _is_selected:
		return
		
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

# Add visibility change handler
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_is_hovering = false
				_reset_visual_state()
				
func _on_pressed() -> void:
	#test the selection
	_is_selected = !_is_selected
	var t = get_tree().create_tween()
	
	if _is_selected:
		t.tween_property(
			_shader_material, 
			"shader_parameter/glow_intensity", 
			glow_intensity, 
			0.1
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		emit_signal("power_up_selected", data.id)
	else:
		t.tween_property(
			_shader_material, 
			"shader_parameter/glow_intensity", 
			0.0, 
			0.1
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		emit_signal("power_up_deselected", data.id)

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