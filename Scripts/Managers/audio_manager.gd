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

# Dice lock/click audio configuration
const DICE_LOCK_PITCH_MIN: float = 0.95
const DICE_LOCK_PITCH_MAX: float = 1.05

# Panel swoosh audio configuration
const SWOOSH_PITCH: float = 0.55

# Fan out/in audio configuration
const FAN_OUT_PITCH_MIN: float = 1.15
const FAN_OUT_PITCH_MAX: float = 1.35
const FAN_IN_PITCH_MIN: float = 0.75
const FAN_IN_PITCH_MAX: float = 0.90

# Tab switch audio configuration
const TAB_SWITCH_PITCH_MIN: float = 1.10
const TAB_SWITCH_PITCH_MAX: float = 1.25

# Money tick audio configuration
const MONEY_TICK_PITCH_MIN: float = 1.0
const MONEY_TICK_PITCH_MAX: float = 1.3
const MONEY_TICK_MAX_AMOUNT: int = 25
const MONEY_DEBOUNCE_MS: int = 250

# Denied audio configuration
const DENIED_PITCH: float = 0.6

# Confirm audio configuration
const CONFIRM_PITCH: float = 0.7

# Dice land audio configuration
const DICE_LAND_PITCH_MIN: float = 0.85
const DICE_LAND_PITCH_MAX: float = 0.95

# Sell audio configuration
const SELL_PITCH: float = 1.3

# Round start audio configuration
const ROUND_START_PITCH: float = 1.0

# Audio resources
var dice_sounds: Array[AudioStream] = []
var scoring_sound: AudioStream
var money_sound: AudioStream
var button_click_sound: AudioStream
var firework_sound: AudioStream
var dice_click_sound: AudioStream
var swoosh_sound: AudioStream
var fan_out_sound: AudioStream
var fan_in_sound: AudioStream
var tab_switch_sound: AudioStream
var money_tick_sound: AudioStream
var denied_sound: AudioStream
var confirm_sound: AudioStream
var dice_land_sound: AudioStream
var sell_sound: AudioStream
var round_start_sound: AudioStream
var static_burst_sound: AudioStream
var challenge_reveal_sound: AudioStream

## NEW SOUNDS — drop files in Resources/Audio/UI/ as marked below
var dice_spawn_sound: AudioStream           ## NEW: DICE_SPAWN_1.wav
var jackpot_sound: AudioStream              ## NEW: JACKPOT_1.wav
var streak_sound: AudioStream               ## NEW: STREAK_1.wav
var next_turn_sound: AudioStream            ## NEW: NEXT_TURN_1.wav
var shop_open_sound: AudioStream            ## NEW: SHOP_OPEN_1.wav
var powerup_apply_sound: AudioStream        ## NEW: POWERUP_APPLY_1.wav
var threat_alarm_sound: AudioStream         ## NEW: THREAT_ALARM_1.wav
var victory_sound: AudioStream              ## NEW: VICTORY_1.wav

# Audio players - pooled for dice (one per die), single for others
var dice_players: Array[AudioStreamPlayer] = []
var scoring_player: AudioStreamPlayer
var money_player: AudioStreamPlayer
var button_player: AudioStreamPlayer
var firework_player: AudioStreamPlayer
var dice_click_player: AudioStreamPlayer
var swoosh_player: AudioStreamPlayer
var fan_out_player: AudioStreamPlayer
var fan_in_player: AudioStreamPlayer
var tab_switch_player: AudioStreamPlayer
var money_tick_player: AudioStreamPlayer
var denied_player: AudioStreamPlayer
var confirm_player: AudioStreamPlayer
var dice_land_player: AudioStreamPlayer
var sell_player: AudioStreamPlayer
var round_start_player: AudioStreamPlayer
var static_burst_player: AudioStreamPlayer
var challenge_reveal_player: AudioStreamPlayer

