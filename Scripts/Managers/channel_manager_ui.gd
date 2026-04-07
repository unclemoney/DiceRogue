extends Control
class_name ChannelManagerUI

## ChannelManagerUI
##
## A TV remote-style UI for selecting the starting difficulty channel.
## Displays at game start, allowing player to choose Channel 1-20.
## Features Up/Down buttons, channel display, and Start button.

signal start_pressed(channel: int)

# References
var channel_manager = null

# UI Components
var overlay: ColorRect
var shader_overlay: ColorRect
var panel_container: PanelContainer
var channel_label: Label
var checkmark_icon: Label
var completion_label: Label
var multiplier_label: Label
var difficulty_label: Label
var up_button: Button
var down_button: Button
var start_button: Button
var _intro_label: Label

# Shader
var _shader_material: ShaderMaterial

# Font
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

@onready var _tfx := get_node("/root/TweenFXHelper")


func _ready() -> void:
	visible = false
	_build_ui()


## set_channel_manager(manager) -> void
##
## Sets the ChannelManager reference and connects signals.
func set_channel_manager(manager) -> void:
	channel_manager = manager
	if channel_manager:
		channel_manager.channel_changed.connect(_on_channel_changed)
		_update_display()


## show_channel_selector() -> void
##
## Shows the channel selection UI for game start.
func show_channel_selector() -> void:
	print("[ChannelManagerUI] Showing channel selector")
	_update_display()
	
	# Position and size this control to fill the viewport
	var viewport = get_viewport()
	if viewport:
		var viewport_rect = viewport.get_visible_rect()
		global_position = Vector2.ZERO
		size = viewport_rect.size
		# Set z_index high to ensure it's on top
		z_index = 100
	
	visible = true
	_animate_entrance()


## hide_channel_selector() -> void
##
## Hides the channel selection UI.
func hide_channel_selector() -> void:
	print("[ChannelManagerUI] Hiding channel selector")
	_animate_exit()


