extends Control
class_name PowerUpIcon

signal power_up_selected(power_up_id: String)
signal power_up_deselected(power_up_id: String)
signal power_up_sell_requested(power_up_id: String)

@export var data: PowerUpData
@export var glow_intensity: float = 0.25
@export var hover_tilt: float = 0.05
@export var hover_scale: float = 1.05
@export var transition_speed: float = 0.05
@export var max_offset_shadow: float = 20.0

# Mouse movement variables
@export var spring: float = 150.0
@export var damp: float = 10.0
@export var velocity_multiplier: float = 2.0

# Add these properties near the top of your class
@export var angle_x_max: float = 25.0  # Maximum X rotation angle in degrees
@export var angle_y_max: float = 25.0  # Maximum Y rotation angle in degrees

# Node references - initialized in _ready
var card_art: TextureRect
var label_bg: PanelContainer
var hover_label: Label
var sell_button: Button
var card_frame: TextureRect
var card_info: VBoxContainer
var card_title: Label
var shadow: TextureRect
var rarity_icon: TextureRect
var rarity_label: Label

var _shader_material: ShaderMaterial
var _is_hovering := false
var _is_selected := false
var _current_tween: Tween
var _sell_button_visible := false
var _following_mouse := false
var _last_pos := Vector2.ZERO
var _velocity := Vector2.ZERO
var _displacement := 0.0
var _oscillator_velocity := 0.0
var _default_position := Vector2.ZERO
var _hover_card_tween: Tween

# Add these class variables near the top
var _sell_mode_active := false
var _sell_button_pressed := false  # Track when the sell button itself is clicked

