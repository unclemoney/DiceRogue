extends Node2D

## item_value_test.gd
##
## Test scene script for running item value estimations.
## Loads all PowerUpData and ConsumableData .tres resources,
## runs Monte Carlo simulations via ItemValueEstimator, and
## displays/saves the results.

const ItemValueEstimatorScript := preload("res://Scripts/Bot/ItemValueEstimator.gd")
const ItemValueConfigScript := preload("res://Scripts/Bot/ItemValueConfig.gd")

const POWERUP_DIR := "res://Scripts/PowerUps/"
const CONSUMABLE_DIR := "res://Scripts/Consumable/"

@onready var results_panel: PanelContainer = $ItemValueResultsPanel
@export var config: Resource  # ItemValueConfig

var _estimator: RefCounted  # ItemValueEstimator
var _all_results: Array[Dictionary] = []
var _baseline_avg: float = 0.0


func _ready() -> void:
	if not config:
		config = ItemValueConfigScript.new()

	_estimator = ItemValueEstimatorScript.new()

	print("[ItemValueTest] Starting item value estimation...")
	if results_panel:
		results_panel.update_status("Loading item data...")

	# Defer to let scene settle
	await get_tree().create_timer(0.2).timeout
	_run_estimation()


## _run_estimation()
##
## Main entry point: loads items, runs simulations, displays results.
func _run_estimation() -> void:
	# Load item data
	var items: Array[Dictionary] = []

	if config.test_all_powerups:
		items.append_array(_load_powerup_data())
	if config.test_all_consumables:
		items.append_array(_load_consumable_data())

	# If specific IDs provided and not testing all, filter
	if not config.test_all_powerups and not config.test_all_consumables:
		if config.specific_item_ids.size() > 0:
			var all_powerups := _load_powerup_data()
			var all_consumables := _load_consumable_data()
			var combined := all_powerups + all_consumables
			for item in combined:
				if item.id in config.specific_item_ids:
					items.append(item)

	if items.is_empty():
		print("[ItemValueTest] No items to evaluate!")
		if results_panel:
			results_panel.update_status("No items found to evaluate.")
		return

	print("[ItemValueTest] Evaluating %d items with %d simulations each..." % [items.size(), config.simulations_per_item])
	if results_panel:
		results_panel.update_status("Running baseline simulation...")

	# Run baseline
	_baseline_avg = _estimator.simulate_baseline(config.simulations_per_item)
	print("[ItemValueTest] Baseline average score: %.1f" % _baseline_avg)

	if results_panel:
		results_panel.update_status("Evaluating %d items..." % items.size())

	# Process items in batches to prevent frame drops
	_all_results = []
	var batch_size := 5
	for i in range(0, items.size(), batch_size):
		var batch_end := mini(i + batch_size, items.size())
		for j in range(i, batch_end):
			var item: Dictionary = items[j]
			var result: Dictionary = _estimator.estimate_item_value(item.id, item, config.simulations_per_item)
			result["display_name"] = item.get("display_name", item.id)
			result["item_type"] = item.get("item_type", "power_up")
			_all_results.append(result)

			if config.verbose:
				print("[ItemValueTest] %s: tier=%s delta=%.1f $/pt=%.1f" % [
					result.display_name, result.tier, result.score_delta, result.dollars_per_point])

		if results_panel:
			results_panel.update_status("Evaluated %d / %d items..." % [batch_end, items.size()])

		# Yield to let the UI update between batches
		await get_tree().process_frame

	# Sort results
	var tier_order := {"S": 0, "A": 1, "B": 2, "C": 3, "D": 4, "F": 5}
	_all_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = tier_order.get(a.tier, 5)
		var tb: int = tier_order.get(b.tier, 5)
		if ta != tb:
			return ta < tb
		return a.total_value > b.total_value
	)

	# Display results
	if results_panel:
		results_panel.update_status("Complete! %d items evaluated." % _all_results.size())
		results_panel.display_results(_all_results, _baseline_avg)

	# Save report if configured
	if config.save_report:
		_save_report()

	print("[ItemValueTest] Estimation complete!")


## _load_powerup_data() -> Array[Dictionary]
##
## Scans the PowerUps directory for .tres files and loads them as dictionaries.
func _load_powerup_data() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var dir := DirAccess.open(POWERUP_DIR)
	if not dir:
		print("[ItemValueTest] Could not open powerup directory: %s" % POWERUP_DIR)
		return items

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := POWERUP_DIR + file_name
			var res = load(path)
			if res and res.get("id"):
				items.append({
					"id": res.id,
					"display_name": res.display_name if res.display_name else res.id,
					"price": res.price if res.get("price") else 100,
					"rarity": res.rarity if res.get("rarity") else "common",
					"item_type": "power_up",
				})
		file_name = dir.get_next()
	dir.list_dir_end()

	print("[ItemValueTest] Loaded %d powerup definitions" % items.size())
	return items


## _load_consumable_data() -> Array[Dictionary]
##
## Scans the Consumable directory for .tres files and loads them as dictionaries.
func _load_consumable_data() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var dir := DirAccess.open(CONSUMABLE_DIR)
	if not dir:
		print("[ItemValueTest] Could not open consumable directory: %s" % CONSUMABLE_DIR)
		return items

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := CONSUMABLE_DIR + file_name
			var res = load(path)
			if res and res.get("id"):
				items.append({
					"id": res.id,
					"display_name": res.display_name if res.display_name else res.id,
					"price": res.price if res.get("price") else 50,
					"rarity": "common",  # ConsumableData has no rarity field
					"item_type": "consumable",
				})
		file_name = dir.get_next()
	dir.list_dir_end()

	print("[ItemValueTest] Loaded %d consumable definitions" % items.size())
	return items


## _save_report()
##
## Saves the estimation results as a text report to user://item_value_reports/.
func _save_report() -> void:
	var dir_path := "user://item_value_reports"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_path := "%s/item_values_%s.txt" % [dir_path, timestamp]

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("[ItemValueTest] Failed to save report to: %s" % file_path)
		return

	file.store_line("=== Item Value Estimation Report ===")
	file.store_line("Generated: %s" % Time.get_datetime_string_from_system())
	file.store_line("Simulations per item: %d" % config.simulations_per_item)
	file.store_line("Baseline average score: %.1f" % _baseline_avg)
	file.store_line("Items evaluated: %d" % _all_results.size())
	file.store_line("")

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
		var tier_items := _all_results.filter(func(r: Dictionary) -> bool: return r.tier == tier)
		if tier_items.is_empty():
			continue

		file.store_line("--- %s (%d items) ---" % [tier_labels[tier], tier_items.size()])
		for item in tier_items:
			var type_tag: String = "[PU]" if item.get("item_type", "power_up") == "power_up" else "[CON]"
			var dpp_str := "N/A"
			if item.dollars_per_point > 0:
				dpp_str = "$%.1f/pt" % item.dollars_per_point
			file.store_line("  [%s] %s %s | %s | $%d | +%.1f pts | +$%.0f econ | %s | %s" % [
				tier, type_tag, item.get("display_name", item.item_id),
				item.get("rarity", "???").capitalize(),
				item.price, item.score_delta, item.money_delta,
				dpp_str, item.get("effect_desc", "")
			])
		file.store_line("")

	file.close()
	print("[ItemValueTest] Report saved to: %s" % file_path)
