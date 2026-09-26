extends Node
class_name ScoringAnimationController

## ScoringAnimationController
##
## Handles all scoring animations: dice bounces, sink-bound spiral numbers,
## consumable/powerup sequences, and dynamic audio feedback.
## Numbers spawn at their source (die / consumable spine / powerup spine)
## and spiral into a central ScoreSink at screen center; the sink shows the
## running score, wobbles on each arrival, blows up on the final score,
## then drains into the score labels and hides.
## Scales animation intensity based on final score magnitude.

signal animation_sequence_complete

# Dice/spine bounce configuration
const DICE_BOUNCE_HEIGHT: float = 15.0
const COLORED_DICE_EXTRA_BOUNCE: float = 10.0
const CONSUMABLE_BOUNCE_HEIGHT: float = 12.0

# Score-based scaling thresholds
const SMALL_SCORE_THRESHOLD: int = 15
const MEDIUM_SCORE_THRESHOLD: int = 30
const LARGE_SCORE_THRESHOLD: int = 50

# Audio configuration (local fallback when AudioManager is unavailable)
const BASE_PITCH: float = 1.0
const MAX_PITCH: float = 2.0
const PITCH_SCALE_FACTOR: float = 0.02

# Sound effect resource (local fallback)
@export var scoring_sound: AudioStream

# --- Score-sink sequence configuration ---
# Spiral path (polar interpolation around the sink; see _update_spark_flight)
const SPIRAL_TURNS: float = 0.75
const SPIRAL_TURN_REF_DIST: float = 400.0
const SPIRAL_TURN_MIN_FACTOR: float = 0.35
const SPIRAL_ANGLE_EXP: float = 1.6
const SPIRAL_SHRINK_TO: float = 0.6
const SPIRAL_FADE_PORTION: float = 0.2
# Spiral flight durations per phase (divided by speed_scale)
const SPIRAL_T_DICE: float = 0.55
const SPIRAL_T_ADD: float = 0.50
const SPIRAL_T_MULT: float = 0.55
# Phase pacing (divided by speed_scale; staggers have a floor)
const DICE_STAGGER: float = 0.15
const ADD_STAGGER: float = 0.20
const MULT_STAGGER: float = 0.25
const STAGGER_FLOOR: float = 0.05
const BASE_DELAY: float = 0.10
const BASE_BEAT: float = 0.25
const FINAL_SETTLE_T: float = 0.30
const DICE_PHASE_MARGIN: float = 0.10
# Wobble intensities per arrival kind
const WOBBLE_DICE: float = 0.5
const WOBBLE_ADDITIVE: float = 1.0
const MULT_WOBBLE_RAMP: Array[float] = [1.0, 1.3, 1.6, 2.0]
const MULT_WOBBLE_STEP_BEYOND: float = 0.4
const WOBBLE_MAX: float = 3.0
# Drain phase
const COUNT_UP_T: float = 0.60
const DRAIN_FALLBACK_Y: float = 60.0
# Blow-up screen shake intensity
const BLOWUP_SHAKE_INTENSITY: float = 2.0
# Generic floating-number utility (non-scoring callers)
const FLOAT_NUMBER_SPEED: float = 200.0
const FLOAT_NUMBER_DURATION: float = 1.5

const SCORING_PANEL_FILL: Color = Color(0.247059, 0.219608, 0.345098, 0.92)
const SCORING_PANEL_SHADOW: Color = Color(0.070588, 0.062745, 0.101961, 0.45)
const SCORING_TEXT_LIGHT: Color = Color(0.968627, 0.941176, 1.0, 1.0)
const SCORING_TEXT_POSITIVE: Color = Color(0.65098, 0.941176, 0.745098, 1.0)
const SCORING_TEXT_ADDITIVE: Color = Color(1.0, 0.854902, 0.631373, 1.0)
const SCORING_TEXT_MULTIPLIER: Color = Color(0.47451, 0.886275, 0.890196, 1.0)
const SCORING_TEXT_NEGATIVE: Color = Color(1.0, 0.470588, 0.576471, 1.0)
const SCORING_ACCENT_MAGENTA: Color = Color(0.713725, 0.301961, 0.478431, 1.0)
const SCORING_ACCENT_TEAL: Color = Color(0.137255, 0.411765, 0.415686, 1.0)

# Import the FloatingNumber class (generic utility + standalone fallbacks)
const FloatingNumberScript = preload("res://Scripts/Effects/floating_number.gd")

# Node references (duck-typed: real game classes in-game, mocks in tests)
var dice_hand
var game_controller: GameController
var consumable_ui
var power_up_ui
var audio_player: AudioStreamPlayer
var score_card_ui: ScoreCardUI
var score_sink: ScoreSink

# Animation state
var current_animation_sequence: Tween
var animation_in_progress: bool = false
var current_breakdown_info: Dictionary = {}
var animations_cancelled: bool = false

# Sink-sequence state
var _running_score: int = 0
var _sequence_token: int = 0
var _active_sparks: Array = []
var _spark_tweens: Array = []

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
## References are duck-typed so test scenes can register lightweight mocks
## in the same groups.
func _find_required_nodes() -> void:
	# Find DiceHand
	var dice_hand_nodes = get_tree().get_nodes_in_group("dice_hand")
	if dice_hand_nodes.size() > 0:
		dice_hand = dice_hand_nodes[0]
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
		consumable_ui = consumable_ui_nodes[0]
		print("[ScoringAnimationController] Found ConsumableUI")
	else:
		print("[ScoringAnimationController] ConsumableUI not found")

	# Find PowerUpUI
	var power_up_ui_nodes = get_tree().get_nodes_in_group("power_up_ui")
	if power_up_ui_nodes.size() > 0:
		power_up_ui = power_up_ui_nodes[0]
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

## cancel_all_animations(immediate_reveal)
##
## Cancel all pending animations by setting a flag that callbacks check.
## Call this when dice are being cleared to prevent accessing freed objects.
## Also frees in-flight sparks and resets the sink to hidden.
## immediate_reveal=false keeps the scorecard concealed (used by the
## mid-animation restart path — the new event reveals at its own dump).
func cancel_all_animations(immediate_reveal: bool = true) -> void:
	print("[ScoringAnimationController] Cancelling all animations")

	# Set flag to abort any pending timer callbacks
	animations_cancelled = true

	# Stop any existing tween
	if current_animation_sequence and current_animation_sequence.is_valid():
		current_animation_sequence.kill()
		current_animation_sequence = null

	_cleanup_sparks()
	if score_sink and is_instance_valid(score_sink):
		score_sink.reset_sink()

	if immediate_reveal:
		_reveal_concealed_scores_immediately()

	# Reset animation state
	animation_in_progress = false
	current_breakdown_info.clear()

