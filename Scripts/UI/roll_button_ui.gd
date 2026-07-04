extends Control
class_name RollButtonUI

## RollButtonUI
##
## Manages the Roll button, dice rolling logic, pulse animation, tension vignette,
## keyboard roll input, and dice-lock shortcuts. Communicates with GameButtonUI
## via groups for cross-button state coordination (shop disable, next-turn enable).

const ROLL_FONT := preload("res://Resources/Font/BALLOON1.ttf")
const ROLL_HINT_FONT := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const ROLL_BUTTON_SHADER_PATH := "res://Scripts/Shaders/roll_button_glass.gdshader"
const ROLL_BASE := Color(0.247059, 0.219608, 0.345098, 0.98)
const ROLL_PLUM := Color(0.298039, 0.239216, 0.380392, 0.98)
const ROLL_PINK := Color(0.713725, 0.301961, 0.478431, 1.0)
const ROLL_TEAL := Color(0.137255, 0.411765, 0.415686, 1.0)
const ROLL_TEXT := Color(0.968627, 0.941176, 1.0, 1.0)
const ROLL_TEXT_SOFT := Color(0.780392, 0.733333, 0.866667, 1.0)
const ROLL_TEXT_DISABLED := Color(0.592157, 0.572549, 0.65098, 0.95)

@onready var roll_button_shell: Control = $CenterContainer/RollButtonShell
@onready var roll_button_visual: ColorRect = $CenterContainer/RollButtonShell/ShaderRect
@onready var roll_button_label: Label = $CenterContainer/RollButtonShell/ContentMargin/ContentVBox/RollLabel
@onready var roll_button_hint_label: Label = $CenterContainer/RollButtonShell/ContentMargin/ContentVBox/HintLabel
@onready var roll_button: Button = $CenterContainer/RollButtonShell/RollButton
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
var _is_hovered: bool = false
var _roll_shader_material: ShaderMaterial
var _hover_strength: float = 0.0
var _proximity_strength: float = 0.0
var _motion_strength: float = 0.0
var _mouse_uv: Vector2 = Vector2(0.5, 0.5)
var _last_mouse_local: Vector2 = Vector2.ZERO
var _press_flash_tween: Tween

## Keyboard input cooldown to prevent multiple rapid presses
var _input_cooldown: float = 0.0
const INPUT_COOLDOWN_DURATION: float = 0.75

## General button action cooldown to prevent mouse spam
var _button_action_cooldown: float = 0.0
const BUTTON_ACTION_COOLDOWN: float = 0.35

## Prevents roll from being triggered while a roll animation is already in progress
var _roll_in_progress: bool = false
var _pending_round_start_number: int = -1


func _ready() -> void:
	add_to_group("roll_button_ui")
	_setup_roll_button_visuals()

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
	if roll_button and not roll_button.mouse_entered.is_connected(_on_roll_mouse_entered):
		roll_button.mouse_entered.connect(_on_roll_mouse_entered)
	if roll_button and not roll_button.mouse_exited.is_connected(_on_roll_mouse_exited):
		roll_button.mouse_exited.connect(_on_roll_mouse_exited)

	# TweenFX hover / press effects
	if roll_button_shell:
		if not roll_button.mouse_entered.is_connected(_tfx.button_hover.bind(roll_button_shell)):
			roll_button.mouse_entered.connect(_tfx.button_hover.bind(roll_button_shell))
		if not roll_button.mouse_exited.is_connected(_tfx.button_unhover.bind(roll_button_shell)):
			roll_button.mouse_exited.connect(_tfx.button_unhover.bind(roll_button_shell))
		if not roll_button.pressed.is_connected(_tfx.button_press.bind(roll_button_shell)):
			roll_button.pressed.connect(_tfx.button_press.bind(roll_button_shell))

	# Connect to dice_hand
	if dice_hand:
		if not dice_hand.roll_complete.is_connected(_on_dice_roll_complete):
			dice_hand.roll_complete.connect(_on_dice_roll_complete)

	# Connect to turn_tracker
	if turn_tracker:
		turn_tracker.rolls_exhausted.connect(_on_rolls_exhausted)
		turn_tracker.turn_started.connect(_on_turn_started)
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
	_refresh_roll_button_visual_state()

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

	if not round_manager:
		round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
		if round_manager:
			print("[RollButtonUI] Resolved round_manager via group in _connect_game_btn_signals")
	if round_manager and not round_manager.round_started.is_connected(_on_round_started):
		round_manager.round_started.connect(_on_round_started)
		print("[RollButtonUI] Connected round_manager.round_started")

	# Resolve score_card_ui now that the full UI tree is built
	if not score_card_ui:
		score_card_ui = get_tree().get_first_node_in_group("scorecard_ui")
	if score_card_ui and not score_card_ui.hand_scored.is_connected(_hand_scored_disable):
		score_card_ui.hand_scored.connect(_hand_scored_disable)


