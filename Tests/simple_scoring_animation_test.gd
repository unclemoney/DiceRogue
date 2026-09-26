extends Node
class_name SimpleScoringAnimationTest

## SimpleScoringAnimationTest
##
## Test scene for the score-sink scoring animation pipeline. Four scenario
## buttons fire the real ScoringAnimationController with synthetic
## breakdown_info against a MockScoringRig (mock dice + spine shelves).
## Also retains the original floating-number and dice-bounce sandboxes.
##
## Run with F6 / Run Current Scene — no other setup needed.
## Headless hooks: `-- --auto-scenario N` fires scenario N after startup,
## `-- --auto-quit SECONDS` quits automatically.

const FloatingNumber = preload("res://Scripts/Effects/floating_number.gd")
const MockScoringRigScript = preload("res://Tests/mock_scoring_rig.gd")

# --- Scenario constants (edit these to tweak scenarios) ---
# 1: Small score, no additives, no multipliers
const SCN1_DICE: Array[int] = [3, 5]            # dice total 8
# 2: Dice + consumable additive + powerup additive (no multipliers)
const SCN2_DICE: Array[int] = [4, 3, 5]         # dice total 12
const SCN2_ADD_CONSUMABLE: int = 4
const SCN2_ADD_POWERUP: int = 6                 # final 22
# 3: Full chain: additives, then scorecard / colored-dice / consumable /
#    powerup multipliers
const SCN3_DICE: Array[int] = [5, 4, 5]         # dice total 14
const SCN3_ADD_CONSUMABLE: int = 5
const SCN3_ADD_POWERUP: int = 7                 # subtotal 26
const SCN3_MULT_SCORECARD: float = 1.5
const SCN3_MULT_COLORED: float = 2.0
const SCN3_MULT_CONSUMABLE: float = 1.25
const SCN3_MULT_POWERUP: float = 1.5            # final round(26*5.625) = 146
# 4: Extreme score 50+ to hit the epic tier (blow-up shake + jackpot path)
const SCN4_DICE: Array[int] = [6, 6, 6, 6, 6]   # dice total 30
const SCN4_ADD_POWERUP: int = 30                # final 60

const SCN2_CONSUMABLE_ID: String = "test_tonic"
const SCN2_POWERUP_ID: String = "test_battery"
const SCN3_CONSUMABLE_ID: String = "test_tonic"
const SCN3_POWERUP_ID: String = "test_battery"
const SCN3_MULT_CONSUMABLE_ID: String = "test_charm"
const SCN3_MULT_POWERUP_ID: String = "test_engine"
const SCN4_POWERUP_ID: String = "test_nuke"

const SCN1_SCORE: int = 8
const SCN2_SCORE: int = 22
const SCN3_SCORE: int = 146
const SCN4_SCORE: int = 60

@onready var test_label: Label
@onready var floating_test_button: Button
@onready var bounce_test_button: Button
@onready var test_dice: Array[Control] = []

var test_score: int = 10
var test_audio: AudioStreamPlayer

var scoring_controller: ScoringAnimationController
var rig: MockScoringRig
var total_label: Label
var scenario_buttons: Array[Button] = []

func _ready() -> void:
	print("[SimpleScoringAnimationTest] Initializing...")

	# Mock rig first so its groups exist before the controller searches
	rig = MockScoringRigScript.new()
	rig.name = "MockScoringRig"
	add_child(rig)

	# Real scoring animation controller driving the mock rig
	scoring_controller = ScoringAnimationController.new()
	scoring_controller.name = "ScoringAnimationController"
	add_child(scoring_controller)

	# Create test UI
	_create_test_ui()
	_create_test_dice()
	_create_scenario_panel()
	_create_total_label()

	# Create audio player
	test_audio = AudioStreamPlayer.new()
	add_child(test_audio)

	print("[SimpleScoringAnimationTest] Ready!")
	_autopilot()

func _create_test_ui() -> void:
	# Create main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(vbox)

	# Test label
	test_label = Label.new()
	test_label.text = "Simple Scoring Animation Test"
	test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	test_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(test_label)

	# Spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Floating number test button
	floating_test_button = Button.new()
	floating_test_button.text = "Test Floating Numbers (%d)" % test_score
	floating_test_button.pressed.connect(_on_floating_test_pressed)
	vbox.add_child(floating_test_button)

	# Dice bounce test button
	bounce_test_button = Button.new()
	bounce_test_button.text = "Test Dice Bounce Animation"
	bounce_test_button.pressed.connect(_on_bounce_test_pressed)
	vbox.add_child(bounce_test_button)

	# Instructions
	var instructions = Label.new()
	instructions.text = "\nInstructions:\n- Scenario buttons (right panel) drive the sink pipeline\n- Old buttons test floating numbers / bounces\n- Audio pitch steps per sink arrival"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(instructions)

