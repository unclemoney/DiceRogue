extends Node2D
class_name DiceHand

signal roll_complete

@export var dice_scene:      PackedScene
@export var dice_count:      int     = 5
#	set(value):
#		dice_count = value
		# Only update dice if they're already spawned
		#if not dice_list.is_empty():
		#	update_dice_count()
@export var spacing:         float   = 80.0
@export var start_position:  Vector2 = Vector2(100, 200)

var dice_list: Array[Dice] = []

func spawn_dice() -> void:
	clear_dice()
	update_dice_count()



func roll_all() -> void:
	if dice_list.size() == 0:
		return
	for die in dice_list:
		die.roll()
	_update_results()
	emit_signal("roll_complete")

func _update_results() -> void:
	# Direct call to the autoloaded singleton
	DiceResults.update_from_dice(dice_list)

func clear_dice() -> void:
	for die in dice_list:
		die.queue_free()
	dice_list.clear()

# DiceHand.gd
func get_current_dice_values() -> Array[int]:
	var arr: Array[int] = []
	for die in dice_list:
		arr.append(die.value)
	return arr

func update_dice_count() -> void:
	var current_count = dice_list.size()
	
	if current_count == dice_count:
		return
	
	if current_count < dice_count:
		# Add more dice
		for i in range(current_count, dice_count):
			var die = dice_scene.instantiate() as Dice
			add_child(die)
			die.home_position = start_position + Vector2(i * spacing, 0)
			die.position = Vector2(-200, die.home_position.y)
			die.animate_entry(die.position)
			dice_list.append(die)
	else:
		# Remove excess dice
		for i in range(dice_count, current_count):
			var die = dice_list.pop_back()
			die.queue_free()