func _ready() -> void:
	print("[PowerUpIcon] Initializing...")
	
	# If we have no children, create the full card structure
	if get_child_count() == 0:
		print("[PowerUpIcon] Creating card structure")
		_create_card_structure()
	else:
		# Get references to existing nodes
		card_art = get_node_or_null("CardArt")
		label_bg = get_node_or_null("LabelBg")
		sell_button = get_node_or_null("SellButton")
		card_frame = get_node_or_null("CardFrame")
		card_info = get_node_or_null("CardInfo")
		shadow = get_node_or_null("Shadow")
		rarity_icon = get_node_or_null("RarityIcon")
		rarity_label = rarity_icon.get_node_or_null("RarityLabel") if rarity_icon else null
		card_title = card_info.get_node_or_null("Title") if card_info else null
		hover_label = label_bg.get_node_or_null("HoverLabel") if label_bg else null
	
	# Report missing nodes for debugging
	if not card_art:
		print("[PowerUpIcon] WARNING: CardArt node missing")
	if not label_bg:
		print("[PowerUpIcon] WARNING: LabelBg node missing")
	if not sell_button:
		print("[PowerUpIcon] WARNING: SellButton node missing")
	if not card_frame:
		print("[PowerUpIcon] WARNING: CardFrame node missing")
	if not card_info:
		print("[PowerUpIcon] WARNING: CardInfo node missing")
	if not card_title:
		print("[PowerUpIcon] WARNING: Title node missing")
	if not hover_label:
		print("[PowerUpIcon] WARNING: HoverLabel node missing")
	if not shadow:
		print("[PowerUpIcon] WARNING: Shadow node missing")
	if not rarity_icon:
		print("[PowerUpIcon] WARNING: RarityIcon node missing")
	if not rarity_label:
		print("[PowerUpIcon] WARNING: RarityLabel node missing")
	
	# Setup card visuals
	custom_minimum_size = Vector2(80, 120)  # Standard card ratio 2:3
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER
	
	# Connect input signals if not already connected
	if not is_connected("mouse_entered", _on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not is_connected("mouse_exited", _on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	
	# Setup shader material
	_setup_shader()
	
	# Convert angles to radians
	angle_x_max = deg_to_rad(angle_x_max)
	angle_y_max = deg_to_rad(angle_y_max)
	
	# Apply textures and text if we have data
	_apply_data_to_ui()
	
	# Reset visual state
	_reset_visual_state()
	
	# Call this at the end of ready to ensure the position is captured after layout
	call_deferred("_update_default_position")
	
	print("[PowerUpIcon] Initialization complete for:", data.id if data else "unknown")

func _exit_tree() -> void:
	# Clean up stored tweens to prevent warnings
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
	if _hover_card_tween and _hover_card_tween.is_valid():
		_hover_card_tween.kill()
		_hover_card_tween = null

# Add this new function to update the default position after layout
func _update_default_position() -> void:
	# Wait for one frame to ensure layout is complete
	await get_tree().process_frame
	_default_position = position
	_last_pos = position
	print("[PowerUpIcon] Default position updated:", _default_position)

func _process(delta: float) -> void:
	_update_shadow(delta)
	_handle_mouse_following(delta)
	_update_rotation(delta)

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
	add_child(card_info)
	
	# Create Title
	card_title = Label.new()
	card_title.name = "Title"
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.add_theme_font_size_override("font_size", 16)
	card_info.add_child(card_title)
	
	# Create SellButton
	sell_button = Button.new()
	sell_button.name = "SellButton"
	sell_button.text = "SELL"
	sell_button.visible = false
	sell_button.z_index = 3
	sell_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sell_button.size = Vector2(44, 31)
	
	# Apply button styling directly
	_apply_action_button_style(sell_button)
	
	sell_button.pressed.connect(_on_sell_button_pressed)
	add_child(sell_button)
	
	# Create LabelBg
	label_bg = PanelContainer.new()
	label_bg.name = "LabelBg"
	label_bg.visible = false
	label_bg.z_index = 3
	label_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label_bg.position.y = -60
	label_bg.position.x = -60
	
	# Apply hover styling directly
	_apply_hover_tooltip_style(label_bg)
	add_child(label_bg)
	
	# Create HoverLabel
	hover_label = Label.new()
	hover_label.name = "HoverLabel"
	hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_label.custom_minimum_size = Vector2(220, 0)
	hover_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hover_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Apply label styling
	_apply_hover_label_style(hover_label)
	label_bg.add_child(hover_label)
	
	# Create RarityIcon
	rarity_icon = TextureRect.new()
	rarity_icon.name = "RarityIcon"
	rarity_icon.z_index = 4
	rarity_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	rarity_icon.size = Vector2(20, 20)
	rarity_icon.position = Vector2(-20, -20)
	add_child(rarity_icon)
	
	# Create RarityLabel
	rarity_label = Label.new()
	rarity_label.name = "RarityLabel"
	# Set anchors to top-left and offsets to 0 to fill parent
	rarity_label.anchor_left = 0.0
	rarity_label.anchor_top = 0.0
	rarity_label.anchor_right = 1.0
	rarity_label.anchor_bottom = 1.0
	rarity_label.offset_left = 0.0
	rarity_label.offset_top = 0.0
	rarity_label.offset_right = 0.0
	rarity_label.offset_bottom = 0.0
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 13)
	rarity_label.add_theme_color_override("font_color", Color.WHITE)
	rarity_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	rarity_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rarity_label.text = "C"
	rarity_icon.add_child(rarity_label)

func _setup_shader() -> void:
	# Try to load shader
	var shader_path = "res://Scripts/Shaders/card_perspective.gdshader"
	var shader_res = load(shader_path)
	
	if not shader_res:
		print("[PowerUpIcon] WARNING: Could not load shader from path:", shader_path)
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
	if card_art and data.icon:
		card_art.texture = data.icon
		card_art.custom_minimum_size = Vector2(59, 93) # match atlas region size
		card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Apply same texture to shadow and ensure it's visible
		if shadow:
			shadow.texture = data.icon
			shadow.visible = true
	elif card_art:
		card_art.texture = preload("res://icon.svg")
		if shadow:
			shadow.texture = preload("res://icon.svg")
	
	# Set text fields
	if card_title:
		card_title.text = data.display_name if data.display_name else "Unknown PowerUp"
		card_title.add_theme_color_override("font_color", Color.WHITE)
		card_title.add_theme_color_override("font_shadow_color", Color.BLACK)
		card_title.add_theme_color_override("font_outline_color", Color.BLACK)
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if hover_label:
		hover_label.text = data.description if data.description else "No description"
	
	# Set rarity display
	if rarity_icon and rarity_label:
		var rarity_char = PowerUpData.get_rarity_display_char(data.rarity)
		rarity_label.text = rarity_char
		
		# Try to load rarity icon texture
		var rarity_texture = load("res://Resources/Art/PowerUps/Rarity_Icon.png")
		if rarity_texture:
			rarity_icon.texture = rarity_texture
		else:
			print("[PowerUpIcon] WARNING: Could not load rarity icon texture")
		
		# Set color based on rarity
		var rarity_color = _get_rarity_color(data.rarity)
		rarity_label.add_theme_color_override("font_color", rarity_color)
		print("[PowerUpIcon] Set rarity display: %s (%s)" % [rarity_char, data.rarity])
		shadow.visible = true
	
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

func _gui_input(event: InputEvent) -> void:
	# Prevent card interaction if sell button was directly pressed
	if _sell_button_pressed:
		return
	
	# Handle mouse motion for card tilt
	if event is InputEventMouseMotion and _is_hovering and not _following_mouse:
		_handle_mouse_tilt(event.position)
	
	# Handle click events
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Don't trigger card press if clicking on sell button
				var local_point = mouse_event.position
				if sell_button and sell_button.visible and sell_button.get_rect().has_point(local_point - sell_button.position):
					return
				
				_on_pressed()
				_start_mouse_following()
			else:
				_stop_mouse_following()
			get_viewport().set_input_as_handled()

# Add this new function to handle mouse tilt based on position
func _handle_mouse_tilt(mouse_pos: Vector2) -> void:
	# Calculate normalized position (0-1) across card dimensions
	var lerp_val_x = clamp(mouse_pos.x / size.x, 0, 1) 
	var lerp_val_y = clamp(mouse_pos.y / size.y, 0, 1)
	
	# Calculate rotation angles
	var rot_x = rad_to_deg(lerp_angle(-angle_x_max, angle_x_max, lerp_val_x))
	var rot_y = rad_to_deg(lerp_angle(angle_y_max, -angle_y_max, lerp_val_y))
	
	# Apply to shader parameters
	if _shader_material:
		_shader_material.set_shader_parameter("x_rot", rot_y)
		_shader_material.set_shader_parameter("y_rot", rot_x)
		

func _start_mouse_following() -> void:
	# Store current position before we start following so we can return to it
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

func _on_mouse_entered() -> void:
	_is_hovering = true
	update_hover_description()
	
	# Cancel any existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween()
	card_info.visible = true  # Ensure card info is visible
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
	print("[PowerUpIcon] Mouse exited:", data.id if data else "unknown")
	_is_hovering = false
	
	# Reset shader rotation parameters immediately at the start
	if _shader_material:
		print("[PowerUpIcon] Resetting shader rotation parameters")
		_shader_material.set_shader_parameter("x_rot", 0.0)
		_shader_material.set_shader_parameter("y_rot", 0.0)
	
	card_info.visible = false  # Ensure card info is visible
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

func _on_pressed() -> void:
	print("[PowerUpIcon] Card pressed:", data.id if data else "unknown")
	
	# Toggle sell button visibility only for this card
	_sell_button_visible = !_sell_button_visible
	
	if sell_button:
		sell_button.visible = _sell_button_visible
		
		# If we're showing the sell button, hide it on all other cards
		if _sell_button_visible:
			var parent = get_parent()
			if parent:
				for child in parent.get_children():
					if child is PowerUpIcon and child != self and child._sell_button_visible:
						child._sell_button_visible = false
						if child.sell_button:
							child.sell_button.visible = false
	
	# Only toggle selection when hiding the sell button
	if not _sell_button_visible:
		_toggle_selection()

func _toggle_selection() -> void:
	_is_selected = !_is_selected
	
	if _is_selected:
		emit_signal("power_up_selected", data.id)
		
		# Highlight effect for selected state
		if _shader_material:
			_shader_material.set_shader_parameter("glow_intensity", glow_intensity * 1.5)
	else:
		emit_signal("power_up_deselected", data.id)
		
		# Reset visual state
	_reset_visual_state()

func _on_sell_button_pressed() -> void:
	print("[PowerUpIcon] Sell button pressed for:", data.id)
	_sell_button_pressed = true  # Set flag to indicate direct button press
	emit_signal("power_up_sell_requested", data.id)
	# Reset the flag after a short delay
	await get_tree().create_timer(0.1).timeout
	_sell_button_pressed = false

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
			glow_intensity if _is_selected else 0.0)
	
	# Reset label
	if label_bg:
		if not _is_hovering:
			label_bg.visible = false
			label_bg.modulate.a = 0.0
		else:
			label_bg.visible = true
			label_bg.modulate.a = 1.0
		label_bg.scale = Vector2.ONE
	
	# Reset sell button
	if sell_button:
		sell_button.visible = _sell_button_visible
	
	# Reset shadow
	if shadow:
		shadow.scale = Vector2.ONE
		shadow.position = Vector2(5, 5)

