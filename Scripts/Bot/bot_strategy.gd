extends RefCounted
class_name BotStrategy

## BotStrategy
##
## Decision engine for the automated bot player.
## Contains logic for scoring, dice locking, shop purchases, and selling.

# Rarity ordering: higher index = better
const RARITY_ORDER := {
	"common": 0,
	"uncommon": 1,
	"rare": 2,
	"epic": 3,
	"legendary": 4
}


## choose_best_category(scorecard, values) -> Dictionary
##
## Evaluates all unscored categories and picks the one with the highest score.
## Tiebreaks by category priority (more specific = higher).
## Returns { "section": Scorecard.Section, "category": String, "score": int }
## or an empty Dictionary if no categories remain.
func choose_best_category(scorecard: Scorecard, values: Array[int]) -> Dictionary:
	var best_score := -1
	var best_section: int = -1
	var best_category := ""
	var best_priority := -1

	# Upper section
	for category in scorecard.upper_scores.keys():
		if scorecard.upper_scores[category] == null:
			var score = scorecard.evaluate_category(category, values)
			var priority = scorecard._get_category_priority(category)
			if score > best_score or (score == best_score and priority > best_priority):
				best_score = score
				best_section = Scorecard.Section.UPPER
				best_category = category
				best_priority = priority

	# Lower section
	for category in scorecard.lower_scores.keys():
		if scorecard.lower_scores[category] == null:
			var score = scorecard.evaluate_category(category, values)
			var priority = scorecard._get_category_priority(category)
			if score > best_score or (score == best_score and priority > best_priority):
				best_score = score
				best_section = Scorecard.Section.LOWER
				best_category = category
				best_priority = priority

	if best_category == "":
		return {}

	return { "section": best_section, "category": best_category, "score": best_score }


