extends Control
class_name ChallengeIcon

signal challenge_selected(id: String)

@export var data: ChallengeData
@export var glow_intensity: float = 0.25
@export var hover_tilt: float = 0.05
@export var hover_scale: float = 1.05
@export var transition_speed: float = 0.05
@export var max_offset_shadow: float = 20.0

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
var progress_bar: ProgressBar
var card_frame: TextureRect
var card_info: VBoxContainer
var card_title: Label
var shadow: TextureRect

var _shader_material: ShaderMaterial
var _is_hovering := false
var _is_selected := false
var _current_tween: Tween
var _following_mouse := false
var _last_pos := Vector2.ZERO
var _velocity := Vector2.ZERO
var _displacement := 0.0
var _oscillator_velocity := 0.0
var _default_position := Vector2.ZERO
var _hover_card_tween: Tween

var is_active := false

func _ready() -> void:
	print("[ChallengeIcon] Initializing...")
	
	# If we have no children, create the full card structure
	if get_child_count() == 0:
		print("[ChallengeIcon] Creating card structure")
		_create_card_structure()
	else:
		print("[ChallengeIcon] Children present, skipping structure creation")
		# Get references to existing nodes
		card_art = get_node_or_null("CardArt")
		label_bg = get_node_or_null("LabelBg")
		card_frame = get_node_or_null("CardFrame")
		card_info = get_node_or_null("CardInfo")
		shadow = get_node_or_null("Shadow")
		progress_bar = get_node_or_null("ProgressBar")
		card_title = card_info.get_node_or_null("Title") if card_info else null
		hover_label = label_bg.get_node_or_null("HoverLabel") if label_bg else null
			
	# Report missing nodes for debugging
	if not card_art:
		print("[ChallengeIcon] WARNING: CardArt node missing")
	if not label_bg:
		print("[ChallengeIcon] WARNING: LabelBg node missing")
	if not card_frame:
		print("[ChallengeIcon] WARNING: CardFrame node missing")
	if not card_info:
		print("[ChallengeIcon] WARNING: CardInfo node missing")
	if not card_title:
		print("[ChallengeIcon] WARNING: Title node missing")
	if not hover_label:
		print("[ChallengeIcon] WARNING: HoverLabel node missing")
	if not shadow:
		print("[ChallengeIcon] WARNING: Shadow node missing")
	if not progress_bar:
		print("[ChallengeIcon] WARNING: ProgressBar node missing")

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
	if progress_bar:
		progress_bar.value = 0
	if shadow:
		shadow.modulate = Color(0.0, 0.0, 0.0, 0.5)
		shadow.position = Vector2(5, 5)
		
	# Connect input signals if not already connected
	if not is_connected("mouse_entered", _on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not is_connected("mouse_exited", _on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	print("[ChallengeIcon] Setting up shader...")
	_setup_shader()

	# Convert angles to radians
	angle_x_max = deg_to_rad(angle_x_max)
	angle_y_max = deg_to_rad(angle_y_max)

	_apply_data_to_ui()
	
	_reset_visual_state()
	print("[ChallengeIcon] Initialization complete for:", data.id if data else "unknown")

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
	
	# Create ProgressBar
	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	progress_bar.z_index = 2
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.size_flags_vertical = SIZE_SHRINK_END
	progress_bar.custom_minimum_size = Vector2(0, 10)
	progress_bar.offset_bottom = -3
	progress_bar.offset_top = -13
	add_child(progress_bar)
	
	# Create CardInfo
	card_info = VBoxContainer.new()
	card_info.name = "CardInfo"
	card_info.z_index = 2
	card_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card_info.offset_top = -40  # Position above progress bar
	add_child(card_info)
	
	# Create Title
	card_title = Label.new()
	card_title.name = "Title"
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.add_theme_font_size_override("font_size", 16)
	card_info.add_child(card_title)
	
	# Create LabelBg
	label_bg = PanelContainer.new()
	label_bg.name = "LabelBg"
	label_bg.visible = false
	label_bg.z_index = 3
	label_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label_bg.position.y = -60
	label_bg.position.x = -20
	add_child(label_bg)
	
	# Create HoverLabel
	hover_label = Label.new()
	hover_label.name = "HoverLabel"
	hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_label.custom_minimum_size = Vector2(120, 0)
	hover_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hover_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label_bg.add_child(hover_label)

func _setup_shader() -> void:
	# Try to load shader
	var shader_path = "res://Scripts/Shaders/card_perspective.gdshader"
	var shader_res = load(shader_path)
	
	if not shader_res:
		print("[ChallengeIcon] WARNING: Could not load shader from path:", shader_path)
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
		print("No data assigned!")
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
		print("Setting hover_label text to:", data.description)
		hover_label.text = "%s\n%s" % [data.display_name, data.description]
		hover_label.modulate.a = 1.0 # Ensure fully visible
		hover_label.visible = true   # For debugging, always show
	else:
		print("hover_label is null!")

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
	print("[ChallengeIcon] Card pressed:", data.id if data else "unknown")
	# Emit the challenge_selected signal
	if data:
		emit_signal("challenge_selected", data.id)

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
	
	# Reset shadow
	if shadow:
		shadow.scale = Vector2.ONE
		shadow.position = Vector2(5, 5)


func set_data(new_data: ChallengeData) -> void:
	data = new_data
	_apply_data_to_ui()

func _set_shader_tilt(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("tilt", value)

func _set_shader_glow(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", value)

func set_active(active: bool) -> void:
	is_active = active
	
	# Visual feedback for active state
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", glow_intensity if active else 0.0)
	
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
	print("[ChallengeIcon] Mouse entered:", data.id if data else "unknown")
	_is_hovering = true
	
	# Reset shader rotation parameters immediately
	if _shader_material:
		print("[ChallengeIcon] Resetting shader rotation parameters")
		_shader_material.set_shader_parameter("x_rot", 0.0)
		_shader_material.set_shader_parameter("y_rot", 0.0)
	
	# Cancel any existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween()
	
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
	print("[ChallengeIcon] Mouse exited:", data.id if data else "unknown")
	_is_hovering = false
	
	# Reset shader rotation parameters immediately
	if _shader_material:
		print("[ChallengeIcon] Resetting shader rotation parameters")
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
		# Hide label after animation
		var hide_label = func():
			if label_bg:
				label_bg.visible = false
		_current_tween.tween_callback(hide_label)
	
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
