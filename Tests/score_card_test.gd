extends Node2D

@onready var dice_hand := $DiceHand
var locked := false
var DiceScene := preload("res://Scenes/Dice/Dice.tscn")
var die: Dice

@onready var roll_button: Button = $RollButton
@onready var dice_container := $DiceContainer  # Optional Node2D to hold dice

@onready var score_card: Scorecard = $ScoreCard
@onready var score_card_ui: Control = $ScoreCardUI

var dice_list: Array = []

const DICE_COUNT := 5
const START_X := 100
const START_Y := 200
const SPACING := 80

func _ready():
	score_card_ui.bind_scorecard(score_card)

func _on_button_pressed() -> void:
	dice_hand.roll_all()
	DiceResults.update_from_dice(dice_hand.dice_list)
	score_card_ui.turn_scored = false  # 🔄 Reset turn lock
	dice_hand.on_dice_roll_complete()

func toggle_lock():
	locked = !locked
	# Optional: update visual state
	
