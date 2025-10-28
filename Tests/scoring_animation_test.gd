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

func _on_test_button_pressed() -> void:
	if not scoring_controller:
		print("[ScoringAnimationTest] No scoring controller available!")
		return
	
	# Create mock breakdown info for testing
	var breakdown_info = {
		"base_score": test_score,
		"consumable_contributions": {
			"test_consumable": 5
		},
		"powerup_multipliers": {
			"test_powerup": 1.5
		}
	}
	
	print("[ScoringAnimationTest] Triggering animation for score: %d" % test_score)
	
	# Start the animation
	scoring_controller.start_scoring_animation(test_score, "test_category", breakdown_info)
	
	# Increase test score for next test
	test_score += 10
	score_button.text = "Test Score Animation (%d points)" % test_score
	
	# Update label
	test_label.text = "Animation triggered! Score: %d\nWatch for effects..." % (test_score - 10)