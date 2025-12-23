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
const FloatingNumberScript = preload("res://Scripts/Effects/floating_number.gd")

# Node references
var dice_hand: DiceHand
var game_controller: GameController
var consumable_ui: ConsumableUI
var power_up_ui: PowerUpUI
var audio_player: AudioStreamPlayer
var score_card_ui: ScoreCardUI

# Animation state
var current_animation_sequence: Tween
var animation_in_progress: bool = false
var current_breakdown_info: Dictionary = {}
var animations_cancelled: bool = false

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
	
	# Find ScoreCardUI
	var scorecard_ui_nodes = get_tree().get_nodes_in_group("scorecard_ui")
	if scorecard_ui_nodes.size() > 0:
		score_card_ui = scorecard_ui_nodes[0] as ScoreCardUI
		print("[ScoringAnimationController] Found ScoreCardUI")
	else:
		print("[ScoringAnimationController] ScoreCardUI not found")

## cancel_all_animations()
##
## Cancel all pending animations by setting a flag that callbacks check.
## Call this when dice are being cleared to prevent accessing freed objects.
func cancel_all_animations() -> void:
	print("[ScoringAnimationController] Cancelling all animations")
	
	# Set flag to abort any pending timer callbacks
	animations_cancelled = true
	
	# Stop any existing tween
	if current_animation_sequence and current_animation_sequence.is_valid():
		current_animation_sequence.kill()
		current_animation_sequence = null
	
	# Reset animation state
	animation_in_progress = false
	current_breakdown_info.clear()

func start_scoring_animation(score: int, category: String, breakdown_info: Dictionary = {}) -> void:
	if animation_in_progress:
		print("[ScoringAnimationController] Animation already in progress, skipping")
		return
	
	animation_in_progress = true
	animations_cancelled = false  # Reset cancellation flag for new animation
	current_breakdown_info = breakdown_info  # Store for use in animation functions
	print("[ScoringAnimationController] Starting scoring animation for score: %d, category: %s" % [score, category])
	print("[ScoringAnimationController] Breakdown info: %s" % str(breakdown_info))
	
	# Prepare ScoreCardUI for animation - reset breakdown panels
	if score_card_ui:
		score_card_ui.prepare_for_scoring_animation()
	
	# Stop any existing animation
	if current_animation_sequence and current_animation_sequence.is_valid():
		current_animation_sequence.kill()
		current_animation_sequence = null
	
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
		return 2.3
	elif score < LARGE_SCORE_THRESHOLD:
		return 4.6
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
	
	# Phase 1.5: Show category level multiplier if > 1
	var category_level = breakdown_info.get("category_level", 1)
	if category_level > 1:
		var level_delay = 0.05 / speed_scale
		await get_tree().create_timer(level_delay).timeout
		_animate_category_level_multiplier(breakdown_info, intensity_scale, speed_scale)
	
	# Phase 2: Play scoring sound with dynamic pitch
	#_play_scoring_audio(score)
	
	# Phase 2.5: Check for and animate negative contributions (debuffs)
	await _animate_negative_sources(breakdown_info, intensity_scale, speed_scale)
	
	# Phase 3: Wait a bit, then animate contributing consumables and update additive panel
	var consumable_delay = 0.05 / speed_scale  # Reduced from 0.3
	print("[ScoringAnimationController] Waiting %f seconds before consumables..." % consumable_delay)
	await get_tree().create_timer(consumable_delay).timeout
	if breakdown_info.has("active_consumables") and breakdown_info.active_consumables.size() > 0:
		print("[ScoringAnimationController] Starting consumable animations...")
		await _animate_contributing_consumables(breakdown_info, intensity_scale, speed_scale)
	else:
		print("[ScoringAnimationController] No consumables to animate")
		# Still update the panel to show 0 if no consumables (with animation)
		if score_card_ui:
			score_card_ui.update_additive_score_panel(0, true)
	
	# Phase 4: Wait a bit, then animate contributing powerups and update multiplier panel
	var powerup_delay = 0.05 / speed_scale  # Reduced from 0.5
	print("[ScoringAnimationController] Waiting %f seconds before powerups..." % powerup_delay)
	await get_tree().create_timer(powerup_delay).timeout
	if breakdown_info.has("active_powerups") and breakdown_info.active_powerups.size() > 0:
		print("[ScoringAnimationController] Starting powerup animations...")
		await _animate_contributing_powerups(breakdown_info, intensity_scale, speed_scale)
	else:
		print("[ScoringAnimationController] No powerups to animate")
		# Still update the panel to show 1.0 if no powerups (with animation to show multiplication step)
		if score_card_ui:
			score_card_ui.update_multiplier_score_panel(1.0, true)
	
	# Phase 5: Show final score floating number
	var final_delay = 0.05 / speed_scale
	await get_tree().create_timer(final_delay).timeout
	_show_final_score_number(score, intensity_scale)
	
	# Phase 6: Animate total score bounce
	if score_card_ui:
		score_card_ui.animate_total_score_bounce(score)
	
	# Wait for all animations to complete
	await get_tree().create_timer(1.0 / speed_scale).timeout