## choose_dice_to_lock(dice_list, values) -> Array[int]
##
## Decides which dice indices to lock before the next roll.
## Strategy: evaluate what holding various combinations would yield,
## and lock dice that contribute to the best expected outcome.
## Returns an array of dice indices (0-based) to lock.
func choose_dice_to_lock(_scorecard: Scorecard, dice_list: Array, values: Array[int]) -> Array[int]:
	if values.size() == 0:
		return []

	# Count occurrences of each value
	var counts := {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1

	# Find the value with the most occurrences (for of-a-kind strategy)
	var best_value := 0
	var best_count := 0
	for v in counts:
		if counts[v] > best_count:
			best_count = counts[v]
			best_value = v
		elif counts[v] == best_count and v > best_value:
			best_value = v

	# Check if we already have a strong hand
	var sorted_vals := values.duplicate()
	sorted_vals.sort()
	var unique_sorted := []
	for v in sorted_vals:
		if unique_sorted.size() == 0 or unique_sorted[-1] != v:
			unique_sorted.append(v)

	# If we have 4+ of a kind, lock those dice
	if best_count >= 4:
		var lock_indices: Array[int] = []
		for i in range(dice_list.size()):
			if values[i] == best_value:
				lock_indices.append(i)
		return lock_indices

	# If we have a large straight (5 sequential), lock all
	if unique_sorted.size() >= 5:
		var is_straight := true
		for i in range(unique_sorted.size() - 1):
			if i >= 4:
				break
			if unique_sorted[i + 1] - unique_sorted[i] != 1:
				is_straight = false
				break
		if is_straight:
			var lock_indices: Array[int] = []
			for i in range(dice_list.size()):
				lock_indices.append(i)
			return lock_indices

	# If we have 3 of a kind, lock those to try for 4+ or yahtzee
	if best_count >= 3:
		var lock_indices: Array[int] = []
		for i in range(dice_list.size()):
			if values[i] == best_value:
				lock_indices.append(i)
		return lock_indices

	# If we have a pair, lock them (prefer higher value pair)
	if best_count >= 2:
		var lock_indices: Array[int] = []
		for i in range(dice_list.size()):
			if values[i] == best_value:
				lock_indices.append(i)
		return lock_indices

	# No clear pattern - lock the highest value die for chance
	var max_val := 0
	var max_idx := 0
	for i in range(values.size()):
		if values[i] > max_val:
			max_val = values[i]
			max_idx = i
	return [max_idx]


## evaluate_shop_item(item_data, money) -> float
##
## Returns a priority score for a shop item. Higher = buy first.
## Considers rarity, price, and affordability.
func evaluate_shop_item(item_data: Resource, money: int, price: int) -> float:
	if price > money:
		return -1.0

	var score := 0.0

	# Rarity bonus (prefer higher rarity)
	if item_data.has_method("get") or "rarity" in item_data:
		var rarity: String = item_data.get("rarity") if item_data.get("rarity") else "common"
		score += RARITY_ORDER.get(rarity, 0) * 100.0

	# Value ratio: prefer cheaper items of same rarity
	if price > 0:
		score += (1.0 / price) * 50.0

	return score


## choose_shop_purchases(shop_items, money) -> Array
##
## Given available shop items and current money, returns items to buy
## in priority order. Each entry is the ShopItem node reference.
## Strategy: buy highest rarity items first, then by value.
func choose_shop_purchases(shop_items: Array, money: int) -> Array:
	var scored_items := []
	for item in shop_items:
		if not item or not item.item_data:
			continue
		if item.has_method("get") and item.get("buy_button"):
			if item.buy_button.disabled:
				continue
		var priority = evaluate_shop_item(item.item_data, money, item.price)
		if priority >= 0:
			scored_items.append({ "item": item, "priority": priority })

	# Sort by priority descending
	scored_items.sort_custom(func(a, b): return a.priority > b.priority)

	var to_buy := []
	var remaining_money := money
	for entry in scored_items:
		var item = entry.item
		if item.price <= remaining_money:
			to_buy.append(item)
			remaining_money -= item.price

	return to_buy


## choose_powerup_to_sell(active_power_ups) -> String
##
## When at max power-ups and a new one is available, pick the lowest
## rarity power-up to sell. Returns the id of the power-up to sell,
## or "" if none should be sold.
func choose_powerup_to_sell(active_power_ups: Dictionary) -> String:
	var worst_id := ""
	var worst_rarity := 999

	for id in active_power_ups:
		var power_up = active_power_ups[id]
		if not power_up:
			continue
		var data = null
		if power_up.has_method("get_data"):
			data = power_up.get_data()
		elif "power_up_data" in power_up:
			data = power_up.power_up_data

		if not data:
			continue

		var rarity_str: String = data.get("rarity") if data.get("rarity") else "common"
		var rarity_val: int = RARITY_ORDER.get(rarity_str, 0)
		if rarity_val < worst_rarity:
			worst_rarity = rarity_val
			worst_id = id

	return worst_id


## choose_chore_difficulty() -> bool
##
## Decides whether to pick HARD (true) or EASY (false) chores.
## HARD chores reduce goof-off progress by 30 vs 10 for EASY.
## Bot picks randomly with a 60% bias toward HARD since the larger
## progress reduction helps delay Mom's appearance.
func choose_chore_difficulty() -> bool:
	return randf() < 0.6


## should_use_reroll(turn_tracker, scorecard, values) -> bool
##
## Decides whether the bot should use remaining rolls.
## Returns true if more rolling could improve the score.
func should_use_reroll(turn_tracker: TurnTracker, scorecard: Scorecard, values: Array[int]) -> bool:
	if turn_tracker.rolls_left <= 0:
		return false

	# Evaluate current best score
	var current_best = choose_best_category(scorecard, values)
	if current_best.is_empty():
		return false

	# If we already have a yahtzee or large straight, don't reroll
	var best_cat: String = current_best.category
	if best_cat == "yahtzee" and current_best.score > 0:
		return false
	if best_cat == "large_straight" and current_best.score > 0:
		return false

	# If score is very high relative to possible max, don't reroll
	if current_best.score >= 40:
		return false

	# Otherwise, reroll if we have rolls left
	return true
