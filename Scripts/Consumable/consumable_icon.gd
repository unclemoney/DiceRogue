extends TextureButton
class_name ConsumableIcon

@export var data: ConsumableData
@export var glow_intensity: float = 0.5
@export var explosion_effect_scene: PackedScene
var _explosion_instance: GPUParticles2D

@onready var hover_label: Label = $LabelBg/HoverLabel
@onready var label_bg: PanelContainer = $LabelBg

var _shader_material: ShaderMaterial
var _is_hovering := false
var _current_tween: Tween
var is_useable := false  # Can the consumable be activated at all?
var is_active := false   # Has the player clicked to activate it?
var is_used := false     # Has the consumable been consumed?

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
	if data and data.id == "score_reroll":
		connect("pressed", Callable(self, "_on_reroll_pressed"))

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
	
	_reset_visual_state()

func _reset_visual_state() -> void:
	# Cancel any running tweens
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	# Reset shader
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", 
			glow_intensity if is_active else 0.0)
	
	# Reset label
	if label_bg:
		label_bg.visible = _is_hovering or is_active
		label_bg.modulate.a = 1.0 if (_is_hovering or is_active) else 0.0
		label_bg.scale = Vector2.ONE

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
	_is_hovering = true

	# Only show hover effects if not active
	if is_active:
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

	# Only handle hover effects if not active
	if is_active:
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
	print("ConsumableIcon: _on_pressed called")
	print("  is_useable:", is_useable)
	print("  is_active:", is_active)
	print("  is_used:", is_used)
	
	if is_used:
		print("Consumable already used")
		return
		
	if not is_useable:
		print("Consumable not useable yet")
		_on_reroll_denied()
		return
		
	if not is_active:
		# First click - activate the consumable
		print("Activating consumable")
		emit_signal("consumable_used", data.id)
		is_active = true
		_shader_material.set_shader_parameter("glow_intensity", glow_intensity)
		modulate = Color(1.5, 1.5, 1.5)
	else:
		# Already active - shouldn't get here as ScoreCardUI handles the actual usage
		print("Consumable already active")

func set_useable(useable: bool) -> void:
	is_useable = useable
	print("ConsumableIcon: set_useable =", useable)
	# Update visual state
	modulate = Color.WHITE if useable else Color(0.5, 0.5, 0.5, 0.7)

func _on_reroll_activated() -> void:
	print("Reroll activated")
	is_active = true
	_shader_material.set_shader_parameter("glow_intensity", glow_intensity)
	modulate = Color(1.5, 1.5, 1.5)

func _on_reroll_completed() -> void:
	print("Reroll completed")
	is_used = true
	is_active = false
	_shader_material.set_shader_parameter("glow_intensity", 0.0)
	modulate = Color.WHITE
	
	# Play explosion effect before removing
	play_destruction_effect()
	
	# Add a small delay for effect
	await get_tree().create_timer(0.2).timeout
	queue_free()

func _on_reroll_denied() -> void:
	print("Reroll denied")
	
	# Show appropriate message based on state
	if hover_label:
		var original_text = hover_label.text
		
		# Choose message based on state
		var message = ""
		if not is_useable:
			message = "No scores to reroll!"
		elif is_active:
			message = "Already active!"
		elif is_used:
			message = "Already used!"
		
		# Only show denial message if we have one
		if message != "":
			hover_label.text = message
			hover_label.visible = true
			
			# Reset after delay
			var timer = get_tree().create_timer(2.0)
			await timer.timeout
			hover_label.text = original_text
			if not _is_hovering:
				hover_label.visible = false

func play_destruction_effect() -> void:
	print("play_destruction_effect called")
	if explosion_effect_scene:
		var screen_shake = get_tree().root.find_child("ScreenShake", true, false)
		if screen_shake:
			screen_shake.shake(0.4, 0.3)  # Moderate shake for 0.3 seconds
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

func _on_reroll_pressed() -> void:
	print("Reroll pressed, is_active:", is_active)
	if data and data.id == "score_reroll" and not is_active:
		print("Emitting consumable_used signal for score_reroll")
		emit_signal("consumable_used", data.id)