## _animate_negative_sources(breakdown_info, intensity_scale, speed_scale)
##
## Checks breakdown_info for negative values and animates them with debuff effects.
func _animate_negative_sources(breakdown_info: Dictionary, intensity_scale: float, speed_scale: float) -> void:
	var additive_sources = breakdown_info.get("additive_sources", [])
	var multiplier_sources = breakdown_info.get("multiplier_sources", [])
	
	# Check for negative additive values (debuff penalties)
	for source_info in additive_sources:
		var value = source_info.get("value", 0)
		if value < 0:
			var source_name = source_info.get("name", "Penalty")
			print("[ScoringAnimationController] Found negative source: %s with %d" % [source_name, value])
			animate_debuff_source(source_name, abs(value), intensity_scale, speed_scale)
			await get_tree().create_timer(0.2 / speed_scale).timeout
	
	# Check for divisor multipliers (values less than 1 that reduce score)
	for source_info in multiplier_sources:
		var value = source_info.get("value", 1.0)
		if value < 1.0 and value > 0:
			var source_name = source_info.get("name", "Division")
			# This is a divisor, show as negative effect
			var penalty_display = int((1.0 - value) * 100)  # e.g., 0.5 = 50% reduction
			print("[ScoringAnimationController] Found divisor: %s with x%.2f (-%d%%)" % [source_name, value, penalty_display])
			# Use a smaller intensity for divisors
			animate_negative_contribution(-penalty_display, Vector2(100, 200), source_name)
			await get_tree().create_timer(0.2 / speed_scale).timeout


## _animate_dice_bounce_with_scores(intensity_scale, speed_scale)
##
## Animate dice with bounce effect and show individual dice values as floating numbers.
func _animate_dice_bounce_with_scores(intensity_scale: float, speed_scale: float = 1.0) -> void:
	if not dice_hand:
		print("[ScoringAnimationController] No dice hand found for animation")
		return
	
	var dice_array = dice_hand.get_all_dice()
	#print("[ScoringAnimationController] Animating %d dice" % dice_array.size())
	
	var stagger_delay = 0.15 / speed_scale  # Faster stagger for high scores
	var base_delay = 0.1 / speed_scale      # Small base delay to ensure setup is complete
	
	for i in range(dice_array.size()):
		var die = dice_array[i]
		if not die:
			continue
		
		var delay = base_delay + (i * stagger_delay)
		
		# Schedule dice animation
		get_tree().create_timer(delay).timeout.connect(_animate_single_die.bind(die, i, intensity_scale, speed_scale))

	# Return after all dice have been scheduled (wait for the last one to start)
	var total_duration = base_delay + (dice_array.size() * stagger_delay) + (0.6 / speed_scale)
	await get_tree().create_timer(total_duration).timeout