## _build_ui() -> void
##
## Programmatically builds the TV remote-style UI.
func _build_ui() -> void:
	# Create dark base overlay (blocks input)
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Create VHS shader overlay on top of the dark base
	shader_overlay = ColorRect.new()
	shader_overlay.name = "ShaderOverlay"
	shader_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = ShaderMaterial.new()
	var shader = load("res://Scripts/Shaders/vhs_wave.gdshader")
	if shader:
		_shader_material.shader = shader
		_shader_material.set_shader_parameter("wave_speed", 0.5)
		_shader_material.set_shader_parameter("chromatic_drift", 0.02)
		_shader_material.set_shader_parameter("noise_strength", 0.15)
		_shader_material.set_shader_parameter("scanline_intensity", 0.4)
		shader_overlay.material = _shader_material
	shader_overlay.modulate.a = 0.0
	add_child(shader_overlay)
	
	# Create intro label ("CHOOSE YOUR CHANNEL") — hidden until entrance animation
	_intro_label = Label.new()
	_intro_label.name = "IntroLabel"
	_intro_label.text = "CHOOSE YOUR CHANNEL"
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_label.add_theme_font_override("font", vcr_font)
	_intro_label.add_theme_font_size_override("font_size", 36)
	_intro_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	_intro_label.set_anchors_preset(Control.PRESET_CENTER)
	_intro_label.offset_left = -250
	_intro_label.offset_top = -30
	_intro_label.offset_right = 250
	_intro_label.offset_bottom = 30
	_intro_label.modulate.a = 0.0
	_intro_label.visible = false
	add_child(_intro_label)
	
	# Create centered panel container (TV Remote shape)
	panel_container = PanelContainer.new()
	panel_container.name = "RemotePanel"
	panel_container.custom_minimum_size = Vector2(280, 420)
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.offset_left = -140
	panel_container.offset_top = -210
	panel_container.offset_right = 140
	panel_container.offset_bottom = 210
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Load and apply theme
	var theme_path = "res://Resources/UI/powerup_hover_theme.tres"
	var panel_theme = load(theme_path) as Theme
	if panel_theme:
		panel_container.theme = panel_theme
	
	# Create custom StyleBox for remote look
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	style.border_color = Color(0.3, 0.25, 0.35, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.corner_detail = 8
	panel_container.add_theme_stylebox_override("panel", style)
	
	add_child(panel_container)
	
	# Main vertical container
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 15)
	panel_container.add_child(main_vbox)
	
	# Add margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	main_vbox.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(content_vbox)
	
	# Title
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "SELECT CHANNEL"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", vcr_font)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	content_vbox.add_child(title_label)
	
	# Separator
	var sep1 = HSeparator.new()
	content_vbox.add_child(sep1)
	
	# Channel display (large LED-style numbers)
	var display_panel = PanelContainer.new()
	display_panel.custom_minimum_size = Vector2(200, 80)
	
	var display_style = StyleBoxFlat.new()
	display_style.bg_color = Color(0.05, 0.08, 0.05, 1.0)
	display_style.border_color = Color(0.2, 0.25, 0.2, 1.0)
	display_style.set_border_width_all(2)
	display_style.set_corner_radius_all(6)
	display_panel.add_theme_stylebox_override("panel", display_style)
	content_vbox.add_child(display_panel)
	
	var display_vbox = VBoxContainer.new()
	display_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	display_panel.add_child(display_vbox)
	
	# HBox container for checkmark + channel number
	var channel_hbox = HBoxContainer.new()
	channel_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	channel_hbox.add_theme_constant_override("separation", 8)
	display_vbox.add_child(channel_hbox)
	
	# Checkmark icon (hidden by default, animated when shown)
	checkmark_icon = Label.new()
	checkmark_icon.name = "CheckmarkIcon"
	checkmark_icon.text = "✓"
	checkmark_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	checkmark_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	checkmark_icon.add_theme_font_override("font", vcr_font)
	checkmark_icon.add_theme_font_size_override("font_size", 36)
	checkmark_icon.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	checkmark_icon.visible = false
	checkmark_icon.scale = Vector2.ZERO
	checkmark_icon.pivot_offset = Vector2(18, 18)  # Center pivot for scaling
	channel_hbox.add_child(checkmark_icon)
	
	channel_label = Label.new()
	channel_label.name = "ChannelLabel"
	channel_label.text = "01"
	channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	channel_label.add_theme_font_override("font", vcr_font)
	channel_label.add_theme_font_size_override("font_size", 48)
	channel_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	channel_hbox.add_child(channel_label)
	
	# Multiplier display
	multiplier_label = Label.new()
	multiplier_label.name = "MultiplierLabel"
	multiplier_label.text = "1.00x"
	multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	multiplier_label.add_theme_font_override("font", vcr_font)
	multiplier_label.add_theme_font_size_override("font_size", 16)
	multiplier_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	content_vbox.add_child(multiplier_label)
	
	# Difficulty description
	difficulty_label = Label.new()
	difficulty_label.name = "DifficultyLabel"
	difficulty_label.text = "Easy"
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_label.add_theme_font_override("font", vcr_font)
	difficulty_label.add_theme_font_size_override("font_size", 18)
	difficulty_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	content_vbox.add_child(difficulty_label)
	
	# Completion status label
	completion_label = Label.new()
	completion_label.name = "CompletionLabel"
	completion_label.text = "Not Completed"
	completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_label.add_theme_font_override("font", vcr_font)
	completion_label.add_theme_font_size_override("font_size", 14)
	completion_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	content_vbox.add_child(completion_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	content_vbox.add_child(spacer1)
	
	# Up/Down buttons container
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_hbox.add_theme_constant_override("separation", 20)
	content_vbox.add_child(buttons_hbox)
	
	# Down button
	down_button = _create_channel_button("▼", Color(0.8, 0.3, 0.3))
	down_button.pressed.connect(_on_down_pressed)
	down_button.mouse_entered.connect(_tfx.button_hover.bind(down_button))
	down_button.mouse_exited.connect(_tfx.button_unhover.bind(down_button))
	down_button.pressed.connect(_tfx.button_press.bind(down_button))
	buttons_hbox.add_child(down_button)
	
	# Up button
	up_button = _create_channel_button("▲", Color(0.3, 0.8, 0.3))
	up_button.pressed.connect(_on_up_pressed)
	up_button.mouse_entered.connect(_tfx.button_hover.bind(up_button))
	up_button.mouse_exited.connect(_tfx.button_unhover.bind(up_button))
	up_button.pressed.connect(_tfx.button_press.bind(up_button))
	buttons_hbox.add_child(up_button)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	content_vbox.add_child(spacer2)
	
	# Start button
	start_button = Button.new()
	start_button.name = "StartButton"
	start_button.text = "START"
	start_button.custom_minimum_size = Vector2(180, 60)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.add_theme_font_override("font", vcr_font)
	start_button.add_theme_font_size_override("font_size", 24)
	
	# Create start button style
	var start_style = StyleBoxFlat.new()
	start_style.bg_color = Color(0.2, 0.5, 0.2, 1.0)
	start_style.border_color = Color(0.3, 0.7, 0.3, 1.0)
	start_style.set_border_width_all(3)
	start_style.set_corner_radius_all(12)
	start_button.add_theme_stylebox_override("normal", start_style)
	
	var start_hover = start_style.duplicate()
	start_hover.bg_color = Color(0.25, 0.6, 0.25, 1.0)
	start_hover.border_color = Color(0.4, 0.9, 0.4, 1.0)
	start_button.add_theme_stylebox_override("hover", start_hover)
	
	var start_pressed_style = start_style.duplicate()
	start_pressed_style.bg_color = Color(0.15, 0.4, 0.15, 1.0)
	start_button.add_theme_stylebox_override("pressed", start_pressed_style)
	
	start_button.pressed.connect(_on_start_pressed)
	start_button.mouse_entered.connect(_tfx.button_hover.bind(start_button))
	start_button.mouse_exited.connect(_tfx.button_unhover.bind(start_button))
	start_button.pressed.connect(_tfx.button_press.bind(start_button))
	content_vbox.add_child(start_button)


## _create_channel_button(text: String, color: Color) -> Button
##
## Creates a styled channel button (up or down).
func _create_channel_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(70, 70)
	button.add_theme_font_override("font", vcr_font)
	button.add_theme_font_size_override("font_size", 32)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(35)
	button.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.bg_color = color.darkened(0.1)
	hover.border_color = color.lightened(0.2)
	button.add_theme_stylebox_override("hover", hover)
	
	var pressed = style.duplicate()
	pressed.bg_color = color.darkened(0.5)
	button.add_theme_stylebox_override("pressed", pressed)
	
	return button


## _update_display() -> void
##
## Updates all display elements based on current channel.
## Shows lock status for channels that require completions to unlock.
func _update_display() -> void:
	if not channel_manager:
		return
	
	# Guard against UI not being built yet
	if not channel_label or not multiplier_label or not difficulty_label:
		return
	
	channel_label.text = channel_manager.get_channel_display_text()
	
	var mult = channel_manager.get_difficulty_multiplier()
	multiplier_label.text = "%.2fx" % mult
	
	difficulty_label.text = channel_manager.get_difficulty_description()
	
	# Check if channel is locked
	var is_locked = false
	if channel_manager.has_method("is_channel_unlocked"):
		is_locked = not channel_manager.is_channel_unlocked(channel_manager.current_channel)
	
	# Update difficulty label color based on difficulty or lock status
	if is_locked:
		difficulty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))  # Gray for locked
	elif mult < 1.1:
		difficulty_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	elif mult < 2.0:
		difficulty_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	elif mult < 5.0:
		difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	elif mult < 15.0:
		difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
	elif mult < 40.0:
		difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	else:
		difficulty_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.5))
	
	# Update completion status display (also handles lock status)
	_update_completion_status()
	
	# Update start button state based on lock status
	_update_start_button_state(is_locked)


