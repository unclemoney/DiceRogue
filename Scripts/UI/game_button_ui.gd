extends Control
class_name GameButtonUI

@export var dice_hand_path:      NodePath
@export var score_card_ui_path:  NodePath
@export var turn_tracker_path:   NodePath
@export var round_manager_path:  NodePath
@export var challenge_manager_path: NodePath
@export var scoring_animation_controller_path: NodePath = ^"../CRTTV/ScoringAnimationController"

@onready var challenge_manager: ChallengeManager = get_node_or_null(challenge_manager_path)
@onready var scoring_animation_controller = get_node_or_null(scoring_animation_controller_path)

@onready var shop_button: Button = $HBoxContainer/RightButtonArea/ShopButton
@onready var next_round_button: Button = $HBoxContainer/RightButtonArea/NextRoundButton
@onready var next_turn_button: Button = $HBoxContainer/RightButtonArea/NextTurnButton
@onready var _tfx := get_node("/root/TweenFXHelper")

## Emitted when shop is opened so RollButtonUI can disable roll
signal shop_opened
signal shop_button_pressed
signal next_round_pressed
## Emitted when Next Turn is pressed; ScoreCardUI listens to auto-score the best hand
signal next_turn_pressed
## Re-emitted from RollButtonUI for backwards-compat with GameController
signal dice_rolled(dice_values: Array)
signal roll_pressed

var dice_hand
var score_card_ui
var turn_tracker
var round_manager: RoundManager
var scorecard: Scorecard
var is_shop_open: bool = true

var _is_shop_pulsing: bool = false

var _input_cooldown: float = 0.0
const INPUT_COOLDOWN_DURATION: float = 0.75

var _button_action_cooldown: float = 0.0
const BUTTON_ACTION_COOLDOWN: float = 0.35


