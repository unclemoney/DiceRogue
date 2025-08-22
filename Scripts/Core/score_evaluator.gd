extends Node
class_name ScoreEvaluator

static func evaluate(dice_values: Array[int]) -> Dictionary:
	return {
		"pairs": get_pairs(dice_values),
		"three_of_a_kind": get_n_of_a_kind(dice_values, 3),
		"four_of_a_kind": get_n_of_a_kind(dice_values, 4),
		"full_house": is_full_house(dice_values),
		"straight": is_straight(dice_values),
		"sum": get_sum(dice_values)
	}

static func get_sum(values: Array[int]) -> int:
	var total := 0
	for v in values:
		total += v
	return total

static func get_pairs(values: Array[int]) -> int:
	var counts = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	var pairs = 0
	for count in counts.values():
		if count >= 2:
			pairs += 1
	return pairs

static func get_n_of_a_kind(values: Array[int], n: int) -> bool:
	var counts = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	for count in counts.values():
		if count >= n:  # This is correct - already handles extra dice
			return true
	return false


# 3. Fix full house
static func is_full_house(values: Array[int]) -> bool:
	var counts = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	
	# Look for any valid full house combination
	var has_three = false
	var has_pair = false
	
	for count in counts.values():
		if count >= 3:
			has_three = true
		elif count >= 2:
			has_pair = true
		# If we find a count of 5 or more, it can form both parts
		if count >= 5:
			return true
	
	return has_three and has_pair

static func is_straight(values: Array[int]) -> bool:
	var unique := get_unique(values)
	unique.sort()
	
	# Look for any valid 5-dice straight in the sorted unique values
	if unique.size() < 5:
		return false
		
	# Check for consecutive sequences of 5
	for i in range(unique.size() - 4):
		var sequence = unique.slice(i, i + 5)
		if sequence[4] == sequence[0] + 4:
			return true
	
	return false

# Helper function already exists but shown for context
static func get_unique(values: Array) -> Array:
	var seen := {}
	var unique := []
	for val in values:
		if not seen.has(val):
			seen[val] = true
			unique.append(val)
	return unique

static func is_small_straight(values: Array) -> bool:
	var unique := get_unique(values)
	unique.sort()
	return [1,2,3,4].all(unique.has) or \
		   [2,3,4,5].all(unique.has) or \
		   [3,4,5,6].all(unique.has)

static func calculate_score_for_category(category: String, values: Array[int]) -> int:
	print("=== using NEW calculate_score_for_category v2 ===")
	var score: int = 0
	match category:
		"ones":         score = values.count(1) * 1
		"twos":         score = values.count(2) * 2
		"threes":       score = values.count(3) * 3
		"fours":        score = values.count(4) * 4
		"fives":        score = values.count(5) * 5
		"sixes":        score = values.count(6) * 6
		"three_of_a_kind":
			if get_n_of_a_kind(values, 3):
				score = get_sum(values)  # or 10, depending on your rule
			else:
				score = 0
		"four_of_a_kind":
			if get_n_of_a_kind(values, 4):
				score = get_sum(values)  # or 15
		"full_house":
			if is_full_house(values):
				score = 25
		"small_straight":
			if is_small_straight(values):
				score = 30
		"large_straight":
			if is_straight(values):
				score = 40
		"yahtzee":
			if get_n_of_a_kind(values, 5):
				score = 50
		"chance":
			score = get_sum(values)
		_:  # default to zero so you never return null
			score = 0
	print("→ returning:", score, " type:", typeof(score))
	return score