## _create_scenario_panel()
##
## Right-side mall-core panel with the four scenario buttons.
func _create_scenario_panel() -> void:
	var panel = PanelContainer.new()
	panel.name = "ScenarioPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -230
	panel.offset_right = -20
	panel.offset_top = -160
	panel.offset_bottom = 160

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	style.border_color = Color(0.3, 0.25, 0.35, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.corner_detail = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "SCORING SCENARIOS"
	title.add_theme_font_override("font", FloatingNumber.VCR_FONT)
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var labels = [
		"1: Small (%d)" % SCN1_SCORE,
		"2: Additives (%d)" % SCN2_SCORE,
		"3: Full Chain (%d)" % SCN3_SCORE,
		"4: Epic (%d)" % SCN4_SCORE,
	]
	for i in range(labels.size()):
		var button = Button.new()
		button.text = labels[i]
		button.add_theme_font_override("font", FloatingNumber.VCR_FONT)
		button.pressed.connect(_run_scenario.bind(i + 1))
		vbox.add_child(button)
		scenario_buttons.append(button)
		_wire_button_fx(button)

## _wire_button_fx(button)
##
## TweenFXHelper hover/press feedback, guarded for headless runs.
func _wire_button_fx(button: Button) -> void:
	var tfx = get_node_or_null("/root/TweenFXHelper")
	if not tfx:
		return
	button.mouse_entered.connect(tfx.button_hover.bind(button))
	button.mouse_exited.connect(tfx.button_unhover.bind(button))
	button.pressed.connect(tfx.button_press.bind(button))

## _create_total_label()
##
## Mock score label the drain phase counts up (group hook the controller
## discovers without needing a real ScoreCardUI).
func _create_total_label() -> void:
	var caption = Label.new()
	caption.text = "TOTAL"
	caption.add_theme_font_override("font", FloatingNumber.VCR_FONT)
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	caption.offset_left = -60
	caption.offset_right = 60
	caption.offset_top = -90
	caption.offset_bottom = -70
	add_child(caption)

	total_label = Label.new()
	total_label.text = "0"
	total_label.add_theme_font_override("font", FloatingNumber.VCR_FONT)
	total_label.add_theme_font_size_override("font_size", 36)
	total_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	total_label.add_theme_color_override("font_outline_color", Color.BLACK)
	total_label.add_theme_constant_override("outline_size", 4)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	total_label.offset_left = -100
	total_label.offset_right = 100
	total_label.offset_top = -66
	total_label.offset_bottom = -20
	total_label.add_to_group("score_sink_drain_target")
	add_child(total_label)

## _run_scenario(index)
##
## Configure the mock rig, build the synthetic breakdown_info, and fire the
## scoring animation pipeline.
func _run_scenario(index: int) -> void:
	print("[SimpleScoringAnimationTest] Running scenario %d" % index)
	match index:
		1:
			rig.configure(SCN1_DICE, [], [])
			var breakdown = _build_breakdown(SCN1_DICE, [], [])
			scoring_controller.start_scoring_animation(SCN1_SCORE, "test_small", breakdown)
		2:
			rig.configure(SCN2_DICE, [SCN2_CONSUMABLE_ID], [SCN2_POWERUP_ID])
			var breakdown = _build_breakdown(SCN2_DICE,
				[
					{"name": SCN2_CONSUMABLE_ID, "category": "consumable", "value": SCN2_ADD_CONSUMABLE},
					{"name": SCN2_POWERUP_ID, "category": "powerup", "value": SCN2_ADD_POWERUP},
				],
				[],
				{"active_consumables": [SCN2_CONSUMABLE_ID], "active_powerups": [SCN2_POWERUP_ID]})
			scoring_controller.start_scoring_animation(SCN2_SCORE, "test_additives", breakdown)
		3:
			rig.configure(SCN3_DICE, [SCN3_CONSUMABLE_ID, SCN3_MULT_CONSUMABLE_ID], [SCN3_POWERUP_ID, SCN3_MULT_POWERUP_ID])
			var breakdown = _build_breakdown(SCN3_DICE,
				[
					{"name": SCN3_CONSUMABLE_ID, "category": "consumable", "value": SCN3_ADD_CONSUMABLE},
					{"name": SCN3_POWERUP_ID, "category": "powerup", "value": SCN3_ADD_POWERUP},
				],
				[
					{"name": SCN3_MULT_CONSUMABLE_ID, "category": "consumable", "value": SCN3_MULT_CONSUMABLE},
					{"name": SCN3_MULT_POWERUP_ID, "category": "powerup", "value": SCN3_MULT_POWERUP},
				],
				{
					"active_consumables": [SCN3_CONSUMABLE_ID, SCN3_MULT_CONSUMABLE_ID],
					"active_powerups": [SCN3_POWERUP_ID, SCN3_MULT_POWERUP_ID],
					"effective_regular_multiplier": SCN3_MULT_SCORECARD,
					"effective_dice_color_multiplier": SCN3_MULT_COLORED,
				})
			scoring_controller.start_scoring_animation(SCN3_SCORE, "test_full_chain", breakdown)
		4:
			rig.configure(SCN4_DICE, [], [SCN4_POWERUP_ID])
			var breakdown = _build_breakdown(SCN4_DICE,
				[{"name": SCN4_POWERUP_ID, "category": "powerup", "value": SCN4_ADD_POWERUP}],
				[],
				{"active_powerups": [SCN4_POWERUP_ID]})
			scoring_controller.start_scoring_animation(SCN4_SCORE, "yahtzee", breakdown)

## _build_breakdown(dice_values, additive_sources, multiplier_sources, extras) -> Dictionary
##
## Synthetic breakdown_info mirroring Scorecard.calculate_score_with_breakdown.
func _build_breakdown(dice_values: Array, additive_sources: Array, multiplier_sources: Array, extras: Dictionary = {}) -> Dictionary:
	var used: Array = []
	var base = 0
	for i in range(dice_values.size()):
		used.append(i)
		base += int(dice_values[i])
	var breakdown = {
		"base_score": base,
		"dice_values": dice_values,
		"used_dice_indices": used,
		"active_consumables": [],
		"active_powerups": [],
		"additive_sources": additive_sources,
		"multiplier_sources": multiplier_sources,
	}
	# NOTE: Dictionary.merge() does not overwrite existing keys — assign.
	for key in extras.keys():
		breakdown[key] = extras[key]
	return breakdown

## _unhandled_input(event)
##
## Keyboard shortcuts 1-4 fire the scenarios (manual testing convenience).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_run_scenario(1)
			KEY_2:
				_run_scenario(2)
			KEY_3:
				_run_scenario(3)
			KEY_4:
				_run_scenario(4)

## _autopilot()
##
## Headless verification hooks:
## `-- --auto-scenario N` fires scenario N after startup,
## `-- --auto-quit SECONDS` quits automatically,
## `-- --auto-shots` saves viewport screenshots every 0.4s to
## Tests/_layout_shots/ for visual verification.
func _autopilot() -> void:
	var args = OS.get_cmdline_user_args()
	var scenario_index = args.find("--auto-scenario")
	if scenario_index >= 0 and scenario_index + 1 < args.size():
		var scenario = int(args[scenario_index + 1])
		await get_tree().create_timer(0.6).timeout
		_run_scenario(scenario)
	# `-- --auto-interrupt N M DELAY` fires scenario N, then scenario M
	# DELAY seconds later — exercises the mid-animation restart path.
	var interrupt_index = args.find("--auto-interrupt")
	if interrupt_index >= 0 and interrupt_index + 3 < args.size():
		var first = int(args[interrupt_index + 1])
		var second = int(args[interrupt_index + 2])
		var interrupt_delay = float(args[interrupt_index + 3])
		await get_tree().create_timer(0.6).timeout
		_run_scenario(first)
		await get_tree().create_timer(interrupt_delay).timeout
		print("[SimpleScoringAnimationTest] Interrupting with scenario %d" % second)
		_run_scenario(second)
	if args.has("--auto-shots"):
		_auto_shots()
	# `-- --auto-negative` fires a one-off event with a negative additive and
	# a divisor multiplier — exercises the red spiral-in / shrink path.
	if args.has("--auto-negative"):
		await get_tree().create_timer(0.6).timeout
		rig.configure(SCN2_DICE, [SCN2_CONSUMABLE_ID], [SCN2_POWERUP_ID])
		var breakdown = _build_breakdown(SCN2_DICE,
			[
				{"name": SCN2_CONSUMABLE_ID, "category": "consumable", "value": SCN2_ADD_CONSUMABLE},
				{"name": SCN2_POWERUP_ID, "category": "powerup", "value": -3},
			],
			[{"name": "test_divisor", "category": "powerup", "value": 0.5}],
			{"active_consumables": [SCN2_CONSUMABLE_ID], "active_powerups": [SCN2_POWERUP_ID, "test_divisor"]})
		# 12 + 4 - 3 = 13, then ÷2 → 7 (rounded)
		scoring_controller.start_scoring_animation(7, "test_negative", breakdown)
	var quit_index = args.find("--auto-quit")
	if quit_index >= 0 and quit_index + 1 < args.size():
		var seconds = float(args[quit_index + 1])
		await get_tree().create_timer(seconds).timeout
		print("[SimpleScoringAnimationTest] Auto-quit after %.1fs" % seconds)
		get_tree().quit()

## _auto_shots()
##
## Periodically saves viewport screenshots until the scene quits.
func _auto_shots() -> void:
	var dir = "res://Tests/_layout_shots/"
	DirAccess.make_dir_recursive_absolute(dir)
	var shot_index = 0
	while true:
		await get_tree().create_timer(0.4).timeout
		var image = get_viewport().get_texture().get_image()
		image.save_png(dir + "scoring_sink_shot_%02d.png" % shot_index)
		shot_index += 1

# ---------------------------------------------------------------------------
# Original sandbox tests (floating numbers / dice bounce), unchanged.
# ---------------------------------------------------------------------------

func _create_test_dice() -> void:
	# Create mock dice for bounce testing
	var dice_container = HBoxContainer.new()
	dice_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	dice_container.position = Vector2(100, -150)
	add_child(dice_container)

	for i in range(5):
		var die = ColorRect.new()
		die.size = Vector2(60, 60)
		die.color = Color.WHITE

		# Add die face number
		var label = Label.new()
		label.text = str(i + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.BLACK)
		die.add_child(label)

		dice_container.add_child(die)
		test_dice.append(die)

# TODO: colored-dice visual coverage — inject real Dice instances here
# (replace MockDie entries in rig.dice_hand.dice_list) if the owner wants
# the colored-dice emphasis path exercised in this scene.

func _on_floating_test_pressed() -> void:
	print("[SimpleScoringAnimationTest] Testing floating numbers...")

	# Create floating numbers at various positions
	var viewport_size = get_viewport().get_visible_rect().size
	var positions = [
		viewport_size / 2,  # Center
		Vector2(viewport_size.x * 0.25, viewport_size.y * 0.3),  # Top left
		Vector2(viewport_size.x * 0.75, viewport_size.y * 0.3),  # Top right
		Vector2(viewport_size.x * 0.5, viewport_size.y * 0.7),   # Bottom center
	]

	var values = [str(test_score), "+15", "x2.0", "BONUS!"]
	var colors = [Color.GOLD, Color.GREEN, Color.CYAN, Color.MAGENTA]
	var scales = [2.0, 1.2, 1.5, 1.8]

	# Calculate speed scale based on score (simulate the main system)
	var speed_scale = 1.0
	if test_score >= 50:
		speed_scale = 1.6
	elif test_score >= 30:
		speed_scale = 1.4
	elif test_score >= 15:
		speed_scale = 1.2

	for i in range(positions.size()):
		var floating_number = FloatingNumber.create_floating_number(
			self, positions[i], values[i], scales[i], colors[i]
		)
		# Apply speed scaling to test
		if floating_number:
			floating_number.float_duration = floating_number.float_duration / speed_scale

	# Play test audio with pitch based on score
	_play_test_audio(test_score)

	# Update status
	test_label.text = "Score: %d (Speed: %.1fx)\nFloating numbers with VCR font!" % [test_score, speed_scale]

	# Increase score for next test
	test_score += 5
	floating_test_button.text = "Test Floating Numbers (%d)" % test_score

func _on_bounce_test_pressed() -> void:
	print("[SimpleScoringAnimationTest] Testing dice bounce...")

	# Animate all test dice with bounces
	for i in range(test_dice.size()):
		var die = test_dice[i]
		var delay = i * 0.1

		# Create bounce animation with delay
		get_tree().create_timer(delay).timeout.connect(func(): _start_die_bounce(die))

func _start_die_bounce(die: Control) -> void:
	# Store original position
	var original_pos = die.position

	# Create bounce animation
	var bounce_tween = create_tween()
	bounce_tween.tween_method(func(progress: float): _bounce_die(die, original_pos, progress), 0.0, 1.0, 0.6)

	# Change color briefly to show it's being animated
	var color_tween = create_tween()
	color_tween.tween_property(die, "color", Color.YELLOW, 0.1)
	color_tween.tween_property(die, "color", Color.WHITE, 0.5)

func _bounce_die(die: Control, original_pos: Vector2, progress: float) -> void:
	if not die:
		return

	var bounce_height = 20.0
	var bounce_offset = sin(progress * PI) * bounce_height
	die.position = original_pos + Vector2(0, -bounce_offset)

func _play_test_audio(score: int) -> void:
	if not test_audio:
		return

	# Calculate pitch based on score (similar to our main controller)
	var base_pitch = 1.0
	var max_pitch = 2.0
	var pitch_scale_factor = 0.02

	var pitch = base_pitch + (score * pitch_scale_factor)
	pitch = min(pitch, max_pitch)

	test_audio.pitch_scale = pitch

	print("[SimpleScoringAnimationTest] Would play audio with pitch: %.2f" % pitch)
	# Note: No actual audio stream assigned for testing