## _conceal_score_targets()
##
## Hold score displays at their pre-event values for the whole sequence.
## ScoreCardUI self-conceals on the model signal; the force call is a
## no-op then. Group members cover test-scene mock labels.
func _conceal_score_targets() -> void:
	if score_card_ui and is_instance_valid(score_card_ui) and score_card_ui.has_method("begin_scoring_concealment"):
		score_card_ui.begin_scoring_concealment(true)
	for node in get_tree().get_nodes_in_group("score_sink_drain_target"):
		if node.has_method("begin_scoring_concealment"):
			node.begin_scoring_concealment()

## _reveal_concealed_scores_immediately()
##
## Cancel-path safety net: if the sequence dies before the drain, the
## committed score must not stay hidden. Reveals without the count-up.
func _reveal_concealed_scores_immediately() -> void:
	if score_card_ui and is_instance_valid(score_card_ui) and score_card_ui.has_method("is_scoring_concealed"):
		if score_card_ui.is_scoring_concealed():
			score_card_ui.reveal_scoring_scores()
	for node in get_tree().get_nodes_in_group("score_sink_drain_target"):
		if node.has_method("is_scoring_concealed") and node.is_scoring_concealed():
			node.reveal_scoring_scores()

## start_scoring_animation(score, category, breakdown_info)
##
## Entry point for the scoring sequence. A new scoring event fired while a
## sequence is running cancels the old one and restarts cleanly: the sink
## resets to hidden and the new sequence starts fresh.
func start_scoring_animation(score: int, category: String, breakdown_info: Dictionary = {}) -> void:
	if animation_in_progress:
		print("[ScoringAnimationController] Scoring event mid-animation — restarting sequence")
		# Stay concealed: the interrupted event's reveal is cancelled; the new
		# event reveals at its own dump.
		cancel_all_animations(false)

	animation_in_progress = true
	animations_cancelled = false  # Reset cancellation flag for new animation
	_sequence_token += 1
	current_breakdown_info = breakdown_info  # Store for use in animation functions
	print("[ScoringAnimationController] Starting scoring animation for score: %d, category: %s" % [score, category])
	print("[ScoringAnimationController] Breakdown info: %s" % str(breakdown_info))

	# Prepare ScoreCardUI for animation (no-op shim on the new scorecard, kept as a hook)
	if score_card_ui:
		score_card_ui.prepare_for_scoring_animation()

	# Hold the scorecard at its pre-event values for the whole sequence;
	# the drain phase reveals them. ScoreCardUI normally conceals itself on
	# the model's score_assigned signal — this force call covers test rigs.
	_conceal_score_targets()

	# Calculate animation intensity and speed based on score
	var intensity_scale = _calculate_intensity_scale(score)
	var speed_scale = _calculate_speed_scale(score)

	# Start animation sequence
	await _execute_animation_sequence(score, category, breakdown_info, intensity_scale, speed_scale, _sequence_token)

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
## Calculate animation speed multiplier based on score magnitude and user settings.
## Higher scores = faster animations for more excitement.
## User setting from GameSettings.scoring_animation_speed further scales the result.
func _calculate_speed_scale(score: int) -> float:
	var base_speed: float
	if score < SMALL_SCORE_THRESHOLD:
		base_speed = 1.0  # Normal speed
	elif score < MEDIUM_SCORE_THRESHOLD:
		base_speed = 1.2  # 20% faster
	elif score < LARGE_SCORE_THRESHOLD:
		base_speed = 1.4  # 40% faster
	else:
		base_speed = 1.6  # 60% faster

	# Apply user's animation speed setting from GameSettings
	# scoring_animation_speed: 0.5 = slower, 1.0 = normal, 2.0 = faster
	var user_speed_scale = 1.0
	var game_settings = get_node_or_null("/root/GameSettings")
	if game_settings:
		user_speed_scale = game_settings.scoring_animation_speed

	return base_speed * user_speed_scale

## _is_aborted(token)
##
## True when the running sequence was cancelled or superseded by a newer one.
func _is_aborted(token: int) -> bool:
	return animations_cancelled or token != _sequence_token

## _wait_seconds(seconds, speed_scale)
##
## Speed-scaled wait. All sequence pacing divides by speed_scale.
func _wait_seconds(seconds: float, speed_scale: float) -> void:
	await get_tree().create_timer(seconds / speed_scale).timeout

## _stagger(base, speed_scale)
##
## Speed-scaled stagger with a floor so arrivals never land on the same frame.
func _stagger(base: float, speed_scale: float) -> float:
	return maxf(base / speed_scale, STAGGER_FLOOR)

## _execute_animation_sequence(score, category, breakdown_info, intensity_scale, speed_scale, token)
##
## Execute the complete sink sequence in strict phase order:
## dice -> base beat -> category level -> additives -> multipliers ->
## blow-up -> drain into score labels.
func _execute_animation_sequence(score: int, category: String, breakdown_info: Dictionary, intensity_scale: float, speed_scale: float, token: int) -> void:
	# Reset scoring sequence for progressive pitch
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.reset_scoring_sequence()

	_ensure_sink()
	if score_sink:
		score_sink.reset_sink()
		score_sink.show_sink()
	_running_score = 0

	# Phase 1: dice bounce + per-die value sparks spiral into the sink
	await _phase_dice(intensity_scale, speed_scale, token)
	if _is_aborted(token):
		return

	# Phase 2: base established — sink shows the dice-only subtotal, then rests
	var dice_subtotal = int(breakdown_info.get("base_score", -1))
	if dice_subtotal < 0:
		dice_subtotal = _dice_subtotal_fallback(breakdown_info)
	_running_score = dice_subtotal
	if score_sink:
		score_sink.set_running_score(_running_score, true)
	await _wait_seconds(BASE_BEAT, speed_scale)
	if _is_aborted(token):
		return

	# Phase 2.5: category-level factor (multiplicative, shown before additives
	# as in the previous controller)
	var category_level_factor = float(breakdown_info.get("effective_category_level_factor", breakdown_info.get("category_level", 1)))
	if not is_equal_approx(category_level_factor, 1.0):
		await _animate_category_level_factor(breakdown_info, speed_scale, token)
		if _is_aborted(token):
			return

	# Phase 3: additives — consumables first, then powerups (negatives included)
	await _phase_additives(breakdown_info, intensity_scale, speed_scale, token)
	if _is_aborted(token):
		return

	# Phase 4: multipliers — scorecard, colored dice, consumables, powerups
	await _phase_multipliers(breakdown_info, speed_scale, token)
	if _is_aborted(token):
		return

	# Phase 5: final blow-up — reconcile to the authoritative score
	_phase_blowup(score, category, intensity_scale)
	if score_sink:
		await _wait_seconds(score_sink.get_blowup_duration(), speed_scale)
	if _is_aborted(token):
		return

	# Phase 6: drain into the score labels, then hide completely
	await _phase_drain(score, category, speed_scale)
	if _is_aborted(token):
		return

	await _wait_seconds(FINAL_SETTLE_T, speed_scale)

