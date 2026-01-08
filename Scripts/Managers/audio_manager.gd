extends Node

## AudioManager
##
## Centralized audio manager for dynamic sound effects including:
## - Dice roll sounds with per-die randomization and pitch progression
## - Scoring sounds with progressive pitch scaling during scoring sequence
## - Money sounds for end-of-round stats with amount-based pitch variation
## - Button click sounds for UI feedback
## - Firework sounds for celebrations (challenge completion, consumable use)
##
## All players share a master volume setting.

# Master volume for all audio
@export var master_volume_db: float = 0.0

# Dice roll audio configuration
const DICE_BASE_PITCH_MIN: float = 0.9
const DICE_BASE_PITCH_MAX: float = 1.1
const DICE_PITCH_PER_ROLL: float = 0.05  # Linear increase per roll number

# Scoring audio configuration (progressive pitch during scoring sequence)
const SCORING_BASE_PITCH: float = 0.8
const SCORING_MAX_PITCH: float = 1.5
const SCORING_PITCH_INCREMENT: float = 0.08  # Pitch increase per scoring step

# Money audio configuration
const MONEY_BASE_PITCH_MIN: float = 0.8
const MONEY_BASE_PITCH_MAX: float = 1.2
const MONEY_MAX_PITCH: float = 1.5
const MONEY_PITCH_SCALE: float = 0.005  # Per dollar earned

# Button click audio configuration
const BUTTON_PITCH_MIN: float = 0.95
const BUTTON_PITCH_MAX: float = 1.05

# Firework audio configuration
const FIREWORK_PITCH_MIN: float = 0.9
const FIREWORK_PITCH_MAX: float = 1.1

# Audio resources
var dice_sounds: Array[AudioStream] = []
var scoring_sound: AudioStream
var money_sound: AudioStream
var button_click_sound: AudioStream
var firework_sound: AudioStream

# Audio players - pooled for dice (one per die), single for others
var dice_players: Array[AudioStreamPlayer] = []
var scoring_player: AudioStreamPlayer
var money_player: AudioStreamPlayer
var button_player: AudioStreamPlayer
var firework_player: AudioStreamPlayer

# Roll tracking - reset after scoring
var current_roll_number: int = 0

# Scoring sequence tracking - reset at start of each scoring animation
var current_scoring_step: int = 0

# Track buttons we've already connected to avoid duplicate connections
var _connected_buttons: Dictionary = {}


func _ready() -> void:
	print("[AudioManager] Initializing...")
	_load_audio_resources()
	_create_audio_players()
	
	# Start monitoring scene tree for buttons
	get_tree().node_added.connect(_on_node_added)
	
	# Connect to any existing buttons in the tree (deferred to allow scene to load)
	call_deferred("_connect_existing_buttons")
	
	print("[AudioManager] Ready with %d dice sounds loaded" % dice_sounds.size())


## _on_node_added(node: Node)
##
## Called when any node is added to the scene tree.
## If it's a Button, connect click sound to it.
func _on_node_added(node: Node) -> void:
	if node is Button:
		_connect_button_sound(node as Button)


## _connect_existing_buttons()
##
## Scan the entire scene tree for existing buttons and connect click sounds.
func _connect_existing_buttons() -> void:
	var root = get_tree().root
	if root:
		_scan_for_buttons(root)


## _scan_for_buttons(node: Node)
##
## Recursively scan node tree for buttons.
func _scan_for_buttons(node: Node) -> void:
	if node is Button:
		_connect_button_sound(node as Button)
	for child in node.get_children():
		_scan_for_buttons(child)


## _connect_button_sound(button: Button)
##
## Connect button click sound to a button's pressed signal.
## Uses instance ID tracking to avoid duplicate connections.
func _connect_button_sound(button: Button) -> void:
	var button_id = button.get_instance_id()
	if _connected_buttons.has(button_id):
		return
	
	# Mark as connected
	_connected_buttons[button_id] = true
	
	# Connect pressed signal - use CONNECT_DEFERRED for cleaner audio timing
	button.pressed.connect(play_button_click)
	
	# Clean up tracking when button is freed
	button.tree_exiting.connect(func(): _connected_buttons.erase(button_id))
	
	print("[AudioManager] Connected click sound to button: %s" % button.name)


