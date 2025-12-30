extends Control

@export var dice_hand_path:      NodePath
@export var score_card_ui_path:  NodePath
@export var turn_tracker_path:   NodePath
@export var round_manager_path:  NodePath
@export var challenge_manager_path: NodePath
@export var scoring_animation_controller_path: NodePath = ^"../ScoringAnimationController"

@onready var challenge_manager: ChallengeManager = get_node_or_null(challenge_manager_path)
@onready var scoring_animation_controller = get_node_or_null(scoring_animation_controller_path)

@onready var shop_button: Button = $HBoxContainer/ShopButton
@onready var next_round_button: Button = $HBoxContainer/NextRoundButton  
@onready var roll_button: Button = $HBoxContainer/RollButton
@onready var next_turn_button: Button = $HBoxContainer/NextTurnButton  

signal shop_button_pressed
signal next_round_pressed
signal dice_rolled(dice_values: Array)

var dice_hand
var score_card_ui
var turn_tracker
var round_manager: RoundManager
var scorecard: Scorecard
var is_shop_open: bool = true
var first_roll_done: bool = false

## Pulse animation state - Roll button
var _roll_button_pulse_tween: Tween = null
var _is_pulsing: bool = false
var _original_roll_button_modulate: Color = Color.WHITE

## Pulse animation state - Shop button
var _shop_button_pulse_tween: Tween = null
var _is_shop_pulsing: bool = false
var _original_shop_button_modulate: Color = Color.WHITE


func _ready():
	print("ScoreCardUI ready: ", score_card_ui_path)
	dice_hand      = get_node(dice_hand_path)
	score_card_ui  = get_node(score_card_ui_path)
	turn_tracker   = get_node(turn_tracker_path)
	round_manager  = get_node_or_null(round_manager_path)
	challenge_manager = get_node_or_null(challenge_manager_path)  # Initialize challenge_manager
	
	if not score_card_ui:
		print("Error")
		push_error("GameButtonUI: score_card_ui_path not set or node missing")

	roll_button.pressed.connect(_on_roll_button_pressed)
	next_turn_button.pressed.connect(_on_next_turn_button_pressed)
	dice_hand.roll_complete.connect(_on_dice_roll_complete)
	turn_tracker.rolls_exhausted.connect(func(): roll_button.disabled = true; _stop_roll_button_pulse())
	turn_tracker.turn_started.connect(func(): roll_button.disabled = false; _start_roll_button_pulse())
	turn_tracker.connect("game_over",Callable(self, "_on_game_over"))
	score_card_ui.connect("hand_scored", Callable(self, "_hand_scored_disable"))
	score_card_ui.connect("manual_score", Callable(self, "_scored_hand_setup_next_round"))
	
	# Store original roll button modulate for pulse effect
	if roll_button:
		_original_roll_button_modulate = roll_button.modulate
	
	# Shop button is already connected in the scene file, so just configure it
	if shop_button:
		shop_button.disabled = false  # Enabled at the very beginning
		_original_shop_button_modulate = shop_button.modulate
		print("Shop button status: ", shop_button.disabled)
	
	if next_round_button:
		next_round_button.pressed.connect(_on_next_round_button_pressed)
		# Start with Next Round button enabled to begin the game
		next_round_button.disabled = false
	
	# Make sure both round_manager and challenge_manager exist before connecting signals
	if round_manager:
		round_manager.round_started.connect(_on_round_started)
		round_manager.round_completed.connect(_on_round_completed)
	
	if challenge_manager:
		challenge_manager.challenge_completed.connect(_on_challenge_completed)
		print("[GameButtonUI] Connected to challenge_manager.challenge_completed signal")
		print("[GameButtonUI] challenge_manager instance:", challenge_manager)
	else:
		push_error("[GameButtonUI] challenge_manager reference is null - CANNOT CONNECT SIGNALS")

	# Disable gameplay buttons initially
	roll_button.disabled = true
	next_turn_button.disabled = true


## reset_for_new_channel() -> void
##
## Resets button state for a new channel. Called after winning a channel.
func reset_for_new_channel() -> void:
	print("[GameButtonUI] Resetting for new channel")
	first_roll_done = false
	
	# Reset button states
	roll_button.disabled = true
	next_turn_button.disabled = true
	if next_round_button:
		next_round_button.disabled = false
	if shop_button:
		shop_button.disabled = false
	
	# Stop any pulse animations
	_stop_roll_button_pulse()
	_stop_shop_button_pulse()
	
	print("[GameButtonUI] Reset complete - first_roll_done:", first_roll_done)


