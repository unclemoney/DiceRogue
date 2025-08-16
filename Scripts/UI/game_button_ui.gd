extends Control

@export var dice_hand_path:      NodePath
@export var score_card_ui_path:  NodePath
@export var turn_tracker_path:   NodePath

var dice_hand
var score_card_ui
var turn_tracker
var scorecard: Scorecard



func _ready():
	dice_hand      = get_node(dice_hand_path)
	score_card_ui  = get_node(score_card_ui_path)
	turn_tracker   = get_node(turn_tracker_path)

	$HBoxContainer/RollButton.pressed.connect(_on_roll_button_pressed)
	$HBoxContainer/NextTurnButton.pressed.connect(_on_next_turn_button_pressed)

	dice_hand.roll_complete.connect(_on_dice_roll_complete)
	turn_tracker.rolls_exhausted.connect(func(): $HBoxContainer/RollButton.disabled = true)
	turn_tracker.turn_started.connect(func(): $HBoxContainer/RollButton.disabled = false)
	turn_tracker.connect(
		"game_over",
		Callable(self, "_on_game_over")
	)


func _on_roll_button_pressed() -> void:
	if dice_hand.dice_list.size() == 0:
		dice_hand.spawn_dice()
	dice_hand.roll_all()

func _on_dice_roll_complete() -> void:
	# player may now pick a category…
	# lock UI state for scoring
	score_card_ui.turn_scored = false
	turn_tracker.use_roll()

func _on_next_turn_button_pressed() -> void:
	# 1) Auto-score if needed
	if not score_card_ui.turn_scored:
		score_card_ui.scorecard.auto_score_best(dice_hand.get_current_dice_values())
		score_card_ui.turn_scored = true
		score_card_ui.update_all()

	# 2) Proceed with turn advancement
	turn_tracker.start_new_turn()
	score_card_ui.turn_scored = false
	score_card_ui.enable_all_score_buttons()
	for die in dice_hand.dice_list:
		die.unlock()
	$HBoxContainer/RollButton.disabled = false
	_on_roll_button_pressed()

func _on_auto_score_assigned(section, category, score):
	print("Auto-assigned", category, "in", section, "for", score, "points")
	# maybe flash the label or play a sound

func _on_game_over() -> void:
	# Disable all controls
	$HBoxContainer/RollButton.disabled = true
	$HBoxContainer/NextTurnButton.disabled = true
