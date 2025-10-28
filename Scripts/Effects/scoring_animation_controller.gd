extends Node
class_name ScoringAnimationController

## ScoringAnimationController
##
## Handles all scoring animations including dice bounces, floating numbers,
## consumable effects, powerup sequences, and dynamic audio feedback.
## Scales animation intensity based on final score magnitude.

signal animation_sequence_complete

# Animation configuration
const BASE_ANIMATION_DURATION: float = 0.5 #2.5
const DICE_BOUNCE_HEIGHT: float = 15.0
const COLORED_DICE_EXTRA_BOUNCE: float = 10.0
const FLOAT_NUMBER_SPEED: float = 200.0  # Increased from 150.0
const FLOAT_NUMBER_DURATION: float = 1.5
const POWERUP_SEQUENCE_DELAY: float = 0.15  # Reduced from 0.3
const CONSUMABLE_BOUNCE_HEIGHT: float = 12.0

# Score-based scaling thresholds
const SMALL_SCORE_THRESHOLD: int = 15
const MEDIUM_SCORE_THRESHOLD: int = 30
const LARGE_SCORE_THRESHOLD: int = 50

# Audio configuration
const BASE_PITCH: float = 1.0
const MAX_PITCH: float = 2.0
const PITCH_SCALE_FACTOR: float = 0.02

# Sound effect resource
@export var scoring_sound: AudioStream

# Import the FloatingNumber class
const FloatingNumber = preload("res://Scripts/Effects/floating_number.gd")

# Node references
var dice_hand: DiceHand
var game_controller: GameController
var consumable_ui: ConsumableUI
var power_up_ui: PowerUpUI
var audio_player: AudioStreamPlayer

# Animation state
var current_animation_sequence: Tween
var animation_in_progress: bool = false

## _ready()
##
## Initialize the animation controller and set up audio player.
func _ready() -> void:
	print("[ScoringAnimationController] Initializing...")
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Wait a frame to ensure other nodes are ready
	await get_tree().process_frame
	
	# Find required nodes
	_find_required_nodes()

## _find_required_nodes()
##
## Locate and cache references to dice hand and game controller.
func _find_required_nodes() -> void:
	# Find DiceHand
	var dice_hand_nodes = get_tree().get_nodes_in_group("dice_hand")
	if dice_hand_nodes.size() > 0:
		dice_hand = dice_hand_nodes[0] as DiceHand
		print("[ScoringAnimationController] Found DiceHand")
	else:
		push_error("[ScoringAnimationController] Could not find DiceHand node!")
	
	# Find GameController
	game_controller = get_node_or_null("../GameController")
	if not game_controller:
		# Try alternative paths
		game_controller = get_tree().get_first_node_in_group("game_controller")
		if not game_controller:
			push_error("[ScoringAnimationController] Could not find GameController!")
	else:
		print("[ScoringAnimationController] Found GameController")
	
	# Find ConsumableUI
	var consumable_ui_nodes = get_tree().get_nodes_in_group("consumable_ui")
	if consumable_ui_nodes.size() > 0:
		consumable_ui = consumable_ui_nodes[0] as ConsumableUI
		print("[ScoringAnimationController] Found ConsumableUI")
	else:
		print("[ScoringAnimationController] ConsumableUI not found")
	
	# Find PowerUpUI
	var power_up_ui_nodes = get_tree().get_nodes_in_group("power_up_ui")
	if power_up_ui_nodes.size() > 0:
		power_up_ui = power_up_ui_nodes[0] as PowerUpUI
		print("[ScoringAnimationController] Found PowerUpUI")
	else:
		print("[ScoringAnimationController] PowerUpUI not found")