## NEW PLAYERS — paired with new sounds above
var dice_spawn_player: AudioStreamPlayer
var jackpot_player: AudioStreamPlayer
var streak_player: AudioStreamPlayer
var next_turn_player: AudioStreamPlayer
var shop_open_player: AudioStreamPlayer
var powerup_apply_player: AudioStreamPlayer
var threat_alarm_player: AudioStreamPlayer
var victory_player: AudioStreamPlayer

# Roll tracking - reset after scoring
var current_roll_number: int = 0

# Scoring sequence tracking - reset at start of each scoring animation
var current_scoring_step: int = 0

# Track buttons we've already connected to avoid duplicate connections
var _connected_buttons: Dictionary = {}

# Debounce for explicit money sounds vs auto-tick
var _last_explicit_money_time: int = 0


func _ready() -> void:
	print("[AudioManager] Initializing...")
	_load_audio_resources()
	_create_audio_players()
	
	# Start monitoring scene tree for buttons
	get_tree().node_added.connect(_on_node_added)
	
	# Connect to any existing buttons in the tree (deferred to allow scene to load)
	call_deferred("_connect_existing_buttons")
	
	# Connect to PlayerEconomy for mid-round money ticks
	var player_economy = get_node_or_null("/root/PlayerEconomy")
	if player_economy:
		player_economy.money_changed.connect(_on_money_changed)
	
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
	button_click_sound = load("res://Resources/Audio/UI/BUTTON_CLICK_2.wav")
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
	
	# Load dice click/lock sound
	dice_click_sound = load("res://Resources/Audio/UI/DICE_CLICK.wav")
	if dice_click_sound:
		print("[AudioManager] Loaded dice click sound")
	else:
		push_warning("[AudioManager] Failed to load dice click sound")
	
	# Load swoosh sound (repurposed dice roll)
	swoosh_sound = load("res://Resources/Audio/UI/SWOOSH_1.wav")
	if swoosh_sound:
		print("[AudioManager] Loaded swoosh sound")
	else:
		push_warning("[AudioManager] Failed to load swoosh sound")
	
	# Load fan out sound (repurposed dice click)
	fan_out_sound = load("res://Resources/Audio/UI/FANOUT_1.wav")
	if fan_out_sound:
		print("[AudioManager] Loaded fan out sound")
	else:
		push_warning("[AudioManager] Failed to load fan out sound")
	
	# Load fan in sound (repurposed button click)
	fan_in_sound = load("res://Resources/Audio/UI/FANOUT_1.wav")
	if fan_in_sound:
		print("[AudioManager] Loaded fan in sound")
	else:
		push_warning("[AudioManager] Failed to load fan in sound")
	
	# Load tab switch sound (repurposed dice click)
	tab_switch_sound = load("res://Resources/Audio/UI/TAB_SWITCH_1.wav")
	if tab_switch_sound:
		print("[AudioManager] Loaded tab switch sound")
	else:
		push_warning("[AudioManager] Failed to load tab switch sound")
	
	# Load money tick sound (repurposed cash)
	money_tick_sound = load("res://Resources/Audio/UI/COIN_1.wav")
	if money_tick_sound:
		print("[AudioManager] Loaded money tick sound")
	else:
		push_warning("[AudioManager] Failed to load money tick sound")
	
	# Load denied sound (repurposed bongo)
	denied_sound = load("res://Resources/Audio/UI/DENIED_1.wav")
	if denied_sound:
		print("[AudioManager] Loaded denied sound")
	else:
		push_warning("[AudioManager] Failed to load denied sound")
	
	# Load confirm sound (repurposed score)
	confirm_sound = load("res://Resources/Audio/UI/CONFIRM_1.wav")
	if confirm_sound:
		print("[AudioManager] Loaded confirm sound")
	else:
		push_warning("[AudioManager] Failed to load confirm sound")
	
	# Load dice land sound (repurposed dice click)
	dice_land_sound = load("res://Resources/Audio/UI/DENIED_1.wav")
	if dice_land_sound:
		print("[AudioManager] Loaded dice land sound")
	else:
		push_warning("[AudioManager] Failed to load dice land sound")
	
	# Load sell sound (repurposed cash)
	sell_sound = load("res://Resources/Audio/UI/SELL_ITEM_1.wav")
	if sell_sound:
		print("[AudioManager] Loaded sell sound")
	else:
		push_warning("[AudioManager] Failed to load sell sound")
	
	# Load round start sound (repurposed ding)
	round_start_sound = load("res://Resources/Audio/UI/ROUND_START_1.wav")
	if round_start_sound:
		print("[AudioManager] Loaded round start sound")
	else:
		push_warning("[AudioManager] Failed to load round start sound")
	
	# Load static burst sound for CRT channel change
	static_burst_sound = load("res://Resources/Audio/UI/STATIC_BURST.wav")
	if static_burst_sound:
		print("[AudioManager] Loaded static burst sound")
	else:
		push_warning("[AudioManager] Failed to load static burst sound")

	challenge_reveal_sound = load("res://Resources/Audio/UI/CHALLENGE_REVEAL.wav")
	if challenge_reveal_sound:
		print("[AudioManager] Loaded challenge reveal sound")
	else:
		push_warning("[AudioManager] Failed to load challenge reveal sound")
	
	# ── NEW SOUNDS — drop files in Resources/Audio/UI/ as marked ──
	# Dice spawn (was reusing panel swoosh)
	dice_spawn_sound = load("res://Resources/Audio/UI/DICE_SPAWN_1.wav")
	if dice_spawn_sound:
		print("[AudioManager] Loaded dice spawn sound")
	else:
		push_warning("[AudioManager] Failed to load dice spawn sound (DICE_SPAWN_1.wav)")
	
	# Jackpot / Yahtzee celebration
	jackpot_sound = load("res://Resources/Audio/UI/JACKPOT_1.wav")
	if jackpot_sound:
		print("[AudioManager] Loaded jackpot sound")
	else:
		push_warning("[AudioManager] Failed to load jackpot sound (JACKPOT_1.wav)")
	
	# Score streak popup
	streak_sound = load("res://Resources/Audio/UI/STREAK_1.wav")
	if streak_sound:
		print("[AudioManager] Loaded streak sound")
	else:
		push_warning("[AudioManager] Failed to load streak sound (STREAK_1.wav)")
	
	# Next turn
	next_turn_sound = load("res://Resources/Audio/UI/NEXT_TURN_1.wav")
	if next_turn_sound:
		print("[AudioManager] Loaded next turn sound")
	else:
		push_warning("[AudioManager] Failed to load next turn sound (NEXT_TURN_1.wav)")
	
	# Shop open / toggle
	shop_open_sound = load("res://Resources/Audio/UI/SHOP_OPEN_1.wav")
	if shop_open_sound:
		print("[AudioManager] Loaded shop open sound")
	else:
		push_warning("[AudioManager] Failed to load shop open sound (SHOP_OPEN_1.wav)")
	
	# PowerUp / Mod apply
	powerup_apply_sound = load("res://Resources/Audio/UI/POWERUP_APPLY_1.wav")
	if powerup_apply_sound:
		print("[AudioManager] Loaded powerup apply sound")
	else:
		push_warning("[AudioManager] Failed to load powerup apply sound (POWERUP_APPLY_1.wav)")
	
	# Threat alarm (challenge almost-there)
	threat_alarm_sound = load("res://Resources/Audio/UI/THREAT_ALARM_1.wav")
	if threat_alarm_sound:
		print("[AudioManager] Loaded threat alarm sound")
	else:
		push_warning("[AudioManager] Failed to load threat alarm sound (THREAT_ALARM_1.wav)")
	
	# Victory (game over win)
	victory_sound = load("res://Resources/Audio/UI/VICTORY_1.wav")
	if victory_sound:
		print("[AudioManager] Loaded victory sound")
	else:
		push_warning("[AudioManager] Failed to load victory sound (VICTORY_1.wav)")
	
	# Fix: dice land should use its own file instead of DENIED_1.wav
	dice_land_sound = load("res://Resources/Audio/UI/DICE_LAND_1.wav")
	if dice_land_sound:
		print("[AudioManager] Loaded dice land sound")
	else:
		push_warning("[AudioManager] Failed to load dice land sound (DICE_LAND_1.wav)")
	


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
	
	# Create dice click player
	dice_click_player = AudioStreamPlayer.new()
	dice_click_player.name = "DiceClickPlayer"
	dice_click_player.volume_db = master_volume_db
	add_child(dice_click_player)
	
	# Create swoosh player
	swoosh_player = AudioStreamPlayer.new()
	swoosh_player.name = "SwooshPlayer"
	swoosh_player.volume_db = master_volume_db
	add_child(swoosh_player)
	
	# Create fan out player
	fan_out_player = AudioStreamPlayer.new()
	fan_out_player.name = "FanOutPlayer"
	fan_out_player.volume_db = master_volume_db
	add_child(fan_out_player)
	
	# Create fan in player
	fan_in_player = AudioStreamPlayer.new()
	fan_in_player.name = "FanInPlayer"
	fan_in_player.volume_db = master_volume_db
	add_child(fan_in_player)
	
	# Create tab switch player
	tab_switch_player = AudioStreamPlayer.new()
	tab_switch_player.name = "TabSwitchPlayer"
	tab_switch_player.volume_db = master_volume_db
	add_child(tab_switch_player)
	
	# Create money tick player
	money_tick_player = AudioStreamPlayer.new()
	money_tick_player.name = "MoneyTickPlayer"
	money_tick_player.volume_db = master_volume_db
	add_child(money_tick_player)
	
	# Create denied player
	denied_player = AudioStreamPlayer.new()
	denied_player.name = "DeniedPlayer"
	denied_player.volume_db = master_volume_db
	add_child(denied_player)
	
	# Create confirm player
	confirm_player = AudioStreamPlayer.new()
	confirm_player.name = "ConfirmPlayer"
	confirm_player.volume_db = master_volume_db
	add_child(confirm_player)
	
	# Create dice land player
	dice_land_player = AudioStreamPlayer.new()
	dice_land_player.name = "DiceLandPlayer"
	dice_land_player.volume_db = master_volume_db
	add_child(dice_land_player)
	
	# Create sell player
	sell_player = AudioStreamPlayer.new()
	sell_player.name = "SellPlayer"
	sell_player.volume_db = master_volume_db
	add_child(sell_player)
	
	# Create round start player
	round_start_player = AudioStreamPlayer.new()
	round_start_player.name = "RoundStartPlayer"
	round_start_player.volume_db = master_volume_db
	add_child(round_start_player)
	
	# Create static burst player
	static_burst_player = AudioStreamPlayer.new()
	static_burst_player.name = "StaticBurstPlayer"
	static_burst_player.volume_db = master_volume_db
	add_child(static_burst_player)

	# Create challenge reveal player
	challenge_reveal_player = AudioStreamPlayer.new()
	challenge_reveal_player.name = "ChallengeRevealPlayer"
	challenge_reveal_player.volume_db = master_volume_db
	add_child(challenge_reveal_player)
	
	# ── NEW PLAYERS — paired with new sounds above ──
	# Dice spawn player
	dice_spawn_player = AudioStreamPlayer.new()
	dice_spawn_player.name = "DiceSpawnPlayer"
	dice_spawn_player.volume_db = master_volume_db
	add_child(dice_spawn_player)
	
	# Jackpot player
	jackpot_player = AudioStreamPlayer.new()
	jackpot_player.name = "JackpotPlayer"
	jackpot_player.volume_db = master_volume_db
	add_child(jackpot_player)
	
	# Streak player
	streak_player = AudioStreamPlayer.new()
	streak_player.name = "StreakPlayer"
	streak_player.volume_db = master_volume_db
	add_child(streak_player)
	
	# Next turn player
	next_turn_player = AudioStreamPlayer.new()
	next_turn_player.name = "NextTurnPlayer"
	next_turn_player.volume_db = master_volume_db
	add_child(next_turn_player)
	
	# Shop open player
	shop_open_player = AudioStreamPlayer.new()
	shop_open_player.name = "ShopOpenPlayer"
	shop_open_player.volume_db = master_volume_db
	add_child(shop_open_player)
	
	# PowerUp apply player
	powerup_apply_player = AudioStreamPlayer.new()
	powerup_apply_player.name = "PowerUpApplyPlayer"
	powerup_apply_player.volume_db = master_volume_db
	add_child(powerup_apply_player)
	
	# Threat alarm player
	threat_alarm_player = AudioStreamPlayer.new()
	threat_alarm_player.name = "ThreatAlarmPlayer"
	threat_alarm_player.volume_db = master_volume_db
	add_child(threat_alarm_player)
	
	# Victory player
	victory_player = AudioStreamPlayer.new()
	victory_player.name = "VictoryPlayer"
	victory_player.volume_db = master_volume_db
	add_child(victory_player)


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
	
	# Track explicit call time for debounce
	_last_explicit_money_time = Time.get_ticks_msec()
	
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
	
	if dice_click_player:
		dice_click_player.volume_db = volume_db
	
	if swoosh_player:
		swoosh_player.volume_db = volume_db
	
	if fan_out_player:
		fan_out_player.volume_db = volume_db
	
	if fan_in_player:
		fan_in_player.volume_db = volume_db
	
	if tab_switch_player:
		tab_switch_player.volume_db = volume_db
	
	if money_tick_player:
		money_tick_player.volume_db = volume_db
	
	if denied_player:
		denied_player.volume_db = volume_db
	
	if confirm_player:
		confirm_player.volume_db = volume_db
	
	if dice_land_player:
		dice_land_player.volume_db = volume_db
	
	if sell_player:
		sell_player.volume_db = volume_db
	
	if round_start_player:
		round_start_player.volume_db = volume_db
	
	if static_burst_player:
		static_burst_player.volume_db = volume_db
	
	if challenge_reveal_player:
		challenge_reveal_player.volume_db = volume_db
	
	if dice_spawn_player:
		dice_spawn_player.volume_db = volume_db
	
	if jackpot_player:
		jackpot_player.volume_db = volume_db
	
	if streak_player:
		streak_player.volume_db = volume_db
	
	if next_turn_player:
		next_turn_player.volume_db = volume_db
	
	if shop_open_player:
		shop_open_player.volume_db = volume_db
	
	if powerup_apply_player:
		powerup_apply_player.volume_db = volume_db
	
	if threat_alarm_player:
		threat_alarm_player.volume_db = volume_db
	
	if victory_player:
		victory_player.volume_db = volume_db
	
	print("[AudioManager] Master volume set to: %.1f dB" % volume_db)


