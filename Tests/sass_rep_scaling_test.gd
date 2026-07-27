extends Node

## sass_rep_scaling_test.gd
##
## Verifies MomLogicHandler.apply_outcome() sass escalation:
##   1. is_sass adds ProgressManager.get_rep_tier() / SASS_REP_TIER_STEP
##      punishment tiers (clamped to 5).
##   2. is_sass adds +1 debuff count at rep tier >= SASS_REP_EXTRA_DEBUFF_MIN_TIER.
##   3. Non-sass outcomes are unaffected by rep tier.
## The player's saved Rep is preserved and restored after the test.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/SassRepScalingTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

var _failures: int = 0
var _saved_rep: int = 0


## Minimal GameController stand-in for result building.
class FakeGC extends Node:
	var active_power_ups: Dictionary = {}
	var active_mods: Dictionary = {}
	var pu_manager = null
	var chores_manager = null


func _ready() -> void:
	print("[SassRepScalingTest] Starting")
	var gc := FakeGC.new()
	add_child(gc)
	_saved_rep = ProgressManager.get_rep()

	_test_sass_tier_escalation(gc)
	_test_sass_debuff_count(gc)

	# Restore the player's saved Rep
	ProgressManager.adjust_rep(_saved_rep - ProgressManager.get_rep())

	if _failures == 0:
		print("[SassRepScalingTest] PASS - all checks passed")
	else:
		print("[SassRepScalingTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[SassRepScalingTest] OK: " + label)
	else:
		push_error("[SassRepScalingTest] FAILED: " + label)
		_failures += 1


func _make_outcome(effect: String, magnitude: int = 0) -> MomDialogOutcome:
	var outcome := MomDialogOutcome.new()
	outcome.effect = effect
	outcome.magnitude = magnitude
	return outcome


func _set_rep(target: int) -> void:
	ProgressManager.adjust_rep(target - ProgressManager.get_rep())


func _test_sass_tier_escalation(gc) -> void:
	var outcome := _make_outcome("apply_tier", 3)

	# Baseline: no sass, any rep -> exact tier
	_set_rep(75)
	var result = Handler.apply_outcome(gc, outcome, 3)
	_check("non-sass ignores rep tier (tier 3)", result.tier_id == 3)

	# Rep 0 (tier 1): 1 / 2 = 0 bonus tiers
	_set_rep(0)
	_check("rep 0 is tier 1", ProgressManager.get_rep_tier() == 1)
	result = Handler.apply_outcome(gc, outcome, 3, {}, true)
	_check("sass at rep 0 adds 0 tiers (tier 3)", result.tier_id == 3)

	# Rep 25 (tier 2): 2 / 2 = 1 bonus tier
	_set_rep(25)
	result = Handler.apply_outcome(gc, outcome, 3, {}, true)
	_check("sass at rep 25 adds 1 tier (tier 4)", result.tier_id == 4)

	# Rep 50 (tier 3): 3 / 2 = 1 bonus tier
	_set_rep(50)
	result = Handler.apply_outcome(gc, outcome, 3, {}, true)
	_check("sass at rep 50 adds 1 tier (tier 4)", result.tier_id == 4)

	# Rep 75 (tier 4): 4 / 2 = 2 bonus tiers
	_set_rep(75)
	result = Handler.apply_outcome(gc, outcome, 3, {}, true)
	_check("sass at rep 75 adds 2 tiers (tier 5)", result.tier_id == 5)

	# Clamp: tier 5 + bonus stays at 5
	outcome = _make_outcome("apply_tier", 5)
	result = Handler.apply_outcome(gc, outcome, 5, {}, true)
	_check("sass escalation clamps at tier 5", result.tier_id == 5)


func _test_sass_debuff_count(gc) -> void:
	var outcome := _make_outcome("debuff", 1)

	# Below the extra-debuff tier: count stays at 1
	_set_rep(0)
	var result = Handler.apply_outcome(gc, outcome, 3, {}, true)
	_check("sass debuff at rep 0 applies 1 debuff", result.applied_debuffs.size() == 1)

	_set_rep(25)
	result = Handler.apply_outcome(gc, outcome, 3, {}, true)
	_check("sass debuff at rep 25 (tier 2) applies 1 debuff", result.applied_debuffs.size() == 1)

	# At/above SASS_REP_EXTRA_DEBUFF_MIN_TIER: +1 debuff
	_set_rep(50)
	result = Handler.apply_outcome(gc, outcome, 3, {}, true)
	_check("sass debuff at rep 50 (tier 3) applies 2 debuffs", result.applied_debuffs.size() == 2)

	_set_rep(75)
	result = Handler.apply_outcome(gc, outcome, 3, {}, true)
	_check("sass debuff at rep 75 (tier 4) applies 2 debuffs", result.applied_debuffs.size() == 2)

	# Non-sass at high rep: no bonus debuff
	result = Handler.apply_outcome(gc, outcome, 3)
	_check("non-sass debuff at rep 75 applies 1 debuff", result.applied_debuffs.size() == 1)
