extends PowerUp
class_name SweetSixteenPowerUp

## SweetSixteenPowerUp
##
## An uncommon PowerUp that grants $16 at the start of each turn.
## When the player reaches turn 16 and scores above 0,
## awards a one-time $256 bonus for that turn.
##
## Connects to TurnTracker's turn_updated signal for per-turn money
## and Scorecard's score_assigned signal for the turn-16 bonus check.

var turn_tracker_ref: Node = null
var scorecard_ref: Node = null
var game_controller_ref = null

var _current_turn: int = 0
var _turn_16_bonus_awarded: bool = false
var total_earned: int = 0

const MONEY_PER_TURN: int = 16
const TURN_16_BONUS: int = 256
const BONUS_TURN: int = 16

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[SweetSixteenPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying SweetSixteenPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[SweetSixteenPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Find GameController for turn_tracker access
	game_controller_ref = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller_ref and game_controller_ref.turn_tracker:
		turn_tracker_ref = game_controller_ref.turn_tracker
		
		if not turn_tracker_ref.is_connected("turn_updated", _on_turn_updated):
			turn_tracker_ref.turn_updated.connect(_on_turn_updated)
			print("[SweetSixteenPowerUp] Connected to turn_updated signal")
		
		# Capture current turn immediately in case we're mid-game
		_current_turn = turn_tracker_ref.current_turn
	else:
		push_error("[SweetSixteenPowerUp] Could not find TurnTracker via GameController")
		return
	
	# Connect to score_assigned for turn-16 bonus detection
	if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.connect(_on_score_assigned)
		print("[SweetSixteenPowerUp] Connected to score_assigned signal")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[SweetSixteenPowerUp] Applied successfully - will grant $%d per turn, $%d bonus on turn %d" % [MONEY_PER_TURN, TURN_16_BONUS, BONUS_TURN])

func _on_turn_updated(turn: int) -> void:
	_current_turn = turn
	
	# Reset turn-16 bonus flag when a new round starts (turn resets to 1)
	if turn == 1:
		_turn_16_bonus_awarded = false
	
	# Grant per-turn money
	PlayerEconomy.add_money(MONEY_PER_TURN)
	total_earned += MONEY_PER_TURN
	print("[SweetSixteenPowerUp] Turn %d started! Granted $%d (total earned: $%d)" % [turn, MONEY_PER_TURN, total_earned])
	
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func _on_score_assigned(_section, _category: String, score: int) -> void:
	if _current_turn == BONUS_TURN and score > 0 and not _turn_16_bonus_awarded:
		PlayerEconomy.add_money(TURN_16_BONUS)
		total_earned += TURN_16_BONUS
		_turn_16_bonus_awarded = true
		print("[SweetSixteenPowerUp] TURN %d BONUS! Scored %d points. Granted $%d bonus! (total earned: $%d)" % [BONUS_TURN, score, TURN_16_BONUS, total_earned])
		
		emit_signal("description_updated", id, get_current_description())
		
		if is_inside_tree():
			_update_power_up_icons()

func remove(_target) -> void:
	print("=== Removing SweetSixteenPowerUp ===")
	
	if turn_tracker_ref:
		if turn_tracker_ref.is_connected("turn_updated", _on_turn_updated):
			turn_tracker_ref.turn_updated.disconnect(_on_turn_updated)
			print("[SweetSixteenPowerUp] Disconnected from turn_updated signal")
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
			print("[SweetSixteenPowerUp] Disconnected from score_assigned signal")
	
	turn_tracker_ref = null
	scorecard_ref = null
	game_controller_ref = null

func get_current_description() -> String:
	var base_desc = "Grants $%d per turn. Turn %d score bonus: $%d" % [MONEY_PER_TURN, BONUS_TURN, TURN_16_BONUS]
	
	if _turn_16_bonus_awarded:
		base_desc += "\n✓ Turn %d bonus collected!" % BONUS_TURN
	
	if total_earned > 0:
		base_desc += "\nTotal earned: $%d" % total_earned
	
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("sweet_sixteen")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_tree_exiting() -> void:
	if turn_tracker_ref:
		if turn_tracker_ref.is_connected("turn_updated", _on_turn_updated):
			turn_tracker_ref.turn_updated.disconnect(_on_turn_updated)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	
	print("[SweetSixteenPowerUp] Cleanup: Disconnected signals")
