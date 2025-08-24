extends Node
class_name ScoreEvaluator

func evaluate_with_wildcards(dice_values: Array[int]) -> Dictionary:
	print("\n=== Score Evaluation Start ===")
	print("Input dice values:", dice_values)
	
	var wildcard_indices = []
	var regular_values = []
	
	# Separate wildcards from regular dice
	for i in range(dice_values.size()):
		var die = DiceResults.dice_refs[i]
		if die.has_mod("wildcard"):
			print("Found wildcard at index", i, "with value", dice_values[i])
			wildcard_indices.append(i)
		else:
			print("Regular die at index", i, "with value", dice_values[i])
			regular_values.append(dice_values[i])
	
	# If no wildcards, evaluate normally
	if wildcard_indices.is_empty():
		print("No wildcards found - evaluating normally")
		return evaluate_normal(dice_values)
	
	print("Testing wildcard combinations...")
	var best_scores = {}
	
	# Generate all possible combinations
	var combinations = generate_wildcard_combinations(wildcard_indices.size(), 6)
	for combo in combinations:
		# Convert untyped array to Array[int] before evaluation
		var test_values: Array[int] = []
		test_values.assign(regular_values) # Use assign instead of duplicate
		
		for i in range(wildcard_indices.size()):
			test_values.insert(wildcard_indices[i], combo[i])
		print("Testing combination:", test_values)
		
		var scores = evaluate_normal(test_values)
		
		# Update best scores for each category
		for category in scores:
			var current_best = best_scores.get(category, 0)
			if scores[category] > current_best:
				best_scores[category] = scores[category]
				print("New best score for", category + ":", scores[category])
	
	print("=== Score Evaluation Complete ===\n")
	return best_scores


func evaluate_normal(values: Array[int]) -> Dictionary:
	return {
		"ones": calculate_number_score(values, 1),
		"twos": calculate_number_score(values, 2),
		"threes": calculate_number_score(values, 3),
		"fours": calculate_number_score(values, 4),
		"fives": calculate_number_score(values, 5),
		"sixes": calculate_number_score(values, 6),
		"three_of_a_kind": calculate_of_a_kind_score(values, 3),
		"four_of_a_kind": calculate_of_a_kind_score(values, 4),
		"full_house": calculate_full_house_score(values),
		"small_straight": calculate_small_straight_score(values),
		"large_straight": calculate_large_straight_score(values),
		"yahtzee": calculate_yahtzee_score(values),
		"chance": calculate_chance_score(values)
	}


# Update calculate_of_a_kind_score to use the value
func calculate_of_a_kind_score(values: Array[int], required: int) -> int:
	var matching_value = get_n_of_a_kind(values, required)
	if matching_value > 0:
		return get_sum(values)  # Return sum of all dice if we found a match
	return 0  # Return 0 if no match found


func calculate_number_score(values: Array[int], number: int) -> int:
	return values.count(number) * number


func calculate_full_house_score(values: Array[int]) -> int:
	return 25 if is_full_house(values) else 0

func calculate_small_straight_score(values: Array[int]) -> int:
	return 30 if is_small_straight(values) else 0

func calculate_large_straight_score(values: Array[int]) -> int:
	return 40 if is_straight(values) else 0

func calculate_yahtzee_score(values: Array[int]) -> int:
	print("\n=== Calculating Yahtzee Score ===")
	print("Input values:", values)
	
	if is_yahtzee(values):
		print("✓ Yahtzee detected!")
		# Use DiceResults.scorecard instead of trying to find it through dice_refs
		var scorecard = DiceResults.scorecard
		if scorecard:
			print("Current Yahtzee score in scorecard:", scorecard.lower_scores.get("yahtzee"))
			if scorecard.lower_scores.get("yahtzee", 0) == 50:
				print("→ This is a bonus Yahtzee! (100 points)")
				return 100
			else:
				print("→ This is the first Yahtzee (50 points)")
		else:
			push_error("[ScoreEvaluator] No scorecard reference found in DiceResults")
		return 50
	print("✗ Not a Yahtzee")
	return 0
	