## _update_completion_status() -> void
##
## Updates the checkmark icon and completion label based on channel completion and lock status.
## Prioritizes showing lock status for locked channels.
## Animates checkmark with scale tween when channel is completed.
func _update_completion_status() -> void:
	if not checkmark_icon or not completion_label or not channel_manager:
		return
	
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		return
	
	var current_channel = channel_manager.current_channel
	
	# Check lock status first
	var is_locked = false
	var required_completions = 0
	if channel_manager.has_method("is_channel_unlocked"):
		is_locked = not channel_manager.is_channel_unlocked(current_channel)
		# Get unlock requirement for display
		var config = channel_manager.get_channel_config(current_channel) if channel_manager.has_method("get_channel_config") else null
		if config:
			required_completions = config.unlock_requirement
	
	if is_locked:
		# Show lock status
		checkmark_icon.visible = true
		checkmark_icon.text = "🔒"  # Lock emoji
		checkmark_icon.scale = Vector2.ONE
		checkmark_icon.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		
		# Show unlock requirement
		var completed_channels = progress_manager.get_completed_channel_count() if progress_manager.has_method("get_completed_channel_count") else 0
		completion_label.text = "Locked (%d/%d)" % [completed_channels, required_completions]
		completion_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		# Check completion status
		var is_completed = progress_manager.is_channel_completed(current_channel)
		
		if is_completed:
			# Show checkmark with animation
			checkmark_icon.visible = true
			checkmark_icon.text = "✓"  # Checkmark
			checkmark_icon.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			var tween = create_tween()
			tween.tween_property(checkmark_icon, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			
			# Update completion label
			completion_label.text = "Cleared"
			completion_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		else:
			# Hide checkmark (no animation needed)
			checkmark_icon.visible = false
			checkmark_icon.scale = Vector2.ZERO
			
			# Update completion label
			completion_label.text = "Not Completed"
			completion_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


## _on_up_pressed() -> void
##
## Handles the up button being pressed.
func _on_up_pressed() -> void:
	if channel_manager:
		channel_manager.increment_channel()
		_pulse_display()


## _on_down_pressed() -> void
##
## Handles the down button being pressed.
func _on_down_pressed() -> void:
	if channel_manager:
		channel_manager.decrement_channel()
		_pulse_display()


## _on_start_pressed() -> void
##
## Handles the start button being pressed.
## Prevents starting on locked channels.
func _on_start_pressed() -> void:
	if channel_manager:
		# Check if channel is locked
		if channel_manager.has_method("is_channel_unlocked"):
			if not channel_manager.is_channel_unlocked(channel_manager.current_channel):
				# Show feedback that channel is locked
				_show_locked_feedback()
				return
		
		channel_manager.select_channel()
		emit_signal("start_pressed", channel_manager.current_channel)
	hide_channel_selector()


## _update_start_button_state(is_locked) -> void
##
## Updates the start button appearance based on lock status.
## @param is_locked: Whether the current channel is locked
func _update_start_button_state(is_locked: bool) -> void:
	if not start_button:
		return
	
	if is_locked:
		start_button.text = "LOCKED"
		start_button.disabled = true
		start_button.modulate = Color(0.6, 0.6, 0.6)
	else:
		start_button.text = "START"
		start_button.disabled = false
		start_button.modulate = Color.WHITE


## _show_locked_feedback() -> void
##
## Shows visual feedback when player tries to start a locked channel.
func _show_locked_feedback() -> void:
	if not start_button:
		return
	
	# Shake the start button
	var original_pos = start_button.position
	var tween = create_tween()
	tween.tween_property(start_button, "position:x", original_pos.x + 10, 0.05)
	tween.tween_property(start_button, "position:x", original_pos.x - 10, 0.05)
	tween.tween_property(start_button, "position:x", original_pos.x + 5, 0.05)
	tween.tween_property(start_button, "position:x", original_pos.x, 0.05)
	
	# Flash red
	start_button.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.2).timeout
	start_button.modulate = Color(0.6, 0.6, 0.6)