func _setup_roll_button_visuals() -> void:
	if not roll_button or not roll_button_visual:
		return
	var shader_resource := load(ROLL_BUTTON_SHADER_PATH) as Shader
	if shader_resource == null:
		push_error("[RollButtonUI] Failed to load roll button shader at %s" % ROLL_BUTTON_SHADER_PATH)
		return

	_roll_shader_material = ShaderMaterial.new()
	_roll_shader_material.shader = shader_resource
	roll_button_visual.material = _roll_shader_material
	roll_button_visual.color = Color.WHITE
	_roll_shader_material.set_shader_parameter("press_origin", Vector2(0.5, 0.5))
	_roll_shader_material.set_shader_parameter("spark_strength", 0.0)

	var empty_style := StyleBoxEmpty.new()
	roll_button.text = ""
	roll_button.flat = true
	roll_button.focus_mode = Control.FOCUS_NONE
	roll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	roll_button.add_theme_stylebox_override("normal", empty_style)
	roll_button.add_theme_stylebox_override("hover", empty_style)
	roll_button.add_theme_stylebox_override("pressed", empty_style)
	roll_button.add_theme_stylebox_override("disabled", empty_style)
	roll_button.add_theme_stylebox_override("focus", empty_style)

	if roll_button_label:
		roll_button_label.add_theme_font_override("font", ROLL_FONT)
		roll_button_label.add_theme_font_size_override("font_size", 34)
		roll_button_label.add_theme_color_override("font_color", ROLL_TEXT)
		roll_button_label.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
		roll_button_label.add_theme_constant_override("outline_size", 2)

	if roll_button_hint_label:
		roll_button_hint_label.add_theme_font_override("font", ROLL_HINT_FONT)
		roll_button_hint_label.add_theme_font_size_override("font_size", 12)
		roll_button_hint_label.add_theme_color_override("font_color", ROLL_TEXT_SOFT)
		roll_button_hint_label.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 0.95))
		roll_button_hint_label.add_theme_constant_override("outline_size", 1)

	_refresh_roll_button_visual_state()


func _on_roll_mouse_entered() -> void:
	_is_hovered = true


func _on_roll_mouse_exited() -> void:
	_is_hovered = false


func _refresh_roll_button_visual_state() -> void:
	var is_disabled := roll_button == null or roll_button.disabled
	if roll_button_label:
		roll_button_label.modulate = ROLL_TEXT_DISABLED if is_disabled else Color.WHITE
	if roll_button_hint_label:
		roll_button_hint_label.modulate = Color(0.701961, 0.682353, 0.760784, 0.85) if is_disabled else Color.WHITE
	if roll_button_shell:
		roll_button_shell.modulate = Color(1.0, 1.0, 1.0, 0.88) if is_disabled else Color.WHITE
	if _roll_shader_material:
		_roll_shader_material.set_shader_parameter("base_color", ROLL_BASE)
		_roll_shader_material.set_shader_parameter("mid_color", ROLL_PLUM)
		_roll_shader_material.set_shader_parameter("glow_color", ROLL_PINK)
		_roll_shader_material.set_shader_parameter("accent_color", ROLL_TEAL)
		_roll_shader_material.set_shader_parameter("rim_color", ROLL_TEXT)
		_roll_shader_material.set_shader_parameter("disabled_factor", 1.0 if is_disabled else 0.0)


