extends Consumable
class_name GoBrokeOrGoHomeConsumable

## GoBrokeOrGoHomeConsumable
##
## This consumable MUST be used at the beginning of a turn (after Next Turn, before first Roll).
## The player must manually select a category from the LOWER section only.
## If the player scores > 0, their money is doubled.
## If the player scores 0, they lose all their money.

# Signals for consumable events
signal go_broke_or_go_home_applied
signal money_doubled(original_amount: int, new_amount: int)
signal money_lost(lost_amount: int)

var is_active: bool = false
var turn_activated: int = -1
var game_controller_ref: GameController = null
var scorecard_ref: Scorecard = null
var score_card_ui_ref: ScoreCardUI = null
var has_scored: bool = false
var original_money: int = 0

func _ready() -> void:
	add_to_group("consumables")
	print("[GoBrokeOrGoHomeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[GoBrokeOrGoHomeConsumable] Invalid target passed to apply()")
		return
	
	# Store references
	game_controller_ref = game_controller
	scorecard_ref = game_controller.scorecard
	score_card_ui_ref = game_controller.score_card_ui
	
	if not scorecard_ref:
		push_error("[GoBrokeOrGoHomeConsumable] No scorecard found in game controller")
		return
	
	if not score_card_ui_ref:
		push_error("[GoBrokeOrGoHomeConsumable] No ScoreCardUI found in game controller")
		return
	
	# Get current turn number
	var turn_tracker = game_controller.turn_tracker
	if not turn_tracker:
		push_error("[GoBrokeOrGoHomeConsumable] No turn tracker found")
		return
	
	# Check if there are any open lower section categories
	if not _has_open_lower_categories():
		print("[GoBrokeOrGoHomeConsumable] No open lower section categories available")
		return
	
	# Store the turn we're activated on and current money
	turn_activated = turn_tracker.current_turn
	original_money = PlayerEconomy.money if PlayerEconomy else 0
	is_active = true
	has_scored = false
	
	print("[GoBrokeOrGoHomeConsumable] Applied for turn %d with $%d at stake" % [turn_activated, original_money])
	
	# Activate the special lower-section-only scoring mode
	_activate_go_broke_mode()
	
	# Connect to score assignment signals to monitor scoring
	if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.connect(_on_score_assigned)
		print("[GoBrokeOrGoHomeConsumable] Connected to score_assigned signal")
	
	if not scorecard_ref.is_connected("score_auto_assigned", _on_score_auto_assigned):
		scorecard_ref.score_auto_assigned.connect(_on_score_auto_assigned)
		print("[GoBrokeOrGoHomeConsumable] Connected to score_auto_assigned signal")
	
	# Connect to turn_started signal to detect if we're no longer on the active turn
	if not turn_tracker.is_connected("turn_started", _on_turn_started):
		turn_tracker.turn_started.connect(_on_turn_started)
		print("[GoBrokeOrGoHomeConsumable] Connected to turn_started signal")
	
	emit_signal("go_broke_or_go_home_applied")

## _has_open_lower_categories()
##
## Checks if there are any open (unscored) categories in the lower section
func _has_open_lower_categories() -> bool:
	for category in scorecard_ref.lower_scores.keys():
		if scorecard_ref.lower_scores[category] == null:
			return true
	return false

## _activate_go_broke_mode()
##
## Sets up the special UI state for GoBrokeOrGoHome mode - only lower section categories enabled
func _activate_go_broke_mode() -> void:
	print("[GoBrokeOrGoHomeConsumable] Activating Go Broke or Go Home mode - lower section only")
	
	# Disable all upper section buttons
	for category in score_card_ui_ref.upper_section_buttons.keys():
		var button = score_card_ui_ref.upper_section_buttons[category]
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5)  # Gray out disabled buttons
	
	# Enable only open lower section buttons
	for category in score_card_ui_ref.lower_section_buttons.keys():
		var button = score_card_ui_ref.lower_section_buttons[category]
		var has_score = scorecard_ref.lower_scores[category] != null
		
		if has_score:
			# Already scored - disable
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5)  # Gray out
		else:
			# Open category - enable with special highlighting
			button.disabled = false
			button.modulate = Color(1.5, 0.8, 0.8)  # Red highlight for high-risk mode
	
	# Set the go broke mode flag (we'll add this to ScoreCardUI)
	if score_card_ui_ref.has_method("set_go_broke_mode"):
		score_card_ui_ref.set_go_broke_mode(true)