func _ready():
	dice_hand      = get_node_or_null(dice_hand_path)
	score_card_ui  = get_node_or_null(score_card_ui_path)
	turn_tracker   = get_node_or_null(turn_tracker_path)
	round_manager  = get_node_or_null(round_manager_path)
	challenge_manager = get_node_or_null(challenge_manager_path)

	if turn_tracker and not turn_tracker is TurnTracker:
		if turn_tracker.has("tracker"):
			turn_tracker = turn_tracker.tracker
			print("[GameButtonUI] Extracted TurnTracker from VCRTurnTrackerUI wrapper")
		else:
			turn_tracker = null

	if not dice_hand:
		dice_hand = get_tree().get_first_node_in_group("dice_hand")
		if dice_hand:
			print("[GameButtonUI] Found dice_hand via group fallback")

	if not turn_tracker:
		turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
		if turn_tracker:
			print("[GameButtonUI] Found turn_tracker via turn_tracker group")
		else:
			var game_ui = get_tree().get_first_node_in_group("game_ui")
			if game_ui and game_ui.has_node("MarginContainer/MainVBox/UpperSection/TurnInfoContainer/ContentVBox/VCRTurnTrackerUI"):
				var vcr_ui = game_ui.get_node("MarginContainer/MainVBox/UpperSection/TurnInfoContainer/ContentVBox/VCRTurnTrackerUI")
				if vcr_ui and vcr_ui.tracker:
					turn_tracker = vcr_ui.tracker
					print("[GameButtonUI] Found turn_tracker via VCRTurnTrackerUI.tracker")
				else:
					push_error("[GameButtonUI] VCRTurnTrackerUI found but tracker is null")
			if not turn_tracker:
				push_error("[GameButtonUI] turn_tracker could not be resolved -- gameplay will be broken")

	if turn_tracker and not turn_tracker is TurnTracker:
		if turn_tracker.has("tracker"):
			turn_tracker = turn_tracker.tracker
			print("[GameButtonUI] Final unwrap: extracted TurnTracker from wrapper")
		else:
			turn_tracker = null

	if not score_card_ui:
		var game_ui = get_tree().get_first_node_in_group("game_ui")
		if game_ui and game_ui.has_node("MarginContainer/MainVBox/MiddleSection/RightColumn/ScorecardContainer/ScoreCardUI"):
			score_card_ui = game_ui.get_node("MarginContainer/MainVBox/MiddleSection/RightColumn/ScorecardContainer/ScoreCardUI")
		if score_card_ui:
			print("[GameButtonUI] Found score_card_ui via GameUI fallback")

	if not challenge_manager:
		challenge_manager = get_tree().get_first_node_in_group("challenge_manager") as ChallengeManager
		if challenge_manager:
			print("[GameButtonUI] Found challenge_manager via group fallback")

	if not round_manager:
		round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
		if round_manager:
			print("[GameButtonUI] Found round_manager via group fallback")

	add_to_group("game_button_ui")

	if not score_card_ui:
		push_error("GameButtonUI: score_card_ui_path not set or node missing")
	if not dice_hand:
		push_error("GameButtonUI: dice_hand not found")
	if not turn_tracker:
		push_error("GameButtonUI: turn_tracker not found")

	if next_turn_button and not next_turn_button.pressed.is_connected(_on_next_turn_button_pressed):
		next_turn_button.pressed.connect(_on_next_turn_button_pressed)

	if score_card_ui:
		score_card_ui.connect("manual_score", Callable(self, "_scored_hand_setup_next_round"))

	if shop_button:
		shop_button.disabled = false
		print("Shop button status: ", shop_button.disabled)

	for btn in [shop_button, next_turn_button, next_round_button]:
		if btn:
			if not btn.mouse_entered.is_connected(_tfx.button_hover.bind(btn)):
				btn.mouse_entered.connect(_tfx.button_hover.bind(btn))
			if not btn.mouse_exited.is_connected(_tfx.button_unhover.bind(btn)):
				btn.mouse_exited.connect(_tfx.button_unhover.bind(btn))
			if not btn.pressed.is_connected(_tfx.button_press.bind(btn)):
				btn.pressed.connect(_tfx.button_press.bind(btn))

	if next_round_button and not next_round_button.pressed.is_connected(_on_next_round_button_pressed):
		next_round_button.pressed.connect(_on_next_round_button_pressed)
		next_round_button.disabled = false

	if round_manager:
		round_manager.round_started.connect(_on_round_started)
		round_manager.round_completed.connect(_on_round_completed)

	if challenge_manager:
		challenge_manager.challenge_completed.connect(_on_challenge_completed)
		print("[GameButtonUI] Connected to challenge_manager.challenge_completed signal")
		print("[GameButtonUI] challenge_manager instance:", challenge_manager)
	else:
		push_error("[GameButtonUI] challenge_manager reference is null - CANNOT CONNECT SIGNALS")

	if turn_tracker:
		turn_tracker.connect("game_over", Callable(self, "_on_game_over"))

	next_turn_button.disabled = true

	call_deferred("_connect_roll_ui_signals")


