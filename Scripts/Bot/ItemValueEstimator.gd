extends RefCounted
class_name ItemValueEstimator

## ItemValueEstimator
##
## Monte Carlo Yahtzee scoring simulator for estimating item value.
## Simulates many random Yahtzee games and calculates expected scores
## with and without each item's effect to produce $/point ratings.

## Scoring constants (vanilla Yahtzee)
const UPPER_BONUS_THRESHOLD := 63
const UPPER_BONUS_AMOUNT := 35
const FULL_HOUSE_SCORE := 25
const SMALL_STRAIGHT_SCORE := 30
const LARGE_STRAIGHT_SCORE := 40
const YAHTZEE_SCORE := 50
const NUM_DICE := 5
const DICE_SIDES := 6
const NUM_ROLLS := 3
const UPPER_CATEGORIES := ["ones", "twos", "threes", "fours", "fives", "sixes"]
const LOWER_CATEGORIES := ["three_of_a_kind", "four_of_a_kind", "full_house", "small_straight", "large_straight", "yahtzee", "chance"]
const ALL_CATEGORIES := ["ones", "twos", "threes", "fours", "fives", "sixes", "three_of_a_kind", "four_of_a_kind", "full_house", "small_straight", "large_straight", "yahtzee", "chance"]

## Item effect classification for simulation
enum EffectType {
	UNKNOWN,
	SCORE_MULTIPLIER,
	SCORE_ADDITIVE,
	EXTRA_DICE,
	EXTRA_ROLLS,
	CATEGORY_UPGRADE,
	ECONOMY_FLAT,
	ECONOMY_SCALING,
	UTILITY,
	UPPER_BONUS_BOOST,
	LOWER_BONUS_BOOST,
	YAHTZEE_BONUS_BOOST,
	CHANCE_BONUS,
}

