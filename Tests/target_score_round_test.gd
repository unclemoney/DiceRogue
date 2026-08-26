extends Control

## target_score_round_test.gd
##
## Verifies the store/target-score round model that replaced challenges:
##   1. RoundManager._initialize_rounds_data builds 6 rounds per zone with a
##      real store_name (from ChannelManager's seeded assignment) and a
##      target_score > 0, and carries no challenge_id.
##   2. _on_challenge_completed (via the ChallengeManager signal hub) sets
##      is_challenge_completed — the flag name is kept for existing callers.
##   3. Round 6 of every zone is a boss round (levels 4/5/5/5).
##   4. Zone rounds 1-5 match the difficulty spec:
##      z1 max_debuffs 0 / cap 0, z2 cap 2, z3 cap 3, z4 cap 4,
##      grounding_chance 0 / 0.25 / 0.25 / 0.25.

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	print("\n=== TARGET SCORE ROUND TEST ===")
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
	var cm := ChannelManager.new()
	cm.name = "ChannelManager"
	add_child(cm)

	# RoundManager stays off-tree so its _ready (which demands a full game
	# scene) never runs; the two methods under test only need channel_manager.
	var rm := RoundManager.new()
	rm.channel_manager = cm

	_test_rounds_data(cm, rm)
	_test_signal_hub_flag(cm, rm)
	_test_boss_rounds(cm)
	_test_zone_round_specs(cm)

	rm.free()
	cm.queue_free()


## _test_rounds_data(cm, rm)
##
## Per zone: 6 rounds, each with a real store name and target_score > 0.
func _test_rounds_data(cm: ChannelManager, rm: RoundManager) -> void:
	for zone in range(1, ChannelManager.MAX_CHANNEL + 1):
		cm.set_channel(zone)
		cm.assign_stores_to_zones(12345)
		rm._initialize_rounds_data()

		_check(rm.rounds_data.size() == 6, "zone %d builds 6 rounds" % zone)

		var names_ok := true
		var targets_ok := true
		var no_challenge_id := true
		for round_data in rm.rounds_data:
			var store_name: String = round_data.get("store_name", "")
			if store_name.is_empty() or store_name.begins_with("Store "):
				names_ok = false
			if int(round_data.get("target_score", 0)) <= 0:
				targets_ok = false
			if round_data.has("challenge_id"):
				no_challenge_id = false
		_check(names_ok, "zone %d rounds have real store names" % zone)
		_check(targets_ok, "zone %d rounds have target_score > 0" % zone)
		_check(no_challenge_id, "zone %d rounds carry no challenge_id (deprecated)" % zone)


## _test_signal_hub_flag(cm, rm)
##
## Emitting challenge_completed through the ChallengeManager hub (with a store
## name as id) must set RoundManager.is_challenge_completed.
func _test_signal_hub_flag(cm: ChannelManager, rm: RoundManager) -> void:
	var hub := ChallengeManager.new()
	hub.name = "ChallengeManager"
	add_child(hub)
	hub.challenge_completed.connect(rm._on_challenge_completed)

	rm.is_challenge_completed = false
	cm.assign_stores_to_zones(12345)
	var store_name: String = cm.get_store_name(1, 1)
	hub._on_challenge_completed(store_name)
	_check(rm.is_challenge_completed, "hub challenge_completed sets is_challenge_completed")

	rm.is_challenge_completed = false
	hub.challenge_failed.emit(store_name)
	_check(not rm.is_challenge_completed, "hub challenge_failed leaves flag clear")

	hub.queue_free()


## _test_boss_rounds(cm)
##
## Round 6 of every zone is a boss round with levels 4/5/5/5.
func _test_boss_rounds(cm: ChannelManager) -> void:
	var expected_levels: Array[int] = [4, 5, 5, 5]
	for zone in range(1, ChannelManager.MAX_CHANNEL + 1):
		var cfg := cm.get_round_config(zone, 6)
		_check(cfg != null, "zone %d round 6 config exists" % zone)
		if cfg == null:
			continue
		_check(cfg.is_boss_round, "zone %d round 6 is a boss round" % zone)
		_check(cfg.boss_debuff_level == expected_levels[zone - 1],
			"zone %d boss debuff level is %d" % [zone, expected_levels[zone - 1]])


## _test_zone_round_specs(cm)
##
## Rounds 1-5 per zone: z1 max_debuffs 0 / cap 0, z2 cap 2, z3 cap 3,
## z4 cap 4; grounding_chance 0 / 0.25 / 0.25 / 0.25.
func _test_zone_round_specs(cm: ChannelManager) -> void:
	var expected_max_debuffs: Array[int] = [0, 1, 1, 1]
	var expected_caps: Array[int] = [0, 2, 3, 4]
	var expected_grounding: Array[float] = [0.0, 0.25, 0.25, 0.25]
	for zone in range(1, ChannelManager.MAX_CHANNEL + 1):
		var max_ok := true
		var cap_ok := true
		var grounding_ok := true
		for round_number in range(1, 6):
			var cfg := cm.get_round_config(zone, round_number)
			if cfg == null:
				max_ok = false
				cap_ok = false
				grounding_ok = false
				continue
			if cfg.max_debuffs != expected_max_debuffs[zone - 1]:
				max_ok = false
			if cfg.debuff_difficulty_cap != expected_caps[zone - 1]:
				cap_ok = false
			if not is_equal_approx(cfg.grounding_chance, expected_grounding[zone - 1]):
				grounding_ok = false
		_check(max_ok, "zone %d rounds 1-5 max_debuffs = %d" % [zone, expected_max_debuffs[zone - 1]])
		_check(cap_ok, "zone %d rounds 1-5 debuff cap = %d" % [zone, expected_caps[zone - 1]])
		_check(grounding_ok, "zone %d rounds 1-5 grounding_chance = %.2f" % [zone, expected_grounding[zone - 1]])


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[TargetScoreRoundTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(_failures)