## _connect_roll_ui_signals()
##
## Deferred wiring so RollButtonUI and ScoreCardUI have had time to register.
func _connect_roll_ui_signals() -> void:
	var roll_ui = get_tree().get_first_node_in_group("roll_button_ui")
	if roll_ui:
		if roll_ui.has_signal("dice_rolled") and not roll_ui.dice_rolled.is_connected(_on_roll_ui_dice_rolled):
			roll_ui.dice_rolled.connect(_on_roll_ui_dice_rolled)
		if roll_ui.has_signal("roll_pressed") and not roll_ui.roll_pressed.is_connected(_on_roll_ui_roll_pressed):
			roll_ui.roll_pressed.connect(_on_roll_ui_roll_pressed)
	else:
		push_error("[GameButtonUI] RollButtonUI not found in group -- signals will not be re-emitted")

	# Resolve dice_hand via group if the _ready() path lookup missed it
	# (game_ui.gd adds GameButtonUI before DiceHand, so group lookup fails in _ready())
	if not dice_hand:
		dice_hand = get_tree().get_first_node_in_group("dice_hand")
		if dice_hand:
			print("[GameButtonUI] Resolved dice_hand via group in _connect_roll_ui_signals")
		else:
			push_error("[GameButtonUI] dice_hand not found -- dice exit animation will not work")

	# Resolve score_card_ui via group if the _ready() path lookup missed it
	if not score_card_ui:
		score_card_ui = get_tree().get_first_node_in_group("scorecard_ui")
		if score_card_ui:
			print("[GameButtonUI] Resolved score_card_ui via group in _connect_roll_ui_signals")

	# Connect manual_score → _scored_hand_setup_next_round (dice exit animation on manual score)
	if score_card_ui and score_card_ui.has_signal("manual_score"):
		if not score_card_ui.manual_score.is_connected(_scored_hand_setup_next_round):
			score_card_ui.manual_score.connect(_scored_hand_setup_next_round)
			print("[GameButtonUI] Connected manual_score -> _scored_hand_setup_next_round")

	# Connect next_turn_pressed → ScoreCardUI.auto_score_best_hand
	if score_card_ui and score_card_ui.has_method("auto_score_best_hand"):
		if not next_turn_pressed.is_connected(score_card_ui.auto_score_best_hand):
			next_turn_pressed.connect(score_card_ui.auto_score_best_hand)
			print("[GameButtonUI] Connected next_turn_pressed -> ScoreCardUI.auto_score_best_hand")
	else:
		push_error("[GameButtonUI] ScoreCardUI not found or missing auto_score_best_hand -- auto-score will not work")

	# Lazy-resolve round_manager and reconnect its signals
	if not round_manager:
		round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
		if round_manager:
			print("[GameButtonUI] Resolved round_manager via group in _connect_roll_ui_signals")
	if round_manager:
		if not round_manager.round_started.is_connected(_on_round_started):
			round_manager.round_started.connect(_on_round_started)
			print("[GameButtonUI] Connected round_manager.round_started")
		if not round_manager.round_completed.is_connected(_on_round_completed):
			round_manager.round_completed.connect(_on_round_completed)
			print("[GameButtonUI] Connected round_manager.round_completed")
	else:
		push_error("[GameButtonUI] round_manager not found -- round signals will not fire")

	# Lazy-resolve challenge_manager and reconnect its signals
	if not challenge_manager:
		challenge_manager = get_tree().get_first_node_in_group("challenge_manager") as ChallengeManager
		if challenge_manager:
			print("[GameButtonUI] Resolved challenge_manager via group in _connect_roll_ui_signals")
	if challenge_manager:
		if not challenge_manager.challenge_completed.is_connected(_on_challenge_completed):
			challenge_manager.challenge_completed.connect(_on_challenge_completed)
			print("[GameButtonUI] Connected challenge_manager.challenge_completed")
	else:
		push_error("[GameButtonUI] challenge_manager not found -- challenge_completed will not enable Next Round")


func _on_roll_ui_dice_rolled(dice_values: Array) -> void:
	emit_signal("dice_rolled", dice_values)


func _on_roll_ui_roll_pressed() -> void:
	emit_signal("roll_pressed")


## on_roll_ui_pressed() -> void
##
## Called by RollButtonUI after roll button press. Enables Next Turn.
func on_roll_ui_pressed() -> void:
	next_turn_button.disabled = false


## disable_shop_on_first_roll() -> void
##
## Called by RollButtonUI on the first roll of a round.
func disable_shop_on_first_roll() -> void:
	if shop_button:
		shop_button.disabled = true


## trigger_roll() -> void
##
## Pass-through for backwards-compat with consumables (e.g. DiceSurgeConsumable).
func trigger_roll() -> void:
	var roll_ui = get_tree().get_first_node_in_group("roll_button_ui")
	if roll_ui and roll_ui.has_method("trigger_roll"):
		roll_ui.trigger_roll()
	else:
		print("[GameButtonUI] trigger_roll() -- RollButtonUI not found")


## reset_for_new_channel() -> void
##
## Resets button state for a new channel.
func reset_for_new_channel() -> void:
	print("[GameButtonUI] Resetting for new channel")
	next_turn_button.disabled = true
	if next_round_button:
		next_round_button.disabled = false
	if shop_button:
		shop_button.disabled = false
	_stop_shop_button_pulse()
	var roll_ui = get_tree().get_first_node_in_group("roll_button_ui")
	if roll_ui and roll_ui.has_method("reset_for_new_channel"):
		roll_ui.reset_for_new_channel()
	print("[GameButtonUI] Reset complete")


