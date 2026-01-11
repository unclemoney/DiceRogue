extends Control

## MainMenu
##
## The main menu screen for Ghutzee. Features an animated title,
## 3 profile buttons, "Playing as" label, and navigation buttons.
## Manages transitions to game and settings.

signal new_game_pressed
signal settings_pressed
signal quit_pressed
signal profile_selected(slot: int)

# Fonts
var brick_font: Font = preload("res://Resources/Font/BRICK_SANS.ttf")
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# Scene references
# Use DebuffTest.tscn as the main game scene until a dedicated production scene is created
const GAME_SCENE := preload("res://Tests/DebuffTest.tscn")
const SETTINGS_MENU_SCENE := preload("res://Scenes/UI/SettingsMenu.tscn")

# Autoload reference (fetched at runtime to avoid LSP errors)
var _game_settings: Node = null

# UI References
var title_label: Label
var subtitle_label: Label
var playing_as_label: Label
var profile_button_container: HBoxContainer
var profile_buttons: Array[Button] = []
var button_container: VBoxContainer
var new_game_button: Button
var settings_button: Button
var quit_button: Button
var rename_dialog: ConfirmationDialog
var rename_line_edit: LineEdit  # Store direct reference to LineEdit
var settings_menu: Control = null

# Animation
var title_tween: Tween
var title_base_position: Vector2
const TITLE_FLOAT_AMOUNT := 8.0
const TITLE_FLOAT_DURATION := 2.5

# Currently selected profile for renaming
var _renaming_slot: int = 0


func _ready() -> void:
	_game_settings = get_node_or_null("/root/GameSettings")
	_build_ui()
	_update_profile_buttons()
	_update_playing_as_label()
	_start_title_animation()
	
	# Connect to profile changes
	if ProgressManager:
		ProgressManager.profile_loaded.connect(_on_profile_loaded)
		ProgressManager.profile_renamed.connect(_on_profile_renamed)


func _exit_tree() -> void:
	if title_tween and title_tween.is_valid():
		title_tween.kill()


## _build_ui()
##
## Programmatically builds the main menu UI.
func _build_ui() -> void:
	# Set this control to fill the viewport
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Background with shader - uses ColorRect like the game does
	var background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color.WHITE  # Base color for shader
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks
	
	# === SHADER SELECTION ===
	# Uncomment one shader option below to change the main menu background
	
	# CURRENT: Original Balatro-style swirl shader
	#var shader = load("res://Scripts/Shaders/backgground_swirl.gdshader")
	#var shader_params = {
	#	"colour_1": Color(0.15, 0.08, 0.25, 1.0),  # Dark purple
	#	"colour_2": Color(0.25, 0.12, 0.35, 1.0),  # Medium purple
	#	"colour_3": Color(0.08, 0.04, 0.15, 1.0),  # Very dark
	#	"spin_speed": 0.5,
	#	"contrast": 1.5,
	#	"spin_amount": 0.3,
	#	"lighting": 0.5,
	#	"pixel_filter": 500.0
	#}
	
	#OPTION 1: Neon Grid (Tron-style perspective grid)
	#var shader = load("res://Scripts/Shaders/neon_grid.gdshader")
	#var shader_params = {
	#	"colour_1": Color(0.15, 0.08, 0.25, 1.0),  # Dark purple base
	#	"colour_2": Color(0.0, 0.8, 0.8, 1.0),     # Teal/cyan neon
	#	"colour_3": Color(0.8, 0.0, 1.0, 1.0),     # Purple/magenta neon
	#	"grid_speed": 0.3,
	#	"pixel_filter": 500.0,
	#	"grid_density": 20.0,
	#	"perspective_strength": 1.0,
	#	"glow_intensity": 1.2,
	#	"scanline_strength": 0.3
	#}
	
	# OPTION 2: VHS Static Wave (Analog TV interference)
	var shader = load("res://Scripts/Shaders/vhs_wave.gdshader")
	var shader_params = {
		"colour_1": Color(0.08, 0.04, 0.15, 1.0),  # Very dark purple
		"colour_2": Color(0.25, 0.12, 0.35, 1.0),  # Medium purple
		"colour_3": Color(0.0, 0.6, 0.7, 1.0),     # Teal accent
		"wave_speed": 0.5,
		"pixel_filter": 500.0,
		"wave_density": 8.0,
		"wave_amplitude": 0.05,
		"chromatic_drift": 0.02,
		"noise_strength": 0.15,
		"scanline_intensity": 0.4
	}
	
	# OPTION 3: Arcade Starfield (80's space arcade)
	#var shader = load("res://Scripts/Shaders/arcade_starfield.gdshader")
	#var shader_params = {
	#	"colour_1": Color(0.08, 0.04, 0.15, 1.0),  # Dark purple space
	#	"colour_2": Color(0.8, 0.0, 1.0, 1.0),     # Purple/magenta stars
	#	"colour_3": Color(0.0, 0.8, 0.8, 1.0),     # Teal/cyan stars
	#	"star_speed": 0.2,
	#	"pixel_filter": 500.0,
	#	"star_density": 200.0,
	#	"twinkle_speed": 2.0,
	#	"comet_trails": 0.3,
	#	"color_cycle_speed": 1.0
	#}
	
	# Apply selected shader
	if shader:
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = shader
		# Set all parameters from the selected shader_params dictionary
		for param_name in shader_params:
			shader_mat.set_shader_parameter(param_name, shader_params[param_name])
		background.material = shader_mat
		print("[MainMenu] Shader applied to background: ", shader.resource_path)
	else:
		print("[MainMenu] WARNING: Could not load shader!")
		background.color = Color(0.1, 0.05, 0.15, 1.0)  # Fallback solid color
	add_child(background)
	
	# Main container
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_CENTER)
	main_container.offset_left = -400
	main_container.offset_top = -300
	main_container.offset_right = 400
	main_container.offset_bottom = 300
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# Spacer at top
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 40)
	main_container.add_child(top_spacer)
	
	# Title section
	_build_title_section(main_container)
	
	# Spacer
	var mid_spacer = Control.new()
	mid_spacer.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(mid_spacer)
	
	# Profile buttons section
	_build_profile_section(main_container)
	
	# Navigation buttons section
	_build_navigation_section(main_container)
	
	# Build rename dialog
	_build_rename_dialog()