## _phase_dice(intensity_scale, speed_scale, token)
##
## Each used die bounces and launches its value as a spark that spirals
## into the sink. Arrivals tick the running score (WOBBLE_DICE) and play
## the pitch-stepped scoring sound in arrival order.
func _phase_dice(intensity_scale: float, speed_scale: float, token: int) -> void:
	if not dice_hand:
		print("[ScoringAnimationController] No dice hand found for animation")
		return

	var dice_array = _get_dice_array()
	if dice_array.is_empty():
		return

	var stagger = _stagger(DICE_STAGGER, speed_scale)
	var base_delay = BASE_DELAY / speed_scale

	for i in range(dice_array.size()):
		var die = dice_array[i]
		if die == null:
			continue
		var delay = base_delay + (i * stagger)
		get_tree().create_timer(delay).timeout.connect(_animate_single_die.bind(die, i, intensity_scale, speed_scale, token))

	# Wait until the last die's spark has had time to arrive
	var total_duration = base_delay + (dice_array.size() * stagger) + (SPIRAL_T_DICE / speed_scale) + DICE_PHASE_MARGIN
	await get_tree().create_timer(total_duration).timeout

## _animate_single_die(die, die_index, intensity_scale, speed_scale, token)
##
## Bounce a single contributing die and launch its value spark.
func _animate_single_die(die, die_index: int, intensity_scale: float, speed_scale: float, token: int) -> void:
	# Check if animations were cancelled or superseded
	if _is_aborted(token):
		return

	# Validate die is still valid (may be freed if callback is delayed)
	if not die or not is_instance_valid(die):
		return

	# Check if this die contributes to the score
	var used_dice_indices = current_breakdown_info.get("used_dice_indices", [])
	if not die_index in used_dice_indices:
		print("[ScoringAnimationController] Skipping die %d - not used in scoring" % die_index)
		return

	# Juice: spotlight glow on used dice
	var tfx = get_node_or_null("/root/TweenFXHelper")
	if tfx and die:
		tfx.spotlight_enter(die, Color(1.5, 1.5, 1.2, 1.0))
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(die):
				tfx.spotlight_exit(die)
		)

	var die_value = int(die.value)
	print("[ScoringAnimationController] Animating die with value: %d" % die_value)

	# Calculate bounce height
	var bounce_height = DICE_BOUNCE_HEIGHT * intensity_scale

	# Extra bounce for colored dice
	if die.color != DiceColor.Type.NONE:
		bounce_height += COLORED_DICE_EXTRA_BOUNCE * intensity_scale
		print("[ScoringAnimationController] Colored die detected, extra bounce!")

	# Get die center position for the spark origin
	var die_size = Vector2(60, 60)  # Standard dice size
	if die.sprite and die.sprite.texture:
		var texture_size = die.sprite.texture.get_size()
		die_size = texture_size * die.sprite.scale
	var die_center = die.global_position + Vector2(die_size.x - 60, 0)

	if not die or not is_instance_valid(die):
		return

	# Store original LOCAL position to avoid screen shake interference
	var original_local_position = die.position
	var bounce_duration = 0.6 / speed_scale

	if is_instance_valid(die):
		var bounce_tween = create_tween()
		bounce_tween.tween_method(_bounce_die_local.bind(die, original_local_position, bounce_height), 0.0, 1.0, bounce_duration)

	# Launch the die's value spark into the sink
	_launch_spark("+" + str(die_value), die_center, 1.0, SCORING_TEXT_LIGHT, SCORING_ACCENT_MAGENTA,
		SPIRAL_T_DICE / speed_scale,
		func():
			_running_score += die_value
			if score_sink and is_instance_valid(score_sink):
				score_sink.set_running_score(_running_score, true)
				score_sink.bounce_wobble(WOBBLE_DICE)
			_play_scoring_audio(die_value)
	)

	# Colored dice get a second effect spark (does not change the score here)
	if die.color != DiceColor.Type.NONE:
		_show_colored_dice_effect(die, die_center, speed_scale, die_index)

## _phase_additives(breakdown_info, intensity_scale, speed_scale, token)
##
## Consumable additives first, then powerup additives. Each "+X" spirals in
## from its spine; arrival grows the running score with WOBBLE_ADDITIVE.
## Negative sources arrive as red sparks that shrink the score.
func _phase_additives(breakdown_info: Dictionary, intensity_scale: float, speed_scale: float, token: int) -> void:
	var additive_sources = breakdown_info.get("additive_sources", [])
	if additive_sources.is_empty():
		return

	var active_consumables = breakdown_info.get("active_consumables", [])
	var active_powerups = breakdown_info.get("active_powerups", [])

	var consumable_adds: Array = []
	var powerup_adds: Array = []
	for source_info in additive_sources:
		var source_name = source_info.get("name", "")
		var category = source_info.get("category", "")
		if category == "consumable" or source_name in active_consumables:
			consumable_adds.append(source_info)
		elif category == "powerup" or source_name in active_powerups:
			powerup_adds.append(source_info)

	var ordered: Array = []
	ordered.append_array(consumable_adds)
	ordered.append_array(powerup_adds)

	var stagger = _stagger(ADD_STAGGER, speed_scale)
	for source_info in ordered:
		if _is_aborted(token):
			return
		var source_name = source_info.get("name", "")
		var value = int(source_info.get("value", 0))
		var is_consumable = source_info in consumable_adds

		var origin = _additive_origin(source_name, is_consumable)
		_bounce_source_spine(source_name, is_consumable, intensity_scale, speed_scale)

		var text_color = SCORING_TEXT_POSITIVE if is_consumable else SCORING_TEXT_ADDITIVE
		var font_scale = 1.2 if is_consumable else 1.5
		if value < 0:
			text_color = SCORING_TEXT_NEGATIVE
		var text = "+" + str(value) if value >= 0 else str(value)

		var spark_tween = _launch_spark(text, origin, font_scale, text_color, SCORING_ACCENT_MAGENTA,
			SPIRAL_T_ADD / speed_scale,
			func():
				_running_score += value
				if score_sink and is_instance_valid(score_sink):
					score_sink.set_running_score(_running_score, true)
					score_sink.bounce_wobble(WOBBLE_ADDITIVE, value < 0)
				_play_scoring_audio(abs(value))
		)
		if spark_tween:
			await _await_spark(spark_tween, token)
		if _is_aborted(token):
			return
		await get_tree().create_timer(stagger).timeout