func _process(delta: float) -> void:
	if _input_cooldown > 0.0:
		_input_cooldown -= delta
		if _input_cooldown < 0.0:
			_input_cooldown = 0.0
	if _button_action_cooldown > 0.0:
		_button_action_cooldown -= delta
		if _button_action_cooldown < 0.0:
			_button_action_cooldown = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not event.is_pressed():
		return
	if _input_cooldown > 0.0:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("next_turn"):
		if next_turn_button and not next_turn_button.disabled and next_turn_button.visible:
			get_viewport().set_input_as_handled()
			_input_cooldown = INPUT_COOLDOWN_DURATION
			_on_next_turn_button_pressed()
			return
	if event.is_action_pressed("shop"):
		if shop_button and not shop_button.disabled and shop_button.visible:
			get_viewport().set_input_as_handled()
			_input_cooldown = INPUT_COOLDOWN_DURATION
			_on_shop_button_pressed()
			return
	if event.is_action_pressed("next_round"):
		if next_round_button and not next_round_button.disabled and next_round_button.visible:
			get_viewport().set_input_as_handled()
			_input_cooldown = INPUT_COOLDOWN_DURATION
			_on_next_round_button_pressed()
			return


func _start_shop_button_pulse() -> void:
	if _is_shop_pulsing or not shop_button:
		return
	if shop_button.disabled:
		return
	_is_shop_pulsing = true
	_tfx.idle_pulse(shop_button)


func _stop_shop_button_pulse() -> void:
	if not _is_shop_pulsing:
		return
	_is_shop_pulsing = false
	_tfx.stop_effect(shop_button)


func _on_next_turn_button_pressed() -> void:
	if _button_action_cooldown > 0.0:
		return
	_button_action_cooldown = BUTTON_ACTION_COOLDOWN
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_next_turn_sound"):
		audio_mgr.play_next_turn_sound()
	var tutorial_manager = get_node_or_null("/root/TutorialManager")
	if tutorial_manager and tutorial_manager.is_tutorial_active():
		tutorial_manager.action_completed("click_next_turn")
	# Lazy-resolve score_card_ui in case _ready() path lookup failed
	if not score_card_ui:
		score_card_ui = get_tree().get_first_node_in_group("scorecard_ui")
	if score_card_ui and not score_card_ui.turn_scored:
		print("[GameButtonUI] Emitting next_turn_pressed for auto-score...")
		emit_signal("next_turn_pressed")
		_scored_hand_setup_next_round()
	if score_card_ui and score_card_ui.scorecard.is_game_complete():
		print("[GameButtonUI] Scorecard complete -- skipping turn advancement")
		return
	print("[GameButtonUI] Starting new turn - enabling roll button")
	if turn_tracker:
		turn_tracker.start_new_turn()
	if score_card_ui:
		score_card_ui.turn_scored = false
		score_card_ui.enable_all_score_buttons()
	if dice_hand:
		dice_hand.set_all_dice_rollable()
	var roll_ui = get_tree().get_first_node_in_group("roll_button_ui")
	if roll_ui:
		roll_ui.enable_roll()
		roll_ui.start_pulse()
	next_turn_button.disabled = true


func _scored_hand_setup_next_round():
	print("[GameButtonUI] Scored hand, setting up next round")
	if dice_hand:
		dice_hand.animate_all_dice_exit()
		print("[GameButtonUI] Triggered dice exit animation")
		dice_hand.set_all_dice_disabled()
		print("[GameButtonUI] Set all dice to DISABLED state after scoring")


func _on_auto_score_assigned(section, category, score):
	print("Auto-assigned", category, "in", section, "for", score, "points")


func _on_game_over() -> void:
	next_turn_button.disabled = true
	if shop_button:
		shop_button.disabled = true
	_stop_shop_button_pulse()


func _on_shop_button_pressed() -> void:
	if _button_action_cooldown > 0.0:
		return
	_button_action_cooldown = BUTTON_ACTION_COOLDOWN
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_shop_open_sound"):
		audio_mgr.play_shop_open_sound()
	print("[GameButtonUI] Shop button pressed")
	_stop_shop_button_pulse()
	is_shop_open = !is_shop_open
	emit_signal("shop_button_pressed")
	emit_signal("shop_opened")
	print("[GameButtonUI] Signals emitted")
	next_turn_button.disabled = true


