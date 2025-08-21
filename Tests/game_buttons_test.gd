extends Node2D

@onready var dice_hand: DiceHand       = $DiceHand
@onready var dice_container: Node2D    = $DiceContainer
@onready var score_card: Scorecard     = $ScoreCard
@onready var score_card_ui: Control    = $ScoreCardUI
@onready var turn_tracker: TurnTracker = $TurnTracker
@onready var turn_tracker_ui: Control  = $TurnTrackerUI
@onready var game_button_ui: Control   = $GameButtonUI

func _ready():
	score_card_ui.bind_scorecard(score_card)
	turn_tracker_ui.bind_tracker(turn_tracker)
	# GameButtonUI handles all rolling & turn‐advancement
