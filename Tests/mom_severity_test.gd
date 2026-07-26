extends Node

## mom_severity_test.gd
##
## Exercises the reworked MomLogicHandler:
##   1. compute_severity mood bands (0-5) and grudge floor/consumption.
##   2. Escalation via low-mood visit counter.
##   3. apply_tier magnitude semantics (exact / computed / computed+1).
##   4. storms_off outcomes: no punishment, grudge preserved.
##   5. Weighted drawing: resolve_response, draw_entries, bot response pick.
##   6. Direct effects: fine, reward_money defaults.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/MomSeverityTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const ChoresManagerScript := preload("res://Scripts/Managers/ChoresManager.gd")
const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

var _failures: int = 0


## Minimal GameController stand-in for result building.
class FakeGC extends Node:
	var active_power_ups: Dictionary = {}
	var active_mods: Dictionary = {}
	var pu_manager = null
	var chores_manager = null


## PowerUp definition stub with a rating field (duck-types PowerUpData).
class FakePUDef extends RefCounted:
	var rating: String = "G"


## PowerUp manager stub serving FakePUDef instances by id.
class FakePUManager extends Node:
	var defs: Dictionary = {}
	func get_def(id: String):
		return defs.get(id)


func _ready() -> void:
	print("[MomSeverityTest] Starting")
	var cm = ChoresManagerScript.new()
	add_child(cm)
	var gc := FakeGC.new()
	add_child(gc)

	_test_severity_bands(cm)
	_test_grudge_floor(cm)
	_test_escalation(cm)
	_test_defer_system(cm, gc)
	_test_apply_tier_semantics(gc)
	_test_storms_off(gc)
	_test_direct_effects(gc)
	_test_weighted_drawing()
	_test_checkin_tree_selection(gc)
	_test_silent_treatment()

	if _failures == 0:
		print("[MomSeverityTest] PASS - all checks passed")
	else:
		print("[MomSeverityTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[MomSeverityTest] OK: " + label)
	else:
		push_error("[MomSeverityTest] FAILED: " + label)
		_failures += 1


func _make_outcome(effect: String, magnitude: int = 0) -> MomDialogOutcome:
	var outcome := MomDialogOutcome.new()
	outcome.effect = effect
	outcome.magnitude = magnitude
	return outcome


func _test_severity_bands(cm) -> void:
	var cases := {1: 0, 3: 0, 4: 1, 6: 1, 7: 2, 8: 3, 9: 4, 10: 5}
	for mood in cases:
		cm.mom_mood = mood
		cm.grudge = 0
		cm.low_mood_visits_this_run = 0
		var severity: int = Handler.compute_severity(cm)
		_check("mood %d -> severity %d (got %d)" % [mood, cases[mood], severity], severity == cases[mood])


func _test_grudge_floor(cm) -> void:
	cm.mom_mood = 5
	cm.grudge = 2
	cm.low_mood_visits_this_run = 0
	var severity: int = Handler.compute_severity(cm)
	_check("grudge 2 raises floor to severity 2", severity == 2)
	_check("grudge consumed (decays to 1)", cm.grudge == 1)

	# Grudge overrides a reward visit
	cm.mom_mood = 1
	cm.grudge = 3
	severity = Handler.compute_severity(cm)
	_check("grudge 3 overrides reward visit", severity == 3)


func _test_escalation(cm) -> void:
	cm.mom_mood = 8
	cm.grudge = 0
	cm.low_mood_visits_this_run = 2
	var severity: int = Handler.compute_severity(cm)
	_check("mood 8 + 2 low-mood visits -> severity 5", severity == 5)
	_check("visit registered as low-mood", cm.low_mood_visits_this_run == 3)

	# Severity below 3 does not register or escalate
	cm.mom_mood = 5
	cm.low_mood_visits_this_run = 0
	severity = Handler.compute_severity(cm)
	_check("mood 5 stays severity 1", severity == 1)
	_check("severity 1 visit not registered", cm.low_mood_visits_this_run == 0)


