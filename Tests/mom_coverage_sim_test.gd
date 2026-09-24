extends Node

## mom_coverage_sim_test.gd
##
## Layer 5 of the Mom suite: coverage / reachability simulation. Runs 50,000
## seeded simulated visits across the full mood range through the harness
## stub, driving MomLogicHandler's get_visit_tree_id / get_checkin_tree_id /
## should_silent_treatment / pick_response_index / resolve_response /
## apply_outcome directly (mirroring GameController's visit flow minus the
## CastManager claim). Pass B walks every node as a root to cover cast-only
## branches; pass C draws every tier to cover tier-entry effects. Pass D
## drives a REAL CastManager through seeded multi-channel playthroughs to
## trigger the cast-claimed nodes. After the min_channel re-tune (arc beats
## stair-stepped into the live 1-4 channel range, payoffs at channel 4 -
## see mom_cast_diagnosis.md for the pre-tune diagnosis), every cast-claimed
## node is expected to trigger, and every arc's final beat must complete.
##
## Report: printed and written to user://mom_coverage_report.txt.
##
## Run headless:
##   godot --headless --path . Tests/MomCoverageSimTest.tscn -- --quit-after
##   godot --headless --path . Tests/MomCoverageSimTest.tscn -- --quit-after --seed 4242
## Exit code 0 = all checks passed, 1 = at least one failure.

signal finished(failures: int)

const Harness = preload("res://Tests/mom_test_harness.gd")
const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

const TOTAL_VISITS := 50000
const PASS_B_WALKS := 200
const PASS_C_DRAWS := 500
const DEFAULT_SEED := 67890

## Expected rare-event counts at 50k visits (approved bands).
const SILENT_MIN := 910
const SILENT_MAX := 1090
const COOL_MIN := 249
const COOL_MAX := 351

const FLAVOR_POOL := {
	"checkin_neutral": 4.0,
	"checkin_nostalgia": 2.0,
	"checkin_gossip": 2.0,
	"checkin_bargain": 2.0,
	"checkin_zone_flavor": 1.0,
}

## Pass D: cast simulation sizing. Check-in slots per channel must cover the
## channel-4 cluster: every payoff beat lands at min_channel 4 by design, and
## the cross-arc flag chains (debra_backfired, derek_covered) only complete
## there, so their dependent arcs run entirely inside channel 4.
const PASS_D_RUNS := 400
const PASS_D_CHECKINS_PER_CHANNEL := 32
const PASS_D_METER_VISITS_PER_CHANNEL := 6
const PASS_D_ZONE_NAMES: Array[String] = ["North Wing", "East Wing", "West Wing", "South Wing"]

## Cast expectations after the min_channel re-tune: every cast-claimed node
## is reachable and MUST trigger in pass D. Per arc, the final (payoff)
## beat must complete at least once across the simulated playthroughs.
const CAST_CLASS_A: Array[String] = [
	"flag_patterson_doubted", "patterson_contest_failed",
	"sighting_true", "sighting_false", "sighting_false_believed",
	"story_dad_call", "story_dad_cover",
	"story_dad_longweek", "story_dad_writing_down", "story_dad_almost",
	"story_dad_list_found", "story_dad_coverup", "story_dad_list_burned",
	"story_patterson_intro", "story_patterson_escalation", "story_patterson_payoff",
	"story_patterson_informant",
	"story_henderson_warning", "story_henderson_dinner", "story_henderson_payoff",
	"story_henderson_evidence",
	"story_derek_comparison", "story_derek_resentment", "story_derek_twist",
	"story_derek_covers", "story_derek_quiet",
	"story_derek_room_mess", "story_derek_room_blame", "story_derek_room_cleanup",
	"story_debra_opinions", "story_debra_counter", "story_debra_payoff",
	"story_debra_backfire",
	"story_debra_dish_missing", "story_debra_dish_labels", "story_debra_dish_returned",
	"story_squirrel_first_sighting", "story_squirrel_countermove", "story_squirrel_payoff",
	"story_bird_feeder_blueprint", "story_bird_feeder_stakeout", "story_bird_feeder_payoff",
	"story_mom_played", "story_mom_tips", "story_mom_champ", "story_mom_trophy",
]

