# Scripts/Consumable/consumable_icon.gd
extends Control
class_name ConsumableIcon

signal consumable_used(consumable_id: String)
signal consumable_sell_requested(consumable_id: String)

@export var data: ConsumableData
@export var glow_intensity: float = 0.25
@export var hover_tilt: float = 0.05
@export var hover_scale: float = 1.05
@export var transition_speed: float = 0.05
@export var max_offset_shadow: float = 20.0
@export var explosion_effect_scene: PackedScene

# Mouse movement variables
@export var spring: float = 150.0
@export var damp: float = 10.0
@export var velocity_multiplier: float = 2.0

@export var angle_x_max: float = 25.0  # Maximum X rotation angle in degrees
@export var angle_y_max: float = 25.0  # Maximum Y rotation angle in degrees

# Node references - initialized in _ready
var card_art: TextureRect
var label_bg: PanelContainer
var hover_label: Label
var sell_button: Button
var use_button: Button
var card_frame: TextureRect
var card_info: VBoxContainer
var card_title: Label
var shadow: TextureRect

var _explosion_instance: GPUParticles2D
var _shader_material: ShaderMaterial
var _is_hovering := false
var _is_selected := false
var _current_tween: Tween
var _sell_button_visible := false
var _use_button_visible := false
var _following_mouse := false
var _last_pos := Vector2.ZERO
var _velocity := Vector2.ZERO
var _displacement := 0.0
var _oscillator_velocity := 0.0
var _default_position := Vector2.ZERO
var _hover_card_tween: Tween

var is_useable := false  # Can the consumable be activated at all?
var is_active := false   # Has the player clicked to activate it?
var is_used := false     # Has the consumable been consumed?