## _build_title_section(parent)
##
## Builds the animated title and subtitle.
func _build_title_section(parent: Control) -> void:
	var title_container = VBoxContainer.new()
	title_container.name = "TitleContainer"
	title_container.add_theme_constant_override("separation", 5)
	parent.add_child(title_container)
	
	# Main title - "GHUTZEE"
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "GHUTZEE!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", brick_font)
	title_label.add_theme_font_size_override("font_size", 120)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))  # Golden yellow
	title_label.add_theme_color_override("font_shadow_color", Color(0.6, 0.3, 0.0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_container.add_child(title_label)
	
	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = "A Daring Dice Adventure"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_override("font", vcr_font)
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
	title_container.add_child(subtitle_label)


## _build_profile_section(parent)
##
## Builds the profile buttons and "Playing as" label.
func _build_profile_section(parent: Control) -> void:
	var profile_section = VBoxContainer.new()
	profile_section.name = "ProfileSection"
	profile_section.add_theme_constant_override("separation", 15)
	parent.add_child(profile_section)
	
	# Playing as label
	playing_as_label = Label.new()
	playing_as_label.name = "PlayingAsLabel"
	playing_as_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	playing_as_label.add_theme_font_override("font", vcr_font)
	playing_as_label.add_theme_font_size_override("font_size", 18)
	playing_as_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 1.0))  # Green tint
	profile_section.add_child(playing_as_label)
	
	# Center container for profile buttons
	var profile_center = CenterContainer.new()
	profile_center.name = "ProfileCenter"
	profile_section.add_child(profile_center)
	
	# Profile button container
	profile_button_container = HBoxContainer.new()
	profile_button_container.name = "ProfileButtons"
	profile_button_container.add_theme_constant_override("separation", 20)
	profile_center.add_child(profile_button_container)
	
	# Create 3 profile buttons
	for i in range(1, 4):
		var btn = _create_profile_button(i)
		profile_button_container.add_child(btn)
		profile_buttons.append(btn)