## _start_roll_button_pulse()
##
## Starts the pulsing glow animation on the Roll button.
## Used when waiting for the first roll of a turn.
func _start_roll_button_pulse() -> void:
	if _is_pulsing or not roll_button:
		return
	
	if roll_button.disabled:
		return
	
	_is_pulsing = true
	print("[GameButtonUI] Starting Roll button pulse animation")
	_animate_roll_button_pulse()


## _stop_roll_button_pulse()
##
## Stops the pulsing animation and resets the Roll button to normal.
func _stop_roll_button_pulse() -> void:
	if not _is_pulsing:
		return
	
	_is_pulsing = false
	
	if _roll_button_pulse_tween:
		_roll_button_pulse_tween.kill()
		_roll_button_pulse_tween = null
	
	# Reset to original state
	if roll_button:
		roll_button.modulate = _original_roll_button_modulate
		roll_button.scale = Vector2.ONE
	
	print("[GameButtonUI] Stopped Roll button pulse animation")


## _animate_roll_button_pulse()
##
## Creates and runs the looping pulse animation on the Roll button.
func _animate_roll_button_pulse() -> void:
	if not _is_pulsing or not roll_button:
		return
	
	if _roll_button_pulse_tween:
		_roll_button_pulse_tween.kill()
	
	_roll_button_pulse_tween = create_tween()
	_roll_button_pulse_tween.set_loops()
	
	# Pulse color: subtle golden glow
	var pulse_color = Color(1.3, 1.2, 0.9, 1.0)
	var normal_color = _original_roll_button_modulate
	
	# Pulse scale
	var pulse_scale = Vector2(1.05, 1.05)
	var normal_scale = Vector2.ONE
	
	# Set pivot to center for scaling
	roll_button.pivot_offset = roll_button.size / 2.0
	
	# Glow up
	_roll_button_pulse_tween.tween_property(roll_button, "modulate", pulse_color, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_roll_button_pulse_tween.parallel().tween_property(roll_button, "scale", pulse_scale, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	# Glow down
	_roll_button_pulse_tween.tween_property(roll_button, "modulate", normal_color, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_roll_button_pulse_tween.parallel().tween_property(roll_button, "scale", normal_scale, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


## _start_shop_button_pulse()
##
## Starts the pulsing glow animation on the Shop button.
## Used when the shop becomes available between rounds.
func _start_shop_button_pulse() -> void:
	if _is_shop_pulsing or not shop_button:
		return
	
	if shop_button.disabled:
		return
	
	_is_shop_pulsing = true
	print("[GameButtonUI] Starting Shop button pulse animation")
	_animate_shop_button_pulse()


## _stop_shop_button_pulse()
##
## Stops the pulsing animation and resets the Shop button to normal.
func _stop_shop_button_pulse() -> void:
	if not _is_shop_pulsing:
		return
	
	_is_shop_pulsing = false
	
	if _shop_button_pulse_tween:
		_shop_button_pulse_tween.kill()
		_shop_button_pulse_tween = null
	
	# Reset to original state
	if shop_button:
		shop_button.modulate = _original_shop_button_modulate
		shop_button.scale = Vector2.ONE
	
	print("[GameButtonUI] Stopped Shop button pulse animation")


## _animate_shop_button_pulse()
##
## Creates and runs the looping pulse animation on the Shop button.
func _animate_shop_button_pulse() -> void:
	if not _is_shop_pulsing or not shop_button:
		return
	
	if _shop_button_pulse_tween:
		_shop_button_pulse_tween.kill()
	
	_shop_button_pulse_tween = create_tween()
	_shop_button_pulse_tween.set_loops()
	
	# Pulse color: subtle golden glow (same as roll button)
	var pulse_color = Color(1.3, 1.2, 0.9, 1.0)
	var normal_color = _original_shop_button_modulate
	
	# Pulse scale
	var pulse_scale = Vector2(1.05, 1.05)
	var normal_scale = Vector2.ONE
	
	# Set pivot to center for scaling
	shop_button.pivot_offset = shop_button.size / 2.0
	
	# Glow up
	_shop_button_pulse_tween.tween_property(shop_button, "modulate", pulse_color, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_shop_button_pulse_tween.parallel().tween_property(shop_button, "scale", pulse_scale, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	# Glow down
	_shop_button_pulse_tween.tween_property(shop_button, "modulate", normal_color, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_shop_button_pulse_tween.parallel().tween_property(shop_button, "scale", normal_scale, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


func _on_roll_button_pressed() -> void:
	# Stop the pulse animation when roll button is pressed
	_stop_roll_button_pulse()
	
	print("[GameButtonUI] Roll button pressed. Dice list size:", dice_hand.dice_list.size())
	
	next_turn_button.disabled = false
	if not first_roll_done:
		first_roll_done = true
		if shop_button:
			shop_button.disabled = true  # Disable shop after first roll
	if dice_hand.dice_list.is_empty():
		print("[GameButtonUI] Dice list empty - spawning new dice")
		await dice_hand.spawn_dice()
		print("[GameButtonUI] Spawn complete, proceeding to roll")
	else:
		print("[GameButtonUI] Dice list not empty - updating dice count")
		dice_hand.update_dice_count()
	
	# Prepare dice for rolling - set ROLLED dice to ROLLABLE, preserve LOCKED dice
	dice_hand.prepare_dice_for_roll()
	print("[GameButtonUI] Rolling dice (preserving locks)")
	
	dice_hand.roll_all()
	print("▶ Roll pressed — using dice_count =", dice_hand.dice_count)
	if dice_hand:
		var dice_values = dice_hand.get_current_dice_values() # dice_hand.roll_dice() returns the values immediately
		#emit_signal("dice_rolled", dice_values)
		print("[GameButtonUI] Dice rolled with values:", dice_values)
	if score_card_ui:
		score_card_ui.update_best_hand_preview(DiceResults.values)
	else:
		push_error("GameButtonUI: score_card_ui reference is null")


func _on_dice_roll_complete() -> void:
	# player may now pick a category…
	# lock UI state for scoring
	score_card_ui.turn_scored = false
	turn_tracker.use_roll()
	
	# Now that dice have settled, get their values and emit signal
	var dice_values = dice_hand.get_current_dice_values()
	emit_signal("dice_rolled", dice_values)

func _on_next_turn_button_pressed() -> void:
	# 1) Auto-score if needed
	if not score_card_ui.turn_scored:
		print("[GameButtonUI] About to trigger autoscoring...")
		score_card_ui.scorecard.auto_score_best(dice_hand.get_current_dice_values())
		score_card_ui.turn_scored = true
		print("[GameButtonUI] Autoscoring completed, calling update_all()...")
		score_card_ui.update_all()
		print("[GameButtonUI] Manual update_all() completed")
		_scored_hand_setup_next_round()

	# 2) Proceed with turn advancement (after scoring is complete)
	print("[GameButtonUI] Starting new turn - enabling roll button and setting dice to ROLLABLE")
	turn_tracker.start_new_turn()
	score_card_ui.turn_scored = false
	score_card_ui.enable_all_score_buttons()
	
	# Set all dice to ROLLABLE state for new turn
	dice_hand.set_all_dice_rollable()
	
	roll_button.disabled = false
	next_turn_button.disabled = true	

func _scored_hand_setup_next_round():
	print("[GameButtonUI] Scored hand, setting up next round")
	
	# Animate dice exiting the screen
	if dice_hand:
		dice_hand.animate_all_dice_exit()
		print("[GameButtonUI] Triggered dice exit animation")
	
	# Disable dice input after scoring
	dice_hand.set_all_dice_disabled()
	print("[GameButtonUI] Set all dice to DISABLED state after scoring")

func _on_auto_score_assigned(section, category, score):
	print("Auto-assigned", category, "in", section, "for", score, "points")
	# maybe flash the label or play a sound

func _on_game_over() -> void:
	# Disable all controls
	roll_button.disabled = true
	next_turn_button.disabled = true
	if shop_button:
		shop_button.disabled = true
	
	# Stop any pulse animation
	_stop_roll_button_pulse()

func _hand_scored_disable() -> void:
	print("🏁 Hand scored—disabling Roll button")
	roll_button.disabled = true
	_stop_roll_button_pulse()

func _on_shop_button_pressed() -> void:
	print("[GameButtonUI] Shop button pressed")
	# Stop the pulse animation when shop button is pressed
	_stop_shop_button_pulse()
	is_shop_open = !is_shop_open  # Toggle shop state
	emit_signal("shop_button_pressed")
	print("[GameButtonUI] Signal emitted")
	next_turn_button.disabled = true  # Disable next turn while in shop
	roll_button.disabled = true  # Disable roll while in shop
	_stop_roll_button_pulse()  # Stop pulse when roll disabled

func _on_round_started(_round_number: int) -> void:
	print("[GameButtonUI] === ROUND STARTED ===")
	print("[GameButtonUI] Round", _round_number, "started")
	
	if next_round_button:
		next_round_button.disabled = true
		print("[GameButtonUI] NextRound button DISABLED on round start")
	
	if shop_button:
		print("[GameButtonUI] Round started - disabling shop button")
		_stop_shop_button_pulse()  # Stop pulse when shop disabled
		shop_button.disabled = true  # Disable shop at the start of each round
	
	# Enable gameplay buttons when round starts
	roll_button.disabled = false
	next_turn_button.disabled = false
	
	# Start Roll button pulse to draw attention
	_start_roll_button_pulse()
	
	# Always spawn dice when a round starts
	if dice_hand:
		# Since we've just cleared the dice, dice_list should be empty
		print("[GameButtonUI] Spawning dice for round", _round_number)
		dice_hand.spawn_dice()
		
		# Wait a short moment for dice to appear and animate in
		await get_tree().create_timer(0.3).timeout
		
		# Now trigger the roll
		_on_roll_button_pressed()

func _on_round_completed(_round_number: int) -> void:
	if shop_button:
		shop_button.disabled = false  # Enable shop after round is completed
		_start_shop_button_pulse()  # Start pulse to attract attention
	
	if _round_number == 0:  # Initial game state - don't enable next round button yet
		if next_round_button:
			next_round_button.disabled = false

func _on_challenge_completed(challenge_id: String) -> void:
	print("[GameButtonUI] === CHALLENGE COMPLETED ===")
	print("[GameButtonUI] _on_challenge_completed received:", challenge_id)
	print("[GameButtonUI] round_manager:", round_manager)
	if round_manager:
		print("[GameButtonUI] round_manager.current_challenge_id:", round_manager.current_challenge_id)
	
	if round_manager and challenge_id != "":
		if round_manager.current_challenge_id == challenge_id or round_manager.current_challenge_id == "":
			print("[GameButtonUI] Challenge ID match! Enabling Next Round button")
			if next_round_button:
				next_round_button.disabled = false
				print("[GameButtonUI] Next Round button enabled: disabled=", next_round_button.disabled)
			if shop_button:
				shop_button.disabled = false  # Enable shop when challenge is completed
				_start_shop_button_pulse()  # Start pulse to attract attention
		else:
			print("[GameButtonUI] Challenge ID mismatch:", challenge_id, "vs", round_manager.current_challenge_id)

func _on_next_round_button_pressed() -> void:
	print("[GameButtonUI] Next Round button pressed")
	if round_manager:
		print("[GameButtonUI] Current round:", round_manager.get_current_round_number(), "first_roll_done:", first_roll_done)
	
	# Cancel any pending animations before clearing dice
	if scoring_animation_controller:
		scoring_animation_controller.cancel_all_animations()
	
	# Clear dice first
	if dice_hand:
		dice_hand.clear_dice()
	
	# Reset all scores on the scorecard but preserve levels (upgrades persist) and update UI
	if score_card_ui and score_card_ui.scorecard:
		score_card_ui.scorecard.reset_scores_preserve_levels()
		score_card_ui.update_all()
	
	# After clearing dice, proceed with round management
	if round_manager:
		var current_round = round_manager.get_current_round_number()
		
		# If this is the initial state (no round started yet)
		if current_round == 1 and not first_roll_done:
			print("[GameButtonUI] Starting first round")
			round_manager.start_round(1)
		else:
			# Normal round advancement
			print("[GameButtonUI] Advancing from round", current_round, "to round", current_round + 1)
			round_manager.complete_round()
			round_manager.start_round(current_round + 1)
		
		emit_signal("next_round_pressed")
