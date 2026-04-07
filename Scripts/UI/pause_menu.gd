extends Control

## PauseMenu
##
## Simple pause menu overlay with Resume and Main Menu options.
## Triggered by pressing Escape during gameplay.

signal resume_pressed
signal main_menu_pressed

# Font
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# UI References
var resume_button: Button
var main_menu_button: Button
var settings_button: Button
var settings_menu: Control = null
var _overlay: ColorRect
var _panel: PanelContainer
var _is_animating: bool = false

# Scene reference
const MAIN_MENU_SCENE := preload("res://Scenes/UI/MainMenu.tscn")
const SETTINGS_MENU_SCENE := preload("res://Scenes/UI/SettingsMenu.tscn")

# Tutorial warning dialog
var tutorial_warning_dialog: ConfirmationDialog = null

@onready var _tfx := get_node("/root/TweenFXHelper")


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_on_resume_pressed()
		else:
			show_menu()
		get_viewport().set_input_as_handled()


## _build_ui()
##
## Programmatically builds the pause menu UI.
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 200  # Always on top of everything (shop=100, fan-outs=120-135)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block all input to elements behind
	
	# Dark overlay background
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0.75)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.name = "PausePanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -180
	_panel.offset_top = -160
	_panel.offset_right = 180
	_panel.offset_bottom = 160
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.98)
	panel_style.border_color = Color(0.5, 0.45, 0.6, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(vbox)
	
	# Spacer
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(top_spacer)
	
	# Title
	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", vcr_font)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.95, 1.0))
	vbox.add_child(title)
	
	# Spacer
	var mid_spacer = Control.new()
	mid_spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(mid_spacer)
	
	# Button container
	var btn_container = VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_container)
	
	# Resume button
	resume_button = _create_button("RESUME", Color(0.3, 0.7, 0.4, 1.0))
	resume_button.pressed.connect(_on_resume_pressed)
	btn_container.add_child(resume_button)
	
	# Settings button
	settings_button = _create_button("SETTINGS", Color(0.5, 0.5, 0.7, 1.0))
	settings_button.pressed.connect(_on_settings_pressed)
	btn_container.add_child(settings_button)
	
	# Main Menu button
	main_menu_button = _create_button("MAIN MENU", Color(0.7, 0.5, 0.4, 1.0))
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	btn_container.add_child(main_menu_button)
	
	# Connect TweenFX hover/press effects to all buttons
	var all_buttons = [resume_button, settings_button, main_menu_button]
	for btn in all_buttons:
		btn.mouse_entered.connect(func(): _tfx.button_hover(btn))
		btn.mouse_exited.connect(func(): _tfx.button_unhover(btn))
		btn.pressed.connect(func(): _tfx.button_press(btn))
	
	# Build tutorial warning dialog
	_build_tutorial_warning_dialog()


## _create_button(text, accent_color)
##
## Creates a styled button.
func _create_button(text: String, accent_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240, 45)
	btn.add_theme_font_override("font", vcr_font)
	btn.add_theme_font_size_override("font_size", 22)
	
	# Normal style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	normal_style.border_color = accent_color * 0.7
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_color_override("font_color", accent_color)
	
	# Hover style
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.18, 0.15, 0.22, 0.98)
	hover_style.border_color = accent_color
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_color_override("font_hover_color", accent_color * 1.2)
	
	# Pressed style
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = accent_color * 0.3
	pressed_style.border_color = accent_color * 1.2
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	
	return btn


## show_menu()
##
## Shows the pause menu and pauses the game.
## Plays bouncy drop-in entrance animation.
func show_menu() -> void:
	get_tree().paused = true
	visible = true
	_is_animating = true
	_animate_in()
	resume_button.grab_focus()
	print("[PauseMenu] Pause menu opened")


## hide_menu()
##
## Hides the pause menu and resumes the game.
## Plays fly-off exit animation before hiding.
func hide_menu() -> void:
	if _is_animating:
		return
	_is_animating = true
	print("[PauseMenu] Pause menu closing")
	await _animate_out()
	visible = false
	get_tree().paused = false
	_is_animating = false
	print("[PauseMenu] Pause menu closed")


## _on_resume_pressed()
##
## Handler for Resume button.
func _on_resume_pressed() -> void:
	hide_menu()
	resume_pressed.emit()


## _on_settings_pressed()
##
## Handler for Settings button.
func _on_settings_pressed() -> void:
	# Create settings menu if not exists
	if not settings_menu:
		settings_menu = SETTINGS_MENU_SCENE.instantiate()
		settings_menu.closed.connect(_on_settings_closed)
		settings_menu.process_mode = Node.PROCESS_MODE_ALWAYS  # Process even when paused
		add_child(settings_menu)
	
	settings_menu.show_menu()


