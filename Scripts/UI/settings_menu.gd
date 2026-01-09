extends Control

## SettingsMenu
##
## Multi-tab settings menu with Audio, Video, Gameplay, Keyboard, and Controller tabs.
## Features immediate audio preview, Apply button for video, and keybinding validation.

signal closed

# Fonts
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# Autoload reference (fetched at runtime to avoid LSP errors)
var _game_settings: Node = null

# UI References
var tab_container: TabContainer
var close_button: Button

# Audio tab
var sfx_slider: HSlider
var sfx_value_label: Label
var music_slider: HSlider
var music_value_label: Label

# Video tab
var resolution_option: OptionButton
var fullscreen_check: CheckButton
var apply_video_button: Button
var resolution_warning_label: Label

# Gameplay tab
var animation_speed_slider: HSlider
var animation_speed_label: Label

# Keyboard tab
var keyboard_binding_container: VBoxContainer
var keyboard_bindings: Dictionary = {}  # action -> Button

# Controller tab
var controller_binding_container: VBoxContainer
var controller_bindings: Dictionary = {}  # action -> Button

# Keybinding capture state
var _capturing_action: String = ""
var _capturing_is_controller: bool = false
var _capture_button: Button = null

# Resolution options
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]


func _ready() -> void:
	_game_settings = get_node_or_null("/root/GameSettings")
	_build_ui()
	_load_current_settings()


func _input(event: InputEvent) -> void:
	# Handle keybinding capture
	if _capturing_action.is_empty():
		return
	
	if _capturing_is_controller:
		if event is InputEventJoypadButton and event.pressed:
			_finish_capture(event)
			get_viewport().set_input_as_handled()
	else:
		if event is InputEventKey and event.pressed:
			_finish_capture(event)
			get_viewport().set_input_as_handled()


## _build_ui()
##
## Programmatically builds the settings menu UI.
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Dark overlay background
	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Main panel
	var panel = PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -400
	panel.offset_top = -300
	panel.offset_right = 400
	panel.offset_bottom = 300
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.98)
	panel_style.border_color = Color(0.4, 0.35, 0.5, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	
	# Main vbox
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)
	
	# Header with title and close button
	var header = _build_header()
	main_vbox.add_child(header)
	
	# Tab container
	tab_container = TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.custom_minimum_size = Vector2(750, 500)
	tab_container.add_theme_font_override("font", vcr_font)
	tab_container.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(tab_container)
	
	# Build tabs
	_build_audio_tab()
	_build_video_tab()
	_build_gameplay_tab()
	_build_keyboard_tab()
	_build_controller_tab()


## _build_header()
##
## Builds the header with title and close button.
func _build_header() -> Control:
	var header = HBoxContainer.new()
	header.name = "Header"
	
	var title = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_override("font", vcr_font)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.95, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.add_theme_font_override("font", vcr_font)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	
	return header


## _build_audio_tab()
##
## Builds the Audio settings tab with SFX and Music volume sliders.
func _build_audio_tab() -> void:
	var audio_tab = VBoxContainer.new()
	audio_tab.name = "Audio"
	audio_tab.add_theme_constant_override("separation", 25)
	tab_container.add_child(audio_tab)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	audio_tab.add_child(spacer)
	
	# SFX Volume
	var sfx_container = _create_slider_row("Sound Effects Volume", 0, 100, 1)
	sfx_slider = sfx_container.get_node("SliderRow/Slider") as HSlider
	sfx_value_label = sfx_container.get_node("SliderRow/ValueLabel") as Label
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	audio_tab.add_child(sfx_container)
	
	# Music Volume
	var music_container = _create_slider_row("Music Volume", 0, 100, 1)
	music_slider = music_container.get_node("SliderRow/Slider") as HSlider
	music_value_label = music_container.get_node("SliderRow/ValueLabel") as Label
	if music_slider:
		music_slider.value_changed.connect(_on_music_volume_changed)
	audio_tab.add_child(music_container)
	
	# Info label
	var info_label = Label.new()
	info_label.text = "Audio changes apply immediately."
	info_label.add_theme_font_override("font", vcr_font)
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	audio_tab.add_child(info_label)