## Known powerup effect mappings (id → {type, value})
## value meaning depends on type:
##   SCORE_MULTIPLIER: float multiplier (e.g. 1.5 = +50%)
##   SCORE_ADDITIVE: int points per scored category
##   EXTRA_DICE: int extra dice count
##   EXTRA_ROLLS: int extra rolls per turn
##   CATEGORY_UPGRADE: float level boost multiplier
##   ECONOMY_FLAT: int money per game
##   ECONOMY_SCALING: float money multiplier
##   UTILITY: estimated int point value per game
var KNOWN_EFFECTS: Dictionary = {
	# Score multipliers
	"foursome": {"type": EffectType.SCORE_MULTIPLIER, "value": 1.5, "desc": "1.5x multiplier on 4-of-a-kind categories"},
	"upper_bonus_mult": {"type": EffectType.UPPER_BONUS_BOOST, "value": 2.0, "desc": "2x upper bonus"},
	"yahtzee_bonus_mult": {"type": EffectType.YAHTZEE_BONUS_BOOST, "value": 2.0, "desc": "2x yahtzee bonus"},
	"chance520": {"type": EffectType.CHANCE_BONUS, "value": 20, "desc": "+20 to chance score"},
	"evens_no_odds": {"type": EffectType.SCORE_ADDITIVE, "value": 15, "desc": "+15 per even upper category"},
	"extra_dice": {"type": EffectType.EXTRA_DICE, "value": 1, "desc": "+1 die"},
	"wild_dots": {"type": EffectType.UTILITY, "value": 20, "desc": "Wild die face"},
	"extra_rolls": {"type": EffectType.EXTRA_ROLLS, "value": 1, "desc": "+1 roll per turn"},
	"consumable_cash": {"type": EffectType.ECONOMY_FLAT, "value": 50, "desc": "$50 when consumable used"},
	"bonus_money": {"type": EffectType.ECONOMY_FLAT, "value": 75, "desc": "Bonus end-of-round money"},
	"money_multiplier": {"type": EffectType.ECONOMY_SCALING, "value": 1.25, "desc": "1.25x money earned"},
	"full_house_bonus": {"type": EffectType.SCORE_ADDITIVE, "value": 10, "desc": "+10 on full house"},
	"step_by_step": {"type": EffectType.CATEGORY_UPGRADE, "value": 1.5, "desc": "Straight category bonus"},
	"perfect_strangers": {"type": EffectType.SCORE_ADDITIVE, "value": 10, "desc": "+10 if all dice different"},
	"green_monster": {"type": EffectType.SCORE_ADDITIVE, "value": 8, "desc": "Green die additive bonus"},
	"red_power_ranger": {"type": EffectType.SCORE_ADDITIVE, "value": 8, "desc": "Red die additive bonus"},
	"pin_head": {"type": EffectType.SCORE_ADDITIVE, "value": 5, "desc": "Pin bonus per ones"},
	"money_well_spent": {"type": EffectType.ECONOMY_SCALING, "value": 1.1, "desc": "Money from purchases"},
	"highlighted_score": {"type": EffectType.SCORE_ADDITIVE, "value": 12, "desc": "Highlighted category bonus"},
	"the_consumer_is_always_right": {"type": EffectType.ECONOMY_FLAT, "value": 40, "desc": "Economy from consumable use"},
	"green_slime": {"type": EffectType.SCORE_ADDITIVE, "value": 6, "desc": "Green additive"},
	"red_slime": {"type": EffectType.SCORE_ADDITIVE, "value": 6, "desc": "Red additive"},
	"purple_slime": {"type": EffectType.SCORE_MULTIPLIER, "value": 1.15, "desc": "Purple multiplier"},
	"blue_slime": {"type": EffectType.SCORE_MULTIPLIER, "value": 1.1, "desc": "Blue multiplier"},
	"lower_ten": {"type": EffectType.SCORE_ADDITIVE, "value": 10, "desc": "+10 to lower section"},
	"different_straights": {"type": EffectType.SCORE_ADDITIVE, "value": 15, "desc": "Bonus for straights"},
	"plus_thelast": {"type": EffectType.SCORE_ADDITIVE, "value": 8, "desc": "Bonus from previous category"},
	"allowance": {"type": EffectType.ECONOMY_FLAT, "value": 600, "desc": "$100 per challenge (×6 rounds)"},
	"ungrounded": {"type": EffectType.UTILITY, "value": 15, "desc": "Goof-off immunity"},
	"shop_rerolls": {"type": EffectType.UTILITY, "value": 10, "desc": "Free shop rerolls"},
	"tango_and_cash": {"type": EffectType.ECONOMY_FLAT, "value": 100, "desc": "Bonus money mechanic"},
	"even_higher": {"type": EffectType.SCORE_ADDITIVE, "value": 10, "desc": "Even upper section bonus"},
	"money_bags": {"type": EffectType.ECONOMY_FLAT, "value": 200, "desc": "Score-based money bonus"},
	"failed_money": {"type": EffectType.ECONOMY_FLAT, "value": 50, "desc": "Money on round fail"},
	"dice_diversity": {"type": EffectType.SCORE_ADDITIVE, "value": 8, "desc": "Unique face bonus"},
	"lock_and_load": {"type": EffectType.UTILITY, "value": 15, "desc": "Lock dice bonus"},
	"chore_champion": {"type": EffectType.ECONOMY_FLAT, "value": 150, "desc": "Extra chore money"},
	"roll_efficiency": {"type": EffectType.SCORE_ADDITIVE, "value": 10, "desc": "Bonus for fewer rolls used"},
	"pair_paradise": {"type": EffectType.SCORE_ADDITIVE, "value": 12, "desc": "Bonus for pairs"},
	"extra_coupons": {"type": EffectType.UTILITY, "value": 25, "desc": "Extra consumable/powerup slots"},
	"purple_payout": {"type": EffectType.SCORE_MULTIPLIER, "value": 1.15, "desc": "Purple die payout mult"},
	"mod_money": {"type": EffectType.ECONOMY_FLAT, "value": 100, "desc": "Money from mods"},
	"blue_safety_net": {"type": EffectType.UTILITY, "value": 30, "desc": "Blue die protection"},
	"chore_sprint": {"type": EffectType.ECONOMY_FLAT, "value": 200, "desc": "Extra chore rewards"},
	"straight_triplet_master": {"type": EffectType.SCORE_ADDITIVE, "value": 15, "desc": "Straight+3oak combo bonus"},
	"modded_dice_mastery": {"type": EffectType.SCORE_ADDITIVE, "value": 10, "desc": "Modded dice scoring bonus"},
	"debuff_destroyer": {"type": EffectType.UTILITY, "value": 20, "desc": "Negates debuffs"},
	"challenge_easer": {"type": EffectType.UTILITY, "value": 25, "desc": "Reduces target scores"},
	"azure_perfection": {"type": EffectType.SCORE_MULTIPLIER, "value": 1.2, "desc": "Blue die perfection mult"},
	"rainbow_surge": {"type": EffectType.SCORE_MULTIPLIER, "value": 1.15, "desc": "Multi-color bonus"},
	"the_replicator": {"type": EffectType.UTILITY, "value": 40, "desc": "Duplicates a powerup"},
	"the_piggy_bank": {"type": EffectType.ECONOMY_FLAT, "value": 300, "desc": "Saves money over time"},
	"random_card_level": {"type": EffectType.CATEGORY_UPGRADE, "value": 1.5, "desc": "Random category level up"},
	"yahtzeed_dice": {"type": EffectType.UTILITY, "value": 15, "desc": "Yahtzee die lock bonus"},
	"consumable_collector": {"type": EffectType.ECONOMY_FLAT, "value": 50, "desc": "Bonus from consumable collection"},
	"daring_dice": {"type": EffectType.SCORE_ADDITIVE, "value": 10, "desc": "Risk/reward dice bonus"},
	"great_exchange": {"type": EffectType.UTILITY, "value": 20, "desc": "Item exchange mechanic"},
	"extra_rainbow": {"type": EffectType.SCORE_ADDITIVE, "value": 8, "desc": "Extra rainbow die bonus"},
	"melting_dice": {"type": EffectType.SCORE_ADDITIVE, "value": 10, "desc": "Melting die score bonus"},
	"hot_streak": {"type": EffectType.SCORE_MULTIPLIER, "value": 1.15, "desc": "Consecutive scoring bonus"},
	"one_roll_wonder": {"type": EffectType.SCORE_ADDITIVE, "value": 20, "desc": "First roll bonus"},
	"power_surge": {"type": EffectType.SCORE_MULTIPLIER, "value": 1.1, "desc": "Powerup count multiplier"},
	"snake_eyes": {"type": EffectType.SCORE_ADDITIVE, "value": 15, "desc": "Double ones bonus"},
	"randomizer": {"type": EffectType.UTILITY, "value": 15, "desc": "Random effect each round"},
}


