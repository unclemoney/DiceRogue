extends Node2D

@onready var dice_hand := $DiceHand
@onready var roll_button: Button = $RollButton
@onready var dice_container := $DiceContainer  # Optional Node2D to hold dice
@onready var score_card: Scorecard = $ScoreCard
@onready var score_card_ui: Control = $ScoreCardUI
@onready var turn_tracker := $TurnTracker
@onready var turn_tracker_ui := $TurnTrackerUI

var locked := false
var TurnTrackerScene := preload("res://Scenes/Tracker/turn_tracker.tscn")
var DiceScene := preload("res://Scenes/Dice/Dice.tscn")
var die: Dice
var dice_list: Array = []

const DICE_COUNT := 5
const START_X := 100
const START_Y := 200
const SPACING := 80

func _ready():
	score_card_ui.bind_scorecard(score_card)
	turn_tracker_ui.bind_tracker(turn_tracker)
	turn_tracker = TurnTrackerScene.instantiate()
	add_child(turn_tracker)
	turn_tracker_ui.bind_tracker(turn_tracker)
	turn_tracker.rolls_exhausted.connect(func(): _on_rolls_exhausted())


func _on_button_pressed() -> void:
	dice_hand.roll_all()
	DiceResults.update_from_dice(dice_hand.dice_list)
	score_card_ui.turn_scored = false  # 🔄 Reset turn lock
	dice_hand.on_dice_roll_complete()
	turn_tracker.use_roll()


func toggle_lock():
	locked = !locked
	# Optional: update visual state
	

func end_turn():
	turn_tracker.start_new_turn()

func _on_rolls_exhausted():
	roll_button.disabled = true
	print("🎯 Rolls exhausted—roll button disabled.")


func _on_next_turn_button_pressed() -> void:
	end_turn()
