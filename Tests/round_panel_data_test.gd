extends Control

## round_panel_data_test.gd
##
## Verifies that GameController._build_round_panel_data() builds a debuff-only
## preview for the New Round panel, even when legacy saved round data still
## carries a grounding_id key.

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


class StubChannelManager extends RefCounted:
	var current_channel: int = 2

	func get_store_name(channel: int, round_number: int) -> String:
		return "Stub Store %d-%d" % [channel, round_number]

	func get_round_config(_channel: int = -1, _round_number: int = 1):
		return null


func _ready() -> void:
	print("\n=== ROUND PANEL DATA TEST ===")
	await get_tree().process_frame
	_run_tests()
	_finish()


func _check(condition: bool, label: String) -> void:
	var status := "PASS" if condition else "FAIL"
	if not condition:
		_failures += 1
	var line := "%s: %s" % [status, label]
	print(line)
	_lines.append(line)


func _run_tests() -> void:
	var gc := GameController.new()
	var channel_manager := StubChannelManager.new()
	var round_manager := RoundManager.new()
	var debuff_manager := DebuffManager.new()

	var round_debuff := DebuffData.new()
	round_debuff.id = "hail_satan"
	round_debuff.display_name = "Hail Satan"

	var grounding := DebuffData.new()
	grounding.id = "docked_allowance"
	grounding.display_name = "Docked Allowance"
	grounding.is_grounding = true

	debuff_manager.debuff_defs = [round_debuff, grounding]
	round_manager.channel_manager = channel_manager
	round_manager.rounds_data = [{
		"round_number": 1,
		"store_name": channel_manager.get_store_name(2, 1),
		"dice_type": "d6",
		"target_score": 150,
		"completed": false,
		"failed": false,
		"debuff_ids": ["hail_satan"],
		"grounding_id": "docked_allowance",
	}]

	gc.channel_manager = channel_manager
	gc.round_manager = round_manager
	gc.debuff_manager = debuff_manager

	var data: Dictionary = gc._build_round_panel_data(1)
	var debuffs: Array = data.get("debuffs", [])
	_check(data.get("challenge_name", "") == "Stub Store 2-1", "round panel data uses the store name")
	_check(debuffs.size() == 1, "round panel data includes only one debuff preview")
	if debuffs.size() > 0:
		_check(debuffs[0].get("name", "") == "Hail Satan", "round panel preview keeps the round debuff")

	var has_grounding := false
	for debuff_data in debuffs:
		if debuff_data.get("name", "") == "Docked Allowance":
			has_grounding = true
	_check(not has_grounding, "round panel preview ignores legacy grounding_id data")


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[RoundPanelDataTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(_failures)