## _deactivate_go_broke_mode()
##
## Deactivates the special Go Broke or Go Home mode and restores normal button states
func _deactivate_go_broke_mode() -> void:
	print("[GoBrokeOrGoHomeConsumable] Deactivating Go Broke or Go Home mode")
	
	if not score_card_ui_ref:
		return
	
	# Reset all button states
	for button in score_card_ui_ref.upper_section_buttons.values():
		button.modulate = Color.WHITE
		button.disabled = true  # Will be properly set by normal game logic
	
	for button in score_card_ui_ref.lower_section_buttons.values():
		button.modulate = Color.WHITE
		button.disabled = true  # Will be properly set by normal game logic
	
	# Clear the go broke mode flag
	if score_card_ui_ref.has_method("set_go_broke_mode"):
		score_card_ui_ref.set_go_broke_mode(false)

func _on_score_assigned(section: int, category: String, score: int) -> void:
	if not is_active:
		return
	
	# Only care about lower section scores
	if section != Scorecard.Section.LOWER:
		print("[GoBrokeOrGoHomeConsumable] Ignoring upper section score:", category)
		return
	
	print("[GoBrokeOrGoHomeConsumable] Lower section score assigned: %s = %d" % [category, score])
	_handle_score_result(category, score)

func _on_score_auto_assigned(section: int, category: String, score: int, _breakdown_info: Dictionary = {}) -> void:
	if not is_active:
		return
	
	# Only care about lower section scores
	if section != Scorecard.Section.LOWER:
		print("[GoBrokeOrGoHomeConsumable] Ignoring upper section auto-score:", category)
		return
	
	print("[GoBrokeOrGoHomeConsumable] Lower section auto-score assigned: %s = %d" % [category, score])
	_handle_score_result(category, score)

## _handle_score_result(category, score)
##
## Processes the scoring result and applies money doubling or loss
func _handle_score_result(category: String, score: int) -> void:
	if has_scored:
		return  # Already processed a score
		
	has_scored = true
	
	if score > 0:
		# Success! Double the money
		var new_money = original_money * 2
		if PlayerEconomy:
			PlayerEconomy.money = new_money
			PlayerEconomy.emit_signal("money_changed", new_money)
		
		print("[GoBrokeOrGoHomeConsumable] SUCCESS! Scored %d in %s - Money doubled from $%d to $%d" % [score, category, original_money, new_money])
		emit_signal("money_doubled", original_money, new_money)
	else:
		# Failure! Lose all money
		if PlayerEconomy:
			PlayerEconomy.money = 0
			PlayerEconomy.emit_signal("money_changed", 0)
		
		print("[GoBrokeOrGoHomeConsumable] FAILURE! Scored 0 in %s - Lost all money ($%d)" % [category, original_money])
		emit_signal("money_lost", original_money)
	
	# Deactivate after scoring
	_deactivate()

func _on_turn_started() -> void:
	if not is_active:
		return
	
	# If a new turn has started and we haven't scored, deactivate
	var turn_tracker = game_controller_ref.turn_tracker if game_controller_ref else null
	if turn_tracker and turn_tracker.current_turn != turn_activated:
		print("[GoBrokeOrGoHomeConsumable] Turn changed without scoring, deactivating")
		_deactivate()

func _deactivate() -> void:
	if not is_active:
		return
		
	print("[GoBrokeOrGoHomeConsumable] Deactivating")
	is_active = false
	
	# Deactivate the UI mode
	_deactivate_go_broke_mode()
	
	# Disconnect from signals
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		if scorecard_ref.is_connected("score_auto_assigned", _on_score_auto_assigned):
			scorecard_ref.score_auto_assigned.disconnect(_on_score_auto_assigned)
	
	if game_controller_ref and game_controller_ref.turn_tracker:
		var turn_tracker = game_controller_ref.turn_tracker
		if turn_tracker.is_connected("turn_started", _on_turn_started):
			turn_tracker.turn_started.disconnect(_on_turn_started)
	
	# Clear references
	game_controller_ref = null
	scorecard_ref = null
	score_card_ui_ref = null