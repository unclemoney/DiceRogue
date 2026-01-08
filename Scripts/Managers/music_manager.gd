extends Node

## MusicManager
##
## Layered dynamic music system with synchronized looping layers that respond to gameplay.
## Features:
## - Base layer (BOTTOM_LAYER.wav) plays continuously on loop
## - Up to 6 additional layers (LAYER_1 through LAYER_6) with variants (A-Z)
## - Smart variant selection avoiding recent repetition
## - Intensity-based layer activation (0-6 layers active)
## - Loop-boundary transitions for seamless sync
## - Strict duration validation (all layers must match base exactly)
## - Graceful degradation if files missing
##
## File naming convention:
## - res://Resources/Audio/MUSIC/BOTTOM_LAYER.wav (required base)
## - res://Resources/Audio/MUSIC/LAYER_1_A.wav, LAYER_1_B.wav, etc.
## - res://Resources/Audio/MUSIC/LAYER_2_A.wav, LAYER_2_B.wav, etc.
## - Layers 1-6, variants A-Z (max 26 per layer)

const MUSIC_PATH := "res://Resources/Audio/MUSIC/"
const MAX_LAYERS := 6
const MAX_VARIANTS := 26  # A-Z
const MUTED_VOLUME_DB := -80.0

# Configuration exports
@export var music_volume_db: float = -6.0
@export var variant_memory_depth: int = 2
@export var debug_mode: bool = false

# Intensity presets for game phases
@export var intensity_shop: int = 1
@export var intensity_round_start: int = 3
@export var intensity_challenge_complete: int = 6
@export var intensity_round_complete: int = 2
@export var intensity_game_over: int = 0

# Audio resources
var base_layer_stream: AudioStream
var base_loop_duration: float = 0.0
var layer_variants: Dictionary = {}  # {layer_num: [AudioStream, ...]}
var valid_layer_numbers: Array[int] = []  # Layers with at least one valid variant

# Audio players
var base_player: AudioStreamPlayer
var layer_players: Array[AudioStreamPlayer] = []

# Playback state
var _is_enabled: bool = false
var _current_intensity: int = 0
var _pending_intensity: int = -1  # -1 means no pending change
var _pending_transition_duration: float = 3.0
var _active_layers: Dictionary = {}  # {layer_num: AudioStream}
var _variant_history: Dictionary = {}  # {layer_num: [variant_letter, ...]}
var _volume_tweens: Array[Tween] = []


func _ready() -> void:
	_log("Initializing...")
	_load_audio_resources()
	_create_audio_players()
	_connect_game_signals()
	
	if _is_enabled:
		_start_playback()
		_log("Ready - base loop duration: %.3fs, %d layer groups loaded" % [base_loop_duration, valid_layer_numbers.size()])
	else:
		_log("Disabled - no valid BOTTOM_LAYER.wav found")


