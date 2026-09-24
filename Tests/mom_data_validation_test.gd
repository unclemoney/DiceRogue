extends Node

## mom_data_validation_test.gd
##
## Layer 2 of the Mom suite: static validation of every MomDialogNode in
## Resources/Data/Mom/Dialog/ and every MomPunishmentTier in
## Resources/Data/Mom/Punishments/. No game scene needed - autoloads only.
##
## Run headless:
##   godot --headless --path . Tests/MomDataValidationTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

signal finished(failures: int)

const Harness = preload("res://Tests/mom_test_harness.gd")
const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

## Independently maintained known-effect list (dialog-only effects +
## MomPunishmentTier.VALID_EFFECTS). Kept literal so a bad constant in
## production data scripts fails loudly here.
const KNOWN_EFFECTS: Array[String] = [
	"none", "mood_delta", "grudge_delta", "storms_off", "defer_punishment",
	"rep_delta", "apply_tier", "fine", "debuff", "remove_mod",
	"confiscate_powerups", "reward_money", "reward_consumable",
	"reward_powerup", "lock_cosmetics",
]

const VALID_TONES: Array[String] = ["polite", "neutral", "sassy"]

## Roots the router (MomLogicHandler) can select directly.
const ROUTER_ROOTS: Array[String] = [
	"visit_reward", "visit_punishment", "visit_silent_treatment",
	"checkin_neutral", "checkin_nostalgia", "checkin_gossip", "checkin_bargain",
	"checkin_zone_flavor", "checkin_cool_mom", "checkin_warning",
	"checkin_caught_nc17",
]

## Roots claimed in code by CastManager / GameController (not by arcs).
const CODE_CLAIMED_ROOTS: Array[String] = [
	"story_dad_call", "story_derek_quiet", "story_dad_cover",
	"sighting_true", "sighting_false", "sighting_false_believed",
]

const TIER_PATHS: Array[String] = [
	"res://Resources/Data/Mom/Punishments/tier_00_reward.tres",
	"res://Resources/Data/Mom/Punishments/tier_01_disappointed.tres",
	"res://Resources/Data/Mom/Punishments/tier_02_grounded_lite.tres",
	"res://Resources/Data/Mom/Punishments/tier_03_confiscation.tres",
	"res://Resources/Data/Mom/Punishments/tier_04_no_fun.tres",
	"res://Resources/Data/Mom/Punishments/tier_05_furious.tres",
]

var _reporter := Harness.Reporter.new()


func _ready() -> void:
	if get_tree().current_scene == self:
		var failures := await run_tests()
		if OS.get_cmdline_user_args().has("--quit-after"):
			get_tree().quit(failures)


func run_tests() -> int:
	print("[MomTests] --- Layer: data validation ---")
	_reporter = Harness.Reporter.new()

	var scan := Harness.scan_dialog_nodes()
	var nodes: Dictionary = scan["nodes"]
	var files: Dictionary = scan["files"]
	_check_dialog_dir_loads(nodes, files)
	_check_dialog_nodes(nodes, files)
	var reachable := _build_reachability_closure(nodes, files)
	_check_unreachable_nodes(nodes, files, reachable)
	_check_tiers()

	if _reporter.failures == 0:
		print("[MomTests] PASS - data validation (%d checks)" % _reporter.checks)
	else:
		print("[MomTests] FAIL - data validation: %d/%d check(s) failed" % [_reporter.failures, _reporter.checks])
	finished.emit(_reporter.failures)
	return _reporter.failures


func _check_dialog_dir_loads(nodes: Dictionary, files: Dictionary) -> void:
	var dir := DirAccess.open(Harness.DIALOG_DIR)
	_reporter.check("dialog dir opens", dir != null)
	if dir == null:
		return
	var file_count := 0
	var bad_loads := 0
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		file_count += 1
		var res := load(Harness.DIALOG_DIR + file_name)
		if not (res is MomDialogNode):
			bad_loads += 1
			_reporter.check("loads as MomDialogNode: %s" % file_name, false)
	_reporter.check("every .tres in dialog dir loads as MomDialogNode (%d files, %d bad)" % [file_count, bad_loads], bad_loads == 0)
	_reporter.check("dialog dir is not empty (%d nodes)" % nodes.size(), nodes.size() > 0)


