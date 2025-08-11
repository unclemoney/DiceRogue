extends Node2D

@onready var dice_hand := $DiceHand
var locked := false
var DiceScene := preload("res://Scenes/Dice/Dice.tscn")
var die: Dice

@onready var roll_button: Button = $RollButton
@onready var dice_container := $DiceContainer  # Optional Node2D to hold dice


var dice_list: Array = []

const DICE_COUNT := 5
const START_X := 100
const START_Y := 200
const SPACING := 80

func _ready():
	spawn_dice()

func spawn_dice():
	for i in DICE_COUNT:
		var die: Dice = DiceScene.instantiate()
		dice_container.add_child(die)

		var target_pos = Vector2(START_X + i * SPACING, START_Y)
		die.home_position = target_pos

		var start_pos = Vector2(-200, target_pos.y)
		die.animate_entry(start_pos)

		dice_list.append(die)


func _on_button_pressed() -> void:
	for die in dice_list:
		die.roll()

func toggle_lock():
	locked = !locked
	# Optional: update visual state