## arc id -> node id of its final beat (arc completion = payoff reached).
const ARC_FINAL_BEATS := {
	"patterson_file": "story_patterson_informant",
	"dads_long_week": "story_dad_coverup",
	"henderson_called": "story_henderson_evidence",
	"golden_child": "story_derek_covers",
	"moms_secret_past": "story_mom_trophy",
	"perfume_cloud": "story_debra_backfire",
	"squirrel_campaign": "story_squirrel_payoff",
	"bird_feeder_fever": "story_bird_feeder_payoff",
	"derek_room_disaster": "story_derek_room_cleanup",
	"debra_casserole_dish": "story_debra_dish_returned",
}

var _reporter := Harness.Reporter.new()
var _base_seed: int = DEFAULT_SEED
var _report_lines: Array[String] = []

var _root_counts: Dictionary = {}
var _node_counts_a: Dictionary = {}
var _path_counts: Dictionary = {}
var _outcome_effect_counts_a: Dictionary = {}
var _tier_counts_a: Dictionary = {}
var _outcome_effect_counts_b: Dictionary = {}
var _tier_counts_b: Dictionary = {}
var _entry_effect_counts_c: Dictionary = {}
var _node_counts_d: Dictionary = {}
var _silent_count: int = 0
var _cool_count: int = 0


func _ready() -> void:
	if get_tree().current_scene == self:
		var failures := await run_tests()
		if OS.get_cmdline_user_args().has("--quit-after"):
			get_tree().quit(failures)


func run_tests() -> int:
	print("[MomTests] --- Layer: coverage / reachability simulation ---")
	_base_seed = Harness.get_cmdline_seed(DEFAULT_SEED)
	print("[MomTests] Seed: %d" % _base_seed)
	_reporter = Harness.Reporter.new()
	_report_lines = []
	_report("Mom coverage report - seed %d, %d visits" % [_base_seed, TOTAL_VISITS])

	var snap := Harness.snapshot_autoloads()
	# Keep sass escalation deterministic regardless of the operator's save.
	ProgressManager.cumulative_stats["rep"] = 0

	var stub := Harness.StubGameController.new()
	add_child(stub)

	_run_pass_a(stub)
	var scan := Harness.scan_dialog_nodes()
	var nodes: Dictionary = scan["nodes"]
	_run_pass_b(stub, nodes)
	_run_pass_c()
	await _run_pass_d(stub)

	remove_child(stub)
	stub.queue_free()
	Harness.restore_autoloads(snap)

	_check_assertions(nodes, scan["files"])
	_write_report()

	if _reporter.failures == 0:
		print("[MomTests] PASS - coverage sim (%d checks, seed %d)" % [_reporter.checks, _base_seed])
	else:
		print("[MomTests] FAIL - coverage sim: %d/%d check(s) failed (seed %d)" % [_reporter.failures, _reporter.checks, _base_seed])
	finished.emit(_reporter.failures)
	return _reporter.failures


func _report(line: String) -> void:
	_report_lines.append(line)


func _count(dict: Dictionary, key) -> int:
	return int(dict.get(key, 0))


func _bump(dict: Dictionary, key, amount: int = 1) -> void:
	dict[key] = _count(dict, key) + amount


func _setup_inventory(stub: Harness.StubGameController, scenario: int) -> void:
	stub.clear_power_ups()
	if scenario == 8:
		stub.add_power_up("sim_r_pu", "R")
	elif scenario == 9:
		stub.add_power_up("sim_nc17_pu", "NC-17")


## Pass A: 50,000 visits alternating meter / check-in. Mood is uniform 1-10
## within each kind (mood = 1 + (half % 10)); the check-in inventory scenario
## rotates on a slower cycle ((half / 10) % 10) so it stays independent of
## mood: 80% clean, 10% one R item, 10% one NC-17 item.
func _run_pass_a(stub: Harness.StubGameController) -> void:
	GameRNG.initialize(_base_seed)
	for i in range(TOTAL_VISITS):
		if i % 10000 == 0:
			print("[MomTests] pass A progress: %d/%d" % [i, TOTAL_VISITS])
		var is_meter := (i % 2) == 0
		var half := i / 2
		var mood := 1 + (half % 10)
		var chores := stub.chores_manager
		chores.mom_mood = mood
		chores.grudge = 0
		chores.defer_streak = 0
		chores.low_mood_visits_this_run = 0
		var tree_id: String
		var severity: int
		if is_meter:
			_setup_inventory(stub, 0)
			severity = Handler.compute_severity(chores)
			tree_id = Handler.get_visit_tree_id(mood)
			if tree_id == "visit_punishment" and Handler.should_silent_treatment(severity):
				tree_id = "visit_silent_treatment"
				_silent_count += 1
		else:
			_setup_inventory(stub, (half / 10) % 10)
			tree_id = Handler.get_checkin_tree_id(stub, mood)
			if tree_id == "checkin_cool_mom":
				_cool_count += 1
			severity = Handler.get_checkin_severity(tree_id)
		_bump(_root_counts, tree_id)
		_walk_tree(stub, tree_id, severity, _node_counts_a, _path_counts, _outcome_effect_counts_a, _tier_counts_a)
	_report("pass A: %d visits, %d silent treatments, %d cool moms" % [TOTAL_VISITS, _silent_count, _cool_count])


