extends Control
class_name ChannelManagerUI

## ChannelManagerUI
##
## A TV remote-style UI for selecting the starting difficulty channel.
## Displays at game start, allowing player to choose Channel 1-99.
## Features Up/Down buttons, channel display, and Start button.

signal start_pressed(channel: int)

# References
var channel_manager = null

# UI Components
var overlay: ColorRect
var panel_container: PanelContainer
var channel_label: Label
var checkmark_icon: Label
var completion_label: Label
var multiplier_label: Label
var difficulty_label: Label
var up_button: Button
var down_button: Button
var start_button: Button

# Font
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")


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
	# Create semi-transparent overlay
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
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
	
	overlay.add_child(panel_container)
	
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
	buttons_hbox.add_child(down_button)
	
	# Up button
	up_button = _create_channel_button("▲", Color(0.3, 0.8, 0.3))
	up_button.pressed.connect(_on_up_pressed)
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
	
	# Update difficulty label color based on difficulty
	if mult < 1.1:
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
	
	# Update completion status display
	_update_completion_status()


## _update_completion_status() -> void
##
## Updates the checkmark icon and completion label based on channel completion.
## Animates checkmark with scale tween when channel is completed.
func _update_completion_status() -> void:
	if not checkmark_icon or not completion_label or not channel_manager:
		return
	
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		return
	
	var current_channel = channel_manager.current_channel
	var is_completed = progress_manager.is_channel_completed(current_channel)
	
	if is_completed:
		# Show checkmark with animation
		checkmark_icon.visible = true
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
func _on_start_pressed() -> void:
	if channel_manager:
		channel_manager.select_channel()
		emit_signal("start_pressed", channel_manager.current_channel)
	hide_channel_selector()


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
## Animates the panel appearing.
func _animate_entrance() -> void:
	panel_container.scale = Vector2(0.5, 0.5)
	panel_container.modulate.a = 0.0
	overlay.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(panel_container, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## _animate_exit() -> void
##
## Animates the panel disappearing.
func _animate_exit() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(overlay, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	tween.tween_property(panel_container, "scale", Vector2(0.8, 0.8), 0.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false