## start_scoring_animation(score, category, breakdown_info)
##
## Main entry point for scoring animations. Orchestrates the entire sequence
## based on score magnitude and involved game elements.
func start_scoring_animation(score: int, category: String, breakdown_info: Dictionary = {}) -> void:
	if animation_in_progress:
		print("[ScoringAnimationController] Animation already in progress, skipping")
		return
	
	animation_in_progress = true
	print("[ScoringAnimationController] Starting scoring animation for score: %d, category: %s" % [score, category])
	print("[ScoringAnimationController] Breakdown info: %s" % str(breakdown_info))
	
	# Stop any existing animation
	if current_animation_sequence and current_animation_sequence.is_valid():
		current_animation_sequence.kill()
	
	# Create new animation sequence
	current_animation_sequence = create_tween()
	current_animation_sequence.set_parallel(true)
	
	# Calculate animation intensity and speed based on score
	var intensity_scale = _calculate_intensity_scale(score)
	var speed_scale = _calculate_speed_scale(score)
	
	# Start animation sequence
	await _execute_animation_sequence(score, category, breakdown_info, intensity_scale, speed_scale)
	
	animation_in_progress = false
	animation_sequence_complete.emit()

## _calculate_intensity_scale(score)
##
## Calculate animation intensity multiplier based on score magnitude.
func _calculate_intensity_scale(score: int) -> float:
	if score < SMALL_SCORE_THRESHOLD:
		return 1.0
	elif score < MEDIUM_SCORE_THRESHOLD:
		return 1.3
	elif score < LARGE_SCORE_THRESHOLD:
		return 1.6
	else:
		return 2.0

## _calculate_speed_scale(score)
##
## Calculate animation speed multiplier based on score magnitude.
## Higher scores = faster animations for more excitement.
func _calculate_speed_scale(score: int) -> float:
	if score < SMALL_SCORE_THRESHOLD:
		return 1.0  # Normal speed
	elif score < MEDIUM_SCORE_THRESHOLD:
		return 1.2  # 20% faster
	elif score < LARGE_SCORE_THRESHOLD:
		return 1.4  # 40% faster
	else:
		return 1.6  # 60% faster

## _execute_animation_sequence(score, _category, breakdown_info, intensity_scale, speed_scale)
##
## Execute the complete animation sequence in proper order with dynamic speed.
func _execute_animation_sequence(score: int, _category: String, breakdown_info: Dictionary, intensity_scale: float, speed_scale: float) -> void:
	# Phase 1: Dice bounce animation with individual scores
	await _animate_dice_bounce_with_scores(intensity_scale, speed_scale)
	
	# Phase 2: Play scoring sound with dynamic pitch
	_play_scoring_audio(score)
	
	# Phase 3: Wait a bit, then animate contributing consumables
	var consumable_delay = 0.15 / speed_scale  # Reduced from 0.3
	print("[ScoringAnimationController] Waiting %f seconds before consumables..." % consumable_delay)
	await get_tree().create_timer(consumable_delay).timeout
	if breakdown_info.has("active_consumables") and breakdown_info.active_consumables.size() > 0:
		print("[ScoringAnimationController] Starting consumable animations...")
		_animate_contributing_consumables(breakdown_info, intensity_scale, speed_scale)
	else:
		print("[ScoringAnimationController] No consumables to animate")
	
	# Phase 4: Wait a bit, then animate contributing powerups
	var powerup_delay = 0.25 / speed_scale  # Reduced from 0.5
	print("[ScoringAnimationController] Waiting %f seconds before powerups..." % powerup_delay)
	await get_tree().create_timer(powerup_delay).timeout
	if breakdown_info.has("active_powerups") and breakdown_info.active_powerups.size() > 0:
		print("[ScoringAnimationController] Starting powerup animations...")
		_animate_contributing_powerups(breakdown_info, intensity_scale, speed_scale)
	else:
		print("[ScoringAnimationController] No powerups to animate")
	
	# Phase 5: Show final score floating number
	var final_delay = 0.5 / speed_scale
	await get_tree().create_timer(final_delay).timeout
	_show_final_score_number(score, intensity_scale)
	
	# Wait for all animations to complete
	await get_tree().create_timer(1.0 / speed_scale).timeout