## _load_audio_resources()
##
## Preload all audio resources from the Resources/Audio folders.
func _load_audio_resources() -> void:
	# Load dice roll sounds (5 variations)
	for i in range(1, 6):
		var path = "res://Resources/Audio/DICE/DICE_ROLL_%d.wav" % i
		var sound = load(path)
		if sound:
			dice_sounds.append(sound)
			print("[AudioManager] Loaded: %s" % path)
		else:
			push_warning("[AudioManager] Failed to load: %s" % path)
	
	# Load scoring sound
	scoring_sound = load("res://Resources/Audio/SCORING/SCORE_1.wav")
	if scoring_sound:
		print("[AudioManager] Loaded scoring sound")
	else:
		push_warning("[AudioManager] Failed to load scoring sound")
	
	# Load money sound
	money_sound = load("res://Resources/Audio/MONEY/CASH_1.wav")
	if money_sound:
		print("[AudioManager] Loaded money sound")
	else:
		push_warning("[AudioManager] Failed to load money sound")
	
	# Load button click sound
	button_click_sound = load("res://Resources/Audio/UI/BUTTON_CLICK_1.wav")
	if button_click_sound:
		print("[AudioManager] Loaded button click sound")
	else:
		push_warning("[AudioManager] Failed to load button click sound")
	
	# Load firework sound
	firework_sound = load("res://Resources/Audio/SCORING/FIREWORK_1.wav")
	if firework_sound:
		print("[AudioManager] Loaded firework sound")
	else:
		push_warning("[AudioManager] Failed to load firework sound")


## _create_audio_players()
##
## Create pooled AudioStreamPlayer nodes for each sound type.
func _create_audio_players() -> void:
	# Create pool of 8 dice players (max dice per hand)
	for i in range(8):
		var player = AudioStreamPlayer.new()
		player.name = "DicePlayer_%d" % i
		player.volume_db = master_volume_db
		add_child(player)
		dice_players.append(player)
	
	# Create scoring player
	scoring_player = AudioStreamPlayer.new()
	scoring_player.name = "ScoringPlayer"
	scoring_player.volume_db = master_volume_db
	add_child(scoring_player)
	
	# Create money player
	money_player = AudioStreamPlayer.new()
	money_player.name = "MoneyPlayer"
	money_player.volume_db = master_volume_db
	add_child(money_player)
	
	# Create button click player
	button_player = AudioStreamPlayer.new()
	button_player.name = "ButtonPlayer"
	button_player.volume_db = master_volume_db
	add_child(button_player)
	
	# Create firework player
	firework_player = AudioStreamPlayer.new()
	firework_player.name = "FireworkPlayer"
	firework_player.volume_db = master_volume_db
	add_child(firework_player)


## play_dice_roll(die_index: int, roll_number: int)
##
## Play a random dice roll sound for a specific die.
## - die_index: Index of the die (0-7) for player pooling
## - roll_number: Current roll number (1-3) for pitch progression
## Pitch = random(0.9-1.1) + (roll_number - 1) * 0.05
func play_dice_roll(die_index: int, roll_number: int) -> void:
	if dice_sounds.is_empty():
		return
	
	# Clamp die index to available players
	var player_index = clampi(die_index, 0, dice_players.size() - 1)
	var player = dice_players[player_index]
	
	# Select random sound
	var sound_index = randi() % dice_sounds.size()
	player.stream = dice_sounds[sound_index]
	
	# Calculate pitch: random base + linear progression per roll
	var base_pitch = randf_range(DICE_BASE_PITCH_MIN, DICE_BASE_PITCH_MAX)
	var roll_bonus = (roll_number - 1) * DICE_PITCH_PER_ROLL
	player.pitch_scale = base_pitch + roll_bonus
	
	# Apply master volume
	player.volume_db = master_volume_db
	
	player.play()
	#print("[AudioManager] Dice roll - die:%d roll:%d pitch:%.2f" % [die_index, roll_number, player.pitch_scale])