## _create_profile_button(slot)
##
## Creates a profile selection button for the given slot.
func _create_profile_button(slot: int) -> Button:
	var btn = Button.new()
	btn.name = "ProfileButton%d" % slot
	btn.custom_minimum_size = Vector2(180, 80)
	btn.add_theme_font_override("font", vcr_font)
	btn.add_theme_font_size_override("font_size", 16)
	
	# Style the button
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.12, 0.18, 0.9)
	normal_style.border_color = Color(0.4, 0.35, 0.45, 1.0)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 10
	normal_style.content_margin_right = 10
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.15, 0.25, 0.95)
	hover_style.border_color = Color(0.6, 0.5, 0.7, 1.0)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.25, 0.2, 0.3, 1.0)
	pressed_style.border_color = Color(0.7, 0.6, 0.8, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	# Connect signals
	btn.pressed.connect(_on_profile_button_pressed.bind(slot))
	btn.gui_input.connect(_on_profile_button_gui_input.bind(slot))
	
	return btn


## _build_navigation_section(parent)
##
## Builds the main navigation buttons (New Game, Settings, Quit).
func _build_navigation_section(parent: Control) -> void:
	# Center container
	var nav_center = CenterContainer.new()
	nav_center.name = "NavigationCenter"
	parent.add_child(nav_center)
	
	button_container = VBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.add_theme_constant_override("separation", 15)
	nav_center.add_child(button_container)
	
	# New Game button
	new_game_button = _create_nav_button("NEW GAME", Color(0.3, 0.7, 0.4, 1.0))
	new_game_button.pressed.connect(_on_new_game_pressed)
	button_container.add_child(new_game_button)
	
	# Settings button
	settings_button = _create_nav_button("SETTINGS", Color(0.5, 0.5, 0.7, 1.0))
	settings_button.pressed.connect(_on_settings_pressed)
	button_container.add_child(settings_button)
	
	# Quit button
	quit_button = _create_nav_button("QUIT", Color(0.7, 0.4, 0.4, 1.0))
	quit_button.pressed.connect(_on_quit_pressed)
	button_container.add_child(quit_button)


## _create_nav_button(text, accent_color)
##
## Creates a navigation button with consistent styling.
func _create_nav_button(text: String, accent_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 55)
	btn.add_theme_font_override("font", vcr_font)
	btn.add_theme_font_size_override("font_size", 28)
	
	# Normal style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	normal_style.border_color = accent_color * 0.7
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(10)
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


## _build_rename_dialog()
##
## Builds the profile rename dialog.
func _build_rename_dialog() -> void:
	rename_dialog = ConfirmationDialog.new()
	rename_dialog.name = "RenameDialog"
	rename_dialog.title = "Rename Profile"
	rename_dialog.size = Vector2(400, 180)
	rename_dialog.unresizable = true
	
	# Create content container
	var dialog_vbox = VBoxContainer.new()
	dialog_vbox.add_theme_constant_override("separation", 15)
	
	var name_label = Label.new()
	name_label.text = "Enter new profile name (max 30 characters):"
	name_label.add_theme_font_override("font", vcr_font)
	name_label.add_theme_font_size_override("font_size", 14)
	dialog_vbox.add_child(name_label)
	
	# Create and store direct reference to LineEdit
	rename_line_edit = LineEdit.new()
	rename_line_edit.name = "NameEdit"
	rename_line_edit.max_length = 30
	rename_line_edit.placeholder_text = "Profile Name"
	rename_line_edit.custom_minimum_size = Vector2(350, 35)
	rename_line_edit.add_theme_font_override("font", vcr_font)
	rename_line_edit.add_theme_font_size_override("font_size", 16)
	dialog_vbox.add_child(rename_line_edit)
	
	# Add the VBox to the dialog's content area
	rename_dialog.add_child(dialog_vbox)
	
	rename_dialog.confirmed.connect(_on_rename_confirmed)
	rename_dialog.canceled.connect(_on_rename_canceled)
	
	add_child(rename_dialog)


## _start_title_animation()
##
## Starts the floating animation for the title.
func _start_title_animation() -> void:
	if not title_label:
		return
	
	title_base_position = title_label.position
	_animate_title_float()


## _animate_title_float()
##
## Creates a looping float animation for the title.
func _animate_title_float() -> void:
	if title_tween and title_tween.is_valid():
		title_tween.kill()
	
	title_tween = create_tween()
	title_tween.set_loops()
	title_tween.set_trans(Tween.TRANS_SINE)
	title_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Float up
	title_tween.tween_property(title_label, "position:y", 
		title_base_position.y - TITLE_FLOAT_AMOUNT, TITLE_FLOAT_DURATION)
	# Float down
	title_tween.tween_property(title_label, "position:y",
		title_base_position.y + TITLE_FLOAT_AMOUNT, TITLE_FLOAT_DURATION)


## _update_profile_buttons()
##
## Updates the profile button text with profile names and stats.
func _update_profile_buttons() -> void:
	if not ProgressManager:
		return
	
	var profiles = ProgressManager.list_profiles()
	var current_slot = _game_settings.active_profile_slot if _game_settings else 1
	
	for i in range(profile_buttons.size()):
		var btn = profile_buttons[i]
		var info = profiles[i]
		var slot = i + 1
		
		# Build button text with name and brief stats
		var btn_text = "%s\n" % info["name"]
		if info["games_completed"] > 0:
			btn_text += "Games: %d | Best Ch: %d" % [info["games_completed"], info["highest_channel"]]
		else:
			btn_text += "New Profile"
		
		btn.text = btn_text
		
		# Highlight the active profile
		if slot == current_slot:
			_set_profile_button_active(btn, true)
		else:
			_set_profile_button_active(btn, false)


## _set_profile_button_active(button, active)
##
## Sets the visual state of a profile button as active or inactive.
func _set_profile_button_active(button: Button, active: bool) -> void:
	var style = button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if active:
		style.border_color = Color(0.4, 0.8, 0.4, 1.0)  # Green border for active
		style.set_border_width_all(3)
	else:
		style.border_color = Color(0.4, 0.35, 0.45, 1.0)
		style.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", style)


## _update_playing_as_label()
##
## Updates the "Playing as" label with the current profile name.
func _update_playing_as_label() -> void:
	if not playing_as_label:
		return
	
	var profile_name = "Player 1"
	if ProgressManager:
		profile_name = ProgressManager.get_current_profile_name()
	
	playing_as_label.text = "Playing as: %s" % profile_name


## _on_profile_button_pressed(slot)
##
## Handler for when a profile button is clicked.
## Left-click selects the profile.
func _on_profile_button_pressed(slot: int) -> void:
	print("[MainMenu] Profile %d selected" % slot)
	
	# Update active profile in settings
	if _game_settings:
		_game_settings.active_profile_slot = slot
		_game_settings.save_settings()
	
	# Load the profile
	if ProgressManager:
		ProgressManager.load_profile(slot)
	
	# Update UI
	_update_profile_buttons()
	_update_playing_as_label()
	profile_selected.emit(slot)


## _on_profile_button_gui_input(event, slot)
##
## Handler for profile button input.
## Right-click opens the rename dialog.
func _on_profile_button_gui_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("[MainMenu] Profile %d right-clicked - showing rename dialog" % slot)
			_show_rename_dialog(slot)


## _show_rename_dialog(slot)
##
## Shows the rename dialog for the given profile slot.
func _show_rename_dialog(slot: int) -> void:
	_renaming_slot = slot
	
	# Get current name
	var current_name = "Player %d" % slot
	if ProgressManager:
		var info = ProgressManager.get_profile_info(slot)
		current_name = info["name"]
	
	# Set up dialog using direct reference
	if rename_line_edit:
		rename_line_edit.text = current_name
		rename_line_edit.select_all()
	
	rename_dialog.title = "Rename Profile %d" % slot
	rename_dialog.popup_centered()
	
	# Focus the line edit (deferred to ensure dialog is fully shown)
	if rename_line_edit:
		rename_line_edit.call_deferred("grab_focus")


## _on_rename_confirmed()
##
## Handler for when rename dialog is confirmed.
func _on_rename_confirmed() -> void:
	if not rename_line_edit:
		return
	
	var new_name = rename_line_edit.text.strip_edges()
	if new_name.is_empty():
		return
	
	if ProgressManager:
		ProgressManager.rename_profile(_renaming_slot, new_name)
	
	# Also select this profile after renaming
	if _game_settings:
		_game_settings.active_profile_slot = _renaming_slot
		_game_settings.save_settings()
	
	if ProgressManager:
		ProgressManager.load_profile(_renaming_slot)
	
	_update_profile_buttons()
	_update_playing_as_label()
	profile_selected.emit(_renaming_slot)


## _on_rename_canceled()
##
## Handler for when rename dialog is canceled.
func _on_rename_canceled() -> void:
	_renaming_slot = 0


## _on_new_game_pressed()
##
## Handler for New Game button - transitions to game scene.
func _on_new_game_pressed() -> void:
	print("[MainMenu] New Game pressed - transitioning to game scene")
	new_game_pressed.emit()
	
	# Change to game scene
	get_tree().change_scene_to_packed(GAME_SCENE)


## _on_settings_pressed()
##
## Handler for Settings button - shows settings menu overlay.
func _on_settings_pressed() -> void:
	print("[MainMenu] Settings pressed")
	settings_pressed.emit()
	
	# Create settings menu if not exists
	if not settings_menu:
		settings_menu = SETTINGS_MENU_SCENE.instantiate()
		settings_menu.closed.connect(_on_settings_closed)
		add_child(settings_menu)
	
	settings_menu.show_menu()


## _on_settings_closed()
##
## Handler for when settings menu is closed.
func _on_settings_closed() -> void:
	print("[MainMenu] Settings closed")


## _on_quit_pressed()
##
## Handler for Quit button.
func _on_quit_pressed() -> void:
	print("[MainMenu] Quit pressed")
	quit_pressed.emit()
	get_tree().quit()


## _on_profile_loaded(_slot)
##
## Handler for when a profile is loaded.
func _on_profile_loaded(_slot: int) -> void:
	_update_profile_buttons()
	_update_playing_as_label()


## _on_profile_renamed(_slot, _new_name)
##
## Handler for when a profile is renamed.
func _on_profile_renamed(_slot: int, _new_name: String) -> void:
	_update_profile_buttons()
	_update_playing_as_label()