func _ready() -> void:
	print("[ConsumableIcon] Initializing...")
	
	# If we have no children, create the full card structure
	if get_child_count() == 0:
		print("[ConsumableIcon] Creating card structure")
		_create_card_structure()
	else:
		print("[ConsumableIcon] Children present, skipping structure creation")
		# Get references to existing nodes
		card_art = get_node_or_null("CardArt")
		label_bg = get_node_or_null("LabelBg")
		sell_button = get_node_or_null("SellButton")
		use_button = get_node_or_null("UseButton")
		card_frame = get_node_or_null("CardFrame")
		card_info = get_node_or_null("CardInfo")
		shadow = get_node_or_null("Shadow")
		card_title = card_info.get_node_or_null("Title") if card_info else null
		hover_label = label_bg.get_node_or_null("HoverLabel") if label_bg else null
			
	# Report missing nodes for debugging
	if not card_art:
		print("[ConsumableIcon] WARNING: CardArt node missing")
	if not label_bg:
		print("[ConsumableIcon] WARNING: LabelBg node missing")
	if not sell_button:
		print("[ConsumableIcon] WARNING: SellButton node missing")
	if not use_button:
		print("[ConsumableIcon] WARNING: UseButton node missing")
	if not card_frame:
		print("[ConsumableIcon] WARNING: CardFrame node missing")
	if not card_info:
		print("[ConsumableIcon] WARNING: CardInfo node missing")
	if not card_title:
		print("[ConsumableIcon] WARNING: Title node missing")
	if not hover_label:
		print("[ConsumableIcon] WARNING: HoverLabel node missing")
	if not shadow:
		print("[ConsumableIcon] WARNING: Shadow node missing")

	# Setup card visuals
	custom_minimum_size = Vector2(80, 120)  # Standard card ratio 2:3
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER
	
	# Store default position for returning after mouse following
	_default_position = position
	_last_pos = position

	# Setup default appearances
	if label_bg:
		label_bg.visible = false
	if sell_button:
		sell_button.visible = false
		sell_button.text = "SELL"
		if not sell_button.is_connected("pressed", _on_sell_button_pressed):
			sell_button.pressed.connect(_on_sell_button_pressed)
	if use_button:
		use_button.visible = false
		use_button.text = "USE"
		if not use_button.is_connected("pressed", _on_use_button_pressed):
			use_button.pressed.connect(_on_use_button_pressed)
	if shadow:
		shadow.modulate = Color(0.0, 0.0, 0.0, 0.5)
		shadow.position = Vector2(5, 5)
		
	# Connect input signals if not already connected
	if not is_connected("mouse_entered", _on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not is_connected("mouse_exited", _on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	print("[ConsumableIcon] Initializing...")
	_setup_shader()

	# Convert angles to radians
	angle_x_max = deg_to_rad(angle_x_max)
	angle_y_max = deg_to_rad(angle_y_max)

	_apply_data_to_ui()

	# Preload explosion effect
	if not explosion_effect_scene:
		print("[ConsumableIcon] WARNING: explosion_effect_scene not set, loading default")
		explosion_effect_scene = preload("res://Scenes/Effects/ConsumableExplosion.tscn")
	_reset_visual_state()
	print("[ConsumableIcon] Initialization complete for:", data.id if data else "unknown")

func _process(delta: float) -> void:
	_update_shadow(delta)
	_handle_mouse_following(delta)
	_update_rotation(delta)

func _update_default_position() -> void:
	# Wait for one frame to ensure layout is complete
	await get_tree().process_frame
	_default_position = position
	_last_pos = position

func _update_shadow(delta: float) -> void:
	if not shadow:
		return
	
	# Update shadow position based on card position and rotation
	var center = get_viewport_rect().size / 2.0
	var distance = global_position.x - center.x
	
	# Set shadow position with offset based on rotation and distance from center
	var shadow_offset = Vector2(
		lerp(5.0, -sign(distance) * max_offset_shadow, abs(distance/(center.x))), 
		5.0 + abs(_displacement * 10.0)
	)
	
	shadow.position = shadow_offset

func _handle_mouse_following(delta: float) -> void:
	if not _following_mouse:
		return
	
	var target_pos = get_global_mouse_position() - (size / 2.0)
	global_position = global_position.lerp(target_pos, delta * 15.0)
	
func _update_rotation(delta: float) -> void:
	if not _following_mouse:
		return
	
	# Calculate velocity for rotation effect
	_velocity = (position - _last_pos) / delta if delta > 0 else Vector2.ZERO
	_last_pos = position
	
	# Apply spring physics for rotation
	_oscillator_velocity += _velocity.normalized().x * velocity_multiplier
	var force = -spring * _displacement - damp * _oscillator_velocity
	_oscillator_velocity += force * delta
	_displacement += _oscillator_velocity * delta
	
	# Apply rotation with damping
	rotation = _displacement * 0.1

func _gui_input(event: InputEvent) -> void:	
	# Handle mouse motion for card tilt
	if event is InputEventMouseMotion and _is_hovering and not _following_mouse:
		_handle_mouse_tilt(event.position)
	
	# Handle click events
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Don't trigger card press if clicking on buttons
				var local_point = mouse_event.position
				if sell_button and sell_button.visible and sell_button.get_rect().has_point(local_point - sell_button.position):
					return
				if use_button and use_button.visible and use_button.get_rect().has_point(local_point - use_button.position):
					return
					
				_on_pressed()
				_start_mouse_following()
			else:
				_stop_mouse_following()
			get_viewport().set_input_as_handled()

func _handle_mouse_tilt(mouse_pos: Vector2) -> void:
	# Calculate normalized position (0-1) across card dimensions
	var lerp_val_x = clamp(mouse_pos.x / size.x, 0, 1) 
	var lerp_val_y = clamp(mouse_pos.y / size.y, 0, 1)
	
	# Calculate rotation angles
	var angle_x_max = deg_to_rad(15.0)
	var angle_y_max = deg_to_rad(15.0)
	var rot_x = rad_to_deg(lerp_angle(-angle_x_max, angle_x_max, lerp_val_x))
	var rot_y = rad_to_deg(lerp_angle(angle_y_max, -angle_y_max, lerp_val_y))
	
	# Apply to shader parameters
	if _shader_material:
		_shader_material.set_shader_parameter("x_rot", rot_y)
		_shader_material.set_shader_parameter("y_rot", rot_x)

func _create_card_structure() -> void:
	# Create Shadow (underneath everything)
	shadow = TextureRect.new()
	shadow.name = "Shadow"
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.5)
	shadow.z_index = -1
	shadow.position = Vector2(5, 5)
	add_child(shadow)
	
	# Create CardArt
	card_art = TextureRect.new()
	card_art.name = "CardArt"
	card_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(card_art)
	
	# Create CardFrame
	card_frame = TextureRect.new()
	card_frame.name = "CardFrame"
	card_frame.z_index = 1
	card_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(card_frame)
	
	# Create CardInfo
	card_info = VBoxContainer.new()
	card_info.name = "CardInfo"
	card_info.z_index = 2
	card_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card_info.position = Vector2(-186, 100)
	card_info.visible = true
	add_child(card_info)
	
	# Create Title
	card_title = Label.new()
	card_title.name = "Title"
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.add_theme_font_size_override("font_size", 16)
	card_title.visible = true
	card_info.add_child(card_title)
	print("[DEBUG] card_info children: ", card_info.get_children())
	
	# Create SellButton
	sell_button = Button.new()
	sell_button.name = "SellButton"
	sell_button.text = "SELL"
	sell_button.visible = false
	sell_button.z_index = 3
	sell_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sell_button.size = Vector2(44, 31)
	sell_button.position = Vector2(36, 0)  # Position at top right
	sell_button.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_button.pressed.connect(_on_sell_button_pressed)
	add_child(sell_button)
	
	# Create UseButton
	use_button = Button.new()
	use_button.name = "UseButton"
	use_button.text = "USE"
	use_button.visible = false
	use_button.z_index = 3
	use_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	use_button.size = Vector2(44, 31)
	use_button.position = Vector2(36, 41)  # Position at top left
	use_button.mouse_filter = Control.MOUSE_FILTER_STOP
	use_button.pressed.connect(_on_use_button_pressed)
	add_child(use_button)
	
	# Create LabelBg
	label_bg = PanelContainer.new()
	label_bg.name = "LabelBg"
	label_bg.visible = false
	label_bg.z_index = 3
	label_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label_bg.position.y = -60
	label_bg.position.x = -60
	add_child(label_bg)
	
	# Create HoverLabel
	hover_label = Label.new()
	hover_label.name = "HoverLabel"
	hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_label.custom_minimum_size = Vector2(220, 0)
	hover_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hover_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label_bg.add_child(hover_label)

func _setup_shader() -> void:
	# Try to load shader
	var shader_path = "res://Scripts/Shaders/card_perspective.gdshader"
	var shader_res = load(shader_path)
	
	if not shader_res:
		print("[ConsumableIcon] WARNING: Could not load shader from path:", shader_path)
		return
	
	# Create and setup shader
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader_res
	_shader_material.set_shader_parameter("tilt", 0.0)
	_shader_material.set_shader_parameter("glow_intensity", 0.0)
	_shader_material.set_shader_parameter("glow_color", Color(1, 1, 0.4, 1))
	_shader_material.set_shader_parameter("x_rot", 0.0)
	_shader_material.set_shader_parameter("y_rot", 0.0)
	
	# Apply to CardArt if available
	if card_art:
		card_art.material = _shader_material
	
	# Apply same texture to shadow if available
	if shadow and card_art and card_art.texture:
		shadow.texture = card_art.texture

func _apply_data_to_ui() -> void:
	if not data:
		return
	
	# Set card art texture
	if card_art:
		if data.icon:
			card_art.texture = data.icon
			card_art.custom_minimum_size = Vector2(59, 93) # match atlas region size
			card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		else:
			card_art.texture = preload("res://icon.svg")
			
		# Apply same texture to shadow
		if shadow:
			shadow.texture = card_art.texture
	
	# Set text fields
	if card_title:
		card_title.text = data.display_name
		card_title.add_theme_color_override("font_shadow_color", Color.BLACK)
		card_title.add_theme_constant_override("shadow_offset_x", 1)
		card_title.add_theme_constant_override("shadow_offset_y", 1)
		card_title.add_theme_constant_override("shadow_outline_size", 0)
		card_title.add_theme_constant_override("shadow_as_outline", 0)
	
	if hover_label:
		hover_label.text = data.description

func _start_mouse_following() -> void:
	_default_position = position
	_last_pos = position
	
	_following_mouse = true
	
	if _is_hovering:
		# Raise the z-index when following to appear above other cards
		var original_z_index = z_index
		z_index = 100
		
		# Restore z-index when done following
		if _hover_card_tween and _hover_card_tween.is_valid():
			_hover_card_tween.kill()
		_hover_card_tween = create_tween()
		_hover_card_tween.tween_callback(func(): 
			await get_tree().create_timer(0.5).timeout
			z_index = original_z_index
		)


func _stop_mouse_following() -> void:
	_following_mouse = false
	
	# Create a tween to smoothly return to original position and rotation
	if _hover_card_tween and _hover_card_tween.is_valid():
		_hover_card_tween.kill()
	
	_hover_card_tween = create_tween().set_parallel()
	_hover_card_tween.tween_property(self, "position", _default_position, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_card_tween.tween_property(self, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Reset oscillator values
	_displacement = 0.0
	_oscillator_velocity = 0.0

func _on_pressed() -> void:
	print("[ConsumableIcon] Card pressed:", data.id if data else "unknown")
	
	# Toggle buttons visibility
	_sell_button_visible = !_sell_button_visible
	_use_button_visible = !_use_button_visible
	
	if sell_button:
		sell_button.visible = _sell_button_visible
	
	if use_button:
		# Only show use button if consumable is useable
		use_button.visible = _use_button_visible && is_useable
		if _use_button_visible && !is_useable:
			# Show message if not useable
			_on_reroll_denied()

func _reset_visual_state() -> void:
	# Cancel any running tweens
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	# Reset transform
	scale = Vector2.ONE
	rotation = 0
	
	# Reset shader
	if _shader_material:
		_shader_material.set_shader_parameter("tilt", 0.0)
		_shader_material.set_shader_parameter("glow_intensity", 
			glow_intensity if is_active else 0.0)
		_shader_material.set_shader_parameter("x_rot", 0.0)
		_shader_material.set_shader_parameter("y_rot", 0.0)
	
	# Reset label
	if label_bg:
		if not _is_hovering:
			label_bg.visible = false
			label_bg.modulate.a = 0.0
		else:
			label_bg.visible = true
			label_bg.modulate.a = 1.0
		label_bg.scale = Vector2.ONE
		
	# Reset buttons
	if sell_button:
		sell_button.visible = _sell_button_visible
	if use_button:
		use_button.visible = _use_button_visible && is_useable
	
	# Reset shadow
	if shadow:
		shadow.scale = Vector2.ONE
		shadow.position = Vector2(5, 5)


func set_data(new_data: ConsumableData) -> void:
	data = new_data
	_apply_data_to_ui()

func _set_shader_tilt(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("tilt", value)

func _set_shader_glow(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", value)

func set_useable(useable: bool) -> void:
	print("[ConsumableIcon] set_useable =", useable)
	is_useable = useable
	
	# Update visual state based on usability
	if is_useable:
		modulate = Color.WHITE
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	
	# Update use button visibility
	if use_button and _use_button_visible:
		use_button.visible = is_useable

func play_destruction_effect() -> void:
	print("[ConsumableIcon] play_destruction_effect called")
	if explosion_effect_scene:
		var screen_shake = get_tree().root.find_child("ScreenShake", true, false)
		if screen_shake:
			screen_shake.shake(0.4, 0.3)  # Moderate shake for 0.3 seconds
		
		print("[ConsumableIcon] Creating explosion instance from:", explosion_effect_scene.resource_path)
		_explosion_instance = explosion_effect_scene.instantiate()
		if _explosion_instance:
			# Get the root viewport instead of parent for UI visibility
			var viewport = get_tree().root
			viewport.add_child(_explosion_instance)
			
			# Position at center of icon in global coordinates
			var center_pos = get_global_transform_with_canvas().origin + (size / 2)
			_explosion_instance.global_position = center_pos
			print("[ConsumableIcon] Positioned explosion at:", center_pos)
			
			# Ensure visibility and start emitting
			_explosion_instance.show()
			_explosion_instance.emitting = true
			print("[ConsumableIcon] Explosion effect started, emitting:", _explosion_instance.emitting)
			
			# Wait for entire lifetime plus a small buffer
			var total_time = _explosion_instance.lifetime * (1.0 + _explosion_instance.explosiveness)
			print("[ConsumableIcon] Waiting for total time:", total_time)
			await get_tree().create_timer(total_time).timeout
			
			print("[ConsumableIcon] Explosion effect cleanup started")
			_explosion_instance.queue_free()
			print("[ConsumableIcon] Explosion effect cleanup complete")
	else:
		push_error("[ConsumableIcon] No explosion effect scene available!")

func check_outside_click(event_position: Vector2) -> bool:
	if not _sell_button_visible and not _use_button_visible:
		return false
	# If buttons are visible, check if click is outside both card and buttons
	var card_rect = get_global_rect()
	var sell_button_rect = Rect2()
	var use_button_rect = Rect2()

	if sell_button and sell_button.visible:
		sell_button_rect = sell_button.get_global_rect()
	if use_button and use_button.visible:
		use_button_rect = use_button.get_global_rect()	

	if not card_rect.has_point(event_position) and not sell_button_rect.has_point(event_position) and not use_button_rect.has_point(event_position):
		# Click outside card and buttons, hide the buttons
		_sell_button_visible = false
		_use_button_visible = false
		if sell_button:
			sell_button.visible = false
		if use_button:
			use_button.visible = false

		return true

	return false

func _on_reroll_activated() -> void:
	print("[ConsumableIcon] Reroll activated")
	is_active = true
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", glow_intensity)
	modulate = Color(1.5, 1.5, 1.5)

func _on_reroll_completed() -> void:
	print("[ConsumableIcon] Reroll completed")
	is_used = true
	is_active = false
	
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", 0.0)
	modulate = Color.WHITE
	
	# Play explosion effect before removing
	play_destruction_effect()
	
	# Add a small delay for effect
	await get_tree().create_timer(0.2).timeout
	queue_free()

func _on_reroll_denied() -> void:
	print("[ConsumableIcon] Reroll denied")
	
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
			label_bg.visible = true
			hover_label.text = message
			
			# Reset after delay
			var timer = get_tree().create_timer(2.0)
			await timer.timeout
			hover_label.text = original_text
			if not _is_hovering:
				label_bg.visible = false

func _on_use_button_pressed() -> void:
	print("[ConsumableIcon] Use requested for:", data.id)
	
	if is_used:
		print("[ConsumableIcon] Consumable already used")
		return
		
	if not is_useable:
		print("[ConsumableIcon] Consumable not useable yet")
		_on_reroll_denied()
		return
	
	# Emit signal and update state
	emit_signal("consumable_used", data.id)
	is_active = true
	is_used = true  # Mark as used immediately
	
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", glow_intensity)
	modulate = Color(1.5, 1.5, 1.5)
	
	# Hide the buttons
	_sell_button_visible = false
	_use_button_visible = false
	if sell_button:
		sell_button.visible = false
	if use_button:
		use_button.visible = false
	
	# Play destruction effect and remove this icon
	play_destruction_effect()
	
	# Add a small delay for effect before removal
	await get_tree().create_timer(0.2).timeout
	queue_free()

func _on_sell_button_pressed() -> void:
	print("[ConsumableIcon] Sell requested for:", data.id)
	emit_signal("consumable_sell_requested", data.id)
	
	# Hide the buttons
	_sell_button_visible = false
	_use_button_visible = false
	if sell_button:
		sell_button.visible = false
	if use_button:
		use_button.visible = false

func _on_mouse_entered() -> void:
	print("[ConsumableIcon] Mouse entered:", data.id if data else "unknown")
	_is_hovering = true
	
	# Reset shader rotation parameters immediately
	if _shader_material:
		print("[ConsumableIcon] Resetting shader rotation parameters")
		_shader_material.set_shader_parameter("x_rot", 0.0)
		_shader_material.set_shader_parameter("y_rot", 0.0)
	
	# Cancel any existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween()
	card_info.visible = true
	# Show hover label
	if label_bg:
		label_bg.visible = true
		label_bg.modulate.a = 0.0
		label_bg.scale = Vector2(0.8, 0.8)
		
		# Animate label appearance
		_current_tween.tween_property(
			label_bg, "modulate:a", 1.0, transition_speed * 0.5
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		_current_tween.tween_property(
			label_bg, "scale", Vector2(1.1, 1.1), transition_speed * 0.5
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		_current_tween.tween_property(
			label_bg, "scale", Vector2.ONE, transition_speed * 0.25
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Animate card hover effect with elastic spring effect
	_current_tween.parallel().tween_property(
		self, "scale", Vector2.ONE * hover_scale, 0.5
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Animate shadow to be slightly larger
	if shadow:
		_current_tween.parallel().tween_property(
			shadow, "scale", Vector2.ONE * 1.1, 0.5
		).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Animate shader tilt
	if _shader_material:
		_current_tween.parallel().tween_method(
			_set_shader_tilt, 0.0, hover_tilt, transition_speed
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		_current_tween.parallel().tween_method(
			_set_shader_glow, 0.0, glow_intensity, transition_speed
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	

func _on_mouse_exited() -> void:
	print("[ConsumableIcon] Mouse exited:", data.id if data else "unknown")
	_is_hovering = false
	card_info.visible = false
	# Reset shader rotation parameters immediately
	if _shader_material:
		print("[ConsumableIcon] Resetting shader rotation parameters")
		_shader_material.set_shader_parameter("x_rot", 0.0)
		_shader_material.set_shader_parameter("y_rot", 0.0)
	
	# Immediately hide the label regardless of state
	if label_bg:
		label_bg.visible = false
	
	# If we're following the mouse, don't animate out yet
	if _following_mouse:
		return
		
	# Don't animate out if we're selected
	if _is_selected:
		return
		
	# Cancel any existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween()
	
	# Hide hover label with animation
	if label_bg:
		_current_tween.tween_property(
			label_bg, "modulate:a", 0.0, transition_speed
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Add a callback to ensure label is hidden after animation
		_current_tween.tween_callback(func(): label_bg.visible = false)
	
	# Animate card back to normal with elastic effect
	_current_tween.parallel().tween_property(
		self, "scale", Vector2.ONE, 0.55
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Animate shadow back to normal
	if shadow:
		_current_tween.parallel().tween_property(
			shadow, "scale", Vector2.ONE, 0.55
		).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Animate tilt back to zero (not needed since we already set it directly)
	_current_tween.parallel().tween_method(
		_set_shader_tilt, hover_tilt, 0.0, transition_speed
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	_current_tween.parallel().tween_method(
		_set_shader_glow, glow_intensity, 0.0, transition_speed
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
