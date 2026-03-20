extends RefCounted
class_name BotStatistics

## BotStatistics
##
## Collects per-run and aggregate statistics across all bot runs.
## Used by BotReportWriter to produce the final JSON report.

var runs: Array[Dictionary] = []
var attempts: Array[Dictionary] = []
var _current_run: Dictionary = {}
var _current_attempt: Dictionary = {}


## start_run(run_id, channel)
##
## Initializes tracking for a new run.
func start_run(run_id: int, channel: int) -> void:
	# Start a new attempt if none is active
	if _current_attempt.is_empty():
		_start_attempt()
	_current_run = {
		"run_id": run_id,
		"channel": channel,
		"outcome": "in_progress",
		"rounds_completed": 0,
		"rounds_failed": 0,
		"total_score_per_round": [],
		"final_score": 0,
		"money_earned": 0,
		"money_spent": 0,
		"items_purchased": [],
		"power_ups_active": [],
		"consumables_used": [],
		"consumables_sold": [],
		"turns_played": 0,
		"rolls_used": 0,
		"yahtzees_rolled": 0,
		"upper_bonuses": 0,
		"chores_selected_easy": 0,
		"chores_selected_hard": 0,
		"mom_visits": 0,
		"loss_round": -1,
		"round_failed": 7,
		"highest_channel_reached": channel,
		"power_ups_purchased": 0,
		"consumables_purchased": 0,
		"consumables_sold_count": 0,
		"mods_purchased": 0,
		"color_dice_purchased": 0,
		"total_money_earned": 0,
		"challenge_rewards_earned": 0,
		"end_of_round_bonuses": 0,
		"shop_rerolls": 0,
		"budget_estimates": [],
		"start_time": Time.get_ticks_msec()
	}


## _start_attempt()
##
## Begins tracking a new attempt (channel 1 through channel_max or until loss).
func _start_attempt() -> void:
	_current_attempt = {
		"attempt_id": attempts.size() + 1,
		"outcome": "in_progress",
		"highest_channel_reached": 0,
		"channels_completed": 0,
		"total_runs": 0,
		"total_score": 0,
		"start_time": Time.get_ticks_msec()
	}


## end_attempt(outcome, final_channel)
##
## Finalizes the current attempt. outcome is "full_win" or "loss".
func end_attempt(outcome: String, final_channel: int) -> void:
	_current_attempt.outcome = outcome
	_current_attempt.highest_channel_reached = final_channel
	_current_attempt.duration_ms = Time.get_ticks_msec() - _current_attempt.start_time
	attempts.append(_current_attempt)
	_current_attempt = {}


## record_round_score(round_number, score)
func record_round_score(round_number: int, score: int) -> void:
	_current_run.total_score_per_round.append({
		"round": round_number,
		"score": score
	})


## record_round_completed()
func record_round_completed() -> void:
	_current_run.rounds_completed += 1


## record_round_failed(round_number)
func record_round_failed(round_number: int) -> void:
	_current_run.rounds_failed += 1
	_current_run.loss_round = round_number
	_current_run.round_failed = round_number


## record_turn()
func record_turn() -> void:
	_current_run.turns_played += 1


## record_roll()
func record_roll() -> void:
	_current_run.rolls_used += 1


## record_yahtzee()
func record_yahtzee() -> void:
	_current_run.yahtzees_rolled += 1


## record_upper_bonus()
func record_upper_bonus() -> void:
	_current_run.upper_bonuses += 1


## record_purchase(item_id, item_type, price)
func record_purchase(item_id: String, item_type: String, price: int) -> void:
	_current_run.items_purchased.append({
		"id": item_id,
		"type": item_type,
		"price": price
	})
	_current_run.money_spent += price
	match item_type:
		"power_up":
			_current_run.power_ups_purchased += 1
		"consumable":
			_current_run.consumables_purchased += 1
		"mod":
			_current_run.mods_purchased += 1
		"colored_dice":
			_current_run.color_dice_purchased += 1


## record_money_earned(amount)
func record_money_earned(amount: int) -> void:
	_current_run.money_earned += amount
	_current_run.total_money_earned += amount


## record_challenge_reward(amount)
func record_challenge_reward(amount: int) -> void:
	_current_run.challenge_rewards_earned += amount
	_current_run.total_money_earned += amount


## record_end_of_round_bonus(amount)
func record_end_of_round_bonus(amount: int) -> void:
	_current_run.end_of_round_bonuses += amount
	_current_run.total_money_earned += amount


