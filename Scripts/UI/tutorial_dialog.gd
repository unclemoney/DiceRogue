# Scripts/UI/tutorial_dialog.gd
extends Control

## TutorialDialog
##
## Displays Mom's tutorial messages with a typewriter effect.
## Includes Skip and Next buttons, step counter, and mom's expression sprite.

signal next_clicked
signal skip_confirmed
signal dialog_dismissed

# Constants
const TYPEWRITER_SPEED: float = 0.02  # Seconds per character
const GOLDEN_COLOR := Color(1.0, 0.85, 0.32, 1.0)
const DARK_PURPLE_BG := Color(0.08, 0.05, 0.15, 0.95)

# Fonts
var brick_font: Font = preload("res://Resources/Font/BRICK_SANS.ttf")
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# Mom textures
var mom_neutral_texture: Texture2D
var mom_happy_texture: Texture2D
var mom_upset_texture: Texture2D

# UI Components
var dialog_panel: PanelContainer
var mom_sprite: TextureRect
var title_label: Label
var step_counter_label: Label
var message_label: RichTextLabel
var skip_button: Button
var next_button: Button
var skip_confirm_dialog: ConfirmationDialog

# State
var _current_step = null  # TutorialStep
var _typewriter_tween: Tween
var _full_message_text: String = ""
var _typing_complete: bool = false


func _ready() -> void:
	# Ensure dialog works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[TutorialDialog] _ready() called")
	_load_textures()
	_build_ui()
	hide_dialog()
	print("[TutorialDialog] _ready() complete, dialog_panel exists: %s" % (dialog_panel != null))


## _load_textures()
##
## Loads Mom's expression textures.
func _load_textures() -> void:
	mom_neutral_texture = load("res://Resources/Art/Characters/Mom/mom_neutral.png")
	mom_happy_texture = load("res://Resources/Art/Characters/Mom/mom_happy.png")
	mom_upset_texture = load("res://Resources/Art/Characters/Mom/mom_upset.png")


## _build_ui()
##
## Creates the dialog UI programmatically.
func _build_ui() -> void:
	# Set to fill screen for positioning
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Main dialog panel - positioned at bottom center
	dialog_panel = PanelContainer.new()
	dialog_panel.name = "DialogPanel"
	dialog_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog_panel.custom_minimum_size = Vector2(600, 180)
	dialog_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialog_panel.offset_top = -200
	dialog_panel.offset_bottom = -20
	dialog_panel.offset_left = -310
	dialog_panel.offset_right = 310
	
	# Panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = DARK_PURPLE_BG
	panel_style.border_color = GOLDEN_COLOR
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	dialog_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(dialog_panel)
	
	# Main horizontal container
	var main_hbox = HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.add_theme_constant_override("separation", 15)
	dialog_panel.add_child(main_hbox)
	
	# Mom sprite container
	var sprite_container = VBoxContainer.new()
	sprite_container.name = "SpriteContainer"
	sprite_container.custom_minimum_size = Vector2(80, 0)
	main_hbox.add_child(sprite_container)
	
	# Mom sprite
	mom_sprite = TextureRect.new()
	mom_sprite.name = "MomSprite"
	mom_sprite.custom_minimum_size = Vector2(64, 64)
	mom_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	mom_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if mom_happy_texture:
		mom_sprite.texture = mom_happy_texture
	sprite_container.add_child(mom_sprite)
	
	# Spacer to push sprite to top
	var sprite_spacer = Control.new()
	sprite_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite_container.add_child(sprite_spacer)
	
	# Content container (title, message, buttons)
	var content_vbox = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.add_theme_constant_override("separation", 8)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(content_vbox)
	
	# Title row (title + step counter)
	var title_row = HBoxContainer.new()
	title_row.name = "TitleRow"
	content_vbox.add_child(title_row)
	
	# Title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "MOM'S TIPS"
	title_label.add_theme_font_override("font", brick_font)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", GOLDEN_COLOR)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	
	# Step counter label
	step_counter_label = Label.new()
	step_counter_label.name = "StepCounterLabel"
	step_counter_label.text = ""
	step_counter_label.add_theme_font_override("font", vcr_font)
	step_counter_label.add_theme_font_size_override("font_size", 14)
	step_counter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
	title_row.add_child(step_counter_label)
	
	# Message label (RichTextLabel for BBCode support)
	message_label = RichTextLabel.new()
	message_label.name = "MessageLabel"
	message_label.bbcode_enabled = true
	message_label.fit_content = true
	message_label.custom_minimum_size = Vector2(0, 60)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_label.add_theme_font_override("normal_font", vcr_font)
	message_label.add_theme_font_size_override("normal_font_size", 14)
	message_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95, 1.0))
	message_label.scroll_active = false
	content_vbox.add_child(message_label)
	
	# Button row
	var button_row = HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.add_theme_constant_override("separation", 15)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	content_vbox.add_child(button_row)
	
	# Skip button
	skip_button = _create_button("Skip Tutorial", Color(0.5, 0.4, 0.4, 1.0), true)
	skip_button.pressed.connect(_on_skip_pressed)
	button_row.add_child(skip_button)
	
	# Next button
	next_button = _create_button("Next →", Color(0.3, 0.7, 0.4, 1.0), false)
	next_button.pressed.connect(_on_next_pressed)
	button_row.add_child(next_button)
	
	# Skip confirmation dialog
	_build_skip_confirm_dialog()


