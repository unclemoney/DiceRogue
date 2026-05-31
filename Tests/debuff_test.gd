extends Node2D

@onready var dice_hand: DiceHand       = $GameUI/MarginContainer/MainVBox/MiddleSection/CenterColumn/DiceAreaContainer/DiceHand
@onready var dice_container: Node2D    = $CRTTV/DiceContainer
@onready var score_card: Scorecard     = $ScoreCard
@onready var score_card_ui: Control    = $GameUI/MarginContainer/MainVBox/MiddleSection/RightColumn/ScorecardContainer/ScoreCardUI
@onready var turn_tracker: TurnTracker = $TurnTracker
#@onready var turn_tracker_ui: Control  = $TurnTrackerUI
@onready var game_button_ui: Control   = $GameUI/MarginContainer/MainVBox/MiddleSection/LeftColumn/GameButtonContainer/ContentVBox/GameButtonUI
@onready var game_controller: Node     = $GameController
@onready var pu_manager = get_node_or_null("Managers/PowerUpManager")
@onready var pu_ui = get_node_or_null("GameUI/MarginContainer/MainVBox/UpperSection/PowerUpContainer/ContentVBox/PowerUpUI")
@onready var consumable_ui: ConsumableUI = $GameUI/MarginContainer/MainVBox/MiddleSection/LeftColumn/ConsumableContainer/ContentVBox/ConsumableUI
@onready var consumable_manager: ConsumableManager = $Managers/ConsumableManager
@onready var mod_manager: ModManager = $Managers/ModManager
@onready var debuff_manager: DebuffManager = $Managers/DebuffManager
@onready var challenge_manager: ChallengeManager = $Managers/ChallengeManager
@onready var challenge_ui_node: Control = $GameUI/MarginContainer/MainVBox/MiddleSection/LeftColumn/ChallengeContainer/ContentVBox/ChallengeUI
@onready var vcr_ui: VCRTurnTrackerUI = $GameUI/MarginContainer/MainVBox/UpperSection/TurnInfoContainer/ContentVBox/VCRTurnTrackerUI

func _ready():
	score_card_ui.bind_scorecard(score_card)
	if vcr_ui and turn_tracker:
		vcr_ui.bind_tracker(turn_tracker)

	# Log missing optional components without errors
	if not pu_manager:
		print("Note: PowerUpManager not found - optional component")
	if not pu_ui:
		print("Note: PowerUpUI not found - optional component")
	
	# Add Camera2D + CameraDynamics for juice zoom effects
	var crt = get_node_or_null("CRTTV")
	if crt and not crt.has_node("Camera2D"):
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
		cam.position = Vector2.ZERO
		crt.add_child(cam)
		var dyn = CameraDynamics.new()
		dyn.name = "CameraDynamics"
		cam.add_child(dyn)
		print("[DebuffTest] Added Camera2D + CameraDynamics to CRTTV")
	
	print("Round Manager Test Scene")
	
	# Note: start_game() is called from GameController._on_game_start(),
	# no need to call it manually here.