func _check_dialog_nodes(nodes: Dictionary, files: Dictionary) -> void:
	var known_ids: Array[String] = []
	for id in nodes:
		known_ids.append(id)

	# id uniqueness is structural (Dictionary keys), but duplicate ids across
	# files must be detected before the key overwrite hides them - rescan.
	var seen: Dictionary = {}
	var dup_ids := 0
	var dir := DirAccess.open(Harness.DIALOG_DIR)
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load(Harness.DIALOG_DIR + file_name)
		if not (res is MomDialogNode):
			continue
		if res.id.is_empty():
			_reporter.check("id non-empty: %s" % file_name, false)
			continue
		if seen.has(res.id):
			dup_ids += 1
			_reporter.check("duplicate node id '%s' in %s (first seen in %s)" % [res.id, file_name, seen[res.id]], false)
		else:
			seen[res.id] = file_name
	_reporter.check("node ids unique across %d files" % seen.size(), dup_ids == 0)

	var bad_text := 0
	var bad_responses := 0
	var bad_effects := 0
	var bad_weights := 0
	var bad_tier_magnitudes := 0
	var bad_end_flags := 0
	var bad_followups := 0
	var bad_validate := 0

	for id in nodes:
		var node: MomDialogNode = nodes[id]
		var label := "%s (%s)" % [id, files.get(id, "?")]
		if node.mom_text.is_empty():
			bad_text += 1
			_reporter.check("mom_text non-empty: %s" % label, false)
		for response in node.responses:
			if response == null:
				bad_responses += 1
				_reporter.check("null response: %s" % label, false)
				continue
			if response.button_text.is_empty():
				bad_responses += 1
				_reporter.check("button_text non-empty: %s" % label, false)
			if response.tone not in VALID_TONES:
				bad_responses += 1
				_reporter.check("tone valid ('%s'): %s / '%s'" % [response.tone, label, response.button_text], false)
			if response.outcomes.is_empty():
				bad_responses += 1
				_reporter.check("outcomes non-empty: %s / '%s'" % [label, response.button_text], false)
			var any_positive := false
			for outcome in response.outcomes:
				if outcome == null:
					bad_responses += 1
					_reporter.check("null outcome: %s / '%s'" % [label, response.button_text], false)
					continue
				if outcome.effect not in KNOWN_EFFECTS:
					bad_effects += 1
					_reporter.check("effect known ('%s'): %s / '%s'" % [outcome.effect, label, response.button_text], false)
				if outcome.weight < 0.0:
					bad_weights += 1
					_reporter.check("weight >= 0 (%s): %s / '%s'" % [outcome.weight, label, response.button_text], false)
				if outcome.weight > 0.0:
					any_positive = true
				if outcome.effect == "apply_tier":
					if outcome.magnitude < -1 or outcome.magnitude > 5:
						bad_tier_magnitudes += 1
						_reporter.check("apply_tier magnitude in {-1,0..5} (got %d): %s / '%s'" % [outcome.magnitude, label, response.button_text], false)
				if outcome.effect == "storms_off" and not outcome.ends_visit:
					bad_end_flags += 1
					_reporter.check("storms_off ends visit: %s / '%s'" % [label, response.button_text], false)
				if outcome.effect == "defer_punishment" and not outcome.ends_visit:
					bad_end_flags += 1
					_reporter.check("defer_punishment ends visit: %s / '%s'" % [label, response.button_text], false)
				if not outcome.ends_visit and outcome.followup_node_id.is_empty() and outcome.result_text.is_empty():
					bad_end_flags += 1
					_reporter.check("non-ending outcome has follow-up or reply: %s / '%s'" % [label, response.button_text], false)
				if outcome.has_followup() and outcome.followup_node_id not in known_ids:
					bad_followups += 1
					_reporter.check("followup resolves ('%s'): %s / '%s'" % [outcome.followup_node_id, label, response.button_text], false)
			if not response.outcomes.is_empty() and not any_positive:
				bad_weights += 1
				_reporter.check("at least one outcome weight > 0: %s / '%s'" % [label, response.button_text], false)
		if not node.validate(known_ids):
			bad_validate += 1
			_reporter.check("node.validate() passes: %s" % label, false)

	_reporter.check("mom_text non-empty on all nodes (%d bad)" % bad_text, bad_text == 0)
	_reporter.check("responses well-formed (%d bad)" % bad_responses, bad_responses == 0)
	_reporter.check("all outcome effects in known set (%d bad)" % bad_effects, bad_effects == 0)
	_reporter.check("all outcome weights valid (%d bad)" % bad_weights, bad_weights == 0)
	_reporter.check("apply_tier magnitudes in {-1,0..5} (%d bad)" % bad_tier_magnitudes, bad_tier_magnitudes == 0)
	_reporter.check("ends_visit / follow-up flags consistent (%d bad)" % bad_end_flags, bad_end_flags == 0)
	_reporter.check("no dangling followup_node_id links (%d bad)" % bad_followups, bad_followups == 0)
	_reporter.check("node.validate() passes for all nodes (%d bad)" % bad_validate, bad_validate == 0)


func _build_reachability_closure(nodes: Dictionary, files: Dictionary) -> Dictionary:
	var roots: Array[String] = []
	roots.append_array(ROUTER_ROOTS)
	roots.append_array(CODE_CLAIMED_ROOTS)

	var cast := Harness.collect_cast_dialog_ids()
	var cast_ids: Array = cast["ids"]
	_reporter.check("cast arcs introspected (or text-scan fallback worked)", bool(cast["introspection_ok"]))
	_reporter.check("cast arcs reference dialog nodes (%d ids)" % cast_ids.size(), cast_ids.size() > 0)
	for node_id in cast_ids:
		roots.append(node_id)

	var missing_roots := 0
	var closure: Dictionary = {}
	var queue: Array[String] = []
	for root_id in roots:
		if root_id in closure:
			continue
		if not nodes.has(root_id):
			missing_roots += 1
			_reporter.check("root id exists as dialog node: '%s'" % root_id, false)
			continue
		closure[root_id] = true
		queue.append(root_id)
	_reporter.check("every reachability root resolves to a dialog node (%d missing)" % missing_roots, missing_roots == 0)

	while not queue.is_empty():
		var current_id: String = queue.pop_back()
		var node: MomDialogNode = nodes[current_id]
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