## _create_button(text, color, small)
##
## Creates a styled button.
func _create_button(text: String, color: Color, small: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100 if small else 120, 32)
	btn.add_theme_font_override("font", vcr_font)
	btn.add_theme_font_size_override("font_size", 14 if small else 16)
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.12, 0.2, 0.95)
	normal_style.border_color = color * 0.7
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_color_override("font_color", color)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.17, 0.28, 0.98)
	hover_style.border_color = color
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_color_override("font_hover_color", color * 1.2)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = color * 0.3
	pressed_style.border_color = color * 1.2
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	return btn


## _build_skip_confirm_dialog()
##
## Creates the skip confirmation dialog.
func _build_skip_confirm_dialog() -> void:
	skip_confirm_dialog = ConfirmationDialog.new()
	skip_confirm_dialog.name = "SkipConfirmDialog"
	skip_confirm_dialog.title = "Skip Tutorial?"
	skip_confirm_dialog.dialog_text = "Are you sure you want to skip the tutorial?\n\nYou can replay it later from the main menu."
	skip_confirm_dialog.ok_button_text = "Skip"
	skip_confirm_dialog.cancel_button_text = "Continue Tutorial"
	skip_confirm_dialog.confirmed.connect(_on_skip_confirmed)
	add_child(skip_confirm_dialog)


## show_step(step)
##
## Shows a tutorial step with typewriter animation.
func show_step(step) -> void:
	print("[TutorialDialog] show_step called for: %s" % step.id)
	
	if not dialog_panel:
		push_error("[TutorialDialog] dialog_panel is null! UI not built yet.")
		return
	
	_current_step = step
	_typing_complete = false
	
	# Update title
	if step.title != "":
		title_label.text = step.title
	else:
		title_label.text = "MOM'S TIPS"
	
	# Update step counter
	var step_label_text = step.get_step_label()
	if step_label_text != "":
		step_counter_label.text = step_label_text
		step_counter_label.show()
	else:
		step_counter_label.hide()
	
	# Update expression
	_set_expression(step.mom_expression)
	
	# Start typewriter effect
	_full_message_text = step.message
	message_label.text = ""
	_start_typewriter()
	
	# Update button text for final step
	if step.is_final_step():
		next_button.text = "Finish!"
	else:
		next_button.text = "Next →"
	
	# Position dialog based on step hint
	_position_dialog(step)
	
	# Show dialog - ensure both the panel and self are visible
	show()
	dialog_panel.show()
	print("[TutorialDialog] Dialog shown, visible: %s, panel visible: %s" % [visible, dialog_panel.visible])


## hide_dialog()
##
## Hides the tutorial dialog.
func hide_dialog() -> void:
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	
	if dialog_panel:
		dialog_panel.hide()


## _position_dialog(step)
##
## Positions the dialog based on the step's dialog_position hint.
## "auto" tries to position opposite to the highlighted element to avoid overlap.
func _position_dialog(step) -> void:
	if not dialog_panel:
		return
	
	var screen_size = get_viewport_rect().size
	var dialog_size = dialog_panel.custom_minimum_size
	var margin := 20.0
	
	# Get position hint (defaults to "auto" if property doesn't exist)
	var position_hint := "auto"
	if step.has_method("get") and "dialog_position" in step:
		position_hint = step.dialog_position
	elif "dialog_position" in step:
		position_hint = step.dialog_position
	
	# For "auto", determine best position based on highlight
	if position_hint == "auto":
		position_hint = _determine_auto_position(step, screen_size)
	
	# Apply the position
	match position_hint:
		"top":
			# Position at top center
			dialog_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
			dialog_panel.offset_top = margin
			dialog_panel.offset_bottom = margin + 180
			dialog_panel.offset_left = -310
			dialog_panel.offset_right = 310
		"bottom":
			# Position at bottom center (default)
			dialog_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			dialog_panel.offset_top = -200
			dialog_panel.offset_bottom = -margin
			dialog_panel.offset_left = -310
			dialog_panel.offset_right = 310
		"left":
			# Position at left center
			dialog_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
			dialog_panel.offset_left = margin
			dialog_panel.offset_right = margin + 620
			dialog_panel.offset_top = -90
			dialog_panel.offset_bottom = 90
		"right":
			# Position at right center
			dialog_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			dialog_panel.offset_left = -620 - margin
			dialog_panel.offset_right = -margin
			dialog_panel.offset_top = -90
			dialog_panel.offset_bottom = 90
		"center":
			# Position at center
			dialog_panel.set_anchors_preset(Control.PRESET_CENTER)
			dialog_panel.offset_left = -310
			dialog_panel.offset_right = 310
			dialog_panel.offset_top = -90
			dialog_panel.offset_bottom = 90
		_:
			# Default to bottom
			dialog_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			dialog_panel.offset_top = -200
			dialog_panel.offset_bottom = -margin
			dialog_panel.offset_left = -310
			dialog_panel.offset_right = 310
	
	print("[TutorialDialog] Positioned at: %s" % position_hint)