## _on_channel_changed(new_channel: int) -> void
##
## Signal handler for when channel changes.
func _on_channel_changed(_new_channel: int) -> void:
	_update_display()


## _pulse_display() -> void
##
## Creates a visual pulse effect on the channel display.
func _pulse_display() -> void:
	var tween = create_tween()
	tween.tween_property(channel_label, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(channel_label, "scale", Vector2(1.0, 1.0), 0.1)


## _animate_entrance() -> void
##
## Cinematic entrance sequence:
## 1. Fade in dark overlay + VHS shader with bounce intensity
## 2. Drop in "CHOOSE YOUR CHANNEL" label with bounce, hold, then vanish
## 3. Drop in TV remote panel with bounce
func _animate_entrance() -> void:
	# Hide panel initially
	panel_container.modulate.a = 0.0
	panel_container.scale = Vector2.ONE
	panel_container.pivot_offset = panel_container.size / 2.0
	overlay.modulate.a = 0.0
	shader_overlay.modulate.a = 0.0
	_intro_label.visible = true
	_intro_label.modulate.a = 0.0
	_intro_label.pivot_offset = Vector2(250, 30)  # Center of the label
	
	# Step 1: Fade in dark overlay (0.3s)
	var overlay_tween = create_tween()
	overlay_tween.tween_property(overlay, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await overlay_tween.finished
	
	# Step 2: Fade in VHS shader overlay with bounce intensity (0.5s)
	var shader_tween = create_tween()
	shader_tween.tween_property(shader_overlay, "modulate:a", 0.6, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await shader_tween.finished
	
	# Step 3: Drop in "CHOOSE YOUR CHANNEL" label with bounce
	# Set alpha=1.0 right before drop_in so it doesn't flash during the overlay fades
	_intro_label.modulate.a = 1.0
	var label_tween = TweenFX.drop_in(_intro_label, 0.6, 150.0, Vector2(1.3, 0.7))
	await label_tween.finished
	
	# Hold the label for a moment
	await get_tree().create_timer(0.8).timeout
	
	# Step 4: Vanish the intro label
	var vanish_tween = TweenFX.vanish(_intro_label, 0.3)
	await vanish_tween.finished
	_intro_label.visible = false
	
	# Step 5: Drop in the TV remote panel with smooth overshoot landing
	var panel_original_pos: Vector2 = panel_container.position
	var panel_original_scale: Vector2 = panel_container.scale
	panel_container.position = panel_original_pos - Vector2(0, 200)
	panel_container.scale = Vector2(1.1, 0.9)
	panel_container.modulate.a = 0.0
	var panel_tween = create_tween()
	panel_tween.tween_property(panel_container, "position", panel_original_pos, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(panel_container, "scale", panel_original_scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(panel_container, "modulate:a", 1.0, 0.3)
	await panel_tween.finished


## _animate_exit() -> void
##
## Cinematic exit sequence:
## 1. TV remote flies off downward with acceleration
## 2. VHS shader fades out
## 3. Dark overlay fades out
func _animate_exit() -> void:
	# Step 1: TV remote flies off downward
	var panel_tween = TweenFX.drop_out(panel_container, 0.4, 600.0)
	await panel_tween.finished
	
	# Step 2: Fade out shader overlay (0.3s)
	var shader_tween = create_tween()
	shader_tween.tween_property(shader_overlay, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await shader_tween.finished
	
	# Step 3: Fade out dark overlay (0.2s)
	var overlay_tween = create_tween()
	overlay_tween.tween_property(overlay, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await overlay_tween.finished
	
	visible = false
