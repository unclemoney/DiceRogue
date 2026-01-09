# Scripts/Managers/game_settings.gd
extends Node

## GameSettings Autoload
##
## Centralized settings manager for game configuration including:
## - Active profile slot tracking
## - Audio volumes (SFX and Music)
## - Video settings (resolution, fullscreen)
## - Gameplay settings (animation speed)
## - Keyboard and controller bindings
##
## Persists all settings to user://settings.cfg using ConfigFile.

signal settings_loaded
signal settings_saved
signal profile_changed(slot: int)
signal video_settings_changed
signal keybinding_changed(action: String, is_controller: bool)

const SETTINGS_FILE_PATH := "user://settings.cfg"
const PROFILE_NAME_MAX_LENGTH := 30

# Profile settings
var active_profile_slot: int = 1

# Audio settings (0.0 to 1.0 range)
var sfx_volume: float = 0.8
var music_volume: float = 0.6

# Gameplay settings
var scoring_animation_speed: float = 1.0  # Range: 0.5 to 2.0

# Video settings
var screen_resolution: Vector2i = Vector2i(1280, 720)
var fullscreen: bool = false

# Keyboard bindings (action name -> InputEventKey keycode)
var keybindings: Dictionary = {}

# Controller bindings (action name -> JoyButton/JoyAxis)
var controller_bindings: Dictionary = {}

# Default keyboard bindings - supports up to 16 dice locks
const DEFAULT_KEYBINDINGS := {
	"roll": KEY_SPACE,
	"next_turn": KEY_ENTER,
	"shop": KEY_S,
	"next_round": KEY_N,
	"menu": KEY_ESCAPE,
	# Dice locks 1-10 use number keys (1-9, then 0 for 10th)
	"lock_dice_1": KEY_1,
	"lock_dice_2": KEY_2,
	"lock_dice_3": KEY_3,
	"lock_dice_4": KEY_4,
	"lock_dice_5": KEY_5,
	"lock_dice_6": KEY_6,
	"lock_dice_7": KEY_7,
	"lock_dice_8": KEY_8,
	"lock_dice_9": KEY_9,
	"lock_dice_10": KEY_0,
	# Dice locks 11-16 use Q-Y row
	"lock_dice_11": KEY_Q,
	"lock_dice_12": KEY_W,
	"lock_dice_13": KEY_E,
	"lock_dice_14": KEY_R,
	"lock_dice_15": KEY_T,
	"lock_dice_16": KEY_Y,
}

# Default controller bindings (JoyButton enum values)
# Controller can only lock first 5 dice due to limited buttons
const DEFAULT_CONTROLLER_BINDINGS := {
	"roll": JOY_BUTTON_A,           # A / Cross
	"next_turn": JOY_BUTTON_B,      # B / Circle
	"shop": JOY_BUTTON_Y,           # Y / Triangle
	"next_round": JOY_BUTTON_X,     # X / Square
	"menu": JOY_BUTTON_START,       # Start
	"lock_dice_1": JOY_BUTTON_LEFT_SHOULDER,   # L1
	"lock_dice_2": JOY_BUTTON_RIGHT_SHOULDER,  # R1
	"lock_dice_3": JOY_BUTTON_LEFT_STICK,      # L3
	"lock_dice_4": JOY_BUTTON_RIGHT_STICK,     # R3
	"lock_dice_5": JOY_BUTTON_BACK,            # Select/Back
}

# Resolution presets
const RESOLUTION_PRESETS := {
	"1280x720": Vector2i(1280, 720),
	"1920x1080": Vector2i(1920, 1080),
	"2560x1440": Vector2i(2560, 1440),
	"3840x2160": Vector2i(3840, 2160),
}

func _ready() -> void:
	print("[GameSettings] Initializing...")
	_set_default_bindings()
	load_settings()
	print("[GameSettings] Ready - Active profile slot: %d" % active_profile_slot)


## _set_default_bindings()
##
## Initialize keybindings and controller_bindings with defaults.
func _set_default_bindings() -> void:
	keybindings = DEFAULT_KEYBINDINGS.duplicate()
	controller_bindings = DEFAULT_CONTROLLER_BINDINGS.duplicate()