func _check_unreachable_nodes(nodes: Dictionary, files: Dictionary, reachable: Dictionary) -> void:
	var orphans: Array[String] = []
	for id in nodes:
		if id not in reachable:
			orphans.append("%s (%s)" % [id, files.get(id, "?")])
	for orphan in orphans:
		_reporter.check("unreachable node - no pool, no parent link, not cast-claimed: %s" % orphan, false)
	_reporter.check("all %d dialog nodes reachable from a root" % nodes.size(), orphans.is_empty())


func _check_tiers() -> void:
	GameRNG.initialize(12345)
	var tier_ids: Array[int] = []
	var tiers: Array[MomPunishmentTier] = []
	for path in TIER_PATHS:
		var res := load(path)
		_reporter.check("tier loads as MomPunishmentTier: %s" % path.get_file(), res is MomPunishmentTier)
		if res is MomPunishmentTier:
			tiers.append(res)
			tier_ids.append(res.tier_id)
	_reporter.check("six punishment tiers loaded", tiers.size() == 6)
	tier_ids.sort()
	_reporter.check("tier_id set is exactly {0,1,2,3,4,5}", tier_ids == [0, 1, 2, 3, 4, 5])

	for tier in tiers:
		var label := "tier %d (%s)" % [tier.tier_id, tier.display_name]
		_reporter.check("%s: display_name non-empty" % label, not tier.display_name.is_empty())
		_reporter.check("%s: picks >= 1" % label, tier.picks >= 1)
		_reporter.check("%s: entries non-empty" % label, not tier.entries.is_empty())
		_reporter.check("%s: picks (%d) <= entries (%d)" % [label, tier.picks, tier.entries.size()], tier.picks <= tier.entries.size())
		var bad_entries := 0
		for i in range(tier.entries.size()):
			var entry: Dictionary = tier.entries[i]
			var effect: String = entry.get("effect", "")
			if effect not in MomPunishmentTier.VALID_EFFECTS:
				bad_entries += 1
				_reporter.check("%s entry %d: effect '%s' in VALID_EFFECTS" % [label, i, effect], false)
			if float(entry.get("weight", 0.0)) <= 0.0:
				bad_entries += 1
				_reporter.check("%s entry %d: weight > 0" % [label, i], false)
		_reporter.check("%s: all entries valid (%d bad)" % [label, bad_entries], bad_entries == 0)
		# Duplicate entries in the source data would make the draw check below
		# ambiguous (deep-equal compares cannot tell identity).
		var dup_entries := 0
		for i in range(tier.entries.size()):
			for j in range(i + 1, tier.entries.size()):
				if tier.entries[i] == tier.entries[j]:
					dup_entries += 1
					_reporter.check("%s: entries %d and %d are deep-equal duplicates" % [label, i, j], false)
		_reporter.check("%s: no duplicate entries in source data" % label, dup_entries == 0)
		# Functional draw: never overdraws picks, never repeats an entry.
		var draw_failures := 0
		var expected_size: int = mini(tier.picks, tier.entries.size())
		for draw_index in range(1000):
			var drawn: Array = Handler.draw_entries(tier)
			if drawn.size() != expected_size:
				draw_failures += 1
				break
			for i in range(drawn.size()):
				for j in range(i + 1, drawn.size()):
					if drawn[i] == drawn[j]:
						draw_failures += 1
		_reporter.check("%s: 1000 draws, size == min(picks, entries), no duplicates" % label, draw_failures == 0)

	_reporter.check("get_tier(-1) clamps to tier 0", Handler.get_tier(-1).tier_id == 0)
	_reporter.check("get_tier(99) clamps to tier 5", Handler.get_tier(99).tier_id == 5)

	# The handler's empty-pool reward fallbacks index TIER_00.entries[1] and
	# [2] directly - pin the layout so a reorder breaks loudly here.
	var tier_00: MomPunishmentTier = Handler.TIER_00
	_reporter.check("tier_00 has at least 3 entries (fallback pool layout)", tier_00.entries.size() >= 3)
	if tier_00.entries.size() >= 3:
		_reporter.check("tier_00.entries[1] is the consumable reward pool", tier_00.entries[1].get("effect") == "reward_consumable")
		_reporter.check("tier_00.entries[2] is the power-up reward pool", tier_00.entries[2].get("effect") == "reward_powerup")
		_reporter.check("tier_00 consumable pool non-empty", (tier_00.entries[1].get("params", {}) as Dictionary).get("pool", []).size() > 0)
		_reporter.check("tier_00 power-up pool non-empty", (tier_00.entries[2].get("params", {}) as Dictionary).get("pool", []).size() > 0)
