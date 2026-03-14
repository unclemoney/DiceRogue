extends PanelContainer

## bot_results_panel.gd
##
## In-game panel showing bot run results and status updates.

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel


func _ready() -> void:
	if not status_label:
		status_label = Label.new()
		status_label.name = "StatusLabel"
	if not results_label:
		results_label = RichTextLabel.new()
		results_label.name = "ResultsLabel"


## _on_status_changed(message)
func _on_status_changed(message: String) -> void:
	if status_label:
		status_label.text = message


## _on_runs_completed()
##
## Called when all bot runs are done. Populates the results panel.
func _on_runs_completed() -> void:
	# Find the BotController in the scene
	var bot_controller = get_parent().get_node_or_null("BotController")
	if not bot_controller:
		return

	var agg = bot_controller.statistics.get_aggregate()
	if agg.total_runs == 0:
		return

	var text := "[b]=== Bot Results ===[/b]\n\n"

	# Attempt-level overview
	text += "[b]Attempts:[/b]\n"
	text += "  Total: %d | Full Clears: %d | Losses: %d\n" % [agg.total_attempts, agg.full_clears, agg.attempt_losses]
	text += "  Clear Rate: %.1f%%\n" % (agg.attempt_clear_rate * 100.0)
	text += "  Avg Channels/Attempt: %.1f\n" % agg.avg_channels_per_attempt
	text += "  Highest Channel Reached: %d\n" % agg.highest_channel_reached

	# Channel reached distribution
	if agg.channel_reached_distribution.size() > 0:
		text += "\n[b]Attempts by Highest Channel:[/b]\n"
		var ch_keys = agg.channel_reached_distribution.keys()
		ch_keys.sort()
		for ch_key in ch_keys:
			var count: int = agg.channel_reached_distribution[ch_key]
			var pct = float(count) / agg.total_attempts * 100.0 if agg.total_attempts > 0 else 0.0
			text += "  Ch %s: %d (%.1f%%)\n" % [ch_key, count, pct]

	# Per-channel win/loss breakdown
	if agg.channel_results.size() > 0:
		text += "\n[b]Channel Win/Loss (per run):[/b]\n"
		var ch_keys = agg.channel_results.keys()
		ch_keys.sort()
		for ch in ch_keys:
			var cr = agg.channel_results[ch]
			var total_ch: int = cr.wins + cr.losses
			var ch_wr := float(cr.wins) / total_ch * 100.0 if total_ch > 0 else 0.0
			text += "  Ch %s: %dW / %dL (%.0f%%)\n" % [ch, cr.wins, cr.losses, ch_wr]

	# Scoring
	text += "\n[b]Scoring:[/b]\n"
	text += "  Avg Score: %d | High: %d | Low: %d\n" % [agg.average_score, agg.highest_score, agg.lowest_score]
	text += "  Channel Win Rate (per run): %.1f%% (%d/%d)\n" % [agg.channel_win_rate * 100.0, agg.wins, agg.total_runs]
	text += "  Yahtzees: %d | Upper Bonuses: %d\n" % [agg.total_yahtzees, agg.total_upper_bonuses]

	# Gameplay
	text += "\n[b]Gameplay:[/b]\n"
	text += "  Runs: %d | Rounds: %d | Turns: %d | Rolls: %d\n" % [agg.total_runs, agg.total_rounds_completed, agg.total_turns, agg.total_rolls]

	if agg.most_common_loss_round > 0:
		text += "  Most Common Loss Round: %d\n" % agg.most_common_loss_round
	if agg.loss_round_distribution.size() > 0:
		var loss_parts := []
		var lr_keys = agg.loss_round_distribution.keys()
		lr_keys.sort()
		for lr in lr_keys:
			loss_parts.append("R%s:%d" % [str(lr), agg.loss_round_distribution[lr]])
		text += "  Loss by Round: %s\n" % ", ".join(loss_parts)

	# Economy
	text += "\n[b]Economy:[/b]\n"
	text += "  Money Earned: $%d | Spent: $%d\n" % [agg.total_money_earned, agg.total_money_spent]
	text += "  Challenge Rewards: $%d | Round Bonuses: $%d\n" % [agg.total_challenge_rewards, agg.total_end_of_round_bonuses]

	# Items
	text += "\n[b]Items:[/b]\n"
	text += "  Power-Ups: %d | Consumables: %d (used: %d, sold: %d)\n" % [agg.total_power_ups_purchased, agg.total_consumables_purchased, agg.total_consumables_used, agg.total_consumables_sold]
	text += "  Mods: %d | Color Dice: %d\n" % [agg.total_mods_purchased, agg.total_color_dice_purchased]

	# Chores
	text += "\n[b]Chores:[/b]\n"
	text += "  Easy: %d | Hard: %d | Mom Visits: %d\n" % [agg.total_chores_easy, agg.total_chores_hard, agg.total_mom_visits]

	text += "\n[b]Debug:[/b] Errors: %d | Edge Cases: %d" % [bot_controller.logger.get_error_count(), bot_controller.logger.get_edge_case_count()]

	if results_label:
		results_label.bbcode_enabled = true
		results_label.text = text