## _load_audio_resources()
##
## Scan MUSIC folder for BOTTOM_LAYER.wav and all LAYER_N_X.wav variants.
## Validates durations match base exactly.
func _load_audio_resources() -> void:
	# Load base layer first
	var base_path = MUSIC_PATH + "BOTTOM_LAYER.wav"
	base_layer_stream = load(base_path)
	
	if not base_layer_stream:
		push_error("[MusicManager] BOTTOM_LAYER.wav not found at: %s - music system disabled" % base_path)
		_is_enabled = false
		return
	
	# Get base duration for validation
	base_loop_duration = base_layer_stream.get_length()
	_log("Loaded BOTTOM_LAYER.wav - duration: %.3fs" % base_loop_duration)
	_is_enabled = true
	
	# Scan for layer variants
	var dir = DirAccess.open(MUSIC_PATH)
	if not dir:
		push_warning("[MusicManager] Could not open music directory: %s" % MUSIC_PATH)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".wav"):
			_try_load_layer_variant(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Build list of valid layer numbers
	for layer_num in layer_variants.keys():
		if layer_variants[layer_num].size() > 0:
			valid_layer_numbers.append(layer_num)
	valid_layer_numbers.sort()
	
	# Log summary
	_log("Layer loading complete:")
	for layer_num in valid_layer_numbers:
		var variants = layer_variants[layer_num] as Array
		_log("  LAYER_%d: %d variants" % [layer_num, variants.size()])


## _try_load_layer_variant(file_name: String)
##
## Attempt to parse and load a layer variant file.
## Expected format: LAYER_N_X.wav where N=1-6, X=A-Z
func _try_load_layer_variant(file_name: String) -> void:
	# Skip non-layer files
	if not file_name.begins_with("LAYER_"):
		return
	
	# Parse LAYER_N_X.wav format
	var regex = RegEx.new()
	regex.compile("^LAYER_(\\d+)_([A-Z])\\.wav$")
	var result = regex.search(file_name)
	
	if not result:
		_log("Skipping unrecognized file: %s" % file_name)
		return
	
	var layer_num = result.get_string(1).to_int()
	var _variant_letter = result.get_string(2)  # Used for naming, stored with stream
	
	# Validate layer number
	if layer_num < 1 or layer_num > MAX_LAYERS:
		push_warning("[MusicManager] Invalid layer number %d in %s (must be 1-%d)" % [layer_num, file_name, MAX_LAYERS])
		return
	
	# Load the stream
	var stream_path = MUSIC_PATH + file_name
	var stream = load(stream_path) as AudioStream
	
	if not stream:
		push_warning("[MusicManager] Failed to load: %s" % stream_path)
		return
	
	# Validate duration matches base exactly
	var duration = stream.get_length()
	if not is_equal_approx(duration, base_loop_duration):
		push_error("[MusicManager] Duration mismatch: %s is %.3fs, expected %.3fs - SKIPPED" % [file_name, duration, base_loop_duration])
		return
	
	# Add to layer variants dictionary
	if not layer_variants.has(layer_num):
		layer_variants[layer_num] = []
	
	layer_variants[layer_num].append(stream)
	_log("Loaded %s (duration: %.3fs)" % [file_name, duration])


## _create_audio_players()
##
## Create pooled AudioStreamPlayer nodes for base and all layers.
func _create_audio_players() -> void:
	# Create base layer player
	base_player = AudioStreamPlayer.new()
	base_player.name = "BasePlayer"
	base_player.volume_db = music_volume_db
	base_player.finished.connect(_on_base_loop_finished)
	add_child(base_player)
	
	# Create 6 layer players (all start muted)
	for i in range(MAX_LAYERS):
		var player = AudioStreamPlayer.new()
		player.name = "LayerPlayer_%d" % (i + 1)
		player.volume_db = MUTED_VOLUME_DB
		add_child(player)
		layer_players.append(player)
	
	_log("Created %d audio players" % (1 + layer_players.size()))


## _connect_game_signals()
##
## Connect to game state signals for automatic intensity changes.
func _connect_game_signals() -> void:
	# Defer signal connections to ensure other autoloads are ready
	call_deferred("_deferred_connect_signals")


## _deferred_connect_signals()
##
## Actually connect signals after scene tree is ready.
func _deferred_connect_signals() -> void:
	var tree = get_tree()
	if not tree:
		return
	
	# Wait for scene to be ready
	await tree.process_frame
	
	var root = tree.root
	if not root:
		return
	
	# Try to find and connect to RoundManager
	var round_manager = root.find_child("RoundManager", true, false)
	if round_manager:
		if round_manager.has_signal("round_started"):
			round_manager.round_started.connect(_on_round_started)
			_log("Connected to RoundManager.round_started")
		if round_manager.has_signal("round_completed"):
			round_manager.round_completed.connect(_on_round_completed)
			_log("Connected to RoundManager.round_completed")
	
	# Try to find and connect to ShopUI
	var shop_ui = root.find_child("ShopUI", true, false)
	if shop_ui:
		if shop_ui.has_signal("shop_button_opened"):
			shop_ui.shop_button_opened.connect(_on_shop_opened)
			_log("Connected to ShopUI.shop_button_opened")
	
	# Try to find and connect to ChallengeManager
	var challenge_manager = root.find_child("ChallengeManager", true, false)
	if challenge_manager:
		if challenge_manager.has_signal("challenge_completed"):
			challenge_manager.challenge_completed.connect(_on_challenge_completed)
			_log("Connected to ChallengeManager.challenge_completed")
	
	# Try to find and connect to TurnTracker
	var turn_tracker = root.find_child("TurnTracker", true, false)
	if turn_tracker:
		if turn_tracker.has_signal("game_over"):
			turn_tracker.game_over.connect(_on_game_over)
			_log("Connected to TurnTracker.game_over")


## _start_playback()
##
## Begin music playback with base layer at intensity 0.
func _start_playback() -> void:
	if not _is_enabled or not base_layer_stream:
		return
	
	base_player.stream = base_layer_stream
	base_player.play()
	
	# Start all layer players in sync but muted
	for i in range(MAX_LAYERS):
		var layer_num = i + 1
		if layer_variants.has(layer_num) and layer_variants[layer_num].size() > 0:
			var variant = _get_random_variant(layer_num)
			layer_players[i].stream = variant
			layer_players[i].volume_db = MUTED_VOLUME_DB
			layer_players[i].play()
	
	_current_intensity = 0
	_log("Playback started at intensity 0")


## _on_base_loop_finished()
##
## Called when base layer finishes - sync all layers and apply pending intensity.
func _on_base_loop_finished() -> void:
	if not _is_enabled:
		return
	
	_log("Loop finished - syncing all layers")
	
	# Apply pending intensity change if queued
	if _pending_intensity >= 0:
		_apply_intensity_change()
	
	# Restart all players in sync
	_sync_all_layers()


## _sync_all_layers()
##
## Restart base and all layer players simultaneously at loop start.
func _sync_all_layers() -> void:
	# Restart base
	base_player.play()
	
	# Restart all layer players with potentially new variants
	for i in range(MAX_LAYERS):
		var layer_num = i + 1
		var player = layer_players[i]
		
		if layer_variants.has(layer_num) and layer_variants[layer_num].size() > 0:
			# If this layer is active, maybe pick new variant
			if _active_layers.has(layer_num):
				var new_variant = _get_random_variant(layer_num)
				player.stream = new_variant
				_active_layers[layer_num] = new_variant
			player.play()
	
	_log("All layers synced and restarted")


## _apply_intensity_change()
##
## Apply the pending intensity change - select random layers and fade volumes.
func _apply_intensity_change() -> void:
	var new_intensity = _pending_intensity
	var transition_duration = _pending_transition_duration
	_pending_intensity = -1  # Clear pending
	
	_log("Applying intensity change: %d -> %d (%.1fs transition)" % [_current_intensity, new_intensity, transition_duration])
	
	# Kill any active volume tweens
	for tween in _volume_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_volume_tweens.clear()
	
	# Determine which layers should be active
	var layers_to_activate = _select_random_layers(new_intensity)
	
	_log("Selected layers for intensity %d: %s" % [new_intensity, str(layers_to_activate)])
	
	# Update active layers and fade volumes
	var new_active_layers: Dictionary = {}
	
	for layer_num in layers_to_activate:
		var variant = _get_random_variant(layer_num)
		new_active_layers[layer_num] = variant
		
		var player_index = layer_num - 1
		var player = layer_players[player_index]
		
		# Set new stream if different
		if player.stream != variant:
			player.stream = variant
		
		# Fade in this layer
		_fade_player_volume(player, music_volume_db, transition_duration)
	
	# Fade out layers that are no longer active
	for layer_num in _active_layers.keys():
		if not new_active_layers.has(layer_num):
			var player_index = layer_num - 1
			var player = layer_players[player_index]
			_fade_player_volume(player, MUTED_VOLUME_DB, transition_duration)
	
	_active_layers = new_active_layers
	_current_intensity = new_intensity


## _select_random_layers(count: int) -> Array[int]
##
## Select count random layer numbers from available valid layers.
func _select_random_layers(count: int) -> Array[int]:
	if count <= 0:
		return []
	
	if valid_layer_numbers.size() == 0:
		return []
	
	# Clamp count to available layers
	var actual_count = mini(count, valid_layer_numbers.size())
	
	# Shuffle and pick first N
	var shuffled = valid_layer_numbers.duplicate()
	shuffled.shuffle()
	
	var result: Array[int] = []
	for i in range(actual_count):
		result.append(shuffled[i])
	
	result.sort()
	return result


## _get_random_variant(layer_num: int) -> AudioStream
##
## Get a random variant for the given layer, avoiding recently used variants.
func _get_random_variant(layer_num: int) -> AudioStream:
	if not layer_variants.has(layer_num):
		return null
	
	var variants = layer_variants[layer_num] as Array
	if variants.size() == 0:
		return null
	
	if variants.size() == 1:
		return variants[0]
	
	# Get history for this layer
	if not _variant_history.has(layer_num):
		_variant_history[layer_num] = []
	
	var history = _variant_history[layer_num] as Array
	
	# Build pool excluding recent variants
	var available_indices: Array[int] = []
	for i in range(variants.size()):
		if not history.has(i):
			available_indices.append(i)
	
	# If all variants are in history, reset and use full pool
	if available_indices.size() == 0:
		available_indices.clear()
		for i in range(variants.size()):
			available_indices.append(i)
		history.clear()
	
	# Pick random from available
	var chosen_index = available_indices[randi() % available_indices.size()]
	
	# Update history
	history.append(chosen_index)
	while history.size() > variant_memory_depth:
		history.pop_front()
	_variant_history[layer_num] = history
	
	_log("Layer %d: chose variant index %d (history: %s)" % [layer_num, chosen_index, str(history)])
	
	return variants[chosen_index]


## _fade_player_volume(player: AudioStreamPlayer, target_db: float, duration: float)
##
## Smoothly fade a player's volume to target over duration.
func _fade_player_volume(player: AudioStreamPlayer, target_db: float, duration: float) -> void:
	if duration <= 0:
		player.volume_db = target_db
		return
	
	var tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, duration).set_trans(Tween.TRANS_LINEAR)
	_volume_tweens.append(tween)