## play_static_burst()
##
## Play a brief static burst for CRT channel-change glitch effect.
func play_static_burst() -> void:
	if not static_burst_sound:
		return
	
	static_burst_player.stream = static_burst_sound
	static_burst_player.pitch_scale = randf_range(0.95, 1.05)
	static_burst_player.volume_db = master_volume_db
	static_burst_player.play()


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


## play_dice_lock()
##
## Play dice lock/unlock click sound with slight random pitch variation.
## Pitch ranges from 0.95 to 1.05 for natural feel.
func play_dice_lock() -> void:
	if not dice_click_sound:
		return
	
	dice_click_player.stream = dice_click_sound
	
	# Slight random pitch variation
	dice_click_player.pitch_scale = randf_range(DICE_LOCK_PITCH_MIN, DICE_LOCK_PITCH_MAX)
	
	# Apply master volume
	dice_click_player.volume_db = master_volume_db
	
	dice_click_player.play()


## _on_money_changed(new_amount: int, change: int)
##
## Connected to PlayerEconomy.money_changed. Plays a quick tick for small
## mid-round earnings, but debounces when explicit money sounds were recently triggered.
func _on_money_changed(_new_amount: int, change: int) -> void:
	if change <= 0:
		return
	if change > MONEY_TICK_MAX_AMOUNT:
		return
	if Time.get_ticks_msec() - _last_explicit_money_time < MONEY_DEBOUNCE_MS:
		return
	play_money_tick(change)