## Simulate N games of Yahtzee and return average total score.
func simulate_baseline(num_games: int, num_dice: int = NUM_DICE, num_rolls: int = NUM_ROLLS) -> float:
	var total_score: float = 0.0
	for _i in range(num_games):
		total_score += _simulate_one_game(num_dice, num_rolls)
	return total_score / num_games


## Simulate a single Yahtzee game and return total score.
func _simulate_one_game(num_dice: int = NUM_DICE, num_rolls: int = NUM_ROLLS) -> int:
	var upper_scores := {}
	var lower_scores := {}
	var dice_values := []

	# Play 13 turns (one per category)
	var remaining_categories := ALL_CATEGORIES.duplicate()
	for _turn in range(ALL_CATEGORIES.size()):
		if remaining_categories.is_empty():
			break
		# Roll dice with re-rolls
		dice_values = _simulate_turn_rolling(num_dice, num_rolls)
		# Choose best category
		var best_cat := _choose_best_category(dice_values, remaining_categories)
		var score := _calculate_category_score(best_cat, dice_values)
		if best_cat in UPPER_CATEGORIES:
			upper_scores[best_cat] = score
		else:
			lower_scores[best_cat] = score
		remaining_categories.erase(best_cat)

	# Calculate totals
	var upper_total := 0
	for cat in UPPER_CATEGORIES:
		upper_total += upper_scores.get(cat, 0)
	var upper_bonus := UPPER_BONUS_AMOUNT if upper_total >= UPPER_BONUS_THRESHOLD else 0

	var lower_total := 0
	for cat in LOWER_CATEGORIES:
		lower_total += lower_scores.get(cat, 0)

	return upper_total + upper_bonus + lower_total