func _test_defer_system(cm, gc) -> void:
	gc.chores_manager = cm

	# Defer streak compounds onto severity
	cm.mom_mood = 5  # base severity 1
	cm.grudge = 0
	cm.low_mood_visits_this_run = 0
	cm.defer_streak = 2
	var severity: int = Handler.compute_severity(cm)
	_check("defer streak 2 compounds severity 1 -> 3", severity == 3)

	# Defer streak clamps at 5
	cm.mom_mood = 9  # base severity 4
	severity = Handler.compute_severity(cm)
	_check("defer streak clamps severity at 5", severity == 5)
	cm.defer_streak = 0

	# defer_punishment outcome: no punishment, deferred flag, grudge +1
	var outcome := _make_outcome("defer_punishment")
	var result = Handler.apply_outcome(gc, outcome, 3)
	_check("defer_punishment flagged", result.deferred)
	_check("defer_punishment applies no tier", result.tier_id == -1)
	_check("defer_punishment adds grudge +1", result.grudge_delta == 1)
	_check("defer_punishment applies no punishment", result.fine_amount == 0 and result.applied_debuffs.is_empty() and result.removed_power_ups.is_empty())

	# apply_consequences registers the defer
	cm.defer_streak = 0
	Handler.apply_consequences(gc, result)
	_check("defer registered on ChoresManager", cm.defer_streak == 1)

	# Applying a real punishment tier resets the streak
	var tier_result = Handler.MomCheckResult.new()
	tier_result.tier_id = 2
	Handler.apply_consequences(gc, tier_result)
	_check("defer streak resets when tier applied", cm.defer_streak == 0)

	# Defer streak clamps at MAX_DEFER_STREAK
	for i in range(5):
		cm.register_defer()
	_check("defer streak clamps at max", cm.defer_streak == ChoresManagerScript.MAX_DEFER_STREAK)
	cm.defer_streak = 0


func _test_apply_tier_semantics(gc) -> void:	# magnitude 0 = computed severity
	var outcome := _make_outcome("apply_tier", 0)
	var result = Handler.apply_outcome(gc, outcome, 3)
	_check("apply_tier 0 uses visit severity", result.tier_id == 3)

	# magnitude -1 = computed severity + 1
	outcome = _make_outcome("apply_tier", -1)
	result = Handler.apply_outcome(gc, outcome, 2)
	_check("apply_tier -1 escalates one tier", result.tier_id == 3)

	# magnitude >= 1 = exact tier
	outcome = _make_outcome("apply_tier", 5)
	result = Handler.apply_outcome(gc, outcome, 1)
	_check("apply_tier 5 forces tier 5", result.tier_id == 5)

	# Reward tier resolves a reward entry
	outcome = _make_outcome("apply_tier", 0)
	result = Handler.apply_outcome(gc, outcome, 0)
	var has_reward: bool = result.reward_money > 0 or result.reward_consumable_id != "" or result.reward_powerup_id != ""
	_check("tier 0 grants a reward", has_reward)


func _test_storms_off(gc) -> void:
	var outcome := _make_outcome("storms_off")
	outcome.grudge_delta = 1
	outcome.mood_delta = 2
	var result = Handler.apply_outcome(gc, outcome, 4)
	_check("storms_off flagged", result.storms_off)
	_check("storms_off keeps grudge delta", result.grudge_delta == 1)
	_check("storms_off keeps mood delta", result.mood_delta == 2)
	_check("storms_off applies no punishment", result.fine_amount == 0 and result.applied_debuffs.is_empty() and result.removed_power_ups.is_empty())


func _test_direct_effects(gc) -> void:
	# Fine with exact magnitude (PlayerEconomy starts with $100)
	var outcome := _make_outcome("fine", 75)
	var result = Handler.apply_outcome(gc, outcome, 2)
	_check("fine of exactly $75", result.fine_amount == 75)

	# reward_money magnitude 0 uses default $50-150 range
	outcome = _make_outcome("reward_money", 0)
	result = Handler.apply_outcome(gc, outcome, 0)
	_check("default reward in $50-150", result.reward_money >= 50 and result.reward_money <= 150)

	# mood_delta outcome only carries the field delta
	outcome = _make_outcome("mood_delta")
	outcome.mood_delta = -1
	result = Handler.apply_outcome(gc, outcome, 1)
	_check("mood_delta outcome carries delta", result.mood_delta == -1)
	_check("mood_delta outcome has no side effects", result.fine_amount == 0 and result.applied_debuffs.is_empty())

	# remove_mod picks from active mods
	gc.active_mods = {"odd_only": {}, "gold_six": {}}
	outcome = _make_outcome("remove_mod", 1)
	result = Handler.apply_outcome(gc, outcome, 4)
	_check("remove_mod picks one mod", result.removed_mods.size() == 1)
	_check("removed mod was active", result.removed_mods[0] in ["odd_only", "gold_six"])


