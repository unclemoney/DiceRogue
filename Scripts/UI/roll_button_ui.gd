extends Control
class_name RollButtonUI

## RollButtonUI
##
## Manages the Roll button, dice rolling logic, pulse animation, tension vignette,
## keyboard roll input, and dice-lock shortcuts. Communicates with GameButtonUI
## via groups for cross-button state coordination (shop disable, next-turn enable).

@onready var roll_button: Button = $CenterContainer/RollButton
@onready var _tfx := get_node("/root/TweenFXHelper")

signal roll_pressed
signal dice_rolled(dice_values: Array)

var dice_hand
var score_card_ui
var turn_tracker
var round_manager: RoundManager

var first_roll_done: bool = false

## Pulse animation state
var _is_pulsing: bool = false

## Keyboard input cooldown to prevent multiple rapid presses
var _input_cooldown: float = 0.0
const INPUT_COOLDOWN_DURATION: float = 0.75

## General button action cooldown to prevent mouse spam
var _button_action_cooldown: float = 0.0
const BUTTON_ACTION_COOLDOWN: float = 0.35

## Prevents roll from being triggered while a roll animation is already in progress
var _roll_in_progress: bool = false


func _ready() -> void:
	add_to_group("roll_button_ui")

	# Resolve dice_hand
	dice_hand = get_tree().get_first_node_in_group("dice_hand")

	# Resolve turn_tracker
	turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if turn_tracker and not turn_tracker is TurnTracker:
		if turn_tracker.has("tracker"):
			turn_tracker = turn_tracker.tracker
		else:
			turn_tracker = null
	if not turn_tracker:
		var ui_root = get_tree().get_first_node_in_group("game_ui")
		if ui_root and ui_root.has_node("MarginContainer/MainVBox/UpperSection/TurnInfoContainer/ContentVBox/VCRTurnTrackerUI"):
			var vcr_ui = ui_root.get_node("MarginContainer/MainVBox/UpperSection/TurnInfoContainer/ContentVBox/VCRTurnTrackerUI")
			if vcr_ui and vcr_ui.tracker:
				turn_tracker = vcr_ui.tracker
	if turn_tracker and not turn_tracker is TurnTracker:
		if turn_tracker.has("tracker"):
			turn_tracker = turn_tracker.tracker
		else:
			turn_tracker = null

	# Resolve score_card_ui
	var game_ui_node = get_tree().get_first_node_in_group("game_ui")
	if game_ui_node and game_ui_node.has_node("MarginContainer/MainVBox/MiddleSection/RightColumn/ScorecardContainer/ScoreCardUI"):
		score_card_ui = game_ui_node.get_node("MarginContainer/MainVBox/MiddleSection/RightColumn/ScorecardContainer/ScoreCardUI")

	# Resolve round_manager
	round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager

	# Connect roll button
	if roll_button and not roll_button.pressed.is_connected(_on_roll_button_pressed):
		roll_button.pressed.connect(_on_roll_button_pressed)

	# TweenFX hover / press effects
	if roll_button:
		if not roll_button.mouse_entered.is_connected(_tfx.button_hover.bind(roll_button)):
			roll_button.mouse_entered.connect(_tfx.button_hover.bind(roll_button))
		if not roll_button.mouse_exited.is_connected(_tfx.button_unhover.bind(roll_button)):
			roll_button.mouse_exited.connect(_tfx.button_unhover.bind(roll_button))
		if not roll_button.pressed.is_connected(_tfx.button_press.bind(roll_button)):
			roll_button.pressed.connect(_tfx.button_press.bind(roll_button))

	# Connect to dice_hand
	if dice_hand:
		if not dice_hand.roll_complete.is_connected(_on_dice_roll_complete):
			dice_hand.roll_complete.connect(_on_dice_roll_complete)

	# Connect to turn_tracker
	if turn_tracker:
		turn_tracker.rolls_exhausted.connect(_on_rolls_exhausted)
		turn_tracker.turn_started.connect(func(): enable_roll(); start_pulse())
		turn_tracker.rolls_updated.connect(_on_rolls_updated)
		turn_tracker.connect("game_over", Callable(self, "_on_game_over"))

	# Connect to round_manager
	if round_manager:
		round_manager.round_started.connect(_on_round_started)

	# score_card_ui resolved deferred (added after this node in _build_ui)

	# Score streak popup
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_signal("score_streak_changed"):
		game_controller.score_streak_changed.connect(_on_score_streak_changed)

	# Tension vignette
	_create_tension_vignette()

	# Start disabled
	roll_button.disabled = true

	# Deferred cross-UI signal wiring — allows GameButtonUI time to add itself to its group
	call_deferred("_connect_game_btn_signals")