## record_shop_reroll()
##
## Tracks when the bot rerolls the shop.
func record_shop_reroll() -> void:
	_current_run.shop_rerolls += 1


## record_economy_estimate(round_num, budget_info)
##
## Stores the economy estimate snapshot taken during a shop phase.
func record_economy_estimate(round_num: int, budget_info: Dictionary) -> void:
	_current_run.budget_estimates.append({
		"round": round_num,
		"pressure": budget_info.get("budget_pressure", "low"),
		"points_gap": budget_info.get("points_gap", 0),
		"dollars_per_point": budget_info.get("dollars_per_point_needed", 0.0),
		"projected_income": budget_info.get("projected_income", 0)
	})


## record_consumable_used(consumable_id)
func record_consumable_used(consumable_id: String) -> void:
	_current_run.consumables_used.append(consumable_id)


## record_consumable_sold(consumable_id)
func record_consumable_sold(consumable_id: String) -> void:
	_current_run.consumables_sold.append(consumable_id)
	_current_run.consumables_sold_count += 1


## record_highest_channel(channel)
func record_highest_channel(channel: int) -> void:
	if channel > _current_run.highest_channel_reached:
		_current_run.highest_channel_reached = channel


## record_chore_selected(is_hard)
##
## Tracks whether the bot selected an EASY or HARD chore.
func record_chore_selected(is_hard: bool) -> void:
	if is_hard:
		_current_run.chores_selected_hard += 1
	else:
		_current_run.chores_selected_easy += 1


## record_mom_visit()
##
## Tracks when Mom appeared during the run.
func record_mom_visit() -> void:
	_current_run.mom_visits += 1


## end_run(outcome, final_score)
##
## Finalizes the current run. outcome is "win" or "loss".
func end_run(outcome: String, final_score: int) -> void:
	_current_run.outcome = outcome
	_current_run.final_score = final_score
	_current_run.duration_ms = Time.get_ticks_msec() - _current_run.start_time
	runs.append(_current_run)

	# Update current attempt tracking
	if not _current_attempt.is_empty():
		_current_attempt.total_runs += 1
		_current_attempt.total_score += final_score
		if outcome == "win":
			_current_attempt.channels_completed += 1
			var ch: int = _current_run.channel
			if ch > _current_attempt.highest_channel_reached:
				_current_attempt.highest_channel_reached = ch

	_current_run = {}