## _animate_single_die(die, die_index, intensity_scale, speed_scale)
##
## Animate a single die with bounce and floating value, only if it contributes to the score.
func _animate_single_die(die, die_index: int, intensity_scale: float, speed_scale: float = 1.0) -> void:
	# Check if animations were cancelled (e.g., dice cleared for next round)
	if animations_cancelled:
		return
	
	# Validate die is still valid (may be freed if callback is delayed)
	if not die or not is_instance_valid(die):
		return
	
	# Check if this die contributes to the score
	var used_dice_indices = current_breakdown_info.get("used_dice_indices", [])
	
	# Only animate dice that actually contribute to the score
	if not die_index in used_dice_indices:
		print("[ScoringAnimationController] Skipping die %d - not used in scoring" % die_index)
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
	var die_center = die.global_position + Vector2(die_size.x -60, 0)  # Above and center
	
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
		# Use bind() instead of lambda to avoid freed capture issues
		# The method will validate the die before using it
		bounce_tween.tween_method(_bounce_die_local.bind(die, original_local_position, bounce_height), 0.0, 1.0, bounce_duration)
	
	# Show floating dice value (always white now)
	var dice_color = Color.WHITE
	
	# Create floating number with speed-adjusted duration and speed
	var floating_number = FloatingNumberScript.create_floating_number(get_tree().current_scene, die_center, 
		"+" +str(die.value), 1.0, dice_color)
	if floating_number:
		floating_number.float_duration = floating_number.float_duration / speed_scale
		floating_number.float_speed = FLOAT_NUMBER_SPEED * speed_scale  # Make it faster for higher scores
	
	# Add separate floating number for colored dice effects
	if die.color != DiceColor.Type.NONE:
		_show_colored_dice_effect(die, die_center, speed_scale)

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

## _bounce_die_local(progress, die, original_local_position, bounce_height)
##
## Animate individual die bounce using local position to avoid screen shake interference.
## Uses local position which is unaffected by camera shake.
## Note: progress comes first because tween_method passes it, then bound args follow.
func _bounce_die_local(progress: float, die, original_local_position: Vector2, bounce_height: float) -> void:
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
## Updates the additive panel incrementally as each consumable animates.
func _animate_contributing_consumables(breakdown_info: Dictionary, intensity_scale: float, speed_scale: float) -> void:
	if not consumable_ui:
		print("[ScoringAnimationController] No ConsumableUI found")
		return
	
	var active_consumables = breakdown_info.get("active_consumables", [])
	print("[ScoringAnimationController] Active consumables: %s" % str(active_consumables))
	
	# Check additive sources for consumable contributions
	var additive_sources = breakdown_info.get("additive_sources", [])
	var stagger_delay = 0.15 / speed_scale
	var running_additive = 0
	
	for source_info in additive_sources:
		var source_name = source_info.get("name", "")
		var source_value = source_info.get("value", 0)
		
		# Check if this is a consumable source
		if source_info.get("category", "") == "consumable" or source_name in active_consumables:
			# Animate the consumable
			_animate_consumable_contribution(source_name, source_value, intensity_scale, speed_scale)
			
			# Update running total and panel
			running_additive += source_value
			if score_card_ui:
				score_card_ui.update_additive_score_panel(running_additive, true)
			
			# Wait for stagger delay
			await get_tree().create_timer(stagger_delay).timeout

