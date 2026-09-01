extends Debuff
class_name HailSatanDebuff

## HailSatanDebuff
##
## When the player rolls and the resulting hand shows 3 or more sixes
## (locked dice included — DiceResults is synced before roll_complete
## fires), the debuff triggers: the turn immediately ends and a 0 is
## scored in a random unscored category, no matter what power-ups are
## owned. set_score() never emits about_to_score (the power-up pre-calc
## hook) and legacy score modifiers clamp at 0, so the scratch sticks.
##
## Target: GameController (set by GameController.apply_debuff).

var _game_controller: GameController = null
var _triggering: bool = false


func _ready() -> void:
	add_to_group("debuffs")


func apply(new_target) -> void:
	var game_controller = new_target as GameController
	if not game_controller:
		push_error("[HailSatanDebuff] Invalid target — expected GameController")
		return
	_game_controller = game_controller
	self.target = new_target
	is_active = true
	var dice_hand = _game_controller.dice_hand
	if not dice_hand:
		push_error("[HailSatanDebuff] No dice_hand on GameController")
		return
	if not dice_hand.is_connected("roll_complete", _on_roll_complete):
		dice_hand.roll_complete.connect(_on_roll_complete)
	print("[HailSatanDebuff] Applied — watching rolls for 3 sixes")


func remove() -> void:
	if _game_controller and _game_controller.dice_hand:
		var dice_hand = _game_controller.dice_hand
		if dice_hand.is_connected("roll_complete", _on_roll_complete):
			dice_hand.roll_complete.disconnect(_on_roll_complete)
	_game_controller = null
	_triggering = false
	is_active = false
	print("[HailSatanDebuff] Removed")


## _on_roll_complete()
##
## Counts sixes in the full hand (locked dice included) and forfeits the
## turn when 3 or more are showing.
func _on_roll_complete() -> void:
	if not is_active or _triggering:
		return
	if not _game_controller:
		return
	var sixes := 0
	for value in DiceResults.values:
		if value == 6:
			sixes += 1
	if sixes < 3:
		return
	_triggering = true
	print("[HailSatanDebuff] HAIL SATAN! %d sixes rolled — turn forfeited" % sixes)
	request_visual_pulse(1.0, 0.6)
	_forfeit_turn()
	_triggering = false


## _forfeit_turn()
##
## Scores a 0 in a random unscored category, then mirrors the Next Turn
## tail (see GameButtonUI._on_next_turn_button_pressed) so the turn ends
## immediately and the game advances.
func _forfeit_turn() -> void:
	var scorecard = _game_controller.scorecard
	var turn_tracker = _game_controller.turn_tracker
	var dice_hand = _game_controller.dice_hand
	var score_card_ui = get_tree().get_first_node_in_group("scorecard_ui")
	if not scorecard or not turn_tracker or not dice_hand:
		push_error("[HailSatanDebuff] Missing scorecard/turn_tracker/dice_hand — cannot forfeit turn")
		return
	if score_card_ui and score_card_ui.turn_scored:
		# Hand already scored this turn — nothing to forfeit
		return

	# Pick a random unscored category
	var candidates: Array = []
	for category in scorecard.upper_scores:
		if scorecard.upper_scores[category] == null:
			candidates.append({"section": Scorecard.Section.UPPER, "category": category})
	for category in scorecard.lower_scores:
		if scorecard.lower_scores[category] == null:
			candidates.append({"section": Scorecard.Section.LOWER, "category": category})
	if candidates.is_empty():
		return
	var pick = candidates[GameRNG.randi_range(0, candidates.size() - 1)]
	print("[HailSatanDebuff] Scoring 0 in category:", pick["category"])
	scorecard.set_score(pick["section"], pick["category"], 0)

	# Mirror the manual-score side effects, then the Next Turn tail
	if score_card_ui:
		score_card_ui.turn_scored = true
		score_card_ui.disable_all_score_buttons()
		score_card_ui.emit_signal("hand_scored")
	dice_hand.animate_all_dice_exit()
	if scorecard.is_game_complete():
		return
	turn_tracker.start_new_turn()
	if score_card_ui:
		score_card_ui.turn_scored = false
		score_card_ui.enable_all_score_buttons()
	dice_hand.set_all_dice_rollable()
	var roll_ui = get_tree().get_first_node_in_group("roll_button_ui")
	if roll_ui:
		roll_ui.enable_roll()
		roll_ui.start_pulse()