## _build_video_tab()
##
## Builds the Video settings tab with resolution and fullscreen options.
func _build_video_tab() -> void:
	var video_tab = VBoxContainer.new()
	video_tab.name = "Video"
	video_tab.add_theme_constant_override("separation", 20)
	tab_container.add_child(video_tab)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	video_tab.add_child(spacer)
	
	# Resolution
	var res_row = HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 20)
	video_tab.add_child(res_row)
	
	var res_label = Label.new()
	res_label.text = "Resolution:"
	res_label.custom_minimum_size = Vector2(200, 0)
	res_label.add_theme_font_override("font", vcr_font)
	res_label.add_theme_font_size_override("font_size", 18)
	res_row.add_child(res_label)
	
	resolution_option = OptionButton.new()
	resolution_option.custom_minimum_size = Vector2(200, 40)
	resolution_option.add_theme_font_override("font", vcr_font)
	resolution_option.add_theme_font_size_override("font_size", 16)
	for res in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])
	res_row.add_child(resolution_option)
	
	# Resolution warning
	resolution_warning_label = Label.new()
	resolution_warning_label.add_theme_font_override("font", vcr_font)
	resolution_warning_label.add_theme_font_size_override("font_size", 14)
	resolution_warning_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 1.0))
	resolution_warning_label.visible = false
	video_tab.add_child(resolution_warning_label)
	
	# Fullscreen
	var fs_row = HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 20)
	video_tab.add_child(fs_row)
	
	var fs_label = Label.new()
	fs_label.text = "Fullscreen:"
	fs_label.custom_minimum_size = Vector2(200, 0)
	fs_label.add_theme_font_override("font", vcr_font)
	fs_label.add_theme_font_size_override("font_size", 18)
	fs_row.add_child(fs_label)
	
	fullscreen_check = CheckButton.new()
	fullscreen_check.add_theme_font_override("font", vcr_font)
	fs_row.add_child(fullscreen_check)
	
	# Apply button
	var apply_container = CenterContainer.new()
	video_tab.add_child(apply_container)
	
	apply_video_button = Button.new()
	apply_video_button.text = "APPLY"
	apply_video_button.custom_minimum_size = Vector2(150, 45)
	apply_video_button.add_theme_font_override("font", vcr_font)
	apply_video_button.add_theme_font_size_override("font_size", 20)
	apply_video_button.pressed.connect(_on_apply_video_pressed)
	apply_container.add_child(apply_video_button)
	
	# Info label
	var info_label = Label.new()
	info_label.text = "Click Apply to save video settings."
	info_label.add_theme_font_override("font", vcr_font)
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	video_tab.add_child(info_label)


## _build_gameplay_tab()
##
## Builds the Gameplay settings tab with animation speed slider.
func _build_gameplay_tab() -> void:
	var gameplay_tab = VBoxContainer.new()
	gameplay_tab.name = "Gameplay"
	gameplay_tab.add_theme_constant_override("separation", 25)
	tab_container.add_child(gameplay_tab)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	gameplay_tab.add_child(spacer)
	
	# Animation Speed
	var speed_container = _create_slider_row("Scoring Animation Speed", 0.5, 2.0, 0.1)
	animation_speed_slider = speed_container.get_node("SliderRow/Slider") as HSlider
	animation_speed_label = speed_container.get_node("SliderRow/ValueLabel") as Label
	if animation_speed_slider:
		animation_speed_slider.value_changed.connect(_on_animation_speed_changed)
	gameplay_tab.add_child(speed_container)
	
	# Speed description
	var desc_label = Label.new()
	desc_label.text = "0.5x = Slower (detailed), 2.0x = Faster (quick)"
	desc_label.add_theme_font_override("font", vcr_font)
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	gameplay_tab.add_child(desc_label)


