extends Node

## cast_manager_test.gd
##
## Exercises the Mom's World systems:
##   1. Zone logging + unvisited pool (Patterson true/false zone sources)
##   2. Sighting truth flags and mood-weighted false-chance bands
##   3. Delayed pending reports (trouble surfaces zones later)
##   4. Story arc gating, beat advancement, rewards, and flag nodes
##   5. Check-in precedence (Derek quiet > Dad cover > arcs > sightings)
##   6. Save/load round-trip and new-game reset
##
## Scene-based test (autoloads must be compiled before CastManager).
## Run headless:
##   godot --headless --path . Tests/CastManagerTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

var _failures: int = 0


## Minimal stand-ins for the channel/current-channel lookups CastManager
## performs on the game controller.
class FakeChannelManager:
	var current_channel: int = 1


class FakeGameController extends Node:
	var channel_manager = FakeChannelManager.new()


func _ready() -> void:
	print("[CastManagerTest] Starting")
	var cm := CastManager.new()
	add_child(cm)

	_test_zone_logging(cm)
	_test_sighting_truth(cm)
	_test_false_chance_bands(cm)
	_test_pending_report_delay(cm)
	_test_arc_gating_and_completion(cm)
	_test_flag_nodes(cm)
	_test_checkin_precedence(cm)
	_test_save_load_roundtrip(cm)
	_test_reset(cm)

	if _failures == 0:
		print("[CastManagerTest] PASS - all checks passed")
	else:
		print("[CastManagerTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[CastManagerTest] OK: " + label)
	else:
		push_error("[CastManagerTest] FAILED: " + label)
		_failures += 1


func _zone_config(zone_name: String, channel: int) -> ChannelDifficultyData:
	var config := ChannelDifficultyData.new()
	config.mall_zone_name = zone_name
	config.channel_number = channel
	return config


func _fake_gc(channel: int) -> FakeGameController:
	var gc := FakeGameController.new()
	gc.channel_manager.current_channel = channel
	add_child(gc)
	return gc


func _test_zone_logging(cm: CastManager) -> void:
	cm.record_zone_visit(_zone_config("Food Court", 1))
	cm.record_zone_visit(_zone_config("Arcade", 2))
	cm.record_zone_visit(_zone_config("Arcade", 2))  # duplicate must not re-log
	_check("two zones logged in order", cm.visited_zones.size() == 2 \
		and cm.visited_zones[0] == "Food Court" and cm.visited_zones[1] == "Arcade")
	_check("zone channel recorded", int(cm.visited_zone_channels.get("Arcade", 0)) == 2)
	_check("Food Court visited", cm.has_visited_zone("Food Court"))
	_check("J-Mart not visited", not cm.has_visited_zone("J-Mart"))
	_check("unvisited pool excludes logged zones", "Arcade" not in cm.get_unvisited_zones())
	# Pool is built from the 4 mall-zone channel configs; fictional test zones
	# never enter it, so all 4 wings remain unvisited.
	_check("unvisited pool still has other zones", cm.get_unvisited_zones().size() == 4)


func _test_sighting_truth(cm: CastManager) -> void:
	# cm has Food Court (ch1) + Arcade (ch2); pretend current channel is 3
	var true_seen := 0
	var false_seen := 0
	for i in range(60):
		var sighting := cm._roll_sighting(3)
		if sighting.is_empty():
			continue
		if sighting["is_true"]:
			true_seen += 1
			_check("true sighting zone was really visited", sighting["zone"] in ["Food Court", "Arcade"])
		else:
			false_seen += 1
			_check("false sighting zone was never visited", not cm.has_visited_zone(sighting["zone"]))
	_check("both true and false sightings generated over 60 rolls", true_seen > 0 and false_seen > 0)


func _test_false_chance_bands(cm: CastManager) -> void:
	_check("happy mom doubts Patterson (0.25)", is_equal_approx(cm._false_report_chance(8), 0.25))
	_check("neutral mom base rate (0.40)", is_equal_approx(cm._false_report_chance(5), 0.40))
	_check("angry mom believes Patterson (0.60)", is_equal_approx(cm._false_report_chance(4), 0.60))


