extends Control
class_name AutoscoringUITest

## AutoscoringUITest
##
## Tests whether the ScoreCardUI properly updates when autoscoring is triggered

@onready var scorecard: Scorecard
@onready var score_card_ui: ScoreCardUI
@onready var test_label: Label
@onready var test_button: Button

func _ready():
	print("[AutoscoringUITest] Starting autoscoring UI test")
	
	# Create UI elements
	test_label = Label.new()
	test_label.text = "Autoscoring UI Test - Click button to test"
	test_label.position = Vector2(20, 20)
	add_child(test_label)
	
	test_button = Button.new()
	test_button.text = "Test Autoscoring"
	test_button.position = Vector2(20, 60)
	test_button.size = Vector2(200, 40)
	test_button.pressed.connect(_test_autoscoring)
	add_child(test_button)
	
	# Create scorecard and UI
	scorecard = Scorecard.new()
	add_child(scorecard)
	
	# Create a minimal ScoreCardUI for testing
	score_card_ui = ScoreCardUI.new()
	add_child(score_card_ui)
	
	# Bind them together
	score_card_ui.bind_scorecard(scorecard)
	
	# Connect to signals to monitor
	score_card_ui.hand_scored.connect(_on_hand_scored)
	scorecard.score_assigned.connect(_on_score_assigned)
	scorecard.score_changed.connect(_on_score_changed)

func _test_autoscoring():
	print("[AutoscoringUITest] Testing autoscoring...")
	
	# Set up test dice values (should score well in ones)
	var test_dice = [1, 1, 1, 2, 3]
	
	# Get initial total
	var initial_total = scorecard.get_total_score()
	print("[AutoscoringUITest] Initial total score:", initial_total)
	
	# Trigger autoscoring
	scorecard.auto_score_best(test_dice)
	
	# Check if total changed
	await get_tree().process_frame
	var new_total = scorecard.get_total_score()
	print("[AutoscoringUITest] New total score:", new_total)
	
	if new_total > initial_total:
		test_label.text = "✓ Autoscoring worked! Score: " + str(initial_total) + " → " + str(new_total)
		test_label.modulate = Color.GREEN
	else:
		test_label.text = "✗ Autoscoring failed. Score unchanged: " + str(initial_total)
		test_label.modulate = Color.RED

func _on_hand_scored():
	print("[AutoscoringUITest] hand_scored signal received from ScoreCardUI")

func _on_score_assigned(section: Scorecard.Section, category: String, score: int):
	print("[AutoscoringUITest] score_assigned signal received:", section, category, score)

func _on_score_changed(total_score: int):
	print("[AutoscoringUITest] score_changed signal received. Total:", total_score)