## _build_keyboard_tab()
##
## Builds the Keyboard keybindings tab.
func _build_keyboard_tab() -> void:
	var keyboard_tab = VBoxContainer.new()
	keyboard_tab.name = "Keyboard"
	keyboard_tab.add_theme_constant_override("separation", 10)
	tab_container.add_child(keyboard_tab)
	
	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	keyboard_tab.add_child(scroll)
	
	keyboard_binding_container = VBoxContainer.new()
	keyboard_binding_container.add_theme_constant_override("separation", 8)
	scroll.add_child(keyboard_binding_container)
	
	# Build keybinding rows
	_build_keybinding_rows(keyboard_binding_container, false)
	
	# Reset button
	var reset_container = CenterContainer.new()
	keyboard_tab.add_child(reset_container)
	
	var reset_btn = Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.custom_minimum_size = Vector2(180, 40)
	reset_btn.add_theme_font_override("font", vcr_font)
	reset_btn.add_theme_font_size_override("font_size", 16)
	reset_btn.pressed.connect(_on_reset_keyboard_pressed)
	reset_container.add_child(reset_btn)


## _build_controller_tab()
##
## Builds the Controller keybindings tab.
func _build_controller_tab() -> void:
	var controller_tab = VBoxContainer.new()
	controller_tab.name = "Controller"
	controller_tab.add_theme_constant_override("separation", 10)
	tab_container.add_child(controller_tab)
	
	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controller_tab.add_child(scroll)
	
	controller_binding_container = VBoxContainer.new()
	controller_binding_container.add_theme_constant_override("separation", 8)
	scroll.add_child(controller_binding_container)
	
	# Build controller binding rows
	_build_keybinding_rows(controller_binding_container, true)
	
	# Reset button
	var reset_container = CenterContainer.new()
	controller_tab.add_child(reset_container)
	
	var reset_btn = Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.custom_minimum_size = Vector2(180, 40)
	reset_btn.add_theme_font_override("font", vcr_font)
	reset_btn.add_theme_font_size_override("font_size", 16)
	reset_btn.pressed.connect(_on_reset_controller_pressed)
	reset_container.add_child(reset_btn)


## _build_keybinding_rows(container, is_controller)
##
## Builds keybinding rows for keyboard or controller.
func _build_keybinding_rows(container: VBoxContainer, is_controller: bool) -> void:
	# Action names must match DEFAULT_KEYBINDINGS in game_settings.gd
	var action_names = {
		"roll": "Roll Dice",
		"next_turn": "Next Turn",
		"shop": "Open Shop",
		"next_round": "Next Round",
		"menu": "Menu / Back",
		"lock_dice_1": "Lock Die 1",
		"lock_dice_2": "Lock Die 2",
		"lock_dice_3": "Lock Die 3",
		"lock_dice_4": "Lock Die 4",
		"lock_dice_5": "Lock Die 5"
	}
	
	for action in action_names.keys():
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		container.add_child(row)
		
		var action_label = Label.new()
		action_label.text = action_names[action] + ":"
		action_label.custom_minimum_size = Vector2(200, 0)
		action_label.add_theme_font_override("font", vcr_font)
		action_label.add_theme_font_size_override("font_size", 16)
		row.add_child(action_label)
		
		var bind_btn = Button.new()
		bind_btn.name = action
		bind_btn.custom_minimum_size = Vector2(200, 35)
		bind_btn.add_theme_font_override("font", vcr_font)
		bind_btn.add_theme_font_size_override("font_size", 14)
		bind_btn.pressed.connect(_on_keybind_button_pressed.bind(action, is_controller, bind_btn))
		row.add_child(bind_btn)
		
		# Store reference
		if is_controller:
			controller_bindings[action] = bind_btn
		else:
			keyboard_bindings[action] = bind_btn
		
		# Set initial text
		_update_keybind_button_text(bind_btn, action, is_controller)


## _create_slider_row(label_text, min_val, max_val, step)
##
## Creates a labeled slider row.
func _create_slider_row(label_text: String, min_val: float, max_val: float, step: float) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_override("font", vcr_font)
	label.add_theme_font_size_override("font_size", 18)
	container.add_child(label)
	
	var slider_row = HBoxContainer.new()
	slider_row.name = "SliderRow"
	slider_row.add_theme_constant_override("separation", 15)
	container.add_child(slider_row)
	
	var slider = HSlider.new()
	slider.name = "Slider"
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.custom_minimum_size = Vector2(400, 30)
	slider_row.add_child(slider)
	
	var value_label = Label.new()
	value_label.name = "ValueLabel"
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.add_theme_font_override("font", vcr_font)
	value_label.add_theme_font_size_override("font_size", 16)
	slider_row.add_child(value_label)
	
	return container