## _animate_dice_bounce_with_scores(intensity_scale, speed_scale)
##
## Animate dice with bounce effect and show individual dice values as floating numbers.
func _animate_dice_bounce_with_scores(intensity_scale: float, speed_scale: float = 1.0) -> void:
	if not dice_hand:
		print("[ScoringAnimationController] No dice hand found for animation")
		return
	
	var dice_array = dice_hand.get_all_dice()
	print("[ScoringAnimationController] Animating %d dice" % dice_array.size())
	
	var stagger_delay = 0.15 / speed_scale  # Faster stagger for high scores
	var base_delay = 0.1 / speed_scale      # Small base delay to ensure setup is complete
	
	for i in range(dice_array.size()):
		var die = dice_array[i]
		if not die:
			continue
		
		var delay = base_delay + (i * stagger_delay)  # Add base delay to all dice
		
		# Schedule dice animation
		get_tree().create_timer(delay).timeout.connect(func(): _animate_single_die(die, intensity_scale, speed_scale))
	
	# Return after all dice have been scheduled (wait for the last one to start)
	var total_duration = base_delay + (dice_array.size() * stagger_delay) + (0.6 / speed_scale)
	await get_tree().create_timer(total_duration).timeout

## _animate_single_die(die, intensity_scale, speed_scale)
##
## Animate a single die with bounce and floating value.
func _animate_single_die(die: Dice, intensity_scale: float, speed_scale: float = 1.0) -> void:
	if not die:
		return
	
	print("[ScoringAnimationController] Animating die with value: %d" % die.value)
	
	# Calculate bounce height
	var bounce_height = DICE_BOUNCE_HEIGHT * intensity_scale
	
	# Extra bounce for colored dice
	if die.color != DiceColor.Type.NONE:
		bounce_height += COLORED_DICE_EXTRA_BOUNCE * intensity_scale
		print("[ScoringAnimationController] Colored die detected, extra bounce!")
	
	# Get die center position for floating number (improved positioning)
	var die_size = Vector2(60, 60)  # Standard dice size
	if die.sprite and die.sprite.texture:
		var texture_size = die.sprite.texture.get_size()
		die_size = texture_size * die.sprite.scale
	var die_center = die.global_position + Vector2(die_size.x / 2, 0)  # Above and center
	
	# Ensure the die is valid before creating animations
	if not die or not is_instance_valid(die):
		print("[ScoringAnimationController] Invalid die, skipping animation")
		return
	
	# Store original LOCAL position to avoid screen shake interference
	# Using local position ensures dice return to the correct spot regardless of camera shake
	var original_local_position = die.position
	var bounce_duration = 0.6 / speed_scale
	
	# Create bounce animation with speed scaling and validation
	if is_instance_valid(die):
		var bounce_tween = create_tween()
		# Create a simple callback that doesn't need complex validation
		var bounce_callback = func(progress: float):
			_bounce_die_local(die, original_local_position, bounce_height, progress)
		
		bounce_tween.tween_method(bounce_callback, 0.0, 1.0, bounce_duration)
	
	# Show floating dice value with appropriate color
	var dice_color = Color.WHITE
	if die.color != DiceColor.Type.NONE:
		# Use different colors for different dice colors
		match die.color:
			DiceColor.Type.GREEN:
				dice_color = Color.GREEN
			DiceColor.Type.RED:
				dice_color = Color.RED
			DiceColor.Type.PURPLE:
				dice_color = Color.MAGENTA
			DiceColor.Type.BLUE:
				dice_color = Color.CYAN
			_:
				dice_color = Color.WHITE
	
	# Create floating number with speed-adjusted duration and speed
	var floating_number = FloatingNumber.create_floating_number(get_tree().current_scene, die_center, 
		str(die.value), 1.0, dice_color)
	if floating_number:
		floating_number.float_duration = floating_number.float_duration / speed_scale
		floating_number.float_speed = FLOAT_NUMBER_SPEED * speed_scale  # Make it faster for higher scores

## _bounce_die(die, original_position, bounce_height, progress)
##
## Animate individual die bounce using sine wave motion.
func _bounce_die(die: Node2D, original_position: Vector2, bounce_height: float, progress: float) -> void:
	if not die:
		return
	
	# Ensure exact position at the end to prevent drift
	if progress >= 1.0:
		die.global_position = original_position
		return
	
	# Create bounce motion using sine wave
	var bounce_offset = sin(progress * PI) * bounce_height
	die.global_position = original_position + Vector2(0, -bounce_offset)