## load_settings()
##
## Load all settings from the config file. Uses defaults if file doesn't exist.
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	
	if err != OK:
		print("[GameSettings] No settings file found, using defaults")
		save_settings()  # Create default settings file
		settings_loaded.emit()
		return
	
	# Load profile settings
	active_profile_slot = config.get_value("profile", "active_slot", 1)
	
	# Load audio settings
	sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
	music_volume = config.get_value("audio", "music_volume", 0.6)
	
	# Load gameplay settings
	scoring_animation_speed = config.get_value("gameplay", "animation_speed", 1.0)
	scoring_animation_speed = clampf(scoring_animation_speed, 0.5, 2.0)
	
	# Load video settings
	var res_x = config.get_value("video", "resolution_x", 1280)
	var res_y = config.get_value("video", "resolution_y", 720)
	screen_resolution = Vector2i(res_x, res_y)
	fullscreen = config.get_value("video", "fullscreen", false)
	
	# Load keyboard bindings
	for action in DEFAULT_KEYBINDINGS.keys():
		var key = config.get_value("keyboard", action, DEFAULT_KEYBINDINGS[action])
		keybindings[action] = key
	
	# Load controller bindings
	for action in DEFAULT_CONTROLLER_BINDINGS.keys():
		var button = config.get_value("controller", action, DEFAULT_CONTROLLER_BINDINGS[action])
		controller_bindings[action] = button
	
	# Apply loaded settings
	_apply_audio_settings()
	_apply_input_mappings()
	
	print("[GameSettings] Settings loaded successfully")
	settings_loaded.emit()


## save_settings()
##
## Save all current settings to the config file.
func save_settings() -> void:
	var config = ConfigFile.new()
	
	# Save profile settings
	config.set_value("profile", "active_slot", active_profile_slot)
	
	# Save audio settings
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	
	# Save gameplay settings
	config.set_value("gameplay", "animation_speed", scoring_animation_speed)
	
	# Save video settings
	config.set_value("video", "resolution_x", screen_resolution.x)
	config.set_value("video", "resolution_y", screen_resolution.y)
	config.set_value("video", "fullscreen", fullscreen)
	
	# Save keyboard bindings
	for action in keybindings.keys():
		config.set_value("keyboard", action, keybindings[action])
	
	# Save controller bindings
	for action in controller_bindings.keys():
		config.set_value("controller", action, controller_bindings[action])
	
	var err = config.save(SETTINGS_FILE_PATH)
	if err != OK:
		push_error("[GameSettings] Failed to save settings file: %d" % err)
		return
	
	print("[GameSettings] Settings saved successfully")
	settings_saved.emit()


## _apply_audio_settings()
##
## Apply current audio volume settings to AudioManager and MusicManager.
func _apply_audio_settings() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("set_master_volume"):
		# Convert 0-1 range to decibels (-40 to 0)
		var sfx_db = linear_to_db(sfx_volume) if sfx_volume > 0 else -80.0
		audio_mgr.set_master_volume(sfx_db)
	
	var music_mgr = get_node_or_null("/root/MusicManager")
	if music_mgr and music_mgr.has_method("set_music_volume"):
		var music_db = linear_to_db(music_volume) if music_volume > 0 else -80.0
		music_mgr.set_music_volume(music_db)


## apply_audio_settings()
##
## Public method to apply audio settings (for use by settings menu).
func apply_audio_settings() -> void:
	_apply_audio_settings()


## _apply_input_mappings()
##
## Update the InputMap with current keybindings and controller bindings.
func _apply_input_mappings() -> void:
	# Apply keyboard bindings
	for action in keybindings.keys():
		_update_action_keyboard(action, keybindings[action])
	
	# Apply controller bindings
	for action in controller_bindings.keys():
		_update_action_controller(action, controller_bindings[action])


## _update_action_keyboard(action, keycode)
##
## Update or create an InputMap action with the given keyboard key.
func _update_action_keyboard(action: String, keycode: int) -> void:
	# Ensure action exists
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	
	# Remove existing keyboard events for this action
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	
	# Add new keyboard event
	var key_event = InputEventKey.new()
	key_event.keycode = keycode
	InputMap.action_add_event(action, key_event)


## _update_action_controller(action, button)
##
## Update or create an InputMap action with the given controller button.
func _update_action_controller(action: String, button: int) -> void:
	# Ensure action exists
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	
	# Remove existing controller events for this action
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
	
	# Add new controller event
	var joy_event = InputEventJoypadButton.new()
	joy_event.button_index = button
	InputMap.action_add_event(action, joy_event)


## set_sfx_volume(volume)
##
## Set SFX volume and immediately apply to AudioManager.
## @param volume: Volume level (0.0 to 1.0)
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	_apply_audio_settings()
	save_settings()


## set_music_volume(volume)
##
## Set music volume and immediately apply to MusicManager.
## @param volume: Volume level (0.0 to 1.0)
func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	_apply_audio_settings()
	save_settings()


## set_animation_speed(speed)
##
## Set scoring animation speed multiplier.
## @param speed: Speed multiplier (0.5 to 2.0)
func set_animation_speed(speed: float) -> void:
	scoring_animation_speed = clampf(speed, 0.5, 2.0)
	save_settings()


## get_animation_duration(base_duration)
##
## Calculate adjusted animation duration based on speed setting.
## @param base_duration: The default duration in seconds
## @return: Adjusted duration (faster = shorter duration)
func get_animation_duration(base_duration: float) -> float:
	return base_duration / scoring_animation_speed