## _load_current_settings()
##
## Loads current settings from _game_settings and updates UI.
func _load_current_settings() -> void:
	if not _game_settings:
		return
	
	# Audio
	sfx_slider.value = _game_settings.sfx_volume * 100
	sfx_value_label.text = "%d%%" % int(_game_settings.sfx_volume * 100)
	music_slider.value = _game_settings.music_volume * 100
	music_value_label.text = "%d%%" % int(_game_settings.music_volume * 100)
	
	# Video
	var current_res = _game_settings.screen_resolution
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == current_res:
			resolution_option.selected = i
			break
	fullscreen_check.button_pressed = _game_settings.fullscreen
	_validate_resolution_display()
	
	# Gameplay
	animation_speed_slider.value = _game_settings.scoring_animation_speed
	animation_speed_label.text = "%.1fx" % _game_settings.scoring_animation_speed
	
	# Keybindings
	_update_all_keybind_buttons()


## _update_all_keybind_buttons()
##
## Updates all keybinding button text from current settings.
func _update_all_keybind_buttons() -> void:
	for action in keyboard_bindings.keys():
		_update_keybind_button_text(keyboard_bindings[action], action, false)
	
	for action in controller_bindings.keys():
		_update_keybind_button_text(controller_bindings[action], action, true)


## _update_keybind_button_text(button, action, is_controller)
##
## Updates a keybind button's text to show the current binding.
func _update_keybind_button_text(button: Button, action: String, is_controller: bool) -> void:
	if not _game_settings:
		button.text = "---"
		return
	
	var code: int = 0
	if is_controller:
		code = _game_settings.controller_bindings.get(action, 0)
	else:
		code = _game_settings.keybindings.get(action, 0)
	
	if code != 0:
		if is_controller:
			button.text = _get_joypad_button_name(code)
		else:
			button.text = OS.get_keycode_string(code)
	else:
		button.text = "---"