## _bounce_die_local(die, original_local_position, bounce_height, progress)
##
## Animate individual die bounce using local position to avoid screen shake interference.
## Uses local position which is unaffected by camera shake.
func _bounce_die_local(die: Node2D, original_local_position: Vector2, bounce_height: float, progress: float) -> void:
	# Validate die exists and is still valid
	if not die or not is_instance_valid(die):
		return
	
	# Ensure exact position at the end to prevent drift
	if progress >= 1.0:
		die.position = original_local_position
		return
	
	# Create bounce motion using sine wave (in local space)
	var bounce_offset = sin(progress * PI) * bounce_height
	die.position = original_local_position + Vector2(0, -bounce_offset)

## _play_scoring_audio(score)
##
## Play scoring sound effect with pitch scaled by score magnitude.
func _play_scoring_audio(score: int) -> void:
	if not audio_player:
		return
	
	# Only play if we have a sound effect assigned
	if scoring_sound:
		audio_player.stream = scoring_sound
		
		# Calculate pitch based on score
		var pitch = BASE_PITCH + (score * PITCH_SCALE_FACTOR)
		pitch = min(pitch, MAX_PITCH)  # Cap at maximum pitch
		
		audio_player.pitch_scale = pitch
		audio_player.play()
		
		print("[ScoringAnimationController] Playing audio with pitch: %.2f" % pitch)
	else:
		print("[ScoringAnimationController] No scoring sound effect assigned")

## _animate_contributing_consumables(breakdown_info, intensity_scale, speed_scale)
##
## Animate only consumables that actually contributed to the score.
func _animate_contributing_consumables(breakdown_info: Dictionary, intensity_scale: float, speed_scale: float) -> void:
	if not consumable_ui:
		print("[ScoringAnimationController] No ConsumableUI found")
		return
	
	var active_consumables = breakdown_info.get("active_consumables", [])
	print("[ScoringAnimationController] Active consumables: %s" % str(active_consumables))
	
	# Check additive sources for consumable contributions
	var additive_sources = breakdown_info.get("additive_sources", [])
	var stagger_delay = 0.15 / speed_scale  # Reduced to match other delays
	var delay = 0.0
	
	for source_info in additive_sources:
		var source_name = source_info.get("name", "")
		var source_value = source_info.get("value", 0)
		
		# Check if this is a consumable source
		if source_info.get("category", "") == "consumable" or source_name in active_consumables:
			get_tree().create_timer(delay).timeout.connect(
				func(): _animate_consumable_contribution(source_name, source_value, intensity_scale, speed_scale)
			)
			delay += stagger_delay

## _animate_contributing_powerups(breakdown_info, intensity_scale, speed_scale)
##
## Animate only powerups that actually contributed to the score.
func _animate_contributing_powerups(breakdown_info: Dictionary, intensity_scale: float, speed_scale: float) -> void:
	if not power_up_ui:
		print("[ScoringAnimationController] No PowerUpUI found")
		return
	
	var active_powerups = breakdown_info.get("active_powerups", [])
	print("[ScoringAnimationController] Active powerups: " + str(active_powerups))
	
	# Debug: Print all breakdown_info contents
	print("[ScoringAnimationController] Full breakdown_info: " + str(breakdown_info))
	
	# Check both additive and multiplier sources for powerup contributions
	var additive_sources = breakdown_info.get("additive_sources", [])
	var multiplier_sources = breakdown_info.get("multiplier_sources", [])
	print("[ScoringAnimationController] Additive sources: " + str(additive_sources))
	print("[ScoringAnimationController] Multiplier sources: " + str(multiplier_sources))
	var stagger_delay = 0.15 / speed_scale  # Reduced to match other delays
	var delay = 0.0
	var animated_any_powerups = false
	
	# Animate additive powerups
	for source_info in additive_sources:
		var source_name = source_info.get("name", "")
		var source_value = source_info.get("value", 0)
		
		if source_info.get("category", "") == "powerup" or source_name in active_powerups:
			get_tree().create_timer(delay).timeout.connect(
				func(): _animate_powerup_additive(source_name, source_value, intensity_scale, speed_scale)
			)
			delay += stagger_delay
			animated_any_powerups = true
	
	# Animate multiplier powerups
	for source_info in multiplier_sources:
		var source_name = source_info.get("name", "")
		var source_value = source_info.get("value", 1.0)
		
		if source_info.get("category", "") == "powerup" or source_name in active_powerups:
			get_tree().create_timer(delay).timeout.connect(
				func(): _animate_powerup_multiplier(source_name, source_value, intensity_scale, speed_scale)
			)
			delay += stagger_delay
			animated_any_powerups = true
	
	# Fallback: If no powerups were animated from sources but we have active powerups,
	# animate them with a generic bounce effect (for manual scoring)
	if not animated_any_powerups and active_powerups.size() > 0:
		print("[ScoringAnimationController] No source breakdown, animating active powerups generically")
		for powerup_id in active_powerups:
			get_tree().create_timer(delay).timeout.connect(
				func(): _animate_powerup_generic(powerup_id, intensity_scale, speed_scale)
			)
			delay += stagger_delay