## play_money_tick(amount: int)
##
## Plays a brief cash tick for small mid-round money earnings.
func play_money_tick(amount: int) -> void:
	if not money_tick_sound:
		return
	
	money_tick_player.stream = money_tick_sound
	
	var base_pitch = randf_range(MONEY_TICK_PITCH_MIN, MONEY_TICK_PITCH_MAX)
	var amount_bonus = amount * MONEY_PITCH_SCALE
	var final_pitch = base_pitch + amount_bonus
	final_pitch = minf(final_pitch, MONEY_MAX_PITCH)
	money_tick_player.pitch_scale = final_pitch
	money_tick_player.volume_db = master_volume_db
	money_tick_player.play()


## play_panel_swoosh()
##
## Play a swoosh sound for panel fly-in animations.
## Repurposes dice roll at very low pitch.
func play_panel_swoosh() -> void:
	if not swoosh_sound:
		return
	
	swoosh_player.stream = swoosh_sound
	swoosh_player.pitch_scale = SWOOSH_PITCH
	swoosh_player.volume_db = master_volume_db
	swoosh_player.play()


## play_fan_out()
##
## Play a crisp spread sound when cards fan out.
func play_fan_out() -> void:
	if not fan_out_sound:
		print("[AudioManager] Fan out sound not loaded, skipping")
		return
	print("[AudioManager] Playing fan out sound")
	fan_out_player.stream = fan_out_sound
	fan_out_player.pitch_scale = randf_range(FAN_OUT_PITCH_MIN, FAN_OUT_PITCH_MAX)
	fan_out_player.volume_db = master_volume_db
	fan_out_player.play()