## play_scoring_sound(_score: int)
##
## Play scoring sound with progressive pitch that increases each step.
## Call reset_scoring_sequence() at the start of each scoring animation.
## Pitch scales from 0.8 to 1.5 based on step count.
## Note: _score parameter kept for API compatibility but pitch is now step-based.
func play_scoring_sound(_score: int) -> void:
	if not scoring_sound:
		return
	
	scoring_player.stream = scoring_sound
	
	# Calculate pitch based on current step (progressive pitch)
	var pitch = SCORING_BASE_PITCH + (current_scoring_step * SCORING_PITCH_INCREMENT)
	pitch = minf(pitch, SCORING_MAX_PITCH)
	scoring_player.pitch_scale = pitch
	
	# Increment step for next call
	current_scoring_step += 1
	
	# Apply master volume
	scoring_player.volume_db = master_volume_db
	
	scoring_player.play()
	#print("[AudioManager] Scoring sound - step:%d pitch:%.2f" % [current_scoring_step, pitch])


## reset_scoring_sequence()
##
## Reset the scoring step counter at the start of each scoring animation.
## Call this before the first play_scoring_sound() in a sequence.
func reset_scoring_sequence() -> void:
	current_scoring_step = 0
	#print("[AudioManager] Scoring sequence reset")


## play_money_sound(amount: int)
##
## Play money/cash sound with pitch based on amount earned.
## Pitch = random(0.8-1.2) + amount * 0.005 (capped at 1.5)
func play_money_sound(amount: int) -> void:
	if not money_sound:
		return
	
	money_player.stream = money_sound
	
	# Calculate pitch: random base + amount scaling
	var base_pitch = randf_range(MONEY_BASE_PITCH_MIN, MONEY_BASE_PITCH_MAX)
	var amount_bonus = amount * MONEY_PITCH_SCALE
	var final_pitch = base_pitch + amount_bonus
	final_pitch = minf(final_pitch, MONEY_MAX_PITCH)
	money_player.pitch_scale = final_pitch
	
	# Apply master volume
	money_player.volume_db = master_volume_db
	
	money_player.play()
	print("[AudioManager] Money sound - amount:$%d pitch:%.2f" % [amount, final_pitch])


## reset_roll_count()
##
## Reset the roll number tracker after scoring. Called when a category is scored.
func reset_roll_count() -> void:
	current_roll_number = 0
	print("[AudioManager] Roll count reset")


## increment_roll_count()
##
## Increment the roll counter when starting a new roll.
func increment_roll_count() -> void:
	current_roll_number += 1
	print("[AudioManager] Roll count: %d" % current_roll_number)


## get_current_roll_number() -> int
##
## Returns the current roll number (1-3 typically).
func get_current_roll_number() -> int:
	return current_roll_number


## set_master_volume(volume_db: float)
##
## Set master volume for all audio players.
func set_master_volume(volume_db: float) -> void:
	master_volume_db = volume_db
	
	for player in dice_players:
		player.volume_db = volume_db
	
	if scoring_player:
		scoring_player.volume_db = volume_db
	
	if money_player:
		money_player.volume_db = volume_db
	
	if button_player:
		button_player.volume_db = volume_db
	
	if firework_player:
		firework_player.volume_db = volume_db
	
	print("[AudioManager] Master volume set to: %.1f dB" % volume_db)


## play_button_click()
##
## Play button click sound with slight random pitch variation.
## Pitch ranges from 0.95 to 1.05 for natural feel.
func play_button_click() -> void:
	if not button_click_sound:
		return
	
	button_player.stream = button_click_sound
	
	# Slight random pitch variation
	button_player.pitch_scale = randf_range(BUTTON_PITCH_MIN, BUTTON_PITCH_MAX)
	
	# Apply master volume
	button_player.volume_db = master_volume_db
	
	button_player.play()


## play_firework_sound()
##
## Play firework/explosion sound for celebrations.
## Pitch ranges from 0.9 to 1.1 for natural variation.
func play_firework_sound() -> void:
	if not firework_sound:
		return
	
	firework_player.stream = firework_sound
	
	# Slight random pitch variation
	firework_player.pitch_scale = randf_range(FIREWORK_PITCH_MIN, FIREWORK_PITCH_MAX)
	
	# Apply master volume
	firework_player.volume_db = master_volume_db
	
	firework_player.play()
	print("[AudioManager] Firework sound played")
