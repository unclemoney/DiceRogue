extends RefCounted
class_name BotStatistics

## BotStatistics
##
## Collects per-run and aggregate statistics across all bot runs.
## Used by BotReportWriter to produce the final JSON report.

var runs: Array[Dictionary] = []
var _current_run: Dictionary = {}


## start_run(run_id, channel)
##
## Initializes tracking for a new run.
func start_run(run_id: int, channel: int) -> void:
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
		"turns_played": 0,
		"rolls_used": 0,
		"yahtzees_rolled": 0,
		"upper_bonuses": 0,
		"chores_selected_easy": 0,
		"chores_selected_hard": 0,
		"mom_visits": 0,
		"loss_round": -1,
		"start_time": Time.get_ticks_msec()
	}


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


## record_money_earned(amount)
func record_money_earned(amount: int) -> void:
	_current_run.money_earned += amount


## record_consumable_used(consumable_id)
func record_consumable_used(consumable_id: String) -> void:
	_current_run.consumables_used.append(consumable_id)


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
		"wins": wins,
		"losses": losses,
		"win_rate": float(wins) / total_runs if total_runs > 0 else 0.0,
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
		"most_common_loss_round": most_common_loss_round,
		"loss_round_distribution": loss_round_counts,
		"channel_results": channel_results
	}


## clear()
func clear() -> void:
	runs.clear()
	_current_run = {}