## _phase_multipliers(breakdown_info, speed_scale, token)
##
## Strict order: scorecard multiplier, colored-dice multipliers (purple
## then blue), consumable multipliers, powerup multipliers. Each "xY"
## spirals in; arrival multiplies the running score and wobbles with
## strictly increasing intensity (MULT_WOBBLE_RAMP, then +0.4, cap 3.0).
## Divisor multipliers (<1) render red "÷Y" and shrink the score.
func _phase_multipliers(breakdown_info: Dictionary, speed_scale: float, token: int) -> void:
	var chain: Array = []  # {value: float, origin: Vector2, display_info: Dictionary}

	var scorecard_mult = float(breakdown_info.get("effective_regular_multiplier", breakdown_info.get("regular_multiplier", 1.0)))
	if not is_equal_approx(scorecard_mult, 1.0):
		chain.append({
			"value": scorecard_mult,
			"origin": _scorecard_origin(),
			"display_info": {
				"display_mode": breakdown_info.get("regular_multiplier_display_mode", ""),
				"display_operator": breakdown_info.get("regular_multiplier_display_operator", ""),
				"display_value": breakdown_info.get("regular_multiplier_display_value", scorecard_mult),
			},
		})

	var purple_mult = float(breakdown_info.get("effective_dice_color_multiplier", breakdown_info.get("dice_color_multiplier", 1.0)))
	if not is_equal_approx(purple_mult, 1.0):
		chain.append({
			"value": purple_mult,
			"origin": _dice_area_center(),
			"display_info": {
				"display_mode": breakdown_info.get("dice_color_multiplier_display_mode", ""),
				"display_operator": breakdown_info.get("dice_color_multiplier_display_operator", ""),
				"display_value": breakdown_info.get("dice_color_multiplier_display_value", purple_mult),
			},
		})

	var blue_mult = float(breakdown_info.get("effective_blue_score_multiplier", breakdown_info.get("blue_score_multiplier", 1.0)))
	if not is_equal_approx(blue_mult, 1.0):
		chain.append({
			"value": blue_mult,
			"origin": _dice_area_center(),
			"display_info": {
				"display_mode": breakdown_info.get("blue_score_multiplier_display_mode", ""),
				"display_operator": breakdown_info.get("blue_score_multiplier_display_operator", ""),
				"display_value": breakdown_info.get("blue_score_multiplier_display_value", blue_mult),
			},
		})

	# Source-list multipliers: consumables first, then powerups. Entries whose
	# category is scorecard/colored_dice are already covered by the effective
	# keys above and are skipped to avoid double-counting the visuals.
	var active_powerups = breakdown_info.get("active_powerups", [])
	var multiplier_sources = breakdown_info.get("multiplier_sources", [])
	var consumable_mults: Array = []
	var powerup_mults: Array = []
	for source_info in multiplier_sources:
		var source_name = source_info.get("name", "")
		var category = source_info.get("category", "")
		if category == "scorecard" or category == "colored_dice":
			continue
		if category == "consumable":
			consumable_mults.append(source_info)
		elif category == "powerup" or source_name in active_powerups:
			powerup_mults.append(source_info)

	for source_info in consumable_mults:
		chain.append({
			"value": float(source_info.get("value", 1.0)),
			"origin": _additive_origin(source_info.get("name", ""), true),
			"display_info": source_info,
		})
	for source_info in powerup_mults:
		chain.append({
			"value": float(source_info.get("value", 1.0)),
			"origin": _additive_origin(source_info.get("name", ""), false),
			"display_info": source_info,
		})

	var stagger = _stagger(MULT_STAGGER, speed_scale)
	var index = 0
	for entry in chain:
		if _is_aborted(token):
			return
		var value = float(entry["value"])
		var display = _resolve_multiplier_display(value, entry["display_info"])
		var is_divide = display["mode"] == "divide"
		var intensity = _multiplier_wobble_intensity(index)

		var text = "%s%.1f" % [display["operator"], display["value"]]
		var text_color = SCORING_TEXT_NEGATIVE if is_divide else SCORING_TEXT_MULTIPLIER
		var accent = SCORING_ACCENT_MAGENTA if is_divide else SCORING_ACCENT_TEAL

		var spark_tween = _launch_spark(text, entry["origin"], 1.5, text_color, accent,
			SPIRAL_T_MULT / speed_scale,
			func():
				_running_score = int(round(_running_score * value))
				if score_sink and is_instance_valid(score_sink):
					score_sink.set_running_score(_running_score, true)
					score_sink.bounce_wobble(intensity, is_divide)
				_play_scoring_audio(int(maxf(absf(display["value"]), 1.0) * 10))
		)
		if spark_tween:
			await _await_spark(spark_tween, token)
		if _is_aborted(token):
			return
		await get_tree().create_timer(stagger).timeout
		index += 1

## _await_spark(spark_tween, token)
##
## Waits for a spark flight to finish. Killed tweens (cancel/restart) never
## emit finished, so poll validity each frame and bail on abort instead of
## awaiting the signal and leaking the coroutine.
func _await_spark(spark_tween: Tween, token: int) -> void:
	while spark_tween.is_valid() and spark_tween.is_running():
		if _is_aborted(token):
			return
		await get_tree().process_frame

## _multiplier_wobble_intensity(index) -> float
##
## Strictly increasing wobble ramp across the multiplier chain.
func _multiplier_wobble_intensity(index: int) -> float:
	if index < MULT_WOBBLE_RAMP.size():
		return MULT_WOBBLE_RAMP[index]
	return minf(MULT_WOBBLE_RAMP[MULT_WOBBLE_RAMP.size() - 1] + MULT_WOBBLE_STEP_BEYOND * float(index - MULT_WOBBLE_RAMP.size() + 1), WOBBLE_MAX)

