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
	update_result()

func update_result():
	var result_node = get_node_or_null("/Scripts/Core/DiceResults")  # if autoloaded
	if result_node:
		result_node.update_from_dice(dice_list)

func clear_dice():
	for die in dice_list:
		die.queue_free()
	dice_list.clear()

# DiceHand.gd
func process_roll():
	var values := get_current_dice_values()
	DiceResults.set_values(values)
	
func get_current_dice_values() -> Array[int]:
	var values: Array[int] = []
	for die in dice_list:
		values.append(die.value)
	return values
	
# DiceHand or UI
func show_score():
	var score = DiceResults.score
	print(score)

func show_score_feedback(score: Dictionary):
	print("Score breakdown:")
	for key in score.keys():
		print("%s: %s" % [key, score[key]])

func on_dice_roll_complete():
	print("Dice Roll Complete")
	var values = get_current_dice_values()
	var score = DiceResults.set_values(values)
	show_score_feedback(score)