## _get_joypad_button_name(button_index)
##
## Gets a human-readable name for a joypad button.
func _get_joypad_button_name(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A: return "A / Cross"
		JOY_BUTTON_B: return "B / Circle"
		JOY_BUTTON_X: return "X / Square"
		JOY_BUTTON_Y: return "Y / Triangle"
		JOY_BUTTON_LEFT_SHOULDER: return "LB / L1"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB / R1"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_BACK: return "Back / Select"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_GUIDE: return "Guide"
		JOY_BUTTON_DPAD_UP: return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Pad Right"
		_: return "Button %d" % button_index


## _validate_resolution_display()
##
## Validates selected resolution and shows warning if needed.
func _validate_resolution_display() -> void:
	if not resolution_warning_label:
		return
	
	var selected_idx = resolution_option.selected
	if selected_idx < 0 or selected_idx >= RESOLUTIONS.size():
		resolution_warning_label.visible = false
		return
	
	var selected_res = RESOLUTIONS[selected_idx]
	var screen_size = DisplayServer.screen_get_size()
	
	if selected_res.x > screen_size.x or selected_res.y > screen_size.y:
		resolution_warning_label.text = "Warning: Resolution larger than screen (%dx%d)" % [screen_size.x, screen_size.y]
		resolution_warning_label.visible = true
	else:
		resolution_warning_label.visible = false


## _on_sfx_volume_changed(value)
##
## Handler for SFX volume slider change.
func _on_sfx_volume_changed(value: float) -> void:
	sfx_value_label.text = "%d%%" % int(value)
	if _game_settings:
		_game_settings.sfx_volume = value / 100.0
		_game_settings.apply_audio_settings()
		_game_settings.save_settings()


## _on_music_volume_changed(value)
##
## Handler for Music volume slider change.
func _on_music_volume_changed(value: float) -> void:
	music_value_label.text = "%d%%" % int(value)
	if _game_settings:
		_game_settings.music_volume = value / 100.0
		_game_settings.apply_audio_settings()
		_game_settings.save_settings()


## _on_animation_speed_changed(value)
##
## Handler for animation speed slider change.
func _on_animation_speed_changed(value: float) -> void:
	animation_speed_label.text = "%.1fx" % value
	if _game_settings:
		_game_settings.scoring_animation_speed = value
		_game_settings.save_settings()


## _on_apply_video_pressed()
##
## Handler for Apply video settings button.
func _on_apply_video_pressed() -> void:
	if not _game_settings:
		return
	
	var selected_idx = resolution_option.selected
	if selected_idx >= 0 and selected_idx < RESOLUTIONS.size():
		_game_settings.screen_resolution = RESOLUTIONS[selected_idx]
	
	_game_settings.fullscreen = fullscreen_check.button_pressed
	_game_settings.apply_video_settings()
	_game_settings.save_settings()
	
	_validate_resolution_display()
	print("[SettingsMenu] Video settings applied")


## _on_keybind_button_pressed(action, is_controller, button)
##
## Handler for keybind button click - starts capture mode.
func _on_keybind_button_pressed(action: String, is_controller: bool, button: Button) -> void:
	_capturing_action = action
	_capturing_is_controller = is_controller
	_capture_button = button
	
	button.text = "Press key..."
	if is_controller:
		button.text = "Press button..."


## _finish_capture(event)
##
## Finishes keybinding capture with the given event.
func _finish_capture(event: InputEvent) -> void:
	if _capturing_action.is_empty() or not _capture_button:
		return
	
	if not _game_settings:
		_cancel_capture()
		return
	
	# Extract the keycode or button index from the event
	var code: int = 0
	if event is InputEventKey:
		# Use keycode for consistent display with OS.get_keycode_string()
		# Fall back to physical_keycode if keycode is 0
		code = event.keycode if event.keycode != 0 else event.physical_keycode
	elif event is InputEventJoypadButton:
		code = event.button_index
	else:
		_cancel_capture()
		return
	
	# Validate for conflicts
	var validation = _game_settings.validate_keybinding(_capturing_action, code, _capturing_is_controller)
	if not validation["valid"]:
		print("[SettingsMenu] Keybinding conflict with: %s" % validation["conflict_action"])
		_capture_button.text = "CONFLICT!"
		await get_tree().create_timer(1.0).timeout
		_update_keybind_button_text(_capture_button, _capturing_action, _capturing_is_controller)
		_cancel_capture()
		return
	
	# Apply the new binding
	_game_settings.update_keybinding(_capturing_action, code, _capturing_is_controller)
	_update_keybind_button_text(_capture_button, _capturing_action, _capturing_is_controller)
	
	_cancel_capture()


## _cancel_capture()
##
## Cancels keybinding capture mode.
func _cancel_capture() -> void:
	_capturing_action = ""
	_capturing_is_controller = false
	_capture_button = null


## _on_reset_keyboard_pressed()
##
## Handler for Reset Keyboard Defaults button.
func _on_reset_keyboard_pressed() -> void:
	if _game_settings:
		_game_settings.reset_keybindings(false)
		_update_all_keybind_buttons()
		print("[SettingsMenu] Keyboard bindings reset to defaults")


## _on_reset_controller_pressed()
##
## Handler for Reset Controller Defaults button.
func _on_reset_controller_pressed() -> void:
	if _game_settings:
		_game_settings.reset_keybindings(true)
		_update_all_keybind_buttons()
		print("[SettingsMenu] Controller bindings reset to defaults")


## _on_close_pressed()
##
## Handler for Close button.
func _on_close_pressed() -> void:
	print("[SettingsMenu] Closed")
	closed.emit()
	visible = false


## show_menu()
##
## Shows the settings menu.
func show_menu() -> void:
	_load_current_settings()
	visible = true


## hide_menu()
##
## Hides the settings menu.
func hide_menu() -> void:
	visible = false
	closed.emit()
