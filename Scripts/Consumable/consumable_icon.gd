extends TextureButton
class_name ConsumableIcon

@export var data: ConsumableData
@export var glow_intensity: float = 0.5
@export var explosion_effect_scene: PackedScene
var _explosion_instance: GPUParticles2D

@onready var hover_label: Label = $LabelBg/HoverLabel
@onready var label_bg: PanelContainer = $LabelBg

var _shader_material: ShaderMaterial
var is_active := false

signal consumable_used(consumable_id: String)

func _ready() -> void:
	print("ConsumableIcon: _ready() called")
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
	# Preload explosion effect
	# Check explosion effect scene
	print("Checking explosion effect scene...")
	if explosion_effect_scene:
		print("Explosion effect scene assigned in inspector:", explosion_effect_scene.resource_path)
	else:
		print("No explosion effect scene assigned, attempting to preload...")
		explosion_effect_scene = preload("res://Scenes/Effects/ConsumableExplosion.tscn")
		if explosion_effect_scene:
			print("Successfully preloaded explosion effect:", explosion_effect_scene.resource_path)
		else:
			push_error("Failed to preload ConsumableExplosion scene!")

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
	
	# Play explosion effect before removing
	play_destruction_effect()
	
	# Add a small delay for effect
	await get_tree().create_timer(0.2).timeout
	queue_free()

func play_destruction_effect() -> void:
	print("play_destruction_effect called")
	if explosion_effect_scene:
		print("Creating explosion instance from:", explosion_effect_scene.resource_path)
		_explosion_instance = explosion_effect_scene.instantiate()
		if _explosion_instance:
			# Get the root viewport instead of parent for UI visibility
			var viewport = get_tree().root
			viewport.add_child(_explosion_instance)
			
			# Position at center of icon in global coordinates
			var center_pos = get_global_transform_with_canvas().origin + (size / 2)
			_explosion_instance.global_position = center_pos
			print("Positioned explosion at:", center_pos)
			
			# Ensure visibility and start emitting
			_explosion_instance.show()
			_explosion_instance.emitting = true
			print("Explosion effect started, emitting:", _explosion_instance.emitting)
			
			# Wait for entire lifetime plus a small buffer
			var total_time = _explosion_instance.lifetime * (1.0 + _explosion_instance.explosiveness)
			print("Waiting for total time:", total_time)
			await get_tree().create_timer(total_time).timeout
			
			print("Explosion effect cleanup started")
			_explosion_instance.queue_free()
			print("Explosion effect cleanup complete")
	else:
		push_error("No explosion effect scene available!")