extends Node
class_name DiceResult

var values: Array[int] = []
var locked: Array[bool] = []
var score: Dictionary = {}


func set_values(values: Array[int]) -> Dictionary:
	self.values = values  # store values for later use

	score = ScoreEvaluator.evaluate(values)  # call your scoring logic
	print("Score output:", score)  # ✅ this will now print!

	return score  # return full score breakdown

func update_from_dice(dice_list: Array):
	values.clear()
	locked.clear()
	for die in dice_list:
		values.append(die.value)
		locked.append(die.is_locked)

func get_score() -> int:
	# Example: sum of all dice
	return values.reduce(func(accum, val): return accum + val, 0)

func reset():
	values.clear()
	locked.clear()