func set_data(new_data: PowerUpData) -> void:
	data = new_data
	_apply_data_to_ui()

func _set_shader_tilt(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("tilt", value)

func _set_shader_glow(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", value)

# Compatibility methods to maintain current functionality
func get_is_selected() -> bool:
	return _is_selected
	
func deselect() -> void:
	if _is_selected:
		_toggle_selection()
	
	if _sell_button_visible:
		_sell_button_visible = false
		if sell_button:
			sell_button.visible = false
		_sell_mode_active = false
		
		# Remove the static variable reference here
		# Update global sell mode state
		# PowerUpIcon._any_sell_button_active = false
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child is PowerUpIcon and child != self and child._sell_button_visible:
					# Don't try to set the static variable
					# PowerUpIcon._any_sell_button_active = true
					break

func select() -> void:
	if not _is_selected:
		_toggle_selection()

# Add this new function for PowerUpUI to call when the container is clicked
func check_outside_click(event_position: Vector2) -> bool:
	if not _sell_button_visible:
		return false
	
	# If sell button is visible, check if click is outside both card and button
	var card_rect = get_global_rect()
	var button_rect = Rect2()
	
	if sell_button:
		button_rect = sell_button.get_global_rect()
	
	if not card_rect.has_point(event_position) and not button_rect.has_point(event_position):
		# Click outside both card and button, hide the sell button
		_sell_button_visible = false
		if sell_button:
			sell_button.visible = false
		
		return true
	
	return false

# Helper function to get rarity color
func _get_rarity_color(rarity_string: String) -> Color:
	match rarity_string.to_lower():
		"common": return Color.GRAY
		"uncommon": return Color.GREEN
		"rare": return Color.BLUE
		"epic": return Color.PURPLE
		"legendary": return Color.ORANGE
		_: return Color.WHITE

# Add to power_up_icon.gd
func update_hover_description() -> void:
	print("[PowerUpIcon] Updating hover description for:", data.id if data else "unknown")
	
	if not data or not hover_label:
		print("[PowerUpIcon] Missing data or hover_label")
		return
		
	var description = data.description
	print("[PowerUpIcon] Default description:", description)
	
	# Get the current node that might be referenced by this icon
	var power_up_node = null
	
	# Find the GameController directly
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		power_up_node = game_controller.get_active_power_up(data.id)
		print("[PowerUpIcon] Found power_up_node via GameController:", power_up_node)
	
	# If we found the node, try to get its current description
	if power_up_node and power_up_node.has_method("get_current_description"):
		print("[PowerUpIcon] Node has get_current_description method")
		description = power_up_node.get_current_description()
		print("[PowerUpIcon] Updated description:", description)
	else:
		print("[PowerUpIcon] No method get_current_description found")
		
	hover_label.text = description
	print("[PowerUpIcon] Set hover_label.text to:", hover_label.text)

## _apply_action_button_style(button)
## Applies the action button styling directly to a button
func _apply_action_button_style(button: Button) -> void:
	# Load VCR font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile
	if vcr_font:
		button.add_theme_font_override("font", vcr_font)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Color(1, 0.98, 0.9, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 0.95, 1))
		button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		button.add_theme_constant_override("outline_size", 1)
	
	# Create style boxes for different states
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.95)
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(1, 0.8, 0.2, 1)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.content_margin_left = 8.0
	style_normal.content_margin_top = 6.0
	style_normal.content_margin_right = 8.0
	style_normal.content_margin_bottom = 6.0
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.18, 0.25, 0.98)
	style_hover.border_width_left = 3
	style_hover.border_width_top = 3
	style_hover.border_width_right = 3
	style_hover.border_width_bottom = 3
	style_hover.border_color = Color(1, 0.9, 0.3, 1)
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.content_margin_left = 8.0
	style_hover.content_margin_top = 6.0
	style_hover.content_margin_right = 8.0
	style_hover.content_margin_bottom = 6.0
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.25, 0.22, 0.3, 1)
	style_pressed.border_width_left = 3
	style_pressed.border_width_top = 3
	style_pressed.border_width_right = 3
	style_pressed.border_width_bottom = 3
	style_pressed.border_color = Color(1, 1, 0.4, 1)
	style_pressed.corner_radius_top_left = 4
	style_pressed.corner_radius_top_right = 4
	style_pressed.corner_radius_bottom_right = 4
	style_pressed.corner_radius_bottom_left = 4
	style_pressed.content_margin_left = 8.0
	style_pressed.content_margin_top = 6.0
	style_pressed.content_margin_right = 8.0
	style_pressed.content_margin_bottom = 6.0
	
	# Apply styles to button
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	print("[PowerUpIcon] Direct button styling applied")

## _apply_hover_tooltip_style(panel)
## Applies the hover tooltip styling directly to a PanelContainer
func _apply_hover_tooltip_style(panel: PanelContainer) -> void:
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.06, 0.12, 0.98)
	style_box.border_width_left = 4
	style_box.border_width_top = 4
	style_box.border_width_right = 4
	style_box.border_width_bottom = 4
	style_box.border_color = Color(1, 0.8, 0.2, 1)
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.content_margin_left = 16.0
	style_box.content_margin_top = 12.0
	style_box.content_margin_right = 16.0
	style_box.content_margin_bottom = 12.0
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 2
	
	panel.add_theme_stylebox_override("panel", style_box)
	print("[PowerUpIcon] Hover tooltip styling applied")

## _apply_hover_label_style(label)
## Applies the hover label font styling directly to a Label
func _apply_hover_label_style(label: Label) -> void:
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1, 0.98, 0.9, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 1)
	print("[PowerUpIcon] Hover label styling applied")
