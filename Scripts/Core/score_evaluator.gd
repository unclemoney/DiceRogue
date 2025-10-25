extends Node
#class_name ScoreEvaluator

var _evaluation_count := 0  # Add at top of class

func reset_evaluation_count() -> void:
	_evaluation_count = 0

func evaluate_with_wildcards(dice_values: Array[int]) -> Dictionary:
	# Don't increment here - let the caller manage the count
	# This method can be called multiple times legitimately during category evaluation
	
	# Check for Yahtzee bonus potential first
	var _has_bonus_potential = false
	if DiceResults.scorecard and DiceResults.scorecard.lower_scores.get("yahtzee") == 50:
		if is_yahtzee(dice_values):
			_has_bonus_potential = true
	
	var wildcard_indices = []
	var regular_values = []
	
	# Separate wildcards from regular dice
	for i in range(dice_values.size()):
		var die = DiceResults.dice_refs[i]
		if die.has_mod("wildcard"):
			wildcard_indices.append(i)
		else:
			regular_values.append(dice_values[i])
	
	var best_scores = {}
	var has_yahtzee = false
	# NOTE: Bonus Yahtzee handling is done in the scorecard, not here
	# ScoreEvaluator only calculates base scores for categories

	# Only generate combinations once
	var combinations = generate_wildcard_combinations(wildcard_indices.size(), 6)
	#print("Generated", combinations.size(), "possible combinations")
	
	# Check if this could be a bonus Yahtzee first
	if DiceResults.scorecard and DiceResults.scorecard.lower_scores.get("yahtzee") == 50:
		if is_yahtzee(dice_values):
			has_yahtzee = true
	
	# Limit combinations if too many
	if combinations.size() > 100:
		push_warning("[ScoreEvaluator] Too many combinations (", combinations.size(), "), limiting to first 100")
		combinations = combinations.slice(0, 100)
	
	for combo in combinations:
		var test_values: Array[int] = []
		test_values.assign(regular_values)
		
		for i in range(wildcard_indices.size()):
			test_values.insert(wildcard_indices[i], combo[i])
		
		var scores = evaluate_normal(test_values)
		
		# If this is a bonus Yahtzee, we still only calculate base scores
		# Bonus points are handled separately in the scorecard
		if has_yahtzee:
			# has_yahtzee is tracked but no score modification needed here
			pass
		
		# Update best scores for each category
		for category in scores:
			var current_best = best_scores.get(category, 0)
			if scores[category] > current_best:
				best_scores[category] = scores[category]
	return best_scores


func filter_disabled_values(values: Array[int]) -> Array[int]:
	var filtered: Array[int] = []
	
	# More robust way to find game controller
	var game_controller = get_tree().get_first_node_in_group("game_controller") as GameController
	
	# Fallback to try getting game controller through DiceResults
	if game_controller == null and DiceResults.dice_refs.size() > 0:
		var first_die = DiceResults.dice_refs[0]
		if first_die and first_die.get_parent():
			# Try finding GameController through ancestry
			var parent = first_die.get_parent()
			while parent != null:
				if parent is GameController:
					game_controller = parent
					break
				parent = parent.get_parent()
	
	#print("[ScoreEvaluator] Game controller reference:", game_controller)
	
	# Check if the disabled_twos debuff is active
	var disabled_twos_active = false
	if game_controller != null:
		disabled_twos_active = game_controller.is_debuff_active("disabled_twos")
		#print("[ScoreEvaluator] Disabled twos active:", disabled_twos_active)
	
	# If we can't find game_controller, check if DiceResults has any dice showing 2s with a red shader
	if game_controller == null:
		print("[ScoreEvaluator] No game controller found, checking for visual indicators")
		for i in range(min(values.size(), DiceResults.dice_refs.size())):
			var die = DiceResults.dice_refs[i]
			if die and die.dice_material and die.dice_material.get_shader_parameter("disabled"):
				if values[i] == 2:
					disabled_twos_active = true
					print("[ScoreEvaluator] Found visually disabled die with value 2")
					break
	
	for i in range(values.size()):
		var value = values[i]
		
		# Skip value 2 if debuff is active
		if disabled_twos_active and value == 2:
			var die = DiceResults.dice_refs[i] if i < DiceResults.dice_refs.size() else null
			# Only include value 2 if it comes from a die with wildcard mod
			if die and die.has_mod("wildcard"):
				filtered.append(value)
				print("[ScoreEvaluator] Including wildcard value 2")
			else:
				print("[ScoreEvaluator] Filtering out value 2")
				# Don't add this value
				continue
		else:
			filtered.append(value)
	
	if disabled_twos_active:
		print("[ScoreEvaluator] Original values:", values)
		print("[ScoreEvaluator] Filtered values:", filtered)
	
	return filtered