## _connect_game_btn_signals()
##
## Deferred wiring so GameButtonUI and ScoreCardUI have had time to register.
func _connect_game_btn_signals() -> void:
	var game_btn = get_tree().get_first_node_in_group("game_button_ui")
	if game_btn and game_btn.has_signal("shop_opened"):
		if not game_btn.shop_opened.is_connected(_on_shop_opened):
			game_btn.shop_opened.connect(_on_shop_opened)

	# Resolve score_card_ui now that the full UI tree is built
	if not score_card_ui:
		score_card_ui = get_tree().get_first_node_in_group("scorecard_ui")
	if score_card_ui and not score_card_ui.hand_scored.is_connected(_hand_scored_disable):
		score_card_ui.hand_scored.connect(_hand_scored_disable)


## _on_shop_opened()
##
## Called when the shop is opened. Disables roll until next turn.
func _on_shop_opened() -> void:
	disable_roll()
	stop_pulse()


## enable_roll() -> void
##
## Enables the roll button.
func enable_roll() -> void:
	if roll_button:
		roll_button.disabled = false


## disable_roll() -> void
##
## Disables the roll button and clears roll-in-progress state.
func disable_roll() -> void:
	if roll_button:
		roll_button.disabled = true
	_roll_in_progress = false


## start_pulse() -> void
##
## Public wrapper to start the roll button pulse animation.
func start_pulse() -> void:
	_start_roll_button_pulse()


## stop_pulse() -> void
##
## Public wrapper to stop the roll button pulse animation.
func stop_pulse() -> void:
	_stop_roll_button_pulse()


## reset_for_new_channel() -> void
##
## Resets roll button state for a new channel.
func reset_for_new_channel() -> void:
	first_roll_done = false
	disable_roll()
	_stop_roll_button_pulse()
	print("[RollButtonUI] Reset for new channel")


## trigger_roll() -> void
##
## Programmatically triggers a dice roll.
## Used by consumables like Dice Surge.
func trigger_roll() -> void:
	if roll_button and not roll_button.disabled and roll_button.visible:
		print("[RollButtonUI] trigger_roll() called")
		_on_roll_button_pressed()
	else:
		print("[RollButtonUI] trigger_roll() ignored - roll button not available")


## on_roll_ui_pressed() — alias kept so GameButtonUI can call it as well
func _process(delta: float) -> void:
	if _input_cooldown > 0.0:
		_input_cooldown -= delta
		if _input_cooldown < 0.0:
			_input_cooldown = 0.0
	if _button_action_cooldown > 0.0:
		_button_action_cooldown -= delta
		if _button_action_cooldown < 0.0:
			_button_action_cooldown = 0.0


## _unhandled_input(event)
##
## Handles Roll keybind and dice-lock shortcuts.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not event.is_pressed():
		return
	if _input_cooldown > 0.0:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("roll"):
		if roll_button and not roll_button.disabled and roll_button.visible:
			get_viewport().set_input_as_handled()
			_input_cooldown = INPUT_COOLDOWN_DURATION
			_on_roll_button_pressed()
			return
	_handle_dice_lock_input(event)


## _handle_dice_lock_input(event)
##
## Handles dice lock keybindings (lock_dice_1 through lock_dice_16).
func _handle_dice_lock_input(event: InputEvent) -> void:
	if not dice_hand:
		return
	for i in range(1, 17):
		var action_name = "lock_dice_%d" % i
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
			_toggle_die_lock(i - 1)
			get_viewport().set_input_as_handled()
			return


## _toggle_die_lock(index)
##
## Toggles the lock state of the die at the given 0-based index.
func _toggle_die_lock(index: int) -> void:
	if not dice_hand:
		return
	var dice_list = dice_hand.dice_list
	if index < 0 or index >= dice_list.size():
		return
	var die = dice_list[index]
	if die and die.has_method("toggle_lock"):
		die.toggle_lock()
		print("[RollButtonUI] Toggled lock on die %d" % (index + 1))


func _start_roll_button_pulse() -> void:
	if _is_pulsing or not roll_button:
		return
	if roll_button.disabled:
		return
	_is_pulsing = true
	_tfx.idle_pulse(roll_button)
	print("[RollButtonUI] Starting Roll button pulse animation")


func _stop_roll_button_pulse() -> void:
	if not _is_pulsing:
		return
	_is_pulsing = false
	_tfx.stop_effect(roll_button)
	print("[RollButtonUI] Stopped Roll button pulse animation")


func _on_roll_button_pressed() -> void:
	if _button_action_cooldown > 0.0 or _roll_in_progress:
		return
	if not dice_hand:
		push_error("[RollButtonUI] Roll pressed but dice_hand is null")
		return

	_button_action_cooldown = BUTTON_ACTION_COOLDOWN
	_roll_in_progress = true
	roll_button.disabled = true
	_stop_roll_button_pulse()

	emit_signal("roll_pressed")

	print("[RollButtonUI] Roll button pressed. Dice list size:", dice_hand.dice_list.size())

	# Notify GameButtonUI: enable next turn button
	var game_btn = get_tree().get_first_node_in_group("game_button_ui")
	if game_btn and game_btn.has_method("on_roll_ui_pressed"):
		game_btn.on_roll_ui_pressed()

	# On first roll, disable the shop
	if not first_roll_done:
		first_roll_done = true
		if game_btn and game_btn.has_method("disable_shop_on_first_roll"):
			game_btn.disable_shop_on_first_roll()

	if dice_hand.dice_list.is_empty():
		print("[RollButtonUI] Dice list empty - spawning new dice")
		await dice_hand.spawn_dice()
		print("[RollButtonUI] Spawn complete, proceeding to roll")
	else:
		print("[RollButtonUI] Dice list not empty - updating dice count")
		dice_hand.update_dice_count()

	dice_hand.prepare_dice_for_roll()
	print("[RollButtonUI] Rolling dice (preserving locks)")
	dice_hand.roll_all()
	print("▶ Roll pressed — using dice_count =", dice_hand.dice_count)


