extends Node
class_name ScoringAnimationTest

## ScoringAnimationTest
##
## Test scene to verify scoring animations work correctly

const ScoringAnimationController = preload("res://Scripts/Effects/scoring_animation_controller.gd")

@onready var test_label: Label
@onready var score_button: Button
@onready var test_score: int = 15

var scoring_controller: ScoringAnimationController

func _ready() -> void:
	print("[ScoringAnimationTest] Initializing test scene...")
	
	# Create test UI
	_create_test_ui()
	
	# Create scoring animation controller
	scoring_controller = ScoringAnimationController.new()
	scoring_controller.name = "ScoringAnimationController"
	add_child(scoring_controller)
	
	# Wait for initialization
	await get_tree().process_frame
	
	print("[ScoringAnimationTest] Test scene ready!")

	# Auto-fire once for automated verification runs.
	await get_tree().create_timer(1.5).timeout
	print("[ScoringAnimationTest] AUTO: triggering scoring animation with console sources")
	_on_test_button_pressed()

func _create_test_ui() -> void:
	# Create main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(vbox)

	# Test label
	test_label = Label.new()
	test_label.text = "Scoring Animation Test\nClick button to trigger test animation"
	test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	test_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(test_label)

	# Test button
	score_button = Button.new()
	score_button.text = "Test Score Animation (%d points)" % test_score
	score_button.pressed.connect(_on_test_button_pressed)
	vbox.add_child(score_button)

	# Controls info
	var controls_label = Label.new()
	controls_label.text = "\nControls:\n- Click button to test animations\n- Numbers will increase each test\n- Watch for bouncing dice effects"
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(controls_label)

	# Mock gaming console UI so console chips have a launch origin.
	# Duck-types GamingConsoleUI: group "gaming_console_ui" + _compact_spine.
	var mock_console_ui := Control.new()
	mock_console_ui.name = "MockGamingConsoleUI"
	mock_console_ui.add_to_group("gaming_console_ui")
	add_child(mock_console_ui)
	var mock_spine := Panel.new()
	mock_spine.name = "_compact_spine"
	mock_spine.custom_minimum_size = Vector2(104, 56)
	mock_spine.set_size(Vector2(104, 56))
	mock_spine.position = Vector2(60, 500)
	mock_console_ui.add_child(mock_spine)
	var mock_spine_label := Label.new()
	mock_spine_label.text = "CONSOLE"
	mock_spine_label.set_anchors_preset(Control.PRESET_CENTER)
	mock_spine.add_child(mock_spine_label)

func _on_test_button_pressed() -> void:
	if not scoring_controller:
		print("[ScoringAnimationTest] No scoring controller available!")
		return

	# Create mock breakdown info for testing (includes console sources)
	var breakdown_info = {
		"base_score": test_score,
		"consumable_contributions": {
			"test_consumable": 5
		},
		"powerup_multipliers": {
			"test_powerup": 1.5
		},
		"additive_sources": [
			{"name": "combo_system", "value": 9, "category": "console", "display_name": "Sega"},
		],
		"multiplier_sources": [
			{"name": "blast_processing", "value": 1.5, "category": "console", "display_name": "SNES"},
		],
	}
	
	print("[ScoringAnimationTest] Triggering animation for score: %d" % test_score)
	
	# Start the animation
	scoring_controller.start_scoring_animation(test_score, "test_category", breakdown_info)
	
	# Increase test score for next test
	test_score += 10
	score_button.text = "Test Score Animation (%d points)" % test_score
	
	# Update label
	test_label.text = "Animation triggered! Score: %d\nWatch for effects..." % (test_score - 10)