## Simulate a single turn of dice rolling (with intelligent re-rolling).
func _simulate_turn_rolling(num_dice: int, num_rolls: int) -> Array:
	var dice := []
	for _i in range(num_dice):
		dice.append(randi_range(1, DICE_SIDES))

	# Simulate re-rolls: keep the most frequent face to build toward sets
	for _roll in range(num_rolls - 1):
		var counts := _count_faces(dice)
		var best_face := 0
		var best_count := 0
		for face in counts:
			if counts[face] > best_count:
				best_count = counts[face]
				best_face = face
			elif counts[face] == best_count and face > best_face:
				best_face = face
		# Re-roll dice that don't match the best face (simple greedy strategy)
		for i in range(dice.size()):
			if dice[i] != best_face:
				dice[i] = randi_range(1, DICE_SIDES)

	return dice


## Count occurrences of each die face.
func _count_faces(dice: Array) -> Dictionary:
	var counts := {}
	for d in dice:
		counts[d] = counts.get(d, 0) + 1
	return counts


## Choose the best available category for the given dice.
func _choose_best_category(dice: Array, available: Array) -> String:
	var best_cat: String = available[0]
	var best_score := -1
	for cat in available:
		var score := _calculate_category_score(cat, dice)
		if score > best_score:
			best_score = score
			best_cat = cat
		elif score == best_score:
			# Prefer lower section categories (harder to fill well later)
			if cat in LOWER_CATEGORIES and best_cat in UPPER_CATEGORIES:
				best_cat = cat
	return best_cat


## Calculate the score for a specific category with given dice.
func _calculate_category_score(category: String, dice: Array) -> int:
	var counts := _count_faces(dice)
	var total := 0
	for d in dice:
		total += d

	match category:
		"ones":
			return counts.get(1, 0) * 1
		"twos":
			return counts.get(2, 0) * 2
		"threes":
			return counts.get(3, 0) * 3
		"fours":
			return counts.get(4, 0) * 4
		"fives":
			return counts.get(5, 0) * 5
		"sixes":
			return counts.get(6, 0) * 6
		"three_of_a_kind":
			for face in counts:
				if counts[face] >= 3:
					return total
			return 0
		"four_of_a_kind":
			for face in counts:
				if counts[face] >= 4:
					return total
			return 0
		"full_house":
			var has_three := false
			var has_two := false
			for face in counts:
				if counts[face] == 3:
					has_three = true
				if counts[face] == 2:
					has_two = true
			if has_three and has_two:
				return FULL_HOUSE_SCORE
			return 0
		"small_straight":
			if _has_straight(counts, 4):
				return SMALL_STRAIGHT_SCORE
			return 0
		"large_straight":
			if _has_straight(counts, 5):
				return LARGE_STRAIGHT_SCORE
			return 0
		"yahtzee":
			for face in counts:
				if counts[face] >= 5:
					return YAHTZEE_SCORE
			return 0
		"chance":
			return total
		_:
			return 0


## Check if the dice contain a straight of the given length.
func _has_straight(counts: Dictionary, length: int) -> bool:
	var consecutive := 0
	for face in range(1, DICE_SIDES + 1):
		if counts.get(face, 0) > 0:
			consecutive += 1
			if consecutive >= length:
				return true
		else:
			consecutive = 0
	return false