func _update_roll_button_visual_response(delta: float) -> void:
	if not _roll_shader_material or not roll_button_shell:
		return
	if roll_button_shell.size.x <= 0.0 or roll_button_shell.size.y <= 0.0:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var rect := Rect2(roll_button_shell.global_position, roll_button_shell.size)
	var rect_end := rect.position + rect.size
	var clamped_mouse := Vector2(
		clampf(mouse_pos.x, rect.position.x, rect_end.x),
		clampf(mouse_pos.y, rect.position.y, rect_end.y)
	)
	var local_mouse := clamped_mouse - rect.position
	var target_uv := Vector2(
		local_mouse.x / maxf(rect.size.x, 1.0),
		local_mouse.y / maxf(rect.size.y, 1.0)
	)
	var distance := mouse_pos.distance_to(clamped_mouse)
	var max_distance := maxf(rect.size.x, rect.size.y) * 1.22
	var target_proximity := 1.0 - clampf(distance / max_distance, 0.0, 1.0)
	target_proximity = pow(target_proximity, 0.85)
	if roll_button.disabled:
		target_proximity *= 0.18
	var target_hover := 1.0 if (_is_hovered and not roll_button.disabled) else 0.0
	var speed := local_mouse.distance_to(_last_mouse_local) / maxf(delta, 0.001)
	var target_motion := clampf(speed / 950.0, 0.0, 1.0) * maxf(target_proximity, target_hover)

	_mouse_uv = _mouse_uv.lerp(target_uv, clampf(delta * 12.0, 0.0, 1.0))
	_hover_strength = lerpf(_hover_strength, target_hover, clampf(delta * 10.0, 0.0, 1.0))
	_proximity_strength = lerpf(_proximity_strength, target_proximity, clampf(delta * 8.0, 0.0, 1.0))
	_motion_strength = lerpf(_motion_strength, target_motion, clampf(delta * 10.0, 0.0, 1.0))
	_last_mouse_local = local_mouse

	_roll_shader_material.set_shader_parameter("aspect_ratio", rect.size.x / maxf(rect.size.y, 1.0))
	_roll_shader_material.set_shader_parameter("mouse_uv", _mouse_uv)
	_roll_shader_material.set_shader_parameter("hover_strength", _hover_strength)
	_roll_shader_material.set_shader_parameter("proximity_strength", _proximity_strength)
	_roll_shader_material.set_shader_parameter("motion_strength", _motion_strength)
	_roll_shader_material.set_shader_parameter("pulse_strength", 1.0 if (_is_pulsing and not roll_button.disabled) else 0.0)