## get_aggregate() -> Dictionary
##
## Computes aggregate statistics across all completed runs.
func get_aggregate() -> Dictionary:
	if runs.size() == 0:
		return { "total_runs": 0 }

	var total_runs := runs.size()
	var wins := 0
	var losses := 0
	var total_score := 0
	var total_rounds_completed := 0
	var total_turns := 0
	var total_rolls := 0
	var total_yahtzees := 0
	var total_upper_bonuses := 0
	var total_mom_visits := 0
	var total_chores_easy := 0
	var total_chores_hard := 0
	var total_power_ups_purchased := 0
	var total_consumables_purchased := 0
	var total_consumables_used := 0
	var total_consumables_sold := 0
	var total_mods_purchased := 0
	var total_color_dice_purchased := 0
	var total_money_earned := 0
	var total_money_spent := 0
	var total_challenge_rewards := 0
	var total_end_of_round_bonuses := 0
	var total_shop_rerolls := 0
	var overall_highest_channel := 0
	var loss_round_counts := {}
	var channel_results := {}
	var highest_score := 0
	var lowest_score := 999999

	for run in runs:
		if run.outcome == "win":
			wins += 1
		else:
			losses += 1
			var lr: int = run.get("loss_round", -1)
			if lr > 0:
				loss_round_counts[lr] = loss_round_counts.get(lr, 0) + 1

		total_score += run.final_score
		total_rounds_completed += run.rounds_completed
		total_turns += run.turns_played
		total_rolls += run.rolls_used
		total_yahtzees += run.yahtzees_rolled
		total_upper_bonuses += run.upper_bonuses
		total_mom_visits += run.get("mom_visits", 0)
		total_chores_easy += run.get("chores_selected_easy", 0)
		total_chores_hard += run.get("chores_selected_hard", 0)
		total_power_ups_purchased += run.get("power_ups_purchased", 0)
		total_consumables_purchased += run.get("consumables_purchased", 0)
		total_consumables_used += run.get("consumables_used", []).size()
		total_consumables_sold += run.get("consumables_sold_count", 0)
		total_mods_purchased += run.get("mods_purchased", 0)
		total_color_dice_purchased += run.get("color_dice_purchased", 0)
		total_money_earned += run.get("total_money_earned", 0)
		total_money_spent += run.get("money_spent", 0)
		total_challenge_rewards += run.get("challenge_rewards_earned", 0)
		total_end_of_round_bonuses += run.get("end_of_round_bonuses", 0)

		var run_shop_rerolls: int = run.get("shop_rerolls", 0)
		total_shop_rerolls += run_shop_rerolls

		var run_highest_ch: int = run.get("highest_channel_reached", 0)
		if run_highest_ch > overall_highest_channel:
			overall_highest_channel = run_highest_ch

		if run.final_score > highest_score:
			highest_score = run.final_score
		if run.final_score < lowest_score:
			lowest_score = run.final_score

		var ch_key := str(run.channel)
		if not channel_results.has(ch_key):
			channel_results[ch_key] = { "wins": 0, "losses": 0 }
		if run.outcome == "win":
			channel_results[ch_key].wins += 1
		else:
			channel_results[ch_key].losses += 1

	@warning_ignore("integer_division")
	var avg_score := total_score / total_runs if total_runs > 0 else 0

	# Find most common loss round
	var most_common_loss_round := -1
	var max_loss_count := 0
	for round_num in loss_round_counts:
		if loss_round_counts[round_num] > max_loss_count:
			max_loss_count = loss_round_counts[round_num]
			most_common_loss_round = round_num

	return {
		"total_runs": total_runs,
		"total_attempts": attempts.size(),
		"full_clears": _count_attempt_outcomes("full_win"),
		"attempt_losses": _count_attempt_outcomes("loss"),
		"attempt_clear_rate": float(_count_attempt_outcomes("full_win")) / attempts.size() if attempts.size() > 0 else 0.0,
		"avg_channels_per_attempt": _avg_channels_per_attempt(),
		"channel_reached_distribution": _channel_reached_distribution(),
		"wins": wins,
		"losses": losses,
		"channel_win_rate": float(wins) / total_runs if total_runs > 0 else 0.0,
		"average_score": avg_score,
		"highest_score": highest_score,
		"lowest_score": lowest_score if lowest_score < 999999 else 0,
		"total_rounds_completed": total_rounds_completed,
		"total_turns": total_turns,
		"total_rolls": total_rolls,
		"total_yahtzees": total_yahtzees,
		"total_upper_bonuses": total_upper_bonuses,
		"total_mom_visits": total_mom_visits,
		"total_chores_easy": total_chores_easy,
		"total_chores_hard": total_chores_hard,
		"highest_channel_reached": overall_highest_channel,
		"total_power_ups_purchased": total_power_ups_purchased,
		"total_consumables_purchased": total_consumables_purchased,
		"total_consumables_used": total_consumables_used,
		"total_consumables_sold": total_consumables_sold,
		"total_mods_purchased": total_mods_purchased,
		"total_color_dice_purchased": total_color_dice_purchased,
		"total_money_earned": total_money_earned,
		"total_money_spent": total_money_spent,
		"total_challenge_rewards": total_challenge_rewards,
		"total_end_of_round_bonuses": total_end_of_round_bonuses,
		"total_shop_rerolls": total_shop_rerolls,
		"most_common_loss_round": most_common_loss_round,
		"loss_round_distribution": loss_round_counts,
		"channel_results": channel_results
	}


## clear()
func clear() -> void:
	runs.clear()
	attempts.clear()
	_current_run = {}
	_current_attempt = {}


## _count_attempt_outcomes(outcome) -> int
func _count_attempt_outcomes(outcome: String) -> int:
	var count := 0
	for attempt in attempts:
		if attempt.outcome == outcome:
			count += 1
	return count


## _avg_channels_per_attempt() -> float
func _avg_channels_per_attempt() -> float:
	if attempts.is_empty():
		return 0.0
	var total := 0
	for attempt in attempts:
		total += attempt.channels_completed
	return float(total) / attempts.size()


## _channel_reached_distribution() -> Dictionary
##
## Returns { channel_number: count } showing how many attempts reached each channel.
func _channel_reached_distribution() -> Dictionary:
	var dist := {}
	for attempt in attempts:
		var ch: int = attempt.highest_channel_reached
		var ch_key := str(ch)
		dist[ch_key] = dist.get(ch_key, 0) + 1
	return dist