## _on_settings_closed()
##
## Handler for when settings menu is closed.
func _on_settings_closed() -> void:
	# Re-focus resume button
	resume_button.grab_focus()


## _on_main_menu_pressed()
##
## Handler for Main Menu button.
func _on_main_menu_pressed() -> void:
	# Check if tutorial is in progress and warn player
	var tutorial_manager = get_node_or_null("/root/TutorialManager")
	if tutorial_manager and tutorial_manager.is_tutorial_active():
		_show_tutorial_warning()
		return
	
	hide_menu()
	_return_to_main_menu()


## _animate_in()
##
## Bouncy drop-in entrance for the pause panel.
## Overlay fades in, panel drops from above with bounce and jelly settle.
## Uses local create_tween() (bound to this node with PROCESS_MODE_ALWAYS)
## instead of TweenFX so animations run while the tree is paused.
func _animate_in() -> void:
	_overlay.modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	
	# Save original state for drop-in
	var original_pos: Vector2 = _panel.position
	var original_scale: Vector2 = _panel.scale
	_panel.position = original_pos - Vector2(0, 300)
	_panel.scale = Vector2(1.15, 0.85)
	_panel.modulate.a = 0.0
	
	# Fade in overlay
	var overlay_tween: Tween = create_tween()
	overlay_tween.tween_property(_overlay, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Drop in panel from above with bounce
	var panel_tween: Tween = create_tween()
	panel_tween.tween_property(_panel, "position", original_pos, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(_panel, "scale", original_scale, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.16)
	await panel_tween.finished
	
	# Jelly wobble settle
	var jelly_tween: Tween = create_tween()
	var s: Vector2 = _panel.scale
	jelly_tween.tween_property(_panel, "scale", s * Vector2(1.1, 0.9), 0.075).set_trans(Tween.TRANS_SINE)
	jelly_tween.tween_property(_panel, "scale", s * Vector2(0.9, 1.1), 0.075).set_trans(Tween.TRANS_SINE)
	jelly_tween.tween_property(_panel, "scale", s, 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_is_animating = false


## _animate_out()
##
## Fly-off exit for the pause panel.
## Panel flies up, overlay fades out.
## Uses local create_tween() so animations run while the tree is paused.
func _animate_out() -> void:
	# Panel flies up off screen
	var original_pos: Vector2 = _panel.position
	var panel_tween: Tween = create_tween()
	panel_tween.tween_property(_panel, "position", original_pos + Vector2(0, -400), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	panel_tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.18)
	await panel_tween.finished
	
	# Fade out overlay
	var overlay_tween: Tween = create_tween()
	overlay_tween.tween_property(_overlay, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await overlay_tween.finished
	
	# Reset panel position for next show
	_panel.position = original_pos
	_panel.modulate.a = 1.0


## _show_tutorial_warning()
##
## Shows a warning dialog when player tries to quit during tutorial.
func _show_tutorial_warning() -> void:
	if tutorial_warning_dialog:
		tutorial_warning_dialog.popup_centered()


## _build_tutorial_warning_dialog()
##
## Creates the tutorial warning confirmation dialog.
func _build_tutorial_warning_dialog() -> void:
	tutorial_warning_dialog = ConfirmationDialog.new()
	tutorial_warning_dialog.name = "TutorialWarningDialog"
	tutorial_warning_dialog.title = "Leave Tutorial?"
	tutorial_warning_dialog.dialog_text = "You're in the middle of the tutorial!\n\nIf you leave now, the tutorial will be marked as incomplete and will restart next time you play.\n\nAre you sure you want to leave?"
	tutorial_warning_dialog.ok_button_text = "Leave Anyway"
	tutorial_warning_dialog.cancel_button_text = "Continue Tutorial"
	tutorial_warning_dialog.confirmed.connect(_on_tutorial_warning_confirmed)
	tutorial_warning_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tutorial_warning_dialog)


## _on_tutorial_warning_confirmed()
##
## Called when player confirms leaving during tutorial.
func _on_tutorial_warning_confirmed() -> void:
	_return_to_main_menu()


## _return_to_main_menu()
##
## Actually returns to the main menu.
func _return_to_main_menu() -> void:
	print("[PauseMenu] Returning to main menu")
	main_menu_pressed.emit()
	
	# Save progress before leaving
	if ProgressManager:
		ProgressManager.save_current_profile()
	
	# Unpause before changing scene
	get_tree().paused = false
	
	# Change to main menu scene
	get_tree().change_scene_to_packed(MAIN_MENU_SCENE)