## _determine_auto_position(step, screen_size)
##
## Automatically determines the best dialog position based on the highlight location.
func _determine_auto_position(step, screen_size: Vector2) -> String:
	# If no highlight path, default to top (out of the way of VCR buttons)
	if step.highlight_node_path == "":
		return "top"
	
	# Try to find the highlighted node to determine its position
	var game_root = _get_game_root()
	if not game_root:
		return "top"
	
	var highlight_target = game_root.get_node_or_null(step.highlight_node_path)
	if not highlight_target:
		return "top"
	
	# Get the highlight position
	var highlight_rect: Rect2
	if highlight_target is Control:
		highlight_rect = (highlight_target as Control).get_global_rect()
	elif highlight_target is Node2D:
		var pos = (highlight_target as Node2D).global_position
		highlight_rect = Rect2(pos - Vector2(100, 50), Vector2(200, 100))
	else:
		return "top"
	
	var highlight_center = highlight_rect.get_center()
	
	# If highlight is in bottom half of screen, show dialog at top
	if highlight_center.y > screen_size.y * 0.5:
		return "top"
	# If highlight is in top half, show at bottom
	else:
		return "bottom"


## _get_game_root() -> Node
##
## Gets the game scene root for finding highlighted nodes.
func _get_game_root() -> Node:
	var game_controllers = get_tree().get_nodes_in_group("game_controller")
	if game_controllers.size() > 0:
		return game_controllers[0].get_parent()
	return get_tree().current_scene


## _set_expression(expression_name)
##
## Sets Mom's expression sprite.
func _set_expression(expression_name: String) -> void:
	match expression_name.to_lower():
		"happy":
			if mom_happy_texture:
				mom_sprite.texture = mom_happy_texture
		"upset":
			if mom_upset_texture:
				mom_sprite.texture = mom_upset_texture
		_:  # "neutral" or default
			if mom_neutral_texture:
				mom_sprite.texture = mom_neutral_texture


## _start_typewriter()
##
## Starts the typewriter text reveal effect.
func _start_typewriter() -> void:
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	
	# Calculate total duration based on text length
	var char_count = _strip_bbcode(_full_message_text).length()
	var duration = char_count * TYPEWRITER_SPEED
	
	# Use visible_ratio for typewriter effect
	message_label.text = _full_message_text
	message_label.visible_ratio = 0.0
	
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(message_label, "visible_ratio", 1.0, duration)
	_typewriter_tween.finished.connect(_on_typewriter_complete)


## _strip_bbcode(text)
##
## Removes BBCode tags from text for character counting.
func _strip_bbcode(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)


## _on_typewriter_complete()
##
## Called when typewriter animation finishes.
func _on_typewriter_complete() -> void:
	_typing_complete = true


## _on_skip_pressed()
##
## Called when Skip button is pressed.
func _on_skip_pressed() -> void:
	skip_confirm_dialog.popup_centered()


## _on_skip_confirmed()
##
## Called when skip is confirmed in the dialog.
func _on_skip_confirmed() -> void:
	skip_confirmed.emit()


## _on_next_pressed()
##
## Called when Next button is pressed.
func _on_next_pressed() -> void:
	# If still typing, complete immediately
	if not _typing_complete:
		if _typewriter_tween and _typewriter_tween.is_valid():
			_typewriter_tween.kill()
		message_label.visible_ratio = 1.0
		_typing_complete = true
		return
	
	# Otherwise, advance to next step
	next_clicked.emit()


## _input(event)
##
## Handle keyboard input for dialog.
func _input(event: InputEvent) -> void:
	if not dialog_panel or not dialog_panel.visible:
		return
	
	# Space or Enter to advance (when dialog is visible)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_next_pressed()
			get_viewport().set_input_as_handled()
