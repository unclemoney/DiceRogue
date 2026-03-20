extends PanelContainer

## item_value_results_panel.gd
##
## Displays item value estimation results in a BBCode formatted panel.

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel


func _ready() -> void:
	if not status_label:
		status_label = Label.new()
		status_label.name = "StatusLabel"
	if not results_label:
		results_label = RichTextLabel.new()
		results_label.name = "ResultsLabel"


## update_status(message)
##
## Updates the status label at the top of the panel.
func update_status(message: String) -> void:
	if status_label:
		status_label.text = message


## display_results(results, baseline_avg)
##
## Formats and displays the item value estimation results.
## results: Array[Dictionary] sorted by tier from ItemValueEstimator.generate_full_report()
## baseline_avg: float baseline average score with no items
func display_results(results: Array[Dictionary], baseline_avg: float) -> void:
	if not results_label:
		return

	var text := "[b]=== Item Value Estimation Report ===[/b]\n\n"
	text += "[b]Baseline Average Score:[/b] %.1f\n" % baseline_avg
	text += "[b]Items Evaluated:[/b] %d\n\n" % results.size()

	# Tier color map
	var tier_colors := {
		"S": "gold",
		"A": "green",
		"B": "cyan",
		"C": "white",
		"D": "orange",
		"F": "red",
	}

	# Group by tier
	var tiers := ["S", "A", "B", "C", "D", "F"]
	var tier_labels := {
		"S": "S-Tier (Exceptional)",
		"A": "A-Tier (Strong)",
		"B": "B-Tier (Good)",
		"C": "C-Tier (Average)",
		"D": "D-Tier (Below Average)",
		"F": "F-Tier (Poor)"
	}

	for tier in tiers:
		var tier_items := results.filter(func(r: Dictionary) -> bool: return r.tier == tier)
		if tier_items.is_empty():
			continue

		var color: String = tier_colors.get(tier, "white")
		text += "[color=%s][b]--- %s (%d items) ---[/b][/color]\n" % [color, tier_labels[tier], tier_items.size()]

		for item in tier_items:
			var type_tag: String = "[PU]" if item.get("item_type", "power_up") == "power_up" else "[CON]"
			var rarity_str: String = item.get("rarity", "???")
			var name_str: String = item.get("display_name", item.item_id)
			var dpp_str := "N/A"
			if item.dollars_per_point > 0:
				dpp_str = "$%.1f/pt" % item.dollars_per_point

			text += "  [color=%s][b]%s[/b][/color] %s %s" % [color, tier, type_tag, name_str]
			text += " | %s | $%d" % [rarity_str.capitalize(), item.price]
			text += " | +%.1f pts" % item.score_delta

			if item.money_delta > 0:
				text += " | +$%.0f econ" % item.money_delta

			text += " | %s" % dpp_str
			text += " | [i]%s[/i]\n" % item.get("effect_desc", "")

		text += "\n"

	# Summary statistics
	text += "[b]=== Summary ===[/b]\n"
	var power_ups := results.filter(func(r: Dictionary) -> bool: return r.get("item_type", "power_up") == "power_up")
	var consumables := results.filter(func(r: Dictionary) -> bool: return r.get("item_type", "") == "consumable")

	if power_ups.size() > 0:
		var avg_score_delta := 0.0
		for pu in power_ups:
			avg_score_delta += pu.score_delta
		avg_score_delta /= power_ups.size()
		text += "  Power-Ups: %d evaluated, avg score delta: %.1f\n" % [power_ups.size(), avg_score_delta]

	if consumables.size() > 0:
		var avg_score_delta := 0.0
		for con in consumables:
			avg_score_delta += con.score_delta
		avg_score_delta /= consumables.size()
		text += "  Consumables: %d evaluated, avg score delta: %.1f\n" % [consumables.size(), avg_score_delta]

	for tier in tiers:
		var count: int = results.filter(func(r: Dictionary) -> bool: return r.tier == tier).size()
		if count > 0:
			var color: String = tier_colors.get(tier, "white")
			text += "  [color=%s]%s: %d items[/color]\n" % [color, tier, count]

	results_label.bbcode_enabled = true
	results_label.text = text