func _test_pending_report_delay(cm: CastManager) -> void:
	cm.patterson_pending.append({
		"zone": "Arcade", "is_true": true, "recorded_channel": 2,
		"min_delay_zones": CastManager.PATTERSON_REPORT_DELAY_ZONES,
	})
	_check("report not due one zone later", cm._pop_due_pending_report(3).is_empty())
	_check("report not consumed early", cm.patterson_pending.size() == 1)
	var due := cm._pop_due_pending_report(4)
	_check("report due two zones later", not due.is_empty() and due["zone"] == "Arcade")
	_check("report consumed once due", cm.patterson_pending.is_empty())


func _test_arc_gating_and_completion(cm: CastManager) -> void:
	# Pin Rep to 0 so a persisted save can't leak a rep-gated beat
	# (story_mom_played needs min_rep 10) into the channel-gating checks.
	var progress_manager := cm.get_node_or_null("/root/ProgressManager")
	var saved_rep := 0
	var rep_pinned := false
	if progress_manager and progress_manager.has_method("get_rep") and progress_manager.has_method("reset_rep"):
		saved_rep = progress_manager.get_rep()
		progress_manager.reset_rep()
		rep_pinned = true

	var gc1 := _fake_gc(1)
	_check("no beat due at channel 1", cm._find_due_beat(gc1, 1).is_empty())
	gc1.queue_free()

	var gc2 := _fake_gc(2)
	var claim := cm._find_due_beat(gc2, 2)
	_check("patterson intro due at channel 2", claim.get("tree_id", "") == "story_patterson_intro")

	# Complete beat 0 via session-finished hook
	cm.on_session_finished("story_patterson_intro", [])
	_check("arc advanced to beat 1", int(cm.arc_progress.get("patterson_file", -1)) == 1)
	_check("intro flag set", cm.flags.get("patterson_intro_done", false))

	# Beat 1 requires channel 6 - not due yet at channel 2
	claim = cm._find_due_beat(gc2, 2)
	_check("patterson beat 1 not due at channel 2", claim.get("tree_id", "") != "story_patterson_escalation")

	# Jump to channel 12 with the doubt flag: payoff should not fire before
	# escalation is done (arc order is enforced). Complete the other arcs so
	# only patterson_file competes for the slot (priority order otherwise
	# correctly preempts it - golden_child outranks it).
	cm.flags["flag_patterson_doubted"] = true
	cm.completed_arcs = ["golden_child", "dads_long_week", "perfume_cloud", "henderson_called", "moms_secret_past"]
	var gc12 := _fake_gc(12)
	claim = cm._find_due_beat(gc12, 12)
	_check("escalation still next at channel 12", claim.get("tree_id", "") == "story_patterson_escalation")

	cm.on_session_finished("story_patterson_escalation", [])
	claim = cm._find_due_beat(gc12, 12)
	_check("payoff due after escalation at channel 12", claim.get("tree_id", "") == "story_patterson_payoff")
	cm.on_session_finished("story_patterson_payoff", [])
	_check("truce flag set by payoff", cm.flags.get("patterson_truce", false))
	_check("arc not complete before informant epilogue", "patterson_file" not in cm.completed_arcs)

	# Beat 3 (informant epilogue) requires channel 14 and the truce flag
	claim = cm._find_due_beat(gc12, 12)
	_check("informant beat not due at channel 12", claim.get("tree_id", "") != "story_patterson_informant")
	var gc14 := _fake_gc(14)
	claim = cm._find_due_beat(gc14, 14)
	_check("informant beat due at channel 14", claim.get("tree_id", "") == "story_patterson_informant")
	cm.on_session_finished("story_patterson_informant", [])
	_check("arc completed after informant epilogue", "patterson_file" in cm.completed_arcs)
	claim = cm._find_due_beat(gc14, 14)
	_check("completed arc never fires again", claim.get("arc_id", "") != "patterson_file")
	gc2.queue_free()
	gc12.queue_free()
	gc14.queue_free()

	# Restore the persisted Rep so later runs see the save as it was.
	if rep_pinned:
		progress_manager.adjust_rep(saved_rep - progress_manager.get_rep())