## Pass B: every dialog node as root, at severities 0 and 3, PASS_B_WALKS
## bot-policy walks each. Covers cast-only branches (rep_delta outcomes) and
## severity-0 tier resolution that the live router can never produce.
func _run_pass_b(stub: Harness.StubGameController, nodes: Dictionary) -> void:
	_setup_inventory(stub, 0)
	for node_id in nodes:
		for severity in [0, 3]:
			GameRNG.initialize(_base_seed + 7 + ("%s@%d" % [node_id, severity]).hash() % 10000)
			for walk_index in range(PASS_B_WALKS):
				_walk_tree(stub, node_id, severity, null, null, _outcome_effect_counts_b, _tier_counts_b)
	_report("pass B: %d nodes x 2 severities x %d walks" % [nodes.size(), PASS_B_WALKS])


## Pass C: draw every tier to cover tier-entry effects (fine, debuff,
## remove_mod, lock_cosmetics live only inside tier entries).
func _run_pass_c() -> void:
	GameRNG.initialize(_base_seed + 13)
	for tier_id in range(6):
		var tier := Handler.get_tier(tier_id)
		if tier == null:
			continue
		for draw_index in range(PASS_C_DRAWS):
			for entry in Handler.draw_entries(tier):
				_bump(_entry_effect_counts_c, String(entry.get("effect", "?")))
	_report("pass C: %d draws per tier" % PASS_C_DRAWS)


func _walk_tree(stub: Harness.StubGameController, root_id: String, severity: int,
		node_counts, path_counts, effect_counts: Dictionary, tier_counts: Dictionary) -> void:
	var node := Handler.get_dialog_node(root_id)
	if node == null:
		_reporter.check("root resolves to a node: '%s'" % root_id, false)
		return
	var guard := 0
	while node != null and not node.is_terminal() and guard < 10:
		guard += 1
		if node_counts != null:
			_bump(node_counts, node.id)
		var response_index := Handler.pick_response_index(node)
		if response_index < 0 or response_index >= node.responses.size():
			break
		if path_counts != null:
			_bump(path_counts, "%s:%d" % [node.id, response_index])
		var response: MomDialogResponse = node.responses[response_index]
		var outcome := Handler.resolve_response(response)
		if outcome == null:
			break
		_bump(effect_counts, outcome.effect)
		var result := Handler.apply_outcome(stub, outcome, severity, {}, response.tone == "sassy")
		if result.tier_id >= 0:
			_bump(tier_counts, result.tier_id)
		if outcome.has_followup():
			var followup := Handler.get_dialog_node(outcome.followup_node_id)
			if followup != null and followup.is_terminal():
				if node_counts != null:
					_bump(node_counts, followup.id)
				node = null
			else:
				node = followup
		else:
			node = null
	if node != null and node.is_terminal():
		if node_counts != null:
			_bump(node_counts, node.id)


## Pass D tree walk: like _walk_tree but collects the visited node ids
## (root + follow-ups + terminals, mirroring GameController's
## visited_node_ids) so CastManager.on_session_finished can set flags and
## advance arcs. Successful sass feeds the run-scoped Rep stat the same way
## GameController._compute_rep_delta does (+8 per sassy pick), which is what
## lets the min_rep-gated moms_secret_past beats come due mid-run.
func _walk_tree_cast(stub: Harness.StubGameController, root_id: String, severity: int) -> Array:
	var visited: Array = [root_id]
	var node := Handler.get_dialog_node(root_id)
	if node == null:
		_reporter.check("pass D root resolves to a node: '%s'" % root_id, false)
		return visited
	var guard := 0
	while node != null and not node.is_terminal() and guard < 10:
		guard += 1
		_bump(_node_counts_d, node.id)
		var response_index := Handler.pick_response_index(node)
		if response_index < 0 or response_index >= node.responses.size():
			break
		var response: MomDialogResponse = node.responses[response_index]
		if response.tone == "sassy":
			ProgressManager.cumulative_stats["rep"] = mini(ProgressManager.get_rep() + 8, 100)
		var outcome := Handler.resolve_response(response)
		if outcome == null:
			break
		Handler.apply_outcome(stub, outcome, severity, {}, response.tone == "sassy")
		if outcome.has_followup():
			var followup := Handler.get_dialog_node(outcome.followup_node_id)
			if followup != null:
				visited.append(followup.id)
			if followup != null and followup.is_terminal():
				_bump(_node_counts_d, followup.id)
				node = null
			else:
				node = followup
		else:
			node = null
	if node != null and node.is_terminal():
		_bump(_node_counts_d, node.id)
	return visited