func _on_dice_roll_complete() -> void:
	# Lazy-resolve score_card_ui in case it was added after this node's _ready()
	if not score_card_ui:
		score_card_ui = get_tree().get_first_node_in_group("scorecard_ui")

	if score_card_ui:
		score_card_ui.turn_scored = false
	if turn_tracker:
		turn_tracker.use_roll()

	_roll_in_progress = false
	if turn_tracker and turn_tracker.rolls_left > 0:
		enable_roll()

	var dice_values = dice_hand.get_current_dice_values()
	emit_signal("dice_rolled", dice_values)

	if score_card_ui:
		score_card_ui.update_best_hand_preview(DiceResults.values)


func _on_game_over() -> void:
	disable_roll()
	_stop_roll_button_pulse()


## _hand_scored_disable()
##
## Disables roll when a scoring category is chosen.
func _hand_scored_disable() -> void:
	print("[RollButtonUI] Hand scored—disabling Roll button")
	disable_roll()
	_stop_roll_button_pulse()


## _on_round_started(_round_number)
##
## Side-effects: enables roll button, starts pulse, bounces button, spawns dice and auto-rolls.
func _on_round_started(_round_number: int) -> void:
	enable_roll()
	_start_roll_button_pulse()

	# Bounce animation on the roll button
	if roll_button and not roll_button.disabled:
		roll_button.pivot_offset = roll_button.size / 2.0
		var tween = create_tween()
		tween.tween_property(roll_button, "scale", Vector2(1.15, 0.85), 0.08)
		tween.tween_property(roll_button, "scale", Vector2(0.95, 1.05), 0.08)
		tween.tween_property(roll_button, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Spawn dice and auto-roll at round start
	if dice_hand:
		print("[RollButtonUI] Spawning dice for round", _round_number)
		dice_hand.spawn_dice()
		await get_tree().create_timer(0.3).timeout
		_on_roll_button_pressed()


func _create_tension_vignette() -> void:
	var vignette = ColorRect.new()
	vignette.name = "TensionVignette"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.8, 0.1, 0.1, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.visible = false
	add_child(vignette)


func _show_tension_vignette() -> void:
	var vignette = get_node_or_null("TensionVignette")
	if not vignette:
		return
	vignette.visible = true
	var tween = create_tween()
	tween.tween_property(vignette, "color:a", 0.15, 0.3)


func _hide_tension_vignette() -> void:
	var vignette = get_node_or_null("TensionVignette")
	if not vignette:
		return
	var tween = create_tween()
	tween.tween_property(vignette, "color:a", 0.0, 0.2)
	tween.tween_callback(func(): vignette.visible = false)


## _on_rolls_updated(_rolls_left)
func _on_rolls_updated(_rolls_left: int) -> void:
	pass


## _on_rolls_exhausted()
##
## Handles feedback when player runs out of rolls.
func _on_rolls_exhausted() -> void:
	disable_roll()
	_hide_tension_vignette()
	_tfx.stop_effect(roll_button)

	if dice_hand:
		for die in dice_hand.dice_list:
			if is_instance_valid(die):
				var t = get_tree().create_tween()
				t.tween_property(die, "scale", Vector2(0.95, 0.95), 0.2)
				t.tween_property(die, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)

	_tfx.negative_hit(roll_button)

	var toast = Label.new()
	toast.text = "OUT OF ROLLS"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_override("font", preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf"))
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	toast.position = roll_button.global_position - Vector2(60, 40)
	get_tree().current_scene.add_child(toast)
	var t_tween = get_tree().create_tween()
	t_tween.tween_property(toast, "position:y", toast.position.y - 30, 0.4).set_trans(Tween.TRANS_BACK)
	t_tween.parallel().tween_property(toast, "modulate:a", 0.0, 0.8).set_delay(0.6)
	t_tween.tween_callback(func(): if is_instance_valid(toast): toast.queue_free())


## _on_score_streak_changed(multiplier)
##
## Spawns a floating streak popup near the roll button.
func _on_score_streak_changed(multiplier: float) -> void:
	if multiplier <= 1.0:
		return
	var text = "%.1fx STREAK!" % multiplier
	var ftx = get_node_or_null("/root/FloatingTextManager")
	if ftx:
		ftx.show_popup_at_position(get_tree().current_scene, roll_button.global_position + Vector2(0, -50), text, Color(1.0, 0.8, 0.2), 1.2)
