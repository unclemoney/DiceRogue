extends Node2D

@onready var dice_hand: DiceHand       = $DiceHand
@onready var dice_container: Node2D    = $DiceContainer
@onready var score_card: Scorecard     = $ScoreCard
@onready var score_card_ui: Control    = $ScoreCardUI
@onready var turn_tracker: TurnTracker = $TurnTracker 
@onready var turn_tracker_ui: Control  = $TurnTrackerUI
@onready var game_button_ui: Control   = $GameButtonUI
@onready var game_controller: Node     = $GameController
@onready var pu_manager = get_node_or_null("../PowerUpManager")
@onready var pu_ui = get_node_or_null("../PowerUpUI")
@onready var consumable_ui: ConsumableUI = $ConsumableUI
@onready var consumable_manager: ConsumableManager = $ConsumableManager
@onready var mod_manager: ModManager = $ModManager
@onready var debuff_manager: DebuffManager = $DebuffManager
@onready var challenge_manager: ChallengeManager = $ChallengeManager
@onready var ChallengeUI: Control = $ChallengeUI

func _ready():
	score_card_ui.bind_scorecard(score_card)
	turn_tracker_ui.bind_tracker(turn_tracker)
	
	# Log missing optional components without errors
	if not pu_manager:
		print("Note: PowerUpManager not found - optional component")
	if not pu_ui:
		print("Note: PowerUpUI not found - optional component")
	
	print("Round Manager Test Scene")
	
	# Get references
	var round_manager = $RoundManager
	
	# Manually start the game
	if round_manager:
		round_manager.start_game()