## _animate_category_level_factor(breakdown_info, speed_scale, token)
##
## The effective category-level factor as a sink-bound multiplier spark,
## launched above the dice area. Multiplies the running score on arrival.
func _animate_category_level_factor(breakdown_info: Dictionary, speed_scale: float, _token: int) -> void:
	var effective_category_level = float(breakdown_info.get("effective_category_level_factor", breakdown_info.get("category_level", 1)))
	if is_equal_approx(effective_category_level, 1.0):
		return

	var level_display = _resolve_multiplier_display(effective_category_level, {
		"display_mode": breakdown_info.get("category_level_display_mode", ""),
		"display_operator": breakdown_info.get("category_level_display_operator", ""),
		"display_value": breakdown_info.get("category_level_display_value", effective_category_level)
	})

	print("[ScoringAnimationController] Animating category level factor: %s%.1f" % [level_display.operator, level_display.value])

	var screen_size = get_viewport().get_visible_rect().size
	var level_position = Vector2(screen_size.x / 2, screen_size.y * 0.35)

	var is_divide = level_display.mode == "divide"
	var text_color = SCORING_TEXT_NEGATIVE if is_divide else SCORING_TEXT_ADDITIVE
	var text = "%s%.1f" % [level_display.operator, level_display.value]

	var spark_tween = _launch_spark(text, level_position, 1.8, text_color, SCORING_ACCENT_MAGENTA,
		SPIRAL_T_MULT / speed_scale,
		func():
			_running_score = int(round(_running_score * effective_category_level))
			if score_sink and is_instance_valid(score_sink):
				score_sink.set_running_score(_running_score, true)
				score_sink.bounce_wobble(WOBBLE_ADDITIVE, is_divide)
			_play_scoring_audio(int(maxf(absf(level_display.value), 1.0) * 10))
	)
	if spark_tween:
		await _await_spark(spark_tween, _token)

## _phase_blowup(score, category, intensity_scale)
##
## Reconcile the sink to the authoritative final score, then punch-out +
## particle burst + screen shake. Jackpot celebration fires at 50+/Yahtzee.
func _phase_blowup(score: int, category: String, intensity_scale: float) -> void:
	_running_score = score
	if score_sink and is_instance_valid(score_sink):
		score_sink.set_running_score(score, false)
		score_sink.blow_up()

	_play_scoring_audio(score)

	if dice_hand and dice_hand.has_method("animate_screen_shake"):
		dice_hand.animate_screen_shake(BLOWUP_SHAKE_INTENSITY)

	var is_yahtzee = category.to_lower() == "yahtzee"
	var is_jackpot = score >= LARGE_SCORE_THRESHOLD or is_yahtzee

	if is_jackpot and dice_hand:
		_play_jackpot_effects()

	if intensity_scale >= 1.6 and dice_hand:
		# Critical flash on all dice
		for die in _get_dice_array():
			if is_instance_valid(die) and die.has_method("animate_critical_flash"):
				die.animate_critical_flash()
		# Celebration wave across dice (shake already covered by the blow-up)
		if dice_hand.has_method("animate_celebration_cascade"):
			dice_hand.animate_celebration_cascade(intensity_scale)

## _play_jackpot_effects()
##
## Yahtzee / Jackpot celebration: hitstop, white flash, popup, sound,
## fireworks, camera zoom. Kept from the previous controller, re-timed to
## fire with the blow-up punch.
func _play_jackpot_effects() -> void:
	HitstopController.trigger_hitstop(3)
	# Full-screen white flash
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	flash.z_index = RenderLayers.Z_SCREEN_FX
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(flash)
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	flash_tween.tween_callback(flash.queue_free)
	# Jackpot floating text (anchored to screen center explicitly)
	var ftm = get_node_or_null("/root/FloatingTextManager")
	if ftm:
		ftm.show_popup_at_position(get_tree().root, get_viewport().get_visible_rect().size / 2.0, "JACKPOT!", Color(1.0, 0.8, 0.0, 1.0), 2.0)
	# Jackpot sound
	var jackpot_audio = get_node_or_null("/root/AudioManager")
	if jackpot_audio and jackpot_audio.has_method("play_jackpot_sound"):
		jackpot_audio.play_jackpot_sound()
	# Enhanced firework particles
	var celebration = load("res://Scripts/Effects/challenge_celebration.gd").new()
	get_tree().root.add_child(celebration)
	celebration.trigger_celebration(get_viewport().get_visible_rect().size / 2.0, get_tree().root)
	# Camera zoom
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_node("CameraDynamics"):
		cam.get_node("CameraDynamics").celebrate_zoom(0.6)
	else:
		# Fallback: find CameraDynamics on CRTTV or other Node2D parent
		var crt_tv = get_tree().root.find_child("CRTTV", true, false)
		if crt_tv and crt_tv.has_node("CameraDynamics"):
			crt_tv.get_node("CameraDynamics").celebrate_zoom(0.6)

## _phase_drain(score, category, speed_scale)
##
## The sink empties into the score labels: concealed scores reveal NOW (and
## only now), each changed label counts up from its pre-event value over
## COUNT_UP_T and punch-scales on landing. The sink flies to the first
## label, fades, and hides completely.
func _phase_drain(score: int, category: String, speed_scale: float) -> void:
	var duration = COUNT_UP_T / speed_scale
	var targets: Array = []

	# Real scorecard: reveal concealed scores, count up every changed row.
	if score_card_ui and is_instance_valid(score_card_ui) and score_card_ui.has_method("reveal_scoring_scores"):
		targets.append_array(score_card_ui.reveal_scoring_scores())
	elif score_card_ui and is_instance_valid(score_card_ui):
		# Legacy fallback for a scorecard without the conceal API.
		targets.append_array(_collect_drain_targets(score, category))

	# Test-scene mock labels (group hook).
	for node in get_tree().get_nodes_in_group("score_sink_drain_target"):
		if node.has_method("reveal_scoring_scores"):
			node.reveal_scoring_scores()
		if node is Label:
			var from_value = int(node.text) if node.text.is_valid_int() else 0
			targets.append({"label": node, "from": from_value, "to": from_value + score, "row": null})

	var screen_size = get_viewport().get_visible_rect().size
	var drain_target = Vector2(screen_size.x / 2.0, DRAIN_FALLBACK_Y)
	if targets.size() > 0:
		drain_target = targets[0]["label"].get_global_rect().get_center()

	if score_sink and is_instance_valid(score_sink):
		score_sink.drain(drain_target, duration)

	var tfx = get_node_or_null("/root/TweenFXHelper")
	for target in targets:
		var label = target["label"]
		if not is_instance_valid(label):
			continue
		if tfx:
			tfx.score_count_up(label, target["from"], target["to"], duration)
		else:
			var count_tween = create_tween()
			count_tween.tween_method(func(value): label.text = str(int(value)), float(target["from"]), float(target["to"]), duration)

	await get_tree().create_timer(duration).timeout

	# Landing punch on rows that support it
	for target in targets:
		var row = target["row"]
		if row and is_instance_valid(row) and row.has_method("play_score_lock"):
			row.play_score_lock()

	if score_sink and is_instance_valid(score_sink):
		score_sink.hide_sink()