## Pass D: real CastManager driven through PASS_D_RUNS seeded playthroughs.
## Each run walks channels 1-4 with record_zone_visit (an NC-17 power-up in
## the stub queues delayed true Patterson reports), meter visits that push
## grudge to 2 and let consume_grudge decay it (arming should_dad_call and
## the Dad cover redemption), and check-ins resolved through decide_checkin.
## Claimed trees are walked with the bot policy and closed out with
## on_session_finished, exactly as GameController does.
func _run_pass_d(stub: Harness.StubGameController) -> void:
	var cm := CastManager.new()
	add_child(cm)
	# CastManager._ready defers its chores_manager group lookup one frame.
	await get_tree().process_frame
	await get_tree().process_frame
	var chores := stub.chores_manager
	for run_index in range(PASS_D_RUNS):
		if run_index % 100 == 0:
			print("[MomTests] pass D progress: run %d/%d" % [run_index, PASS_D_RUNS])
		GameRNG.initialize(_base_seed + 101 + run_index)
		cm.reset_for_new_game()
		ProgressManager.cumulative_stats["rep"] = 0
		stub.clear_power_ups()
		stub.add_power_up("sim_d_nc17", "NC-17")
		for channel in range(1, 5):
			stub.channel_manager.current_channel = channel
			var config := ChannelDifficultyData.new()
			config.mall_zone_name = PASS_D_ZONE_NAMES[channel - 1]
			config.channel_number = channel
			cm.record_zone_visit(config, stub)
			for visit_index in range(PASS_D_METER_VISITS_PER_CHANNEL):
				# High moods: visit_punishment needs mood > 3 and the Dad
				# call needs severity >= 4 (mood 9+; low-mood escalation
				# lifts repeat mood-8 visits there too).
				chores.mom_mood = 8 + ((run_index + visit_index) % 3)
				if visit_index % 3 == 0 and chores.grudge < 2:
					chores.add_grudge(2 - chores.grudge)
				var pre_visit_grudge: int = chores.grudge
				var severity := Handler.compute_severity(chores)
				var tree_id: String = Handler.get_visit_tree_id(chores.mom_mood)
				if tree_id == "visit_punishment" and cm.should_dad_call(severity, pre_visit_grudge):
					tree_id = "story_dad_call"
				cm.on_session_finished(tree_id, _walk_tree_cast(stub, tree_id, severity))
			# Grudge persists into check-ins in real play (it only decays on
			# meter visits); several beats gate on min_grudge 1.
			if chores.grudge < 1:
				chores.add_grudge(1)
			for checkin_index in range(PASS_D_CHECKINS_PER_CHANNEL):
				chores.mom_mood = 1 + ((run_index + checkin_index * 3 + channel) % 10)
				chores.chores_completed_this_round = 1
				var claim: Dictionary = cm.decide_checkin(stub)
				var tree_id: String = claim.get("tree_id", "")
				if tree_id == "":
					continue
				var severity := Handler.get_checkin_severity(tree_id)
				cm.on_session_finished(tree_id, _walk_tree_cast(stub, tree_id, severity))
	remove_child(cm)
	cm.queue_free()
	_report("pass D: %d seeded runs x 4 channels through a real CastManager" % PASS_D_RUNS)


