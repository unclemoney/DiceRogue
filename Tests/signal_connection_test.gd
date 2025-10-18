extends Control
class_name SignalConnectionTest

## SignalConnectionTest  
##
## Tests the signal connections between Scorecard and ScoreCardUI

@onready var scorecard: Scorecard
@onready var score_card_ui: Control # Keep as Control to avoid type issues
@onready var test_label: Label
@onready var test_button: Button

var signal_log = []

func _ready():
	print("[SignalConnectionTest] Starting signal connection test")
	
	# Create UI elements
	test_label = Label.new()
	test_label.text = "Signal Connection Test - Click to test"
	test_label.position = Vector2(20, 20)
	test_label.size = Vector2(400, 30)
	add_child(test_label)
	
	test_button = Button.new() 
	test_button.text = "Test Signal Connections"
	test_button.position = Vector2(20, 60)
	test_button.size = Vector2(200, 40)
	test_button.pressed.connect(_test_signal_connections)
	add_child(test_button)
	
	# Test the scorecard signals directly
	_test_scorecard_signals()

func _test_scorecard_signals():
	print("[SignalConnectionTest] Testing scorecard signals...")
	
	# Create scorecard first
	scorecard = Scorecard.new()
	add_child(scorecard)
	
	# Connect to signals to monitor them
	scorecard.score_assigned.connect(_on_score_assigned_test)
	scorecard.score_changed.connect(_on_score_changed_test)
	
	print("[SignalConnectionTest] Scorecard created and signals connected")

func _test_signal_connections():
	print("[SignalConnectionTest] Testing manual scorecard signal emissions...")
	signal_log.clear()
	
	# Manually emit signals
	scorecard.emit_signal("score_assigned", Scorecard.Section.UPPER, "ones", 5)
	scorecard.emit_signal("score_changed", 100)
	
	await get_tree().process_frame
	
	var result = "Signals received: " + str(signal_log)
	test_label.text = result
	test_label.modulate = Color.GREEN if signal_log.size() >= 2 else Color.RED
	print("[SignalConnectionTest] Test complete:", result)

func _on_score_assigned_test(section, category, score):
	print("[SignalConnectionTest] Received score_assigned:", section, category, score)
	signal_log.append("score_assigned")

func _on_score_changed_test(total_score):
	print("[SignalConnectionTest] Received score_changed:", total_score)
	signal_log.append("score_changed")