## set_intensity(level: int, transition_duration: float = 3.0)
##
## Queue an intensity change to be applied at the next loop boundary.
## Level 0 = base only, level 1-6 = that many random layers active.
## Multiple calls before loop boundary will overwrite - only latest is used.
func set_intensity(level: int, transition_duration: float = 3.0) -> void:
	level = clampi(level, 0, MAX_LAYERS)
	_pending_intensity = level
	_pending_transition_duration = transition_duration
	_log("Intensity change queued: %d (will apply at next loop boundary)" % level)


## set_custom_intensity(level: int, transition_duration: float = 3.0)
##
## Public method for manual intensity control from other scripts.
func set_custom_intensity(level: int, transition_duration: float = 3.0) -> void:
	set_intensity(level, transition_duration)


## set_music_volume(volume_db: float)
##
## Change the master music volume. Affects base and all active layers.
func set_music_volume(volume_db: float) -> void:
	music_volume_db = volume_db
	
	# Update base player immediately
	if base_player:
		base_player.volume_db = volume_db
	
	# Update active layer players
	for layer_num in _active_layers.keys():
		var player_index = layer_num - 1
		if player_index >= 0 and player_index < layer_players.size():
			layer_players[player_index].volume_db = volume_db
	
	_log("Music volume set to: %.1f dB" % volume_db)


## stop_music()
##
## Stop all music playback.
func stop_music() -> void:
	if base_player:
		base_player.stop()
	
	for player in layer_players:
		player.stop()
	
	_active_layers.clear()
	_current_intensity = 0
	_log("Music stopped")


## resume_music()
##
## Resume music playback from the beginning.
func resume_music() -> void:
	if _is_enabled:
		_start_playback()


# Signal handlers for automatic intensity changes

func _on_round_started(_round_number: int) -> void:
	set_intensity(intensity_round_start)


func _on_round_completed(_round_number: int) -> void:
	set_intensity(intensity_round_complete)


func _on_shop_opened() -> void:
	set_intensity(intensity_shop)


func _on_challenge_completed(_challenge_id: String) -> void:
	set_intensity(intensity_challenge_complete, 1.0)  # Faster transition for excitement


func _on_game_over() -> void:
	set_intensity(intensity_game_over, 2.0)


## _log(message: String)
##
## Print debug message if debug_mode is enabled.
func _log(message: String) -> void:
	if debug_mode:
		print("[MusicManager] %s" % message)