## play_fan_in()
##
## Play a soft collapse sound when cards fold back.
func play_fan_in() -> void:
	if not fan_in_sound:
		return
	
	fan_in_player.stream = fan_in_sound
	fan_in_player.pitch_scale = randf_range(FAN_IN_PITCH_MIN, FAN_IN_PITCH_MAX)
	fan_in_player.volume_db = master_volume_db
	fan_in_player.play()


## play_tab_switch()
##
## Play a crisp sound when switching tabs in the shop.
func play_tab_switch() -> void:
	if not tab_switch_sound:
		return
	
	tab_switch_player.stream = tab_switch_sound
	tab_switch_player.pitch_scale = randf_range(TAB_SWITCH_PITCH_MIN, TAB_SWITCH_PITCH_MAX)
	tab_switch_player.volume_db = master_volume_db
	tab_switch_player.play()


## play_denied_sound()
##
## Play a low thud for blocked or unaffordable actions.
func play_denied_sound() -> void:
	if not denied_sound:
		return
	
	denied_player.stream = denied_sound
	denied_player.pitch_scale = DENIED_PITCH
	denied_player.volume_db = master_volume_db
	denied_player.play()


## play_confirm_sound()
##
## Play a short confirmation sound for category selection or similar.
func play_confirm_sound() -> void:
	if not confirm_sound:
		return
	
	confirm_player.stream = confirm_sound
	confirm_player.pitch_scale = CONFIRM_PITCH
	confirm_player.volume_db = master_volume_db
	confirm_player.play()


