extends SceneTree

## retarget_channels.gd — Phase 1 migration tool (PLAN_BALANCE.md)
##
## Reads the tone_weighted baseline bot report and rewrites every channel's
## per-round target_score_override to:
##     target_{c,r} = round(margin_c × median_score_{c,r})
## with margin_c from BalanceTuning (0.65 → 0.90 linear).
##
## - Channels 1-2 are hand-set soft tutorial zones (bot can't measure them
##   reliably; see PLAN_BALANCE.md Phase 0 findings).
## - Sparse cells (fewer than MIN_SAMPLES runs reaching that round) are
##   extrapolated from the same round on neighboring late channels, scaled
##   by the channel's round-1 median ratio.
## - goal_score_multiplier is normalized to 1.0 everywhere so the override
##   IS the target (override × multiplier = intended value).
##
## Run headless:
##   godot --headless --path . --script res://Scripts/Editor/retarget_channels.gd [-- --report=<path>]
##
## Idempotent: re-running with a newer baseline just rewrites the numbers.

const MIN_SAMPLES := 5
const CHANNEL_DIR := "res://Resources/Data/Channels/"
const TUNING_PATH := "res://Resources/Data/Balance/balance_tuning.tres"
const REPORT_GLOB_PREFIX := "bot_report_tone_weighted_"

## Hand-set tutorial targets (channels 1-2)
const TUTORIAL_TARGETS := {
	1: [50, 75, 105, 150, 200, 300],
	2: [75, 100, 150, 200, 250, 350],
}


func _init() -> void:
	var report_path := _parse_report_arg()
	if report_path.is_empty():
		report_path = _find_latest_report()
	if report_path.is_empty():
		push_error("[Retarget] No tone_weighted baseline report found in user://bot_reports/")
		quit(1)
		return
	print("[Retarget] Using baseline report: ", report_path)

	var report := _load_json(report_path)
	if report.is_empty():
		push_error("[Retarget] Failed to parse report JSON")
		quit(1)
		return

	var tuning: Resource = load(TUNING_PATH)
	if not tuning:
		push_error("[Retarget] Failed to load BalanceTuning: " + TUNING_PATH)
		quit(1)
		return

	var balance: Dictionary = report.get("aggregate", {}).get("balance", {})
	var per_channel: Dictionary = balance.get("per_channel", {})
	if per_channel.is_empty():
		push_error("[Retarget] Report has no aggregate.balance.per_channel block")
		quit(1)
		return

	var medians := _extract_medians(per_channel)
	var targets := _derive_targets(medians, tuning)
	_apply_targets(targets)
	print("[Retarget] Done. Verify with a tone_weighted re-climb (PLAN_BALANCE.md Phase 1).")
	quit(0)


## _parse_report_arg() -> String
func _parse_report_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			return arg.trim_prefix("--report=")
	return ""


## _find_latest_report() -> String
##
## Picks the newest bot_report_tone_weighted_*.json in user://bot_reports/.
func _find_latest_report() -> String:
	var dir := DirAccess.open("user://bot_reports/")
	if not dir:
		return ""
	var best := ""
	for file_name in dir.get_files():
		if file_name.begins_with(REPORT_GLOB_PREFIX) and file_name.ends_with(".json"):
			if file_name > best:
				best = file_name
	if best.is_empty():
		return ""
	return "user://bot_reports/" + best


## _load_json(path) -> Dictionary
func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.get_data()


## _extract_medians(per_channel) -> Dictionary
##
## Returns { channel: { round: {"median": float, "samples": int} } }.
func _extract_medians(per_channel: Dictionary) -> Dictionary:
	var out := {}
	for ch_key in per_channel:
		var c := int(ch_key)
		out[c] = {}
		var rounds: Dictionary = per_channel[ch_key].get("per_round", {})
		for r_key in rounds:
			out[c][int(r_key)] = {
				"median": float(rounds[r_key].get("median_score", 0.0)),
				"samples": int(rounds[r_key].get("samples", 0)),
			}
	return out


## _derive_targets(medians, tuning) -> Dictionary
##
## Returns { channel: [t1..t6] } with hand-set tutorial channels and
## sparse-cell extrapolation for late-channel rounds.
func _derive_targets(medians: Dictionary, tuning: Resource) -> Dictionary:
	var targets := {}

	# Tutorial zones: hand-set
	for c in TUTORIAL_TARGETS:
		targets[c] = TUTORIAL_TARGETS[c].duplicate()

	# Neighbor pool for sparse extrapolation: same round across ALL channels
	# (late channels often have no r2+ samples at all — pool globally)
	var neighbor_round_median := {}
	for r in range(1, 7):
		var vals: Array = []
		for c in range(3, 20):
			if medians.has(c) and medians[c].has(r) and medians[c][r].samples >= MIN_SAMPLES and medians[c][r].median > 0:
				vals.append(medians[c][r].median)
		vals.sort()
		if not vals.is_empty():
			neighbor_round_median[r] = vals[vals.size() / 2]

	for c in range(3, 21):
		var margin: float = tuning.call("margin_for_channel", c)
		var row: Array = []
		for r in range(1, 7):
			var cell: Dictionary = medians.get(c, {}).get(r, {"median": 0.0, "samples": 0})
			if cell.samples >= MIN_SAMPLES and cell.median > 0:
				row.append(int(round(margin * cell.median)))
				continue
			# Sparse: extrapolate from neighbor channels' same round,
			# scaled by this channel's round-1 median vs theirs.
			var extrapolated := 0.0
			var own_r1: float = medians.get(c, {}).get(1, {"median": 0.0}).median
			if neighbor_round_median.has(r) and neighbor_round_median.has(1) and own_r1 > 0:
				extrapolated = neighbor_round_median[r] * (own_r1 / neighbor_round_median[1])
			elif row.size() > 0:
				# No neighbor data at all: hold previous round's target
				extrapolated = float(row[-1]) / margin
			row.append(int(round(margin * extrapolated)))
			print("[Retarget] ch%d r%d SPARSE (n=%d) -> extrapolated target %d" % [c, r, cell.samples, row[-1]])
		targets[c] = row

	return targets


## _apply_targets(targets)
##
## Writes the derived targets into each channel .tres and normalizes
## goal_score_multiplier to 1.0. Prints a summary table.
func _apply_targets(targets: Dictionary) -> void:
	print("[Retarget] ch | margin | new round targets (override, multiplier -> 1.0)")
	for c in range(1, 21):
		var path := CHANNEL_DIR + "channel_%02d.tres" % c
		var config: ChannelDifficultyData = load(path)
		if not config:
			push_error("[Retarget] Failed to load " + path)
			continue
		var row: Array = targets.get(c, [])
		if row.size() != 6:
			push_error("[Retarget] No target row for channel %d" % c)
			continue
		for i in range(6):
			var round_config := config.get_round_config(i + 1)
			if round_config:
				round_config.target_score_override = row[i]
		config.goal_score_multiplier = 1.0
		var err := ResourceSaver.save(config, path)
		if err != OK:
			push_error("[Retarget] Failed to save %s (err %d)" % [path, err])
			continue
		var margin: float = (load(TUNING_PATH) as Resource).call("margin_for_channel", c)
		print("[Retarget] ch%02d  %.3f | %s" % [c, margin, str(row)])