## _animate_contributing_powerups(breakdown_info, intensity_scale, speed_scale)
##
## Animate only powerups that actually contributed to the score.
## Updates the multiplier panel incrementally as each powerup animates.
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
	var stagger_delay = 0.15 / speed_scale
	var animated_any_powerups = false
	var running_additive = breakdown_info.get("regular_additive", 0) - breakdown_info.get("dice_color_additive", 0)
	var running_multiplier = 1.0
	
	# Animate additive powerups
	for source_info in additive_sources:
		var source_name = source_info.get("name", "")
		var source_value = source_info.get("value", 0)
		
		if source_info.get("category", "") == "powerup" or source_name in active_powerups:
			# Animate the powerup
			_animate_powerup_additive(source_name, source_value, intensity_scale, speed_scale)
			
			# Update running additive (already includes consumables from previous phase)
			running_additive += source_value
			if score_card_ui:
				# Get the total from consumables and add powerup contribution
				var total_with_consumables = breakdown_info.get("total_additive", 0) - breakdown_info.get("regular_additive", 0)
				score_card_ui.update_additive_score_panel(total_with_consumables + running_additive, true)
			
			await get_tree().create_timer(stagger_delay).timeout
			animated_any_powerups = true
	
	# Animate multiplier powerups
	for source_info in multiplier_sources:
		var source_name = source_info.get("name", "")
		var source_value = source_info.get("value", 1.0)
		
		if source_info.get("category", "") == "powerup" or source_name in active_powerups:
			# Animate the powerup
			_animate_powerup_multiplier(source_name, source_value, intensity_scale, speed_scale)
			
			# Update running multiplier
			running_multiplier *= source_value
			var blue_multiplier = breakdown_info.get("blue_score_multiplier", 1.0)
			var combined = running_multiplier * blue_multiplier
			if score_card_ui:
				score_card_ui.update_multiplier_score_panel(combined, true)
			
			await get_tree().create_timer(stagger_delay).timeout
			animated_any_powerups = true
	
	# Fallback: If no powerups were animated from sources but we have active powerups,
	# animate them with a generic bounce effect (for manual scoring)
	# BUT only if they should actually be active for this scoring context
	if not animated_any_powerups and active_powerups.size() > 0:
		print("[ScoringAnimationController] No source breakdown, checking active powerups for context-specific animation")
		for powerup_id in active_powerups:
			# Check if this powerup should be animated for this scoring context
			if _should_animate_powerup_for_context(powerup_id, breakdown_info):
				_animate_powerup_generic(powerup_id, intensity_scale, speed_scale)
				await get_tree().create_timer(stagger_delay).timeout
			else:
				print("[ScoringAnimationController] Skipping powerup %s - not applicable for this scoring context" % powerup_id)

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
	var floating_number = FloatingNumberScript.create_floating_number(get_tree().current_scene, spine_center, 
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
	var floating_number = FloatingNumberScript.create_floating_number(get_tree().current_scene, spine_center, 
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
	var floating_number = FloatingNumberScript.create_floating_number(get_tree().current_scene, spine_center, 
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
	var floating_number = FloatingNumberScript.create_floating_number(get_tree().current_scene, spine_center, 
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
		
		# Schedule this powerup animation using Callable.bind to avoid freed capture issues
		get_tree().create_timer(delay).timeout.connect(
			_animate_single_powerup.bind(powerup_id, multiplier, intensity_scale)
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
	FloatingNumberScript.create_floating_number(get_tree().current_scene, spine_center, 
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
	FloatingNumberScript.create_floating_number(get_tree().current_scene, screen_center, 
		str(score), 2.0 * _intensity_scale, Color.GOLD)
	
	print("[ScoringAnimationController] Showing final score: %d" % score)

## _animate_category_level_multiplier(breakdown_info, intensity_scale, speed_scale)
##
## Animate the category level multiplier as a floating "×N" text.
## Shows above the dice area after dice animations complete.
func _animate_category_level_multiplier(breakdown_info: Dictionary, intensity_scale: float, speed_scale: float) -> void:
	var category_level = breakdown_info.get("category_level", 1)
	if category_level <= 1:
		return  # No animation needed for level 1
	
	var base_score = breakdown_info.get("base_score", 0)
	var score_after_level = breakdown_info.get("score_after_level", base_score)
	
	print("[ScoringAnimationController] Animating category level multiplier: ×%d (base %d → %d)" % [category_level, base_score, score_after_level])
	
	# Position above the dice area - centered horizontally
	var screen_size = get_viewport().get_visible_rect().size
	var level_position = Vector2(screen_size.x / 2, screen_size.y * 0.35)  # Upper third of screen
	
	# Create the level multiplier text with gold color
	var level_text = "×%d" % category_level
	var floating_number = FloatingNumberScript.create_floating_number(
		get_tree().current_scene,
		level_position,
		level_text,
		1.8 * intensity_scale,
		Color(1.0, 0.84, 0.0)  # Gold color
	)
	
	if floating_number:
		floating_number.float_duration = floating_number.float_duration / speed_scale
		floating_number.float_speed = FLOAT_NUMBER_SPEED * speed_scale * 0.8  # Slightly slower float

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

## _show_colored_dice_effect(die, die_center, speed_scale)
##
## Show additional floating effect for colored dice based on their color type.
func _show_colored_dice_effect(die: Dice, die_center: Vector2, speed_scale: float) -> void:
	var effect_text = ""
	var effect_color = Color.WHITE
	
	# Determine effect text and color based on die color
	match die.color:
		DiceColor.Type.GREEN:
			effect_text = "$" + str(die.value)  # Green dice give money
			effect_color = Color.GREEN
		DiceColor.Type.RED:
			effect_text = "+" + str(die.value)  # Red dice give additive bonus
			effect_color = Color.RED
		DiceColor.Type.PURPLE:
			effect_text = "x" + str(die.value)  # Purple dice give multiplier
			effect_color = Color.MAGENTA
		DiceColor.Type.BLUE:
			effect_text = "x" + str(die.value)  # Blue dice give multiplier (could also be "/" for division)
			effect_color = Color.CYAN
		_:
			return  # No effect for NONE color
	
	# Create floating number offset slightly to the right of the main number
	var offset_position = die_center + Vector2(30, 0)
	var floating_number = FloatingNumberScript.create_floating_number(get_tree().current_scene, offset_position, 
		effect_text, 0.8, effect_color)  # Slightly smaller scale
	if floating_number:
		floating_number.float_duration = floating_number.float_duration / speed_scale
		floating_number.float_speed = FLOAT_NUMBER_SPEED * speed_scale

## _should_animate_powerup_for_context(powerup_id, breakdown_info)
##
## Check if a powerup should be animated based on the scoring context.
## Some powerups only apply to certain sections (upper vs lower).
func _should_animate_powerup_for_context(powerup_id: String, breakdown_info: Dictionary) -> bool:
	# For step_by_step powerup, it only applies to upper section scores
	if powerup_id == "step_by_step":
		# Check if any of the used dice indices correspond to upper section scoring
		# For now, we'll use a simple heuristic: if the dice values include low numbers (1-6),
		# it's likely an upper section score. This could be made more sophisticated.
		var dice_values = breakdown_info.get("dice_values", [])
		var used_dice_indices = breakdown_info.get("used_dice_indices", [])
		
		# If we have dice information, check if it looks like upper section scoring
		if dice_values.size() > 0 and used_dice_indices.size() > 0:
			# Check if the used dice are all the same value (typical for upper section)
			var first_used_value = dice_values[used_dice_indices[0]]
			var all_same = true
			for index in used_dice_indices:
				if dice_values[index] != first_used_value:
					all_same = false
					break
			
			# If all used dice have the same value and it's 1-6, it's likely upper section
			if all_same and first_used_value >= 1 and first_used_value <= 6:
				return true
			else:
				return false
		else:
			# If no dice info, assume it should be animated (fallback)
			return true
	
	# For other powerups, always animate for now
	# TODO: Add specific logic for other powerups as needed
	return true


#region Negative/Debuff Animations

## animate_negative_contribution(value, source_position, source_name)
##
## Animates a negative score contribution from debuffs with dramatic visual effects.
## Scales intensity based on the penalty magnitude.
##
## Parameters:
##   value: int - the negative value (should be negative)
##   source_position: Vector2 - position to show floating number
##   source_name: String - name of the debuff for logging
func animate_negative_contribution(value: int, source_position: Vector2, source_name: String = "Debuff") -> void:
	var penalty = abs(value)
	var intensity = clampf(float(penalty) / 5.0, 0.5, 3.0)
	
	print("[ScoringAnimationController] Animating negative contribution: -%d from %s (intensity: %.1f)" % [penalty, source_name, intensity])
	
	# Create red floating number with shake effect
	_create_negative_floating_number(source_position, value, intensity)
	
	# Trigger screen effects based on penalty severity
	if penalty > 10:
		_trigger_red_vignette_pulse(intensity)
	if penalty > 20:
		_trigger_camera_shake(intensity)


## _create_negative_floating_number(position, value, intensity)
##
## Creates a floating number for negative values with shake animation.
func _create_negative_floating_number(position: Vector2, value: int, intensity: float) -> void:
	var text = str(value)  # Value should already be negative
	var scale_factor = 1.2 + (intensity * 0.3)
	
	var floating_number = FloatingNumberScript.create_floating_number(
		get_tree().current_scene,
		position,
		text,
		scale_factor,
		Color.RED
	)
	
	if floating_number:
		floating_number.float_duration = 2.0
		floating_number.float_speed = FLOAT_NUMBER_SPEED * 0.8
		
		# Add shake effect to the floating number
		_apply_shake_to_node(floating_number, intensity)


## _apply_shake_to_node(node, intensity)
##
## Applies a horizontal shake effect to a node.
func _apply_shake_to_node(node: Node, intensity: float) -> void:
	if not node or not is_instance_valid(node):
		return
	
	var shake_amount = 5.0 * intensity
	var shake_duration = 0.5
	var original_x = node.position.x if node is Control else 0.0
	
	var tween = create_tween()
	tween.set_loops(5)
	
	tween.tween_property(node, "position:x", original_x + shake_amount, shake_duration / 10.0)
	tween.tween_property(node, "position:x", original_x - shake_amount, shake_duration / 10.0)


## _trigger_red_vignette_pulse(intensity)
##
## Creates a brief red vignette flash effect on screen.
func _trigger_red_vignette_pulse(intensity: float) -> void:
	var vignette = ColorRect.new()
	vignette.name = "RedVignette"
	vignette.color = Color(0.8, 0.1, 0.1, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = 100
	
	# Cover full viewport
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	get_tree().current_scene.add_child(vignette)
	
	# Calculate alpha based on intensity
	var max_alpha = clampf(0.15 + (intensity * 0.1), 0.15, 0.4)
	
	# Pulse in and out
	var tween = create_tween()
	tween.tween_property(vignette, "color:a", max_alpha, 0.1)
	tween.tween_property(vignette, "color:a", 0.0, 0.3)
	tween.tween_callback(vignette.queue_free)


## _trigger_camera_shake(intensity)
##
## Shakes the camera/viewport for dramatic effect.
func _trigger_camera_shake(intensity: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		# Try to find any Camera2D in the scene
		var cameras = get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			camera = cameras[0]
	
	if not camera:
		# Fallback: shake the root node if no camera
		_shake_node(get_tree().current_scene, intensity)
		return
	
	var shake_amount = 8.0 * intensity
	var shake_duration = 0.4
	var original_offset = camera.offset
	
	var tween = create_tween()
	
	# Rapid back-and-forth shake
	for i in range(6):
		var random_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		tween.tween_property(camera, "offset", original_offset + random_offset, shake_duration / 12.0)
	
	# Return to original
	tween.tween_property(camera, "offset", original_offset, shake_duration / 6.0)


## _shake_node(node, intensity)
##
## Shakes a node's position as fallback when no camera is available.
func _shake_node(node: Node, intensity: float) -> void:
	if not node is Node2D and not node is Control:
		return
	
	var shake_amount = 5.0 * intensity
	var shake_duration = 0.3
	var original_position = node.position
	
	var tween = create_tween()
	
	for i in range(4):
		var random_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		tween.tween_property(node, "position", original_position + random_offset, shake_duration / 8.0)
	
	tween.tween_property(node, "position", original_position, shake_duration / 4.0)


## animate_debuff_source(debuff_id, penalty_value, intensity_scale, speed_scale)
##
## Animate a debuff's contribution to scoring with negative effects.
## intensity_scale and speed_scale reserved for future fine-tuning of animations.
func animate_debuff_source(debuff_id: String, penalty_value: int, _intensity_scale: float, _speed_scale: float) -> void:
	print("[ScoringAnimationController] Animating debuff: %s with penalty: %d" % [debuff_id, penalty_value])
	
	# Try to find the debuff in the CorkboardUI or DebuffUI
	var corkboard_nodes = get_tree().get_nodes_in_group("corkboard_ui")
	var source_position = Vector2(100, 200)  # Default position
	
	if corkboard_nodes.size() > 0:
		var corkboard = corkboard_nodes[0]
		# Use debuff spine position if available
		if corkboard.has_method("get_debuff_spine_position"):
			source_position = corkboard.get_debuff_spine_position()
		else:
			source_position = corkboard.global_position + Vector2(20, 150)
	
	# Animate the negative contribution
	animate_negative_contribution(-penalty_value, source_position, debuff_id)

#endregion