## play_dice_land_sound()
##
## Play a soft clack when dice finish rolling and land.
func play_dice_land_sound() -> void:
	if not dice_land_sound:
		return
	
	dice_land_player.stream = dice_land_sound
	dice_land_player.pitch_scale = randf_range(DICE_LAND_PITCH_MIN, DICE_LAND_PITCH_MAX)
	dice_land_player.volume_db = master_volume_db
	dice_land_player.play()


## play_sell_sound()
##
## Play a cash sound when selling an item.
func play_sell_sound() -> void:
	if not sell_sound:
		return
	
	sell_player.stream = sell_sound
	sell_player.pitch_scale = SELL_PITCH
	sell_player.volume_db = master_volume_db
	sell_player.play()


## play_round_start_sound()
##
## Play a ding when a round transition/round starts.
func play_round_start_sound() -> void:
	if not round_start_sound:
		return
	
	round_start_player.stream = round_start_sound
	round_start_player.pitch_scale = ROUND_START_PITCH
	round_start_player.volume_db = master_volume_db
	round_start_player.play()

## play_challenge_reveal_sound()
## Play a sound when revealing a new challenge.
func play_challenge_reveal_sound() -> void:
	if not challenge_reveal_sound:
		return
	
	challenge_reveal_player.stream = challenge_reveal_sound
	challenge_reveal_player.pitch_scale = 1.0
	challenge_reveal_player.volume_db = master_volume_db
	challenge_reveal_player.play()