## _collect_drain_targets(score, category) -> Array
##
## Legacy fallback when the scorecard lacks the conceal/reveal API:
## duck-typed label discovery off the scored category row + section total.
## Old values are reconstructed as shown-minus-score because the model has
## already pushed final values. Mock group labels are handled by
## _phase_drain directly.
func _collect_drain_targets(score: int, category: String) -> Array:
	var targets: Array = []
	if score_card_ui and is_instance_valid(score_card_ui):
		var key = StringName(category.to_lower())
		var rows = score_card_ui.get("rows")
		if rows is Dictionary and rows.has(key):
			var row = rows[key]
			var label = row.get("score_label") if row else null
			if label is Label:
				var shown = int(label.text) if label.text.is_valid_int() else score
				targets.append({"label": label, "from": maxi(shown - score, 0), "to": shown, "row": row})
		var model = score_card_ui.get("scorecard")
		var summary = score_card_ui.get("summary_rows")
		if model and summary is Dictionary:
			var is_upper = false
			var upper_scores = model.get("upper_scores")
			if upper_scores is Dictionary and upper_scores.has(category.to_lower()):
				is_upper = true
			var sum_key = StringName("upper_total" if is_upper else "lower_total")
			if summary.has(sum_key):
				var summary_row = summary[sum_key]
				var summary_label = summary_row.get("score_label") if summary_row else null
				if summary_label is Label:
					var shown = int(summary_label.text) if summary_label.text.is_valid_int() else score
					targets.append({"label": summary_label, "from": maxi(shown - score, 0), "to": shown, "row": summary_row})
	return targets

## _ensure_sink()
##
## Lazily create the ScoreSink under the current scene (same parent space
## as the previous scoring numbers).
func _ensure_sink() -> void:
	if score_sink and is_instance_valid(score_sink):
		return
	score_sink = ScoreSink.new()
	score_sink.name = "ScoreSink"
	var parent = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(score_sink)

## _launch_spark(text, start_position, font_scale, text_color, accent_color, duration, on_arrival) -> Tween
##
## Spawn a ScoreSpark at a source point and fly it along a polar spiral
## into the sink. Returns the flight tween so phases can await arrival.
func _launch_spark(text: String, start_position: Vector2, font_scale: float, text_color: Color, accent_color: Color, duration: float, on_arrival: Callable) -> Tween:
	if not score_sink or not is_instance_valid(score_sink):
		return null
	var parent = score_sink.get_parent()
	if parent == null:
		return null

	var spark = ScoreSpark.new()
	parent.add_child(spark)
	spark.setup(text, font_scale, text_color, _build_scoring_panel_style(accent_color, false))
	spark.global_position = start_position
	_active_sparks.append(spark)

	var center = score_sink.get_sink_center()
	var offset = start_position - center
	var start_radius = offset.length()
	var start_angle = offset.angle()
	var turns = SPIRAL_TURNS * clampf(start_radius / SPIRAL_TURN_REF_DIST, SPIRAL_TURN_MIN_FACTOR, 1.0)

	var tween = create_tween()
	tween.tween_method(_update_spark_flight.bind(spark, center, start_radius, start_angle, turns), 0.0, 1.0, maxf(duration, STAGGER_FLOOR))
	tween.tween_callback(_on_spark_arrived.bind(spark, on_arrival))
	_spark_tweens.append(tween)
	return tween

## _update_spark_flight(progress, spark, center, start_radius, start_angle, turns)
##
## Polar spiral: radius eases to zero (smoothstep), angle accumulates with
## a late-weighted exponent so the number visibly whips into the center.
## Shrinks en route and fades over the final SPIRAL_FADE_PORTION.
func _update_spark_flight(progress: float, spark: ScoreSpark, center: Vector2, start_radius: float, start_angle: float, turns: float) -> void:
	if not is_instance_valid(spark):
		return
	var eased = progress * progress * (3.0 - 2.0 * progress)
	var angle = start_angle + turns * TAU * pow(progress, SPIRAL_ANGLE_EXP)
	var new_position = center + Vector2.from_angle(angle) * start_radius * (1.0 - eased)
	var spark_scale = lerpf(1.0, SPIRAL_SHRINK_TO, progress)
	var alpha = 1.0
	var fade_start = 1.0 - SPIRAL_FADE_PORTION
	if progress > fade_start:
		alpha = clampf(1.0 - (progress - fade_start) / SPIRAL_FADE_PORTION, 0.0, 1.0)
	spark.fly_update(new_position, spark_scale, alpha)

## _on_spark_arrived(spark, on_arrival)
##
## Spark reached the sink: free it, run the arrival effect (score update,
## wobble, sound), and fire the small impact burst.
func _on_spark_arrived(spark: ScoreSpark, on_arrival: Callable) -> void:
	_active_sparks.erase(spark)
	if is_instance_valid(spark):
		spark.queue_free()
	if animations_cancelled:
		return
	if on_arrival.is_valid():
		on_arrival.call()
	if score_sink and is_instance_valid(score_sink):
		score_sink.arrival_burst()

## _cleanup_sparks()
##
## Kill all flight tweens and free in-flight sparks (cancel/restart path).
func _cleanup_sparks() -> void:
	for tween in _spark_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_spark_tweens.clear()
	for spark in _active_sparks:
		if is_instance_valid(spark):
			spark.queue_free()
	_active_sparks.clear()

## _get_dice_array() -> Array
##
## Duck-typed dice enumeration (real DiceHand or test mock).
func _get_dice_array() -> Array:
	if not dice_hand:
		return []
	if dice_hand.has_method("get_all_dice"):
		var dice = dice_hand.get_all_dice()
		if dice != null:
			return dice
	var listed = dice_hand.get("dice_list")
	if listed != null:
		return listed
	return []

## _dice_subtotal_fallback(breakdown_info) -> int
##
## Dice-only subtotal when base_score is absent (manual scoring path):
## sum the values of the used dice.
func _dice_subtotal_fallback(breakdown_info: Dictionary) -> int:
	var dice_values = breakdown_info.get("dice_values", [])
	var used_dice_indices = breakdown_info.get("used_dice_indices", [])
	if dice_values.size() > 0 and used_dice_indices.size() > 0:
		var total = 0
		for index in used_dice_indices:
			if index >= 0 and index < dice_values.size():
				total += int(dice_values[index])
		return total
	return _running_score

