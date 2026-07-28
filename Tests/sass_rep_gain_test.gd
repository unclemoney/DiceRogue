extends Node

## sass_rep_gain_test.gd
##
## Regression test for the playtest bug "REP stays at 0 despite
## successfully sassing Mom". Covers the real game code path end to end:
##   1. A successful (unpunished) sassy response yields a positive Rep
##      delta via MomLogicHandler.apply_outcome() ->
##      GameController._compute_rep_delta() -> ProgressManager.adjust_rep().
##   2. A punished sassy response yields 0 Rep (by design).
##   3. The gain survives the save that adjust_rep() triggers - even for
##      a player on profile slot 2/3. ProgressManager autoloads BEFORE
##      GameSettings, so boot always loaded slot 1; the profile-mismatch
##      guard in save_current_profile() then reloaded from disk on the
##      first save, silently wiping the just-applied Rep delta.
##      _sync_active_profile_slot() (deferred from ProgressManager._ready)
##      must sync the slot first so the gain persists.
##
## All profile slots and Rep values touched are restored afterwards.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/SassRepGainTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

var _failures: int = 0


## Minimal GameController stand-in for result building (same pattern as
## sass_rep_scaling_test.gd).
class FakeGC extends Node:
	var active_power_ups: Dictionary = {}
	var active_mods: Dictionary = {}
	var pu_manager = null
	var chores_manager = null


func _ready() -> void:
	print("[SassRepGainTest] Starting")
	var pm = get_node_or_null("/root/ProgressManager")
	var gs = get_node_or_null("/root/GameSettings")
	if pm == null or gs == null:
		push_error("[SassRepGainTest] FAILED: ProgressManager/GameSettings autoload missing")
		if OS.get_cmdline_user_args().has("--quit-after"):
			get_tree().quit(1)
		return

	# Preserve original state (restored at the end)
	var orig_pm_slot: int = pm.current_profile_slot
	var orig_gs_slot: int = gs.active_profile_slot
	var orig_rep_current: int = pm.get_rep()

	_test_successful_sass_grants_rep(pm)
	_test_rep_gain_survives_boot_slot_mismatch(pm, gs)

	# Restore original state
	gs.active_profile_slot = orig_gs_slot
	pm.load_profile(orig_pm_slot)
	if pm.get_rep() != orig_rep_current:
		pm.cumulative_stats["rep"] = orig_rep_current
		pm.save_progress()

	if _failures == 0:
		print("[SassRepGainTest] PASS - all checks passed")
	else:
		print("[SassRepGainTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[SassRepGainTest] OK: " + label)
	else:
		push_error("[SassRepGainTest] FAILED: " + label)
		_failures += 1


## _test_successful_sass_grants_rep(pm)
##
## Drives the exact functions GameController._run_mom_dialog_session()
## uses per response and verifies a successful sass raises Rep from 0.
func _test_successful_sass_grants_rep(pm) -> void:
	var fake_gc := FakeGC.new()
	add_child(fake_gc)
	# Real GameController instance (not added to the tree): the Rep
	# functions under test are pure and read no scene state.
	var gc := GameController.new()

	var orig_rep: int = pm.get_rep()
	pm.cumulative_stats["rep"] = 0
	pm.save_progress()

	# Successful sass: sassy tone + flavor-only outcome (no punishment)
	var response := MomDialogResponse.new()
	response.tone = "sassy"
	var outcome := MomDialogOutcome.new()
	outcome.effect = "mood_delta"
	outcome.mood_delta = 2

	var outcome_result = Handler.apply_outcome(fake_gc, outcome, 0, {}, true)
	_check("flavor outcome is a successful sass", gc._is_successful_sass(response, outcome))
	var delta: int = gc._compute_rep_delta(response, outcome_result, false, 0)
	_check("successful sass delta is REP_SASS_SUCCESS", delta == GameController.REP_SASS_SUCCESS)
	pm.adjust_rep(delta)
	_check("rep rises 0 -> %d after successful sass" % GameController.REP_SASS_SUCCESS,
		pm.get_rep() == GameController.REP_SASS_SUCCESS)

	# The save inside adjust_rep must have persisted the gain
	pm.load_profile(pm.current_profile_slot)
	_check("rep gain survives save/load round-trip", pm.get_rep() == GameController.REP_SASS_SUCCESS)

	# Punished sass: apply_tier outcome -> 0 Rep by design
	var punished_outcome := MomDialogOutcome.new()
	punished_outcome.effect = "apply_tier"
	punished_outcome.magnitude = 2
	var punished_result = Handler.apply_outcome(fake_gc, punished_outcome, 0, {}, true)
	_check("punished sass is not a success", not gc._is_successful_sass(response, punished_outcome))
	var punished_delta: int = gc._compute_rep_delta(response, punished_result, false, 0)
	_check("punished sass delta is 0", punished_delta == 0)
	var rep_before: int = pm.get_rep()
	pm.adjust_rep(punished_delta)
	_check("punished sass leaves rep unchanged", pm.get_rep() == rep_before)

	# Storm-off sass escape pays REP_STORM_OFF
	var storm_outcome := MomDialogOutcome.new()
	storm_outcome.effect = "storms_off"
	var storm_result = Handler.apply_outcome(fake_gc, storm_outcome, 0, {}, true)
	var storm_delta: int = gc._compute_rep_delta(response, storm_result, false, 0)
	_check("storm-off sass delta is REP_STORM_OFF", storm_delta == GameController.REP_STORM_OFF)

	# Restore the original Rep on this slot
	pm.cumulative_stats["rep"] = orig_rep
	pm.save_progress()

	gc.free()
	fake_gc.queue_free()


## _test_rep_gain_survives_boot_slot_mismatch(pm, gs)
##
## Reproduces the wipe: a slot-2 player boots with ProgressManager on
## slot 1 (autoload order). Before the fix, the first adjust_rep() save
## hit the mismatch guard in save_current_profile(), reloaded slot 2
## from disk and silently reverted the Rep gain to 0.
func _test_rep_gain_survives_boot_slot_mismatch(pm, gs) -> void:
	# Set the active slot FIRST so the normalization save below does not
	# trip the mismatch guard (which would save the wrong profile).
	var orig_gs_slot: int = gs.active_profile_slot
	gs.active_profile_slot = 2

	# Normalize slot 2's Rep to 0 so the wipe is observable (restored below)
	pm.load_profile(2)
	var orig_rep2: int = pm.get_rep()
	pm.cumulative_stats["rep"] = 0
	pm.save_progress()

	# Simulate boot state for a slot-2 player: ProgressManager loaded
	# slot 1 because GameSettings did not exist yet at autoload time.
	pm.load_profile(1)
	_check("simulated boot mismatch in place", pm.current_profile_slot != gs.active_profile_slot)

	# The fix: the deferred boot sync loads the actually active profile
	pm._sync_active_profile_slot()
	_check("boot sync loads the active profile slot", pm.current_profile_slot == 2)

	# The real save path used by the sass flow
	pm.adjust_rep(GameController.REP_SASS_SUCCESS)
	_check("rep gain survives the save inside adjust_rep", pm.get_rep() == GameController.REP_SASS_SUCCESS)

	# Restore slot 2's original Rep
	pm.cumulative_stats["rep"] = orig_rep2
	pm.save_progress()
