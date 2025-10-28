extends Node
class_name SimpleScoringAnimationTest

## SimpleScoringAnimationTest
##
## Simplified test scene for testing floating number effects and basic animations

const FloatingNumber = preload("res://Scripts/Effects/floating_number.gd")

@onready var test_label: Label
@onready var floating_test_button: Button
@onready var bounce_test_button: Button
@onready var test_dice: Array[Control] = []

var test_score: int = 10
var test_audio: AudioStreamPlayer

func _ready() -> void:
	print("[SimpleScoringAnimationTest] Initializing...")
	
	# Create test UI
	_create_test_ui()
	_create_test_dice()
	
	# Create audio player
	test_audio = AudioStreamPlayer.new()
	add_child(test_audio)
	
	print("[SimpleScoringAnimationTest] Ready!")

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
	instructions.text = "\nInstructions:\n- Click buttons to test different animations\n- Watch for floating numbers and bouncing effects\n- Audio pitch scales with score"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(instructions)

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