## _animate_consumable_contribution(consumable_id, contribution, intensity_scale, speed_scale)
##
## Animate a single consumable's contribution to the score.
func _animate_consumable_contribution(consumable_id: String, contribution: int, intensity_scale: float, speed_scale: float) -> void:
	if not consumable_ui:
		return
	
	# Find the consumable spine in the UI
	var spine_dict = consumable_ui.get("_consumable_spines")
	if not spine_dict or not spine_dict.has(consumable_id):
		print("[ScoringAnimationController] Could not find consumable spine for: %s" % consumable_id)
		return
	
	var spine = spine_dict[consumable_id] as ConsumableSpine
	if not spine:
		return
	
	print("[ScoringAnimationController] Animating consumable: %s with +%d" % [consumable_id, contribution])
	
	# Create bounce animation
	var bounce_height = CONSUMABLE_BOUNCE_HEIGHT * intensity_scale
	var original_position = spine.global_position
	var bounce_duration = 0.6 / speed_scale
	
	var bounce_tween = create_tween()
	bounce_tween.tween_method(func(progress: float): _bounce_consumable_spine(spine, original_position, bounce_height, progress), 0.0, 1.0, bounce_duration)
	
	# Show floating contribution number above and center of the spine
	var spine_bounds = spine.get_rect()
	var spine_center = spine.global_position + Vector2(spine_bounds.size.x / 2, 0)
	var floating_number = FloatingNumber.create_floating_number(get_tree().current_scene, spine_center, 
		"+" + str(contribution), 1.2, Color.GREEN)
	if floating_number:
		floating_number.float_duration = floating_number.float_duration / speed_scale
		floating_number.float_speed = FLOAT_NUMBER_SPEED * speed_scale

## _animate_powerup_additive(powerup_id, additive_value, intensity_scale, speed_scale)
##
## Animate a powerup's additive contribution.
func _animate_powerup_additive(powerup_id: String, additive_value: int, intensity_scale: float, speed_scale: float) -> void:
	if not power_up_ui:
		return
	
	var spine_dict = power_up_ui.get("_spines")
	if not spine_dict or not spine_dict.has(powerup_id):
		print("[ScoringAnimationController] Could not find powerup spine for: %s" % powerup_id)
		return
	
	var spine = spine_dict[powerup_id] as PowerUpSpine
	if not spine:
		return
	
	print("[ScoringAnimationController] Animating powerup additive: %s with +%d" % [powerup_id, additive_value])
	
	# Create bounce animation
	var bounce_height = CONSUMABLE_BOUNCE_HEIGHT * intensity_scale * 1.2
	var original_position = spine.global_position
	var bounce_duration = 0.8 / speed_scale
	
	var bounce_tween = create_tween()
	bounce_tween.tween_method(func(progress: float): _bounce_powerup_spine(spine, original_position, bounce_height, progress), 0.0, 1.0, bounce_duration)
	
	# Show floating additive value above and center of the spine
	var spine_bounds = spine.get_rect()
	var spine_center = spine.global_position + Vector2(spine_bounds.size.x / 2, 0)
	var floating_number = FloatingNumber.create_floating_number(get_tree().current_scene, spine_center, 
		"+" + str(additive_value), 1.5, Color.YELLOW)
	if floating_number:
		floating_number.float_duration = floating_number.float_duration / speed_scale
		floating_number.float_speed = FLOAT_NUMBER_SPEED * speed_scale