## Static follow-up closure from the flow roots (visit/check-in trees the
## router can pick). Nodes inside the closure must trigger in pass A; nodes
## outside are cast-claimed and reported as INFO.
func _flow_reachable_set(nodes: Dictionary) -> Dictionary:
	var roots: Array[String] = [
		"visit_reward", "visit_punishment", "visit_silent_treatment",
		"checkin_neutral", "checkin_nostalgia", "checkin_gossip", "checkin_bargain",
		"checkin_zone_flavor", "checkin_cool_mom", "checkin_warning",
		"checkin_caught_nc17", "checkin_suspicious",
	]
	var closure: Dictionary = {}
	var queue: Array[String] = []
	for root_id in roots:
		if nodes.has(root_id) and root_id not in closure:
			closure[root_id] = true
			queue.append(root_id)
	while not queue.is_empty():
		var node: MomDialogNode = nodes[queue.pop_back()]
		for response in node.responses:
			if response == null:
				continue
			for outcome in response.outcomes:
				if outcome == null or not outcome.has_followup():
					continue
				var next_id: String = outcome.followup_node_id
				if nodes.has(next_id) and next_id not in closure:
					closure[next_id] = true
					queue.append(next_id)
	return closure


func _check_assertions(nodes: Dictionary, files: Dictionary) -> void:
	# Rare events inside their approved bands (actual counts printed either way).
	_report("silent treatment: %d (band %d-%d)" % [_silent_count, SILENT_MIN, SILENT_MAX])
	_reporter.check("silent treatment count %d within band [%d, %d]" % [_silent_count, SILENT_MIN, SILENT_MAX],
		_silent_count >= SILENT_MIN and _silent_count <= SILENT_MAX)
	_report("cool mom: %d (band %d-%d)" % [_cool_count, COOL_MIN, COOL_MAX])
	_reporter.check("cool mom count %d within band [%d, %d]" % [_cool_count, COOL_MIN, COOL_MAX],
		_cool_count >= COOL_MIN and _cool_count <= COOL_MAX)

	# Every outcome effect present in the data is observed in pass A or B.
	var data_effects: Dictionary = {}
	for node_id in nodes:
		for response in (nodes[node_id] as MomDialogNode).responses:
			if response == null:
				continue
			for outcome in response.outcomes:
				if outcome != null:
					data_effects[outcome.effect] = true
	var missing_effects := 0
	for effect in data_effects:
		var seen := _count(_outcome_effect_counts_a, effect) + _count(_outcome_effect_counts_b, effect)
		_report("outcome effect %-20s observed %d (A=%d, B=%d)" % [effect, seen, _count(_outcome_effect_counts_a, effect), _count(_outcome_effect_counts_b, effect)])
		if seen == 0:
			missing_effects += 1
			_reporter.check("outcome effect observed at least once: '%s'" % effect, false)
	_reporter.check("every outcome effect type in the data observed (%d types, %d missing)" % [data_effects.size(), missing_effects], missing_effects == 0)

	# Every tier-entry effect present in the tier data is drawn in pass C.
	var missing_entry_effects := 0
	for tier_id in range(6):
		var tier := Handler.get_tier(tier_id)
		if tier == null:
			continue
		for entry in tier.entries:
			var effect := String(entry.get("effect", "?"))
			if _count(_entry_effect_counts_c, effect) == 0:
				missing_entry_effects += 1
				_reporter.check("tier-entry effect drawn in pass C: '%s' (tier %d)" % [effect, tier_id], false)
	_reporter.check("every tier-entry effect drawn in pass C (%d missing)" % missing_entry_effects, missing_entry_effects == 0)

	# Tiers 1-5 resolve in the flow sim; tiers 0-5 across A and B.
	for tier_id in range(6):
		_report("tier %d resolved: A=%d, B=%d" % [tier_id, _count(_tier_counts_a, tier_id), _count(_tier_counts_b, tier_id)])
	var flow_tiers_ok := true
	for tier_id in range(1, 6):
		if _count(_tier_counts_a, tier_id) == 0:
			flow_tiers_ok = false
			_reporter.check("tier %d resolved at least once in flow sim" % tier_id, false)
	_reporter.check("tiers 1-5 each resolved in flow sim", flow_tiers_ok)
	var all_tiers_ok := true
	for tier_id in range(6):
		if _count(_tier_counts_a, tier_id) + _count(_tier_counts_b, tier_id) == 0:
			all_tiers_ok = false
			_reporter.check("tier %d resolved at least once across passes" % tier_id, false)
	_reporter.check("tiers 0-5 each resolved across passes A+B", all_tiers_ok)
	if _count(_tier_counts_a, 0) == 0:
		_reporter.info("tier 0 never resolved in flow (BY DESIGN): apply_tier magnitude 0 lives only in visit_punishment / story_dad_call, which never run at severity 0; TIER_00's live role is the fallback reward pools")
		_report("INFO: tier 0 never resolved in flow (by design) - fallback pools only")

	# Node coverage against the static flow closure.
	var flow_set := _flow_reachable_set(nodes)
	var never_triggered: Array[String] = []
	for node_id in nodes:
		_report("node %-32s triggered %d%s" % [node_id, _count(_node_counts_a, node_id),
			"" if _count(_node_counts_a, node_id) > 0 else "  <-- never in flow"])
		if _count(_node_counts_a, node_id) == 0:
			never_triggered.append(node_id)
	var suspicious := 0
	for node_id in never_triggered:
		if node_id in flow_set:
			suspicious += 1
			_reporter.check("flow-reachable node triggered in 50k visits: '%s' (%s)" % [node_id, files.get(node_id, "?")], false)
		else:
			var reason := "cast-claimed (CastManager.decide_checkin / should_dad_call)"
			if node_id in CAST_CLASS_A:
				reason = "cast-claimed, reachable via CastManager (pass D must trigger it)"
			_reporter.info("never triggered in flow: '%s' - %s" % [node_id, reason])
			_report("never triggered: %s - %s" % [node_id, reason])
	_reporter.check("every flow-reachable node triggered in pass A (%d suspicious)" % suspicious, suspicious == 0)

	# Pass D: after the min_channel re-tune every cast-claimed node is
	# reachable through the real CastManager and must trigger, and every
	# arc's final (payoff) beat must complete at least once.
	var class_a_missing := 0
	for node_id in CAST_CLASS_A:
		var a_count := _count(_node_counts_d, node_id)
		_report("pass D cast node %-32s triggered %d" % [node_id, a_count])
		if a_count == 0:
			class_a_missing += 1
			_reporter.check("pass D: reachable cast node triggered: '%s'" % node_id, false)
	_reporter.check("pass D: every cast-claimed node triggered (%d/%d, %d missing)" % [
		CAST_CLASS_A.size() - class_a_missing, CAST_CLASS_A.size(), class_a_missing], class_a_missing == 0)
	var payoffs_missing := 0
	for arc_id in ARC_FINAL_BEATS:
		var payoff_id: String = ARC_FINAL_BEATS[arc_id]
		var payoff_count := _count(_node_counts_d, payoff_id)
		_report("pass D arc payoff %-24s %-32s completed %d" % [arc_id, payoff_id, payoff_count])
		if payoff_count == 0:
			payoffs_missing += 1
			_reporter.check("pass D: arc '%s' payoff beat triggered: '%s'" % [arc_id, payoff_id], false)
	_reporter.check("pass D: every arc's payoff beat triggered (%d/%d arcs completed)" % [
		ARC_FINAL_BEATS.size() - payoffs_missing, ARC_FINAL_BEATS.size()], payoffs_missing == 0)

	# Flavor pool shares among flavor check-ins.
	var flavor_total := 0
	for pool_id in FLAVOR_POOL:
		flavor_total += _count(_root_counts, pool_id)
	_reporter.check("flavor check-ins occurred (%d)" % flavor_total, flavor_total > 0)
	if flavor_total > 0:
		var weight_total := 0.0
		for pool_id in FLAVOR_POOL:
			weight_total += float(FLAVOR_POOL[pool_id])
		for pool_id in FLAVOR_POOL:
			var expected := float(FLAVOR_POOL[pool_id]) / weight_total
			var empirical := float(_count(_root_counts, pool_id)) / float(flavor_total)
			_report("flavor %-24s %d (%.4f vs expected %.4f)" % [pool_id, _count(_root_counts, pool_id), empirical, expected])
			_reporter.check("flavor share '%s' %.4f within tolerance of %.4f" % [pool_id, empirical, expected],
				absf(empirical - expected) <= 0.02)

	# Router sanity: warning/caught trees trigger on their inventory slices.
	_reporter.check("NC-17 caught tree triggered (%d times)" % _count(_root_counts, "checkin_caught_nc17"),
		_count(_root_counts, "checkin_caught_nc17") > 0)
	_reporter.check("R warning tree triggered (%d times)" % _count(_root_counts, "checkin_warning"),
		_count(_root_counts, "checkin_warning") > 0)


func _write_report() -> void:
	var file := FileAccess.open("user://mom_coverage_report.txt", FileAccess.WRITE)
	if file == null:
		_reporter.check("coverage report written to user://mom_coverage_report.txt", false)
		return
	for line in _report_lines:
		file.store_line(line)
	file.close()
	print("[MomTests] coverage report written to user://mom_coverage_report.txt (%d lines)" % _report_lines.size())
	_reporter.check("coverage report written", true)