## play_dice_spawn_sound()
##
## Play a sound when dice spawn into the hand.
## Was previously reusing play_panel_swoosh().
func play_dice_spawn_sound() -> void:
	if not dice_spawn_sound:
		return
	
	dice_spawn_player.stream = dice_spawn_sound
	dice_spawn_player.pitch_scale = randf_range(0.95, 1.05)
	dice_spawn_player.volume_db = master_volume_db
	dice_spawn_player.play()


## play_jackpot_sound()
##
## Play a celebration sound for Yahtzee / Jackpot (score >= 50).
func play_jackpot_sound() -> void:
	if not jackpot_sound:
		return
	
	jackpot_player.stream = jackpot_sound
	jackpot_player.pitch_scale = randf_range(0.95, 1.05)
	jackpot_player.volume_db = master_volume_db
	jackpot_player.play()


## play_streak_sound()
##
## Play a sound when a score streak popup appears.
func play_streak_sound() -> void:
	if not streak_sound:
		return
	
	streak_player.stream = streak_sound
	streak_player.pitch_scale = randf_range(0.95, 1.05)
	streak_player.volume_db = master_volume_db
	streak_player.play()


## play_next_turn_sound()
##
## Play a sound when advancing to the next turn.
func play_next_turn_sound() -> void:
	if not next_turn_sound:
		return
	
	next_turn_player.stream = next_turn_sound
	next_turn_player.pitch_scale = randf_range(0.95, 1.05)
	next_turn_player.volume_db = master_volume_db
	next_turn_player.play()


## play_shop_open_sound()
##
## Play a sound when opening or closing the shop.
func play_shop_open_sound() -> void:
	if not shop_open_sound:
		return
	
	shop_open_player.stream = shop_open_sound
	shop_open_player.pitch_scale = randf_range(0.95, 1.05)
	shop_open_player.volume_db = master_volume_db
	shop_open_player.play()


## play_powerup_apply_sound()
##
## Play a sound when a PowerUp or Mod is applied to dice.
## Replaces the previous play_scoring_sound(10) reuse.
func play_powerup_apply_sound() -> void:
	if not powerup_apply_sound:
		return
	
	powerup_apply_player.stream = powerup_apply_sound
	powerup_apply_player.pitch_scale = randf_range(0.95, 1.05)
	powerup_apply_player.volume_db = master_volume_db
	powerup_apply_player.play()


## play_threat_alarm_sound()
##
## Play an urgent alarm when challenge progress reaches >= 80%.
## Replaces the previous play_panel_swoosh() reuse.
func play_threat_alarm_sound() -> void:
	if not threat_alarm_sound:
		return
	
	threat_alarm_player.stream = threat_alarm_sound
	threat_alarm_player.pitch_scale = randf_range(0.95, 1.05)
	threat_alarm_player.volume_db = master_volume_db
	threat_alarm_player.play()


## play_victory_sound()
##
## Play a victory fanfare when the player wins (challenge completed).
func play_victory_sound() -> void:
	if not victory_sound:
		return
	
	victory_player.stream = victory_sound
	victory_player.pitch_scale = randf_range(0.95, 1.05)
	victory_player.volume_db = master_volume_db
	victory_player.play()