## set_active_profile(slot)
##
## Change the active profile slot.
## @param slot: Profile slot number (1-3)
func set_active_profile(slot: int) -> void:
	if slot < 1 or slot > 3:
		push_error("[GameSettings] Invalid profile slot: %d" % slot)
		return
	
	active_profile_slot = slot
	save_settings()
	profile_changed.emit(slot)


## validate_resolution(resolution)
##
## Check if a resolution is valid for the current monitor.
## @param resolution: The resolution to validate
## @return: Dictionary with "valid" bool and "warning" string if applicable
func validate_resolution(resolution: Vector2i) -> Dictionary:
	var screen_size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var result = {"valid": true, "warning": ""}
	
	if resolution.x > screen_size.x or resolution.y > screen_size.y:
		result["warning"] = "Resolution %dx%d exceeds screen size %dx%d" % [
			resolution.x, resolution.y, screen_size.x, screen_size.y
		]
	
	return result


## apply_video_settings()
##
## Apply current video settings (resolution and fullscreen mode).
func apply_video_settings() -> void:
	var window = get_window()
	if not window:
		push_error("[GameSettings] Could not get window reference")
		return
	
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		window.size = screen_resolution
		# Center window on screen
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - screen_resolution) / 2
		window.position = window_pos
	
	save_settings()
	video_settings_changed.emit()
	print("[GameSettings] Video settings applied - %dx%d, Fullscreen: %s" % [
		screen_resolution.x, screen_resolution.y, fullscreen
	])


## validate_keybinding(action, keycode, is_controller)
##
## Check if a keybinding would conflict with an existing binding.
## @param action: The action being rebound
## @param keycode: The key or button code to check
## @param is_controller: True for controller binding, false for keyboard
## @return: Dictionary with "valid" bool and "conflict_action" string if invalid
func validate_keybinding(action: String, keycode: int, is_controller: bool) -> Dictionary:
	var bindings = controller_bindings if is_controller else keybindings
	var result = {"valid": true, "conflict_action": ""}
	
	for existing_action in bindings.keys():
		if existing_action != action and bindings[existing_action] == keycode:
			result["valid"] = false
			result["conflict_action"] = existing_action
			break
	
	return result


## update_keybinding(action, keycode, is_controller)
##
## Update a keybinding after validation.
## @param action: The action to rebind
## @param keycode: The new key or button code
## @param is_controller: True for controller binding, false for keyboard
## @return: True if successful, false if action doesn't exist
func update_keybinding(action: String, keycode: int, is_controller: bool) -> bool:
	if is_controller:
		if not action in controller_bindings:
			push_error("[GameSettings] Unknown controller action: %s" % action)
			return false
		controller_bindings[action] = keycode
		_update_action_controller(action, keycode)
	else:
		if not action in keybindings:
			push_error("[GameSettings] Unknown keyboard action: %s" % action)
			return false
		keybindings[action] = keycode
		_update_action_keyboard(action, keycode)
	
	save_settings()
	keybinding_changed.emit(action, is_controller)
	return true


## reset_keybindings(is_controller)
##
## Reset all bindings to defaults for keyboard or controller.
## @param is_controller: True to reset controller bindings, false for keyboard
func reset_keybindings(is_controller: bool) -> void:
	if is_controller:
		controller_bindings = DEFAULT_CONTROLLER_BINDINGS.duplicate()
		for action in controller_bindings.keys():
			_update_action_controller(action, controller_bindings[action])
	else:
		keybindings = DEFAULT_KEYBINDINGS.duplicate()
		for action in keybindings.keys():
			_update_action_keyboard(action, keybindings[action])
	
	save_settings()
	print("[GameSettings] %s bindings reset to defaults" % ("Controller" if is_controller else "Keyboard"))


## get_key_name(keycode)
##
## Get a human-readable name for a keyboard key.
## @param keycode: The key code
## @return: String name of the key
func get_key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)


## get_button_name(button)
##
## Get a human-readable name for a controller button.
## @param button: The JoyButton enum value
## @return: String name of the button
func get_button_name(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "A / Cross"
		JOY_BUTTON_B: return "B / Circle"
		JOY_BUTTON_X: return "X / Square"
		JOY_BUTTON_Y: return "Y / Triangle"
		JOY_BUTTON_LEFT_SHOULDER: return "LB / L1"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB / R1"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_BACK: return "Select / Back"
		JOY_BUTTON_DPAD_UP: return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Pad Right"
		_: return "Button %d" % button


## is_controller_connected()
##
## Check if any controller is currently connected.
## @return: True if at least one controller is connected
func is_controller_connected() -> bool:
	return Input.get_connected_joypads().size() > 0


## get_native_resolution()
##
## Get the native resolution of the current screen.
## @return: Vector2i of the screen resolution
func get_native_resolution() -> Vector2i:
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
