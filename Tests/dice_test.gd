extends Node2D

var DiceScene := preload("res://Scenes/Dice/Dice.tscn")
var die: Dice

func _ready():
	die = DiceScene.instantiate()
	add_child(die)  # ✅ This ensures get_tree() is valid
	die.position = Vector2(100, 100)  # Optional: place it somewhere visible

func _on_button_pressed() -> void:
	die.roll()
