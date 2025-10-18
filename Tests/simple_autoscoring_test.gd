extends Control
class_name SimpleAutoscoringTest

## SimpleAutoscoringTest
##
## Minimal test to verify scorecard signal connections work

@onready var scorecard: Scorecard
@onready var test_label: Label
@onready var test_button: Button

var signals_received = []

func _ready():
	print("[SimpleAutoscoringTest] Starting simple autoscoring test")
	
	# Create UI elements
	test_label = Label.new()
	test_label.text = "Simple Autoscoring Test - Click button to test"
	test_label.position = Vector2(20, 20)
	add_child(test_label)
	
	test_button = Button.new()
	test_button.text = "Test Autoscoring Signals"
	test_button.position = Vector2(20, 60)
	test_button.size = Vector2(200, 40)
	test_button.pressed.connect(_test_autoscoring_signals)
	add_child(test_button)
	
	# Create scorecard 
	scorecard = Scorecard.new()
	add_child(scorecard)
	
	# Connect to signals to monitor
	scorecard.score_assigned.connect(_on_score_assigned)
	scorecard.score_changed.connect(_on_score_changed)
	scorecard.score_auto_assigned.connect(_on_score_auto_assigned)

func _test_autoscoring_signals():
	print("[SimpleAutoscoringTest] Testing autoscoring signals...")
	signals_received.clear()
	
	# Set up test dice values (should score well in ones)
	var test_dice: Array[int] = [1, 1, 1, 2, 3]
	
	# Get initial total
	var initial_total = scorecard.get_total_score()
	print("[SimpleAutoscoringTest] Initial total score:", initial_total)
	
	# Trigger autoscoring
	scorecard.auto_score_best(test_dice)
	
	# Wait a frame for deferred signals
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check results
	var new_total = scorecard.get_total_score()
	print("[SimpleAutoscoringTest] New total score:", new_total)
	print("[SimpleAutoscoringTest] Signals received:", signals_received)
	
	if new_total > initial_total and signals_received.size() > 0:
		test_label.text = "✓ Signals work! Score: " + str(initial_total) + " → " + str(new_total) + " Signals: " + str(signals_received)
		test_label.modulate = Color.GREEN
	elif new_total > initial_total:
		test_label.text = "Partial success - Score changed but no signals: " + str(initial_total) + " → " + str(new_total)
		test_label.modulate = Color.YELLOW
	else:
		test_label.text = "✗ Test failed. Score: " + str(initial_total) + " Signals: " + str(signals_received)
		test_label.modulate = Color.RED

func _on_score_assigned(section: Scorecard.Section, category: String, score: int):
	print("[SimpleAutoscoringTest] score_assigned signal received:", section, category, score)
	signals_received.append("score_assigned")

func _on_score_changed(total_score: int):
	print("[SimpleAutoscoringTest] score_changed signal received. Total:", total_score)
	signals_received.append("score_changed")

func _on_score_auto_assigned(section: Scorecard.Section, category: String, score: int):
	print("[SimpleAutoscoringTest] score_auto_assigned signal received:", section, category, score)
	signals_received.append("score_auto_assigned")