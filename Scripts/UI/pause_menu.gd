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

# Scene reference
const MAIN_MENU_SCENE := preload("res://Scenes/UI/MainMenu.tscn")
const SETTINGS_MENU_SCENE := preload("res://Scenes/UI/SettingsMenu.tscn")

# Tutorial warning dialog
var tutorial_warning_dialog: ConfirmationDialog = null


func _ready() -> void:
	visible = false
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
	
	# Dark overlay background
	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Main panel
	var panel = PanelContainer.new()
	panel.name = "PausePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_top = -160
	panel.offset_right = 180
	panel.offset_bottom = 160
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.98)
	panel_style.border_color = Color(0.5, 0.45, 0.6, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
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
func show_menu() -> void:
	get_tree().paused = true
	visible = true
	resume_button.grab_focus()
	print("[PauseMenu] Pause menu opened")


## hide_menu()
##
## Hides the pause menu and resumes the game.
func hide_menu() -> void:
	visible = false
	get_tree().paused = false
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
	
	_return_to_main_menu()


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