## Estimate the score delta for a given item effect.
## Returns a Dictionary with: score_delta, money_delta, total_value, description
func estimate_item_value(item_id: String, item_data: Dictionary, num_simulations: int) -> Dictionary:
	var effect: Dictionary = KNOWN_EFFECTS.get(item_id, {})
	var effect_type: int = effect.get("type", EffectType.UNKNOWN)
	var effect_value: float = effect.get("value", 0.0)
	var price: int = item_data.get("price", 100)
	var rarity: String = item_data.get("rarity", "common")

	# Run baseline simulation
	var baseline_avg: float = simulate_baseline(num_simulations)

	var score_delta: float = 0.0
	var money_delta: float = 0.0

	match effect_type:
		EffectType.SCORE_MULTIPLIER:
			# Simulate with multiplied score
			var boosted_avg: float = baseline_avg * effect_value
			score_delta = boosted_avg - baseline_avg

		EffectType.SCORE_ADDITIVE:
			# Flat additive bonus per game (applied across several categories)
			score_delta = effect_value * 6.0  # Rough: bonus triggers ~6 times per game

		EffectType.EXTRA_DICE:
			# Simulate with extra dice
			var boosted_avg: float = simulate_baseline(num_simulations, NUM_DICE + int(effect_value))
			score_delta = boosted_avg - baseline_avg

		EffectType.EXTRA_ROLLS:
			# Simulate with extra rolls
			var boosted_avg: float = simulate_baseline(num_simulations, NUM_DICE, NUM_ROLLS + int(effect_value))
			score_delta = boosted_avg - baseline_avg

		EffectType.CATEGORY_UPGRADE:
			# Level up effect: multiplies individual category scores
			score_delta = baseline_avg * (effect_value - 1.0)

		EffectType.ECONOMY_FLAT:
			money_delta = effect_value

		EffectType.ECONOMY_SCALING:
			# Estimate based on average money earned per game (~200)
			money_delta = 200.0 * (effect_value - 1.0)

		EffectType.UTILITY:
			# Use the estimated point value directly
			score_delta = effect_value

		EffectType.UPPER_BONUS_BOOST:
			# Upper bonus multiplied
			score_delta = UPPER_BONUS_AMOUNT * (effect_value - 1.0)

		EffectType.LOWER_BONUS_BOOST:
			score_delta = 15.0 * effect_value

		EffectType.YAHTZEE_BONUS_BOOST:
			# Yahtzee bonus (base 100) × multiplier, weighted by ~15% chance of getting yahtzee
			score_delta = 100.0 * (effect_value - 1.0) * 0.15

		EffectType.CHANCE_BONUS:
			score_delta = effect_value

		EffectType.UNKNOWN:
			# Unknown effect: estimate conservatively based on rarity
			var rarity_mult := _rarity_value_multiplier(rarity)
			score_delta = 10.0 * rarity_mult

	# Calculate total value (score + money converted to approximate points)
	# Rough conversion: $1 ≈ 0.1 points of value
	var money_as_points: float = money_delta * 0.1
	var total_value: float = score_delta + money_as_points

	# Cost efficiency: $/point
	var dollars_per_point: float = 0.0
	if total_value > 0:
		dollars_per_point = float(price) / total_value

	# Tier rating
	var tier: String = _calculate_tier(total_value, price, rarity)

	return {
		"item_id": item_id,
		"price": price,
		"rarity": rarity,
		"effect_type": EffectType.keys()[effect_type] if effect_type < EffectType.size() else "UNKNOWN",
		"effect_desc": effect.get("desc", "Unknown effect"),
		"baseline_avg": baseline_avg,
		"score_delta": score_delta,
		"money_delta": money_delta,
		"total_value": total_value,
		"dollars_per_point": dollars_per_point,
		"tier": tier
	}


## Calculate a tier rating (S/A/B/C/D/F) based on value, price, and rarity.
func _calculate_tier(total_value: float, price: int, rarity: String) -> String:
	if total_value <= 0:
		return "F"

	# Value efficiency = value per dollar spent
	var efficiency: float = total_value / float(max(price, 1))

	# Adjust for rarity expectation (higher rarity should provide more value)
	var rarity_expectation := _rarity_value_multiplier(rarity)
	var adjusted_efficiency: float = efficiency / rarity_expectation

	if adjusted_efficiency >= 1.0:
		return "S"
	elif adjusted_efficiency >= 0.5:
		return "A"
	elif adjusted_efficiency >= 0.25:
		return "B"
	elif adjusted_efficiency >= 0.1:
		return "C"
	elif adjusted_efficiency >= 0.05:
		return "D"
	else:
		return "F"


## Get a rarity-based value multiplier for expectations.
func _rarity_value_multiplier(rarity: String) -> float:
	match rarity.to_lower():
		"common":
			return 1.0
		"uncommon":
			return 1.5
		"rare":
			return 2.5
		"epic":
			return 4.0
		"legendary":
			return 6.0
		_:
			return 1.0


## Generate a full report for all items.
## Returns Array of dictionaries sorted by tier then total_value descending.
func generate_full_report(items: Array[Dictionary], num_simulations: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for item in items:
		var result: Dictionary = estimate_item_value(item.id, item, num_simulations)
		result["display_name"] = item.get("display_name", item.id)
		result["item_type"] = item.get("item_type", "power_up")
		results.append(result)

	# Sort by tier (S first) then by total_value descending
	var tier_order := {"S": 0, "A": 1, "B": 2, "C": 3, "D": 4, "F": 5}
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = tier_order.get(a.tier, 5)
		var tb: int = tier_order.get(b.tier, 5)
		if ta != tb:
			return ta < tb
		return a.total_value > b.total_value
	)

	return results