## _dice_area_center() -> Vector2
##
## Average position of the used dice (origin for colored-dice multipliers).
func _dice_area_center() -> Vector2:
	var fallback = get_viewport().get_visible_rect().size / 2.0
	var dice_array = _get_dice_array()
	var used_dice_indices = current_breakdown_info.get("used_dice_indices", [])
	var total = Vector2.ZERO
	var count = 0
	for index in used_dice_indices:
		if index >= 0 and index < dice_array.size():
			var die = dice_array[index]
			if die and is_instance_valid(die):
				total += die.global_position
				count += 1
	if count == 0:
		return fallback
	return total / float(count)

## _scorecard_origin() -> Vector2
##
## Screen-space center of the scorecard panel (scorecard multiplier origin).
func _scorecard_origin() -> Vector2:
	if score_card_ui and is_instance_valid(score_card_ui):
		return score_card_ui.get_global_rect().get_center()
	return get_viewport().get_visible_rect().size / 2.0

## _additive_origin(source_name, is_consumable) -> Vector2
##
## Spine center for a source, falling back to the matching UI container.
func _additive_origin(source_name: String, is_consumable: bool) -> Vector2:
	var fallback = _get_game_ui_container_center(
		&"consumable_container" if is_consumable else &"power_up_container",
		get_viewport().get_visible_rect().size / 2.0)
	var spine = _find_source_spine(source_name, is_consumable)
	if spine and is_instance_valid(spine):
		if spine is Control:
			return (spine as Control).get_global_rect().get_center()
		if spine is Node2D:
			return (spine as Node2D).global_position
	return fallback

## _find_source_spine(source_name, is_consumable)
##
## Look up a consumable/powerup spine by id, duck-typed.
func _find_source_spine(source_name: String, is_consumable: bool):
	var ui = consumable_ui if is_consumable else power_up_ui
	if not ui:
		return null
	var spine_dict = ui.get("_consumable_spines" if is_consumable else "_spines")
	if spine_dict is Dictionary and spine_dict.has(source_name):
		return spine_dict[source_name]
	return null

## _bounce_source_spine(source_name, is_consumable, intensity_scale, speed_scale)
##
## Bounce the source's spine while its spark flies (kept from old phases).
func _bounce_source_spine(source_name: String, is_consumable: bool, intensity_scale: float, speed_scale: float) -> void:
	var spine = _find_source_spine(source_name, is_consumable)
	if not spine or not is_instance_valid(spine):
		return
	var bounce_height = CONSUMABLE_BOUNCE_HEIGHT * intensity_scale
	var bounce_duration = 0.6 / speed_scale
	if not is_consumable:
		bounce_height *= 1.2
		bounce_duration = 0.8 / speed_scale
	var original_position = spine.global_position
	var bounce_tween = create_tween()
	# Use bind() instead of a lambda so a freed spine passes null and the
	# helper can bail out (same pattern as _bounce_die_local).
	bounce_tween.tween_method(_bounce_spine_safe.bind(spine, original_position, bounce_height), 0.0, 1.0, bounce_duration)

## _bounce_spine_safe(progress, spine, original_position, bounce_height)
##
## Bounce wrapper for tween_method: progress comes first, bound args follow.
## Validates the spine every frame — spines can be freed mid-flight when a
## scoring sequence is cancelled or restarted.
func _bounce_spine_safe(progress: float, spine, original_position: Vector2, bounce_height: float) -> void:
	if not spine or not is_instance_valid(spine):
		return
	var bounce_offset = sin(progress * PI) * bounce_height
	spine.global_position = original_position + Vector2(0, -bounce_offset)

## _bounce_die(die, original_position, bounce_height, progress)
##
## Animate individual die bounce using sine wave motion (global space).
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
## Play scoring sound effect with pitch scaled by score magnitude via AudioManager.
func _play_scoring_audio(score: int) -> void:
	# Use AudioManager for centralized audio playback
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_scoring_sound(score)
	else:
		# Fallback to local player if AudioManager not available
		if not audio_player:
			return

		if scoring_sound:
			audio_player.stream = scoring_sound
			var pitch = BASE_PITCH + (score * PITCH_SCALE_FACTOR)
			pitch = min(pitch, MAX_PITCH)
			audio_player.pitch_scale = pitch
			audio_player.play()
			print("[ScoringAnimationController] Playing audio with pitch: %.2f (fallback)" % pitch)
		else:
			print("[ScoringAnimationController] No scoring sound effect assigned")

## _resolve_multiplier_display(multiplier_value, display_info)
##
## Normalizes effective multiplier display for animation text and panel updates.
func _resolve_multiplier_display(multiplier_value: float, display_info: Dictionary = {}) -> Dictionary:
	var display_mode = str(display_info.get("display_mode", display_info.get("mode", "")))
	var display_operator = str(display_info.get("display_operator", display_info.get("operator", "")))
	var display_value = float(display_info.get("display_value", multiplier_value))

	if display_mode == "" or display_operator == "":
		if is_equal_approx(multiplier_value, 1.0):
			display_mode = "neutral"
			display_operator = "×"
			display_value = 1.0
		elif multiplier_value > 0.0 and multiplier_value < 1.0:
			display_mode = "divide"
			display_operator = "÷"
			display_value = 1.0 / multiplier_value
		else:
			display_mode = "multiply"
			display_operator = "×"
			display_value = multiplier_value

	return {
		"mode": display_mode,
		"operator": display_operator,
		"value": display_value
	}

## _build_scoring_panel_style(accent_color, use_rotation)
##
## Shared mall-core chip shell for transient scoring feedback panels.
func _build_scoring_panel_style(accent_color: Color, use_rotation: bool = true) -> Dictionary:
	return {
		"fill_color": SCORING_PANEL_FILL,
		"border_color": accent_color,
		"border_width": 3,
		"corner_radius": 14,
		"shadow_color": SCORING_PANEL_SHADOW,
		"shadow_size": 6,
		"rotate_panel": use_rotation,
	}

## _create_scoring_floating_number(target_position, value, font_scale, text_color, accent_color, use_rotation)
##
## Spawn a floating number with the shared mall-core shell. Retained for
## generic (non-sink) callers only; the scoring sequence uses ScoreSpark.
func _create_scoring_floating_number(target_position: Vector2, value: String, font_scale: float, text_color: Color, accent_color: Color, use_rotation: bool = true) -> FloatingNumber:
	return FloatingNumberScript.create_floating_number(
		get_tree().current_scene,
		target_position,
		value,
		font_scale,
		text_color,
		_build_scoring_panel_style(accent_color, use_rotation)
	)

## create_floating_number(position, value, scale_factor)
##
## Utility function to create floating number effects.
func create_floating_number(position: Vector2, value: String, scale_factor: float = 1.0) -> void:
	var floating_number = _create_scoring_floating_number(position, value, scale_factor, SCORING_TEXT_ADDITIVE, SCORING_ACCENT_MAGENTA)
	if floating_number:
		floating_number.float_duration = FLOAT_NUMBER_DURATION
		floating_number.float_speed = FLOAT_NUMBER_SPEED

