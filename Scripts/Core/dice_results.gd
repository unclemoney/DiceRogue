extends Node
class_name DiceResult

var values: Array[int] = []
var locked: Array[bool] = []
var score: Dictionary = {}
var dice_refs: Array[Dice] = []  
var scorecard: Scorecard = null

func set_values(values: Array[int]) -> Dictionary:
	self.values = values  # store values for later use
	
	# Use the autoloaded singleton's evaluate_with_wildcards function
	score = ScoreEvaluatorSingleton.evaluate_with_wildcards(values)
	print("Score output:", score)
	
	return score

func update_from_dice(dice_list: Array):
	values.clear()
	locked.clear()
	dice_refs.clear()  # Clear dice references
	
	for die in dice_list:
		if die is Dice:  # Type check for safety
			values.append(die.value)
			locked.append(die.is_locked)
			dice_refs.append(die)  # Store reference to dice for wildcard checking

func get_score() -> int:
	# Example: sum of all dice
	return values.reduce(func(accum, val): return accum + val, 0)

func set_scorecard(card: Scorecard) -> void:
	scorecard = card
	print("[DiceResults] Scorecard reference set:", scorecard.name if scorecard else "null")

func reset():
	values.clear()
	locked.clear()
	dice_refs.clear()  # Clear dice references
	score.clear()