func _flash_roll_button_shader(strength: float = 1.0, press_uv: Vector2 = Vector2(0.5, 0.5)) -> void:
	if not _roll_shader_material:
		return
	if _press_flash_tween and _press_flash_tween.is_valid():
		_press_flash_tween.kill()
	_roll_shader_material.set_shader_parameter("press_origin", press_uv)
	_roll_shader_material.set_shader_parameter("press_flash", strength)
	_roll_shader_material.set_shader_parameter("spark_strength", strength)
	_press_flash_tween = create_tween()
	_press_flash_tween.tween_method(
		func(value: float):
			_roll_shader_material.set_shader_parameter("press_flash", value)
			var normalized := value / maxf(strength, 0.001)
			_roll_shader_material.set_shader_parameter("spark_strength", pow(normalized, 1.7) * strength),
		strength,
		0.0,
		0.36
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _get_roll_button_center() -> Vector2:
	if roll_button_shell:
		return roll_button_shell.global_position + (roll_button_shell.size / 2.0)
	return roll_button.global_position + (roll_button.size / 2.0)


func _get_roll_button_press_uv() -> Vector2:
	if not roll_button_shell:
		return Vector2(0.5, 0.5)
	var rect := Rect2(roll_button_shell.global_position, roll_button_shell.size)
	var mouse_pos := get_viewport().get_mouse_position()
	if not rect.has_point(mouse_pos) and _proximity_strength < 0.3:
		return Vector2(0.5, 0.5)
	return Vector2(
		clampf((mouse_pos.x - rect.position.x) / maxf(rect.size.x, 1.0), 0.0, 1.0),
		clampf((mouse_pos.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)
	)


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
	_refresh_roll_button_visual_state()


## disable_roll() -> void
##
## Disables the roll button and clears roll-in-progress state.
func disable_roll() -> void:
	if roll_button:
		roll_button.disabled = true
	_is_hovered = false
	_roll_in_progress = false
	_refresh_roll_button_visual_state()


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
	_update_roll_button_visual_response(delta)


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


func _is_round_start_gate_active() -> bool:
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_method("is_round_start_chore_gate_active"):
		return game_controller.is_round_start_chore_gate_active()
	return false


func _on_turn_started() -> void:
	if _is_round_start_gate_active():
		return
	enable_roll()
	start_pulse()


func _activate_round_start(round_number: int) -> void:
	enable_roll()
	_start_roll_button_pulse()

	# Bounce animation on the roll button
	if roll_button_shell and not roll_button.disabled:
		roll_button_shell.pivot_offset = roll_button_shell.size / 2.0
		var tween = create_tween()
		tween.tween_property(roll_button_shell, "scale", Vector2(1.12, 0.9), 0.08)
		tween.tween_property(roll_button_shell, "scale", Vector2(0.97, 1.04), 0.08)
		tween.tween_property(roll_button_shell, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_flash_roll_button_shader(0.45, Vector2(0.5, 0.5))

	# Spawn dice and auto-roll at round start
	if dice_hand:
		print("[RollButtonUI] Spawning dice for round", round_number)
		dice_hand.spawn_dice()
		await get_tree().create_timer(0.3).timeout
		_on_roll_button_pressed()


func release_round_start_gate() -> void:
	var round_number = _pending_round_start_number
	if round_number < 0:
		if not round_manager:
			round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
		round_number = round_manager.get_current_round_number() if round_manager else 1
	_pending_round_start_number = -1
	_activate_round_start(round_number)


func _start_roll_button_pulse() -> void:
	if _is_pulsing or not roll_button:
		return
	if roll_button.disabled:
		return
	_is_pulsing = true
	_tfx.idle_pulse(roll_button_shell, 0.055)
	print("[RollButtonUI] Starting Roll button pulse animation")


func _stop_roll_button_pulse() -> void:
	if not _is_pulsing:
		return
	_is_pulsing = false
	_tfx.stop_effect(roll_button_shell)
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
	_is_hovered = false
	_refresh_roll_button_visual_state()
	_flash_roll_button_shader(1.0, _get_roll_button_press_uv())
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
	if _is_round_start_gate_active():
		_pending_round_start_number = _round_number
		return
	_pending_round_start_number = -1
	_activate_round_start(_round_number)


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
	_tfx.stop_effect(roll_button_shell)

	if dice_hand:
		for die in dice_hand.dice_list:
			if is_instance_valid(die):
				var t = get_tree().create_tween()
				t.tween_property(die, "scale", Vector2(0.95, 0.95), 0.2)
				t.tween_property(die, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)

	_tfx.negative_hit(roll_button_shell)

	var toast = Label.new()
	toast.text = "OUT OF ROLLS"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_override("font", preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf"))
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	toast.position = _get_roll_button_center() - Vector2(86, 42)
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
		ftx.show_popup_at_position(get_tree().current_scene, _get_roll_button_center() + Vector2(0, -56), text, Color(1.0, 0.8, 0.2), 1.2)
