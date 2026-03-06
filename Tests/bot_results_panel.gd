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

	var text := "[b]Bot Results[/b]\n"
	text += "Runs: %d | Wins: %d | Losses: %d\n" % [agg.total_runs, agg.wins, agg.losses]
	text += "Win Rate: %.1f%%\n" % (agg.win_rate * 100.0)
	text += "Avg Score: %d | High: %d | Low: %d\n" % [agg.average_score, agg.highest_score, agg.lowest_score]
	text += "Total Rolls: %d | Yahtzees: %d\n" % [agg.total_rolls, agg.total_yahtzees]
	text += "Upper Bonuses: %d\n" % agg.total_upper_bonuses

	if agg.most_common_loss_round > 0:
		text += "Most Common Loss Round: %d\n" % agg.most_common_loss_round

	# Channel breakdown
	if agg.channel_results.size() > 0:
		text += "\n[b]By Channel:[/b]\n"
		for ch in agg.channel_results:
			var cr = agg.channel_results[ch]
			text += "  Ch %s: %dW / %dL\n" % [ch, cr.wins, cr.losses]

	text += "\nErrors: %d | Edge Cases: %d" % [bot_controller.logger.get_error_count(), bot_controller.logger.get_edge_case_count()]

	if results_label:
		results_label.bbcode_enabled = true
		results_label.text = text
