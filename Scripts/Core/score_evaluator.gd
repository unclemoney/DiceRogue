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
	return n in counts.values()

static func is_full_house(values: Array[int]) -> bool:
	var counts = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	return 3 in counts.values() and 2 in counts.values()

static func is_straight(values: Array[int]) -> bool:
	var sorted = values.duplicate()
	sorted.sort()
	for i in range(1, sorted.size()):
		if sorted[i] != sorted[i - 1] + 1:
			return false
	return true

static func is_small_straight(values: Array[int]) -> bool:
	var sorted = values.duplicate()
	sorted.sort()
	for i in range(1, sorted.size()):
		if sorted[i] != sorted[i - 2] + 1:
			return false
	return true

static func calculate_score_for_category(category: String, values: Array[int]) -> Variant:
	print("Category to Match: ", category)
	match category:
		"ones": return values.count(1) * 1
		"twos": return values.count(2) * 2
		"threes": return values.count(3) * 3
		"fours": return values.count(4) * 4
		"fives": return values.count(5) * 5
		"sixes": return values.count(6) * 6
		"three_of_a_kind":
			print("Values: ", values)
			return 10 if get_n_of_a_kind(values, 3)  else 0
		"four_of_a_kind":
			return 15 if get_n_of_a_kind(values, 4)  else 0
		"full_house":
			return 25 if is_full_house(values) else 0
		"small_straight":
			return 30 if is_small_straight(values) else 0
		"large_straight":
			return 40 if is_straight(values) else 0
		"yahtzee":
			return 50 if get_n_of_a_kind(values, 5) else 0
		"chance":
			return get_sum(values)
		_: return null