func _test_flag_nodes(cm: CastManager) -> void:
	cm.on_session_finished("some_tree", ["story_x", "flag_test_marker"])
	_check("flag_* node sets story flag", cm.flags.get("flag_test_marker", false))
	_check("non-flag node ignored", not cm.flags.has("story_x"))


func _test_checkin_precedence(cm: CastManager) -> void:
	# Derek quiet visit beats everything and fires exactly once
	cm.flags["derek_quiet_pending"] = true
	var gc := _fake_gc(5)
	var claim := cm.decide_checkin(gc)
	_check("derek quiet visit wins the slot", claim.get("tree_id", "") == "story_derek_quiet")
	_check("derek quiet pending consumed", not cm.flags.has("derek_quiet_pending"))

	# Dad cover arms after grudge 2 -> 0, fires once
	cm._on_grudge_changed(2)
	cm._on_grudge_changed(0)
	_check("dad cover armed after grudge recovery", cm.dad_cover_pending)
	claim = cm.decide_checkin(gc)
	_check("dad cover wins the slot", claim.get("tree_id", "") == "story_dad_cover")
	_check("dad cover consumed", not cm.dad_cover_pending and cm.dad_cover_used)

	# Debug forced claim wins over normal flow
	cm.debug_forced_claim = {"tree_id": "sighting_true", "context": {"zone": "Arcade"}}
	claim = cm.decide_checkin(gc)
	_check("debug forced claim honored", claim.get("tree_id", "") == "sighting_true")
	_check("forced claim context carries zone", claim.get("context", {}).get("zone", "") == "Arcade")
	_check("forced claim consumed", cm.debug_forced_claim.is_empty())
	gc.queue_free()


func _test_save_load_roundtrip(cm: CastManager) -> void:
	cm.record_zone_visit(_zone_config("Bookstore", 3))
	cm.flags["flag_roundtrip"] = true
	cm.patterson_pending.append({"zone": "Arcade", "is_true": true, "recorded_channel": 3, "min_delay_zones": 2})
	cm.patterson_sightings_this_run = 4
	cm.last_sighting_channel = 3
	cm.max_grudge_seen = 2

	var state: Dictionary = cm.get_state()
	var cm2 := CastManager.new()
	add_child(cm2)
	cm2.load_state(state)
	_check("visited zones round-trip", cm2.visited_zones.size() == cm.visited_zones.size() \
		and cm2.visited_zones[0] == cm.visited_zones[0])
	_check("flags round-trip", cm2.flags.get("flag_roundtrip", false))
	_check("pending reports round-trip", cm2.patterson_pending.size() == 1)
	_check("sighting counters round-trip", cm2.patterson_sightings_this_run == 4 and cm2.last_sighting_channel == 3)
	_check("arc progress round-trip", int(cm2.arc_progress.get("patterson_file", -1)) == 4)
	_check("completed arcs round-trip", "patterson_file" in cm2.completed_arcs)
	_check("max grudge round-trip", cm2.max_grudge_seen == 2)

	# Tolerant load: an empty state (old save) must not error or corrupt
	var cm3 := CastManager.new()
	add_child(cm3)
	cm3.load_state({})
	_check("empty state tolerated", cm3.visited_zones.is_empty() and cm3.flags.is_empty())
	cm2.queue_free()
	cm3.queue_free()


func _test_reset(cm: CastManager) -> void:
	cm.reset_for_new_game()
	_check("reset clears zones", cm.visited_zones.is_empty())
	_check("reset clears arc progress", cm.arc_progress.is_empty() and cm.completed_arcs.is_empty())
	_check("reset clears flags", cm.flags.is_empty())
	_check("reset clears patterson state", cm.patterson_pending.is_empty() and cm.patterson_sightings_this_run == 0)
	_check("reset clears dad state", not cm.dad_call_used and not cm.dad_cover_used and cm.max_grudge_seen == 0)