func evaluate_normal(values: Array[int]) -> Dictionary:
	# Filter out disabled values first
	var filtered_values = filter_disabled_values(values)
	
	# Cache yahtzee check to avoid multiple calls
	var yahtzee_score = calculate_yahtzee_score(filtered_values)
	
	return {
		"ones": calculate_number_score(filtered_values, 1),
		"twos": calculate_number_score(filtered_values, 2),
		"threes": calculate_number_score(filtered_values, 3),
		"fours": calculate_number_score(filtered_values, 4),
		"fives": calculate_number_score(filtered_values, 5),
		"sixes": calculate_number_score(filtered_values, 6),
		"three_of_a_kind": calculate_of_a_kind_score(filtered_values, 3),
		"four_of_a_kind": calculate_of_a_kind_score(filtered_values, 4),
		"full_house": calculate_full_house_score(filtered_values),
		"small_straight": calculate_small_straight_score(filtered_values),
		"large_straight": calculate_large_straight_score(filtered_values),
		"yahtzee": yahtzee_score,
		"chance": calculate_chance_score(filtered_values)
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
	if is_yahtzee(values):
		var scorecard = DiceResults.scorecard
		if scorecard:
			var current_score = scorecard.lower_scores.get("yahtzee")

			# Check if this is a valid Yahtzee situation for bonus
			if current_score == 50:
				# Check if any category has already been scored
				var any_category_scored = false
				
				# Check upper section
				for category in scorecard.upper_scores:
					if scorecard.upper_scores[category] != null:
						any_category_scored = true
						break
				
				# Check lower section if needed
				if not any_category_scored:
					for category in scorecard.lower_scores:
						if category != "yahtzee" and scorecard.lower_scores[category] != null:
							any_category_scored = true
							break
				
				if any_category_scored:
					return 100
				else:
					return 50
			elif current_score == null:
				return 50
			elif current_score == 0:
				return 0
			else:
				return 0
		else:
			push_error("[ScoreEvaluator] No scorecard reference found in DiceResults")
			return 50
	return 0
	
func calculate_chance_score(values: Array[int]) -> int:
	return get_sum(values)

func calculate_score_for_category(category: String, values: Array[int]) -> int:
	# Increment and check for runaway evaluations
	_evaluation_count += 1
	if _evaluation_count > 1000:  # Much higher threshold - 1000 evaluations
		push_error("[ScoreEvaluator] Excessive evaluations (", _evaluation_count, ") - possible infinite loop in category: ", category)
		return 0
	
	# First evaluate with wildcards to get all possible scores
	var all_scores = evaluate_with_wildcards(values)
	var score = all_scores.get(category, 0)
	return score

func generate_wildcard_combinations(wildcard_count: int, sides: int) -> Array:
	var combinations := []
	
	# Base case
	if wildcard_count == 0:
		combinations.append([])
		return combinations
	
	# For each wildcard, we only need to consider values that could make useful combinations
	# Get the values of non-wildcard dice to inform our choices
	var regular_values = []
	for i in range(DiceResults.dice_refs.size()):
		if not DiceResults.dice_refs[i].has_mod("wildcard"):
			regular_values.append(DiceResults.values[i])

	# If we have regular values, prioritize those and adjacent numbers
	var priority_values = {}
	if not regular_values.is_empty():
		for v in regular_values:
			priority_values[v] = true  # Same value for matching
			priority_values[max(1, v - 1)] = true  # One less for straights
			priority_values[min(6, v + 1)] = true  # One more for straights
	else:
		# If no regular values, use all sides
		for i in range(1, sides + 1):
			priority_values[i] = true
	# Generate combinations using only priority values
	var sub_combinations = generate_wildcard_combinations(wildcard_count - 1, sides)
	for sub_combo in sub_combinations:
		for value in priority_values:
			var new_combo := []
			new_combo.assign(sub_combo)
			new_combo.append(value)
			combinations.append(new_combo)
	
	print("Generated combinations:", combinations.size())
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
	if values.is_empty():
		return false
	
	# Filter out disabled values (like twos with disabled_twos debuff)
	var filtered_values = filter_disabled_values(values)
	
	# If filtering removed too many dice, it can't be a yahtzee
	if filtered_values.size() < 5:
		print("[ScoreEvaluator] Not enough valid dice for yahtzee after filtering")
		return false
		
	var wildcard_count = 0
	var regular_values = []
	var regular_indices = []
	
	# First pass - count wildcards and collect regular values
	for i in range(filtered_values.size()):
		if i < DiceResults.dice_refs.size():
			var die = DiceResults.dice_refs[i]
			if die.has_mod("wildcard"):
				wildcard_count += 1
			else:
				regular_values.append(filtered_values[i])
				regular_indices.append(i)
		else:
			# This shouldn't happen if our filtering is working correctly
			regular_values.append(filtered_values[i])
			regular_indices.append(i)
	
	# If all dice are wildcards, it's automatically a Yahtzee
	if wildcard_count == filtered_values.size():
		print("✓ All wildcards - automatic Yahtzee!")
		return true
	
	# If we have regular values, they all must match
	if not regular_values.is_empty():
		var target_value = regular_values[0]
		
		# Check that all regular dice match
		for value in regular_values:
			if value != target_value:
				return false
		
		# Make sure we have enough matching dice (including wildcards) for a yahtzee
		if regular_values.size() + wildcard_count >= 5:
			print("[ScoreEvaluator] Valid yahtzee: ", regular_values.size(), " matching dice + ", 
				  wildcard_count, " wildcards")
			return true
	
	return false
