extends Node2D

@export var dice_scene: PackedScene
@export var dice_count := 5

var dice_list: Array = []

func _ready() -> void:
	spawn_dice()

func spawn_dice():
	clear_dice()
	for i in dice_count:
		var die: Dice = dice_scene.instantiate()
		add_child(die)

		var target_pos = Vector2(100 + i * 80, 100)  # Adjust spacing as needed
		die.home_position = target_pos

		var start_pos = Vector2(-200, target_pos.y)  # Off-screen left
		die.animate_entry(start_pos, 0.4 + i * 0.05)

		dice_list.append(die)

func roll_all() -> void:
	for die in dice_list:
		if not die.locked:  # Optional: add a `locked` property to Dice
			die.roll()

func clear_dice() -> void:
	for die in dice_list:
		die.queue_free()
	dice_list.clear()
