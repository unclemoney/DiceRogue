extends Node2D
class_name DiceHand

@export var dice_scene: PackedScene
@export var dice_count := 5
@export var spacing := 80
@export var start_position := Vector2(100, 200)

var dice_list: Array = []

func _ready():
	if dice_scene:
		spawn_dice()

func spawn_dice():
	clear_dice()
	for i in dice_count:
		var die: Dice = dice_scene.instantiate()
		add_child(die)

		var target_pos = start_position + Vector2(i * spacing, 0)
		die.home_position = target_pos

		var start_pos = Vector2(-200, target_pos.y)
		die.animate_entry(start_pos)

		dice_list.append(die)

func roll_all():
	for die in dice_list:
		die.roll()

func clear_dice():
	for die in dice_list:
		die.queue_free()
	dice_list.clear()
