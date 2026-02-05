extends Control

## empty_shelves_test.gd
##
## Manual test for verifying Empty Shelves consumable multiplier behavior.
## Tests that the multiplier is properly unregistered after first score assignment.

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var multiplier_label: Label = $VBoxContainer/MultiplierLabel
@onready var scores_label: Label = $VBoxContainer/ScoresLabel
@onready var apply_button: Button = $VBoxContainer/ApplyButton
@onready var assign_score_button: Button = $VBoxContainer/AssignScoreButton
@onready var check_button: Button = $VBoxContainer/CheckMultiplierButton
@onready var log_label: RichTextLabel = $VBoxContainer/LogLabel

var mock_scorecard: MockScorecard
var scores_assigned: int = 0
var empty_slots_count: int = 5  # Simulate 5 empty power-up slots

func _ready() -> void:
	_log("Test scene ready")
	
	# Connect buttons
	apply_button.pressed.connect(_on_apply_pressed)
	assign_score_button.pressed.connect(_on_assign_score_pressed)
	check_button.pressed.connect(_on_check_multiplier_pressed)
	
	# Create mock scorecard
	mock_scorecard = MockScorecard.new()
	add_child(mock_scorecard)
	mock_scorecard.add_to_group("scorecard")
	_log("Mock scorecard created")
	
	# Ensure ScoreModifierManager is available
	if ScoreModifierManager:
		_log("ScoreModifierManager found")
		ScoreModifierManager.reset()
		_log("ScoreModifierManager reset")
	else:
		_log("[color=red]ERROR: ScoreModifierManager not found![/color]")
		status_label.text = "Status: ERROR - ScoreModifierManager missing"
		return
	
	status_label.text = "Status: Ready - Press Apply to test"
	_update_multiplier_display()


func _on_apply_pressed() -> void:
	_log("\n[color=yellow]=== APPLYING EMPTY SHELVES MULTIPLIER ===[/color]")
	
	# Directly simulate what EmptyShelvesConsumable.apply() does
	var multiplier_id = "empty_shelves_multiplier"
	
	# Check if already registered
	if ScoreModifierManager.has_multiplier(multiplier_id):
		_log("[color=orange]Multiplier already registered, removing first...[/color]")
		ScoreModifierManager.unregister_multiplier(multiplier_id)
	
	# Register the multiplier (simulating empty_slots_count empty slots)
	ScoreModifierManager.register_multiplier(multiplier_id, empty_slots_count)
	_log("Registered multiplier '%s' with value %d" % [multiplier_id, empty_slots_count])
	
	# Connect to scorecard signal (simulating the consumable's behavior)
	if not mock_scorecard.is_connected("score_auto_assigned", _on_score_assigned_test):
		mock_scorecard.score_auto_assigned.connect(_on_score_assigned_test)
		_log("Connected to score_auto_assigned signal")
	
	await get_tree().process_frame
	_update_multiplier_display()
	
	status_label.text = "Status: Multiplier applied - Now assign a score"


## Simulates EmptyShelvesConsumable._on_score_assigned behavior
func _on_score_assigned_test(_section: int, _category: String, _score: int, _breakdown_info: Dictionary = {}) -> void:
	_log("[color=magenta]>>> _on_score_assigned_test callback triggered <<<[/color]")
	
	var multiplier_id = "empty_shelves_multiplier"
	
	# This is what EmptyShelvesConsumable does:
	if ScoreModifierManager.has_multiplier(multiplier_id):
		ScoreModifierManager.unregister_multiplier(multiplier_id)
		_log("Unregistered multiplier '%s'" % multiplier_id)
	else:
		_log("[color=orange]Multiplier '%s' already removed or not found[/color]" % multiplier_id)
	
	# Disconnect from signal
	if mock_scorecard.is_connected("score_auto_assigned", _on_score_assigned_test):
		mock_scorecard.score_auto_assigned.disconnect(_on_score_assigned_test)
		_log("Disconnected from score_auto_assigned signal")


func _on_assign_score_pressed() -> void:
	scores_assigned += 1
	_log("\n[color=cyan]=== ASSIGNING SCORE #%d ===[/color]" % scores_assigned)
	
	# Check connection status before emitting
	var is_connected = mock_scorecard.is_connected("score_auto_assigned", _on_score_assigned_test)
	_log("Signal connected before emit: %s" % str(is_connected))
	
	# Emit the signal that Empty Shelves listens to
	_log("Emitting score_auto_assigned signal...")
	mock_scorecard.emit_signal("score_auto_assigned", 0, "test_category", 100, {})
	
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for signal processing
	
	_update_multiplier_display()
	scores_label.text = "Scores assigned: %d" % scores_assigned
	
	# Check if multiplier is still registered
	var has_mult = ScoreModifierManager.has_multiplier("empty_shelves_multiplier")
	if scores_assigned == 1:
		if has_mult:
			_log("[color=red]BUG CONFIRMED: Multiplier still registered after 1st score![/color]")
			status_label.text = "Status: BUG - Multiplier persists after 1st score!"
		else:
			_log("[color=green]SUCCESS: Multiplier correctly removed after 1st score[/color]")
			status_label.text = "Status: SUCCESS - Multiplier removed correctly"
	else:
		if has_mult:
			_log("[color=red]BUG: Multiplier re-registered or persisting after %d scores![/color]" % scores_assigned)
		else:
			_log("Multiplier remains unregistered (correct behavior)")


func _on_check_multiplier_pressed() -> void:
	_log("\n[color=white]=== CHECKING MULTIPLIER STATUS ===[/color]")
	_update_multiplier_display()
	
	if ScoreModifierManager.has_multiplier("empty_shelves_multiplier"):
		var mult_value = ScoreModifierManager.get_total_multiplier()
		_log("Multiplier IS registered, total multiplier: %d" % mult_value)
	else:
		_log("Multiplier is NOT registered")
	
	# Check all registered multipliers
	_log("All registered multipliers: %s" % str(ScoreModifierManager.get_active_multiplier_sources()))


func _update_multiplier_display() -> void:
	if ScoreModifierManager.has_multiplier("empty_shelves_multiplier"):
		var value = ScoreModifierManager.get_multiplier("empty_shelves_multiplier")
		multiplier_label.text = "Multiplier registered: YES (value: %d)" % value
		multiplier_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		multiplier_label.text = "Multiplier registered: NO"
		multiplier_label.add_theme_color_override("font_color", Color.GRAY)


func _log(message: String) -> void:
	var timestamp = "[%s] " % Time.get_time_string_from_system()
	log_label.append_text("\n" + timestamp + message)
	print("[EmptyShelvesTest] " + message.replace("[color=", "").replace("[/color]", "").replace("[b]", "").replace("[/b]", ""))


## Mock Scorecard class for testing signal behavior
class MockScorecard:
	extends Node
	
	signal score_auto_assigned(section: int, category: String, score: int, breakdown_info: Dictionary)
	signal score_assigned(section: int, category: String, score: int)
	
	func _init():
		pass
