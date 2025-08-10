extends Node2D

@onready var dice_hand := $DiceHand
var locked := false
var DiceScene := preload("res://Scenes/Dice/Dice.tscn")
var die: Dice

func _on_roll_button_pressed():
	dice_hand.roll_all()
	
func _ready():
	die = DiceScene.instantiate()
	add_child(die)  # ✅ This ensures get_tree() is valid
	die.position = Vector2(100, 100)  # Optional: place it somewhere visible

func _on_button_pressed() -> void:
	die.roll()

func toggle_lock():
	locked = !locked
	# Optional: update visual state