func calculate_chance_score(values: Array[int]) -> int:
	return get_sum(values)

func calculate_score_for_category(category: String, values: Array[int]) -> int:
	print("\n=== calculate_score_for_category ===")
	print("Category:", category)
	print("Values:", values)

	# First evaluate with wildcards to get all possible scores
	var all_scores = evaluate_with_wildcards(values)
	
	# Return the score for the requested category
	var score = all_scores.get(category, 0)
	print("Calculated score:", score)
	print("=== End calculate_score_for_category ===\n")
	return score

func generate_wildcard_combinations(wildcard_count: int, sides: int) -> Array:
	var combinations := []
	
	if wildcard_count == 0:
		combinations.append([])
		return combinations
	
	var sub_combinations = generate_wildcard_combinations(wildcard_count - 1, sides)
	for sub_combo in sub_combinations:
		for value in range(1, sides + 1):
			# Create a new array and copy values
			var new_combo := []
			new_combo.assign(sub_combo)
			new_combo.append(value)
			combinations.append(new_combo)
	
	return combinations
	

# Helper functions
func get_sum(values: Array[int]) -> int:
	var total := 0
	for v in values:
		total += v
	return total

# Change get_n_of_a_kind to return a matching value instead of bool
func get_n_of_a_kind(values: Array[int], n: int) -> int:
	var counts = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	for value in counts:
		if counts[value] >= n:
			return value  # Return the value that meets the requirement
	return 0  # Return 0 if no match found

func is_full_house(values: Array[int]) -> bool:
	var counts = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	
	var has_three = false
	var has_pair = false
	
	for count in counts.values():
		if count >= 3:
			has_three = true
		elif count >= 2:
			has_pair = true
		if count >= 5:
			return true
	
	return has_three and has_pair

func is_straight(values: Array[int]) -> bool:
	var unique := get_unique(values)
	unique.sort()
	
	if unique.size() < 5:
		return false
		
	for i in range(unique.size() - 4):
		var sequence = unique.slice(i, i + 5)
		if sequence[4] == sequence[0] + 4:
			return true
	
	return false

func get_unique(values: Array[int]) -> Array[int]:
	var seen := {}
	var unique: Array[int] = []
	for val in values:
		if not seen.has(val):
			seen[val] = true
			unique.append(val)
	return unique
	
func is_small_straight(values: Array[int]) -> bool:
	var unique := get_unique(values)
	var check_values: Array[int] = [1,2,3,4]
	var check_values2: Array[int] = [2,3,4,5]
	var check_values3: Array[int] = [3,4,5,6]
	return check_values.all(func(x): return unique.has(x)) or \
		   check_values2.all(func(x): return unique.has(x)) or \
		   check_values3.all(func(x): return unique.has(x))


func is_yahtzee(values: Array[int]) -> bool:
	print("\n=== Checking for Yahtzee ===")
	print("Values:", values)
	
	if values.is_empty():
		print("✗ Empty values array")
		return false
		
	# For regular dice
	var first_value = values[0]
	if values.all(func(v): return v == first_value):
		print("✓ Regular Yahtzee detected - all values are", first_value)
		return true
		
	# For wildcard combinations
	print("Checking wildcard combination...")
	var wildcard_count = 0
	var regular_value = null
	
	for i in range(values.size()):
		if DiceResults.dice_refs[i].has_mod("wildcard"):
			wildcard_count += 1
			print("Found wildcard at index", i)
		else:
			if regular_value == null:
				regular_value = values[i]
				print("First regular value:", regular_value)
			elif values[i] != regular_value:
				print("✗ Mismatch - found", values[i], "expected", regular_value)
				return false
	
	print("Wildcard count:", wildcard_count)
	print("Regular value:", regular_value)
	
	# If all dice are wildcards, it's a Yahtzee
	# Or if all non-wildcard dice show the same value
	var is_valid = wildcard_count == values.size() or (regular_value != null)
	print("Yahtzee valid?", is_valid, 
		"(", "all wildcards" if wildcard_count == values.size() 
		else "matching regular values" if regular_value != null 
		else "invalid combination", ")")
	return is_valid