## _show_colored_dice_effect(die, die_center, speed_scale, die_index)
##
## Show additional sink-bound spark for colored dice based on color type.
## Visual only — the score change is handled by the additive/multiplier
## phases or external systems (e.g. green dice money).
func _show_colored_dice_effect(die: Dice, die_center: Vector2, speed_scale: float, die_index: int) -> void:
	var effect_text = ""
	var effect_color = Color.WHITE
	var accent_color = SCORING_ACCENT_MAGENTA
	var used_dice_indices = current_breakdown_info.get("used_dice_indices", [])
	var is_used = die_index in used_dice_indices
	var score_modifier_manager = get_node_or_null("/root/ScoreModifierManager")

	# Determine effect text and color based on die color
	match die.color:
		DiceColor.Type.GREEN:
			effect_text = "$" + str(die.value)  # Green dice give money
			effect_color = SCORING_TEXT_POSITIVE
		DiceColor.Type.RED:
			effect_text = "+" + str(die.value)  # Red dice give additive bonus
			effect_color = Color(1.0, 0.470588, 0.576471, 1.0)
		DiceColor.Type.PURPLE:
			var purple_factor = 2.0 if is_used else 1.0
			var purple_effective = purple_factor
			if score_modifier_manager and score_modifier_manager.has_method("get_effective_multiplier_factor"):
				purple_effective = score_modifier_manager.get_effective_multiplier_factor(purple_factor)
			var purple_display = _resolve_multiplier_display(purple_effective)
			effect_text = "%s%.1f" % [purple_display.operator, purple_display.value]
			effect_color = Color(0.886275, 0.560784, 0.72549, 1.0)
			accent_color = SCORING_ACCENT_TEAL
			if purple_display.mode == "divide":
				effect_color = SCORING_TEXT_NEGATIVE
				accent_color = SCORING_ACCENT_MAGENTA
		DiceColor.Type.BLUE:
			var blue_factor = 1.0
			if is_used:
				blue_factor = float(die.value)
			elif die.value > 0:
				blue_factor = 1.0 / float(die.value)
			var blue_effective = blue_factor
			if score_modifier_manager and score_modifier_manager.has_method("get_effective_multiplier_factor"):
				blue_effective = score_modifier_manager.get_effective_multiplier_factor(blue_factor)
			var blue_display = _resolve_multiplier_display(blue_effective)
			effect_text = "%s%.1f" % [blue_display.operator, blue_display.value]
			effect_color = SCORING_TEXT_MULTIPLIER
			accent_color = SCORING_ACCENT_TEAL
			if blue_display.mode == "divide":
				effect_color = SCORING_TEXT_NEGATIVE
				accent_color = SCORING_ACCENT_MAGENTA
		_:
			return  # No effect for NONE color

	# Launch offset slightly right of the main value spark; arrival only
	# produces an impact burst (no score change, no wobble).
	var offset_position = die_center + Vector2(30, 0)
	_launch_spark(effect_text, offset_position, 0.8, effect_color, accent_color,
		SPIRAL_T_DICE / speed_scale,
		func():
			pass
	)

#region Negative/Debuff Animations

## animate_negative_contribution(value, source_position, source_name)
##
## Negative score contribution (debuff penalty). When a sink sequence is
## active the penalty spirals into the sink like every other number (one
## motion language); standalone callers get the legacy red floating number.
func animate_negative_contribution(value: int, source_position: Vector2, source_name: String = "Debuff") -> void:
	var penalty = abs(value)
	var intensity = clampf(float(penalty) / 5.0, 0.5, 3.0)

	print("[ScoringAnimationController] Animating negative contribution: -%d from %s (intensity: %.1f)" % [penalty, source_name, intensity])

	if score_sink and is_instance_valid(score_sink) and score_sink.visible:
		_launch_spark(str(value), source_position, 1.2 + (intensity * 0.3), SCORING_TEXT_NEGATIVE, SCORING_ACCENT_MAGENTA,
			SPIRAL_T_ADD,
			func():
				_running_score -= penalty
				if score_sink and is_instance_valid(score_sink):
					score_sink.set_running_score(_running_score, true)
					score_sink.bounce_wobble(WOBBLE_ADDITIVE, true)
				_play_scoring_audio(penalty)
		)
	else:
		_create_negative_floating_number(source_position, value, intensity)

	# Trigger screen effects based on penalty severity
	if penalty > 10:
		_trigger_red_vignette_pulse(intensity)
	if penalty > 20:
		_trigger_camera_shake(intensity)


## _create_negative_floating_number(position, value, intensity)
##
## Legacy standalone red floating number (only used when no sink is active).
func _create_negative_floating_number(position: Vector2, value: int, intensity: float) -> void:
	var text = str(value)  # Value should already be negative
	var scale_factor = 1.2 + (intensity * 0.3)

	var floating_number = _create_scoring_floating_number(position, text, scale_factor, SCORING_TEXT_NEGATIVE, SCORING_ACCENT_MAGENTA, false)

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
	vignette.z_index = RenderLayers.Z_MODAL

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

	# Try to find the debuff in the DebuffUI
	var debuff_ui_nodes = get_tree().get_nodes_in_group("debuff_ui")
	var source_position = _get_game_ui_container_center(&"debuff_container", get_viewport().get_visible_rect().size / 2.0)

	if debuff_ui_nodes.size() > 0:
		var debuff_ui = debuff_ui_nodes[0]
		# Use debuff spine position if available
		if debuff_ui.has_method("get_debuff_spine_position"):
			source_position = debuff_ui.get_debuff_spine_position()
		elif debuff_ui is Control:
			source_position = (debuff_ui as Control).get_global_rect().get_center()

	# Animate the negative contribution
	animate_negative_contribution(-penalty_value, source_position, debuff_id)

#endregion

## _get_game_ui_container_center(container_property, fallback)
##
## Returns the screen-space center of a named container on GameUI
## (e.g. "power_up_container", "debuff_container", "money_container").
## Used as the origin for scoring animations so they start near the
## relevant UI panel instead of stale hardcoded layout positions.
## NOTE: never use GameController.power_up_container for this - that is a
## Node2D logic container sitting at (0,0), not the visual panel.
func _get_game_ui_container_center(container_property: StringName, fallback: Vector2) -> Vector2:
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		var container = game_ui.get(container_property)
		if container is Control:
			return (container as Control).get_global_rect().get_center()
	return fallback