## _animate_powerup_multiplier(powerup_id, multiplier_value, intensity_scale, speed_scale)
##
## Animate a powerup's multiplier contribution.
func _animate_powerup_multiplier(powerup_id: String, multiplier_value: float, intensity_scale: float, speed_scale: float) -> void:
	if not power_up_ui:
		return
	
	var spine_dict = power_up_ui.get("_spines")
	if not spine_dict or not spine_dict.has(powerup_id):
		print("[ScoringAnimationController] Could not find powerup spine for: %s" % powerup_id)
		return
	
	var spine = spine_dict[powerup_id] as PowerUpSpine
	if not spine:
		return
	
	print("[ScoringAnimationController] Animating powerup multiplier: %s with x%.1f" % [powerup_id, multiplier_value])
	
	# Create bounce animation
	var bounce_height = CONSUMABLE_BOUNCE_HEIGHT * intensity_scale * 1.2
	var original_position = spine.global_position
	var bounce_duration = 0.8 / speed_scale
	
	var bounce_tween = create_tween()
	bounce_tween.tween_method(func(progress: float): _bounce_powerup_spine(spine, original_position, bounce_height, progress), 0.0, 1.0, bounce_duration)
	
	# Show floating multiplier value above and center of the spine
	var spine_bounds = spine.get_rect()
	var spine_center = spine.global_position + Vector2(spine_bounds.size.x / 2, 0)
	var multiplier_text = "x%.1f" % multiplier_value
	var floating_number = FloatingNumber.create_floating_number(get_tree().current_scene, spine_center, 
		multiplier_text, 1.5, Color.CYAN)
	if floating_number:
		floating_number.float_duration = floating_number.float_duration / speed_scale
		floating_number.float_speed = FLOAT_NUMBER_SPEED * speed_scale

## _animate_powerup_generic(powerup_id, intensity_scale, speed_scale)
##
## Generic powerup animation for manual scoring when no detailed breakdown is available.
func _animate_powerup_generic(powerup_id: String, intensity_scale: float, speed_scale: float) -> void:
	if not power_up_ui:
		print("[ScoringAnimationController] No PowerUpUI found for generic animation")
		return
		
	var spine_dict = power_up_ui.get("_spines")
	if not spine_dict:
		print("[ScoringAnimationController] Could not access PowerUpUI spines dictionary")
		return
		
	var spine = spine_dict.get(powerup_id, null)
	if not spine:
		print("[ScoringAnimationController] Could not find powerup spine for: %s" % powerup_id)
		return
		
	print("[ScoringAnimationController] Generic powerup animation: %s" % powerup_id)
	
	# Bounce the powerup spine
	var bounce_height = CONSUMABLE_BOUNCE_HEIGHT * intensity_scale
	var original_position = spine.global_position
	var bounce_duration = 0.6 / speed_scale
	
	var bounce_tween = create_tween()
	bounce_tween.tween_method(func(progress: float): _bounce_powerup_spine(spine, original_position, bounce_height, progress), 0.0, 1.0, bounce_duration)
	
	# Show a generic "Active!" floating text
	var spine_bounds = spine.get_rect()
	var spine_center = spine.global_position + Vector2(spine_bounds.size.x / 2, 0)
	var floating_number = FloatingNumber.create_floating_number(get_tree().current_scene, spine_center, 
		"ACTIVE!", 1.0, Color.WHITE)
	if floating_number:
		floating_number.float_duration = floating_number.float_duration / speed_scale
		floating_number.float_speed = FLOAT_NUMBER_SPEED * speed_scale

## _bounce_consumable_spine(spine, original_position, bounce_height, progress)
##
## Animate a consumable spine bounce effect.
func _bounce_consumable_spine(spine: Node, original_position: Vector2, bounce_height: float, progress: float) -> void:
	if not spine:
		return
	
	var bounce_offset = sin(progress * PI) * bounce_height
	spine.global_position = original_position + Vector2(0, -bounce_offset)