func _test_weighted_drawing() -> void:
	# draw_entries respects picks and uniqueness
	var tier := Handler.get_tier(4)
	var entries: Array = Handler.draw_entries(tier)
	_check("tier 4 draws 2 entries", entries.size() == 2)
	_check("tier 4 entries are unique", entries[0] != entries[1])

	# resolve_response returns an outcome from the response
	var node := Handler.get_dialog_node("checkin_neutral")
	_check("checkin_neutral node loaded", node != null)
	var outcome := Handler.resolve_response(node.responses[0])
	_check("resolve_response returns outcome", outcome != null and outcome.weight > 0.0)

	# Bot policy: valid index on response nodes, -1 on terminal
	var idx := Handler.pick_response_index(node)
	_check("bot picks valid response index", idx >= 0 and idx < node.responses.size())
	var terminal := Handler.get_dialog_node("sass_storm_off")
	_check("bot gets -1 on terminal node", Handler.pick_response_index(terminal) == -1)


func _make_pu(rating: String) -> FakePUDef:
	var def := FakePUDef.new()
	def.rating = rating
	return def


func _test_checkin_tree_selection(gc) -> void:
	var pu := FakePUManager.new()
	add_child(pu)
	gc.pu_manager = pu

	# Empty inventory -> neutral check-in
	gc.active_power_ups = {}
	_check("empty inventory -> neutral check-in", Handler.get_checkin_tree_id(gc, 5) == "checkin_neutral")

	# G-rated items are safe
	pu.defs = {"pu_g": _make_pu("G"), "pu_pg": _make_pu("PG")}
	gc.active_power_ups = {"pu_g": {}, "pu_pg": {}}
	_check("G/PG inventory -> neutral check-in", Handler.get_checkin_tree_id(gc, 5) == "checkin_neutral")

	# PG-13 -> warning
	pu.defs["pu_pg13"] = _make_pu("PG-13")
	gc.active_power_ups["pu_pg13"] = {}
	_check("PG-13 -> warning check-in", Handler.get_checkin_tree_id(gc, 5) == "checkin_warning")

	# R -> warning
	pu.defs["pu_r"] = _make_pu("R")
	gc.active_power_ups["pu_r"] = {}
	_check("R -> warning check-in", Handler.get_checkin_tree_id(gc, 5) == "checkin_warning")

	# NC-17 -> caught red-handed, severity 3
	pu.defs["pu_nc17"] = _make_pu("NC-17")
	gc.active_power_ups["pu_nc17"] = {}
	var tree_id := Handler.get_checkin_tree_id(gc, 5)
	_check("NC-17 -> caught check-in", tree_id == "checkin_caught_nc17")
	_check("caught check-in has severity 3", Handler.get_checkin_severity(tree_id) == 3)

	# Rating scan counts
	var counts: Dictionary = Handler.scan_inventory_ratings(gc)
	_check("scan counts 1 NC-17", counts["nc17"] == 1)
	_check("scan counts 1 R", counts["r"] == 1)
	_check("scan counts 1 PG-13", counts["pg13"] == 1)

	# Non-caught trees have severity 0
	_check("warning check-in has severity 0", Handler.get_checkin_severity("checkin_warning") == 0)
	_check("neutral check-in has severity 0", Handler.get_checkin_severity("checkin_neutral") == 0)
	_check("cool mom check-in has severity 0", Handler.get_checkin_severity("checkin_cool_mom") == 0)

	# New dialog nodes loaded
	_check("silent treatment node loaded", Handler.get_dialog_node("visit_silent_treatment") != null)
	_check("caught node loaded", Handler.get_dialog_node("checkin_caught_nc17") != null)
	_check("warning node loaded", Handler.get_dialog_node("checkin_warning") != null)
	_check("cool mom node loaded", Handler.get_dialog_node("checkin_cool_mom") != null)

	# Cool mom: mood <= 3 with clean inventory -> cool_mom or neutral (5% roll)
	gc.active_power_ups = {}
	pu.defs = {}
	var cool_tree := Handler.get_checkin_tree_id(gc, 2)
	_check("happy mood clean inventory -> cool or neutral",
		cool_tree == "checkin_cool_mom" or cool_tree == "checkin_neutral")


func _test_silent_treatment() -> void:
	# Out-of-range severities never trigger silent treatment (deterministic)
	_check("severity 0 never silent", not Handler.should_silent_treatment(0))
	_check("severity 3 never silent", not Handler.should_silent_treatment(3))
	_check("severity 5 never silent", not Handler.should_silent_treatment(5))
	# Severity 1-2 is a 10% roll; result must be a plain bool either way
	var roll: bool = Handler.should_silent_treatment(1)
	_check("severity 1 silent roll is bool", roll == true or roll == false)