func _on_round_started(_round_number: int) -> void:
	print("[GameButtonUI] === ROUND STARTED ===")
	print("[GameButtonUI] Round", _round_number, "started")
	if next_round_button:
		next_round_button.disabled = true
		print("[GameButtonUI] NextRound button DISABLED on round start")
	if shop_button:
		print("[GameButtonUI] Round started - disabling shop button")
		_stop_shop_button_pulse()
		shop_button.disabled = true
	next_turn_button.disabled = false
	animate_button_wave()
	_show_turn_banner(_round_number)


func _on_round_completed(_round_number: int) -> void:
	if shop_button:
		shop_button.disabled = false
		_start_shop_button_pulse()
	# Round is now officially done (stats panel dismissed, shop is opening).
	# Enable Next Round so the player can advance after shopping.
	if next_round_button:
		next_round_button.disabled = false
		print("[GameButtonUI] Next Round button enabled on round_completed")


func animate_button_wave() -> void:
	var buttons = [next_turn_button, shop_button, next_round_button]
	for i in range(buttons.size()):
		var btn = buttons[i]
		if not btn or btn.disabled or not btn.visible:
			continue
		btn.pivot_offset = btn.size / 2.0
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.15, 0.85), 0.08).set_delay(i * 0.06)
		tween.tween_property(btn, "scale", Vector2(0.95, 1.05), 0.08)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
			next_turn_button.disabled = true
			if shop_button:
				shop_button.disabled = false
				_start_shop_button_pulse()
		else:
			print("[GameButtonUI] Challenge ID mismatch:", challenge_id, "vs", round_manager.current_challenge_id)


func _on_next_round_button_pressed() -> void:
	if _button_action_cooldown > 0.0:
		return
	_button_action_cooldown = BUTTON_ACTION_COOLDOWN
	if next_round_button:
		next_round_button.disabled = true
	print("[GameButtonUI] Next Round button pressed")
	var shop_ui_node = get_node_or_null("../ShopUI")
	if shop_ui_node and shop_ui_node.visible:
		shop_ui_node.hide()
		is_shop_open = false
		print("[GameButtonUI] Closed open shop on next round press")
	var tutorial_manager = get_node_or_null("/root/TutorialManager")
	if tutorial_manager and tutorial_manager.is_tutorial_active():
		tutorial_manager.action_completed("click_next_round")
	if round_manager:
		print("[GameButtonUI] Current round:", round_manager.get_current_round_number())
	if scoring_animation_controller:
		scoring_animation_controller.cancel_all_animations()
	if dice_hand:
		dice_hand.clear_dice()
	if score_card_ui and score_card_ui.scorecard:
		score_card_ui.scorecard.reset_scores_preserve_levels()
		score_card_ui.update_all()
	emit_signal("next_round_pressed")


## _show_turn_banner(round_number)
##
## Drops in a "TURN N" label at the top of the screen.
func _show_turn_banner(round_number: int) -> void:
	var banner = Label.new()
	banner.name = "TurnBanner"
	banner.text = "TURN %s" % NumberFormatter.format_int(round_number)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_override("font", preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf"))
	banner.add_theme_font_size_override("font_size", 32)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	banner.add_theme_color_override("font_outline_color", Color(0.4, 0.2, 0.0, 1.0))
	banner.add_theme_constant_override("outline_size", 2)
	var viewport_size = get_viewport_rect().size
	banner.position = Vector2(viewport_size.x / 2 - 80, -50)
	banner.custom_minimum_size = Vector2(160, 40)
	get_tree().current_scene.add_child(banner)
	var tween = get_tree().create_tween()
	tween.tween_property(banner, "position:y", 20, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_panel_swoosh"):
		audio_mgr.play_panel_swoosh()
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(banner):
		var fade = get_tree().create_tween()
		fade.tween_property(banner, "modulate:a", 0.0, 0.3)
		fade.tween_callback(func(): if is_instance_valid(banner): banner.queue_free())
