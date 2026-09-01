extends Control

## round_preselect_test.gd
##
## Verifies that RoundManager pre-selects each round's debuffs when the
## zone's rounds are generated (_initialize_rounds_data): every round_data
## gains a "debuff_ids" Array, boss rounds draw exactly one debuff of the
## configured level, the per-zone draw-once pool prevents repeats, and the
## manager-less fallback stores empty selections.

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


## StubChannelManager
##
## Minimal stand-in exposing what RoundManager._initialize_rounds_data()
## calls on ChannelManager: current_channel, get_store_name, get_round_config.
class StubChannelManager extends RefCounted:
	var current_channel: int = 2
	var round_configs: Array[RoundDifficultyConfig] = []

	func get_store_name(zone: int, round_number: int) -> String:
		return "Stub Store %d-%d" % [zone, round_number]

	func get_round_config(_channel: int = -1, round_number: int = 1) -> RoundDifficultyConfig:
		if round_number >= 1 and round_number <= round_configs.size():
			return round_configs[round_number - 1]
		return null


func _ready() -> void:
	print("\n=== ROUND PRESELECT TEST ===")
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


func _make_debuff_manager() -> DebuffManager:
	var manager := DebuffManager.new()
	var defs: Array[DebuffData] = [
		load("res://Scripts/Debuff/DockedAllowanceDebuff.tres"),
		load("res://Scripts/Debuff/CouponsRevokedDebuff.tres"),
		load("res://Scripts/Debuff/PogsConfiscatedDebuff.tres"),
		load("res://Scripts/Debuff/MixedBagDebuff.tres"),
		load("res://Scripts/Debuff/TooGreedyDebuff.tres"),
		load("res://Scripts/Debuff/FasterChoresDebuff.tres"),
		load("res://Scripts/Debuff/RebellionBuff.tres"),
	]
	manager.debuff_defs = defs
	add_child(manager)
	return manager


## Builds a stub channel whose rounds 1-5 draw one L1 debuff and round 6 is
## a boss round at exact level 5. grounding_chance stays populated to verify
## RoundManager ignores it.
func _make_channel() -> StubChannelManager:
	var stub := StubChannelManager.new()
	for i in range(6):
		var config := RoundDifficultyConfig.new()
		config.round_number = i + 1
		if i == 5:
			config.is_boss_round = true
			config.boss_debuff_level = 5
		else:
			config.max_debuffs = 1
			config.debuff_difficulty_cap = 1
		config.grounding_chance = 1.0 if i == 0 else 0.0
		stub.round_configs.append(config)
	return stub


func _make_round_manager(channel: StubChannelManager, manager: DebuffManager) -> RoundManager:
	# Not added to the tree: @onready resolution and _ready() are skipped,
	# so the references are assigned directly instead.
	var rm := RoundManager.new()
	rm.channel_manager = channel
	rm.debuff_manager = manager
	return rm


func _run_tests() -> void:
	var manager := _make_debuff_manager()

	# 1. Keys present on every round, boss round draws exactly one debuff
	var rm := _make_round_manager(_make_channel(), manager)
	rm._initialize_rounds_data()
	_check(rm.rounds_data.size() == 6, "rounds_data has 6 rounds")
	var debuff_only_data := true
	for round_data in rm.rounds_data:
		if not round_data.has("debuff_ids") or round_data.has("grounding_id"):
			debuff_only_data = false
	_check(debuff_only_data, "every round_data stores only debuff_ids for round modifiers")
	var boss_data: Dictionary = rm.rounds_data[5]
	_check(boss_data["debuff_ids"] is Array, "boss debuff_ids is an Array")
	_check(boss_data["debuff_ids"].size() == 1, "boss round has exactly one debuff id")
	_check(boss_data["debuff_ids"][0] == "too_greedy", "boss debuff is too_greedy (only L5 in pool)")

	# 2. Non-boss rounds draw from the configured cap, no repeats in the zone.
	# The test pool has only two L1 debuffs, so rounds 1-2 each draw one and
	# rounds 3-5 get nothing (draw-once pool exhausted) — by design.
	var drawn: Array[String] = []
	for i in range(2):
		var ids: Array = rm.rounds_data[i]["debuff_ids"]
		_check(ids.size() == 1, "round %d drew one debuff" % (i + 1))
		for id in ids:
			_check(id in ["mixed_bag", "faster_chores"], "round %d debuff within cap 1" % (i + 1))
			_check(id not in drawn, "round %d debuff not repeated this zone" % (i + 1))
			drawn.append(id)
	for i in range(2, 5):
		_check(rm.rounds_data[i]["debuff_ids"].is_empty(), "round %d empty after L1 pool exhausted" % (i + 1))

	# 3. Groundings are no longer pre-selected into round data, even when the
	# round config still carries grounding_chance from older authored content.
	for i in range(6):
		_check(not rm.rounds_data[i].has("grounding_id"), "round %d has no grounding_id key" % (i + 1))

	# 4. Pool state survives a state round-trip (save/load keys preserved)
	var state: Dictionary = rm.get_state()
	var rm2 := _make_round_manager(_make_channel(), manager)
	rm2.load_state(state)
	_check(rm2.rounds_data.size() == 6, "loaded rounds_data has 6 rounds")
	_check(rm2.rounds_data[5]["debuff_ids"] == boss_data["debuff_ids"], "boss debuff ids survive save/load")
	_check(not rm2.rounds_data[0].has("grounding_id"), "load_state scrubs legacy grounding_id data")
	rm2.free()

	# 5. Manager-less fallback stores empty selections (zero-debuff fallback)
	var rm3 := RoundManager.new()
	rm3.channel_manager = _make_channel()
	rm3._initialize_rounds_data()
	_check(rm3.rounds_data.size() == 6, "manager-less init still builds 6 rounds")
	_check(rm3.rounds_data[0]["debuff_ids"].is_empty(), "manager-less round has empty debuff_ids")
	_check(not rm3.rounds_data[0].has("grounding_id"), "manager-less round has no grounding_id key")
	rm3.free()

	rm.free()
	manager.queue_free()


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[RoundPreselectTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(_failures)