## _animate_powerups_sequence(powerup_multipliers, intensity_scale)
##
## Animate powerups one by one showing their multiplier effects.
func _animate_powerups_sequence(powerup_multipliers: Dictionary, intensity_scale: float) -> void:
	if not game_controller:
		return
	
	var delay = 0.0
	for powerup_id in powerup_multipliers:
		var multiplier = powerup_multipliers[powerup_id]
		
		# Schedule this powerup animation using timer
		get_tree().create_timer(delay).timeout.connect(
			func(): _animate_single_powerup(powerup_id, multiplier, intensity_scale)
		)
		
		delay += POWERUP_SEQUENCE_DELAY

## _animate_single_powerup(powerup_id, multiplier, intensity_scale)
##
## Animate a single powerup's multiplier effect.
func _animate_single_powerup(powerup_id: String, multiplier: float, intensity_scale: float) -> void:
	if not power_up_ui:
		print("[ScoringAnimationController] No PowerUpUI found for animation")
		return
	
	# Find the powerup spine in the UI
	var spine_dict = power_up_ui.get("_spines")
	if not spine_dict or not spine_dict.has(powerup_id):
		print("[ScoringAnimationController] Could not find powerup spine for: %s" % powerup_id)
		return
	
	var spine = spine_dict[powerup_id] as PowerUpSpine
	if not spine:
		print("[ScoringAnimationController] PowerUp spine is null for: %s" % powerup_id)
		return
	
	print("[ScoringAnimationController] Animating powerup spine: %s" % powerup_id)
	
	# Create bounce animation for the powerup spine
	var bounce_height = CONSUMABLE_BOUNCE_HEIGHT * intensity_scale * 1.2  # Slightly bigger bounce
	var original_position = spine.global_position
	
	var bounce_tween = create_tween()
	bounce_tween.tween_method(func(progress: float): _bounce_powerup_spine(spine, original_position, bounce_height, progress), 0.0, 1.0, 0.8)
	
	# Show floating multiplier number
	var spine_center = spine.global_position + (spine.size / 2)
	var multiplier_text = "x%.1f" % multiplier
	FloatingNumber.create_floating_number(get_tree().current_scene, spine_center, 
		multiplier_text, 1.5, Color.CYAN)
	
	print("[ScoringAnimationController] Animated powerup %s with multiplier %.1fx" % [powerup_id, multiplier])

## _bounce_powerup_spine(spine, original_position, bounce_height, progress)
##
## Animate a powerup spine bounce effect.
func _bounce_powerup_spine(spine: Node, original_position: Vector2, bounce_height: float, progress: float) -> void:
	if not spine:
		return
	
	var bounce_offset = sin(progress * PI) * bounce_height
	spine.global_position = original_position + Vector2(0, -bounce_offset)

## _show_final_score_number(score, _intensity_scale)
##
## Show the final score as a large floating number.
func _show_final_score_number(score: int, _intensity_scale: float) -> void:
	# Find a good position for the final score - center of screen
	var screen_center = get_viewport().get_visible_rect().size / 2
	
	# Create large, prominent score number
	FloatingNumber.create_floating_number(get_tree().current_scene, screen_center, 
		str(score), 2.0 * _intensity_scale, Color.GOLD)
	
	print("[ScoringAnimationController] Showing final score: %d" % score)

## create_floating_number(position, value, scale_factor)
##
## Utility function to create floating number effects.
func create_floating_number(position: Vector2, value: String, scale_factor: float = 1.0) -> void:
	var label = Label.new()
	label.text = value
	label.global_position = position
	label.scale = Vector2.ONE * scale_factor
	
	# Style the label
	label.add_theme_font_size_override("font_size", int(24 * scale_factor))
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	
	# Add to scene
	get_tree().current_scene.add_child(label)
	
	# Animate the floating effect
	var float_tween = create_tween()
	float_tween.set_parallel(true)
	
	# Move upward
	float_tween.tween_property(label, "global_position", 
		position + Vector2(0, -FLOAT_NUMBER_SPEED), FLOAT_NUMBER_DURATION)
	
	# Fade out
	float_tween.tween_property(label, "modulate:a", 0.0, FLOAT_NUMBER_DURATION)
	
	# Remove after animation
	float_tween.tween_callback(label.queue_free).set_delay(FLOAT_NUMBER_DURATION)
