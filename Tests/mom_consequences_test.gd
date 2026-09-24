extends Node

## mom_consequences_test.gd
##
## Layer 4 of the Mom suite: consequence application. Drives
## MomLogicHandler.apply_outcome() and apply_consequences() against the
## harness StubGameController plus the REAL PlayerEconomy / DiceColorManager /
## ProgressManager autoloads (snapshot before, restore after - never stubbed).
## Ends with the full compute_severity() mapping table.
##
## Run headless:
##   godot --headless --path . Tests/MomConsequencesTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

signal finished(failures: int)

const Harness = preload("res://Tests/mom_test_harness.gd")
const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

const DEFAULT_SEED := 12345

var _reporter := Harness.Reporter.new()
var _base_seed: int = DEFAULT_SEED
var _seed_counter: int = 0


func _ready() -> void:
	if get_tree().current_scene == self:
		var failures := await run_tests()
		if OS.get_cmdline_user_args().has("--quit-after"):
			get_tree().quit(failures)


func run_tests() -> int:
	print("[MomTests] --- Layer: consequence application ---")
	_base_seed = Harness.get_cmdline_seed(DEFAULT_SEED)
	print("[MomTests] Seed: %d" % _base_seed)
	_reporter = Harness.Reporter.new()

	_check_fine_affordable()
	_check_fine_unaffordable_substitutes_debuff()
	_check_debuff_effect()
	_check_debuff_all_active_stacks()
	_check_remove_mod()
	_check_confiscation_outcome()
	_check_confiscation_tier_entry_r_only()
	_check_lock_cosmetics_temporary()
	_check_lock_cosmetics_permanent()
	_check_reward_money()
	_check_reward_consumable()
	_check_reward_powerup()
	_check_reward_powerup_pool_exhausted()
	_check_storms_off()
	_check_defer_punishment()
	_check_defer_streak_reset_on_tier()
	_check_rep_delta_passthrough()
	_check_mood_and_grudge_deltas()
	_check_apply_tier_magnitudes()
	_check_sass_escalation()
	_check_severity_table()

	if _reporter.failures == 0:
		print("[MomTests] PASS - consequences (%d checks, seed %d)" % [_reporter.checks, _base_seed])
	else:
		print("[MomTests] FAIL - consequences: %d/%d check(s) failed (seed %d)" % [_reporter.failures, _reporter.checks, _base_seed])
	finished.emit(_reporter.failures)
	return _reporter.failures


func _next_seed() -> int:
	_seed_counter += 1
	return _base_seed + _seed_counter


func _new_stub() -> Harness.StubGameController:
	var stub := Harness.StubGameController.new()
	add_child(stub)
	GameRNG.initialize(_next_seed())
	return stub


func _free_stub(stub: Harness.StubGameController) -> void:
	remove_child(stub)
	stub.queue_free()


func _check_fine_affordable() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	PlayerEconomy.money = 500
	var outcome := Harness.make_outcome("fine", 100)
	var result := Handler.apply_outcome(stub, outcome, 2)
	_reporter.check("fine: result.fine_amount == 100", result.fine_amount == 100)
	_reporter.check("fine: mom_is_upset set", result.mom_is_upset)
	Handler.apply_consequences(stub, result)
	_reporter.check("fine: money 500 -> 400", PlayerEconomy.money == 400)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_fine_unaffordable_substitutes_debuff() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	PlayerEconomy.money = 0
	var outcome := Harness.make_outcome("fine", 100)
	var result := Handler.apply_outcome(stub, outcome, 2)
	_reporter.check("fine unaffordable: fine_amount == 0", result.fine_amount == 0)
	_reporter.check("fine unaffordable: one debuff substituted", result.applied_debuffs.size() == 1)
	if result.applied_debuffs.size() == 1:
		_reporter.check("fine unaffordable: debuff from AVAILABLE_DEBUFFS", result.applied_debuffs[0] in Handler.AVAILABLE_DEBUFFS)
	Handler.apply_consequences(stub, result)
	_reporter.check("fine unaffordable: no money removed", PlayerEconomy.money == 0)
	_reporter.check("fine unaffordable: debuff enabled on controller", stub.enabled_debuffs == result.applied_debuffs)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_debuff_effect() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	var outcome := Harness.make_outcome("debuff", 2)
	var result := Handler.apply_outcome(stub, outcome, 2)
	_reporter.check("debuff x2: two applied", result.applied_debuffs.size() == 2)
	var distinct := result.applied_debuffs.size() < 2 or result.applied_debuffs[0] != result.applied_debuffs[1]
	_reporter.check("debuff x2: distinct", distinct)
	for debuff_id in result.applied_debuffs:
		_reporter.check("debuff x2: '%s' from AVAILABLE_DEBUFFS" % debuff_id, debuff_id in Handler.AVAILABLE_DEBUFFS)
	_reporter.check("debuff x2: mom_is_upset", result.mom_is_upset)
	Handler.apply_consequences(stub, result)
	_reporter.check("debuff x2: enable_debuff called for each", stub.enabled_debuffs == result.applied_debuffs)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_debuff_all_active_stacks() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	var active: Dictionary = {}
	for debuff_id in Handler.AVAILABLE_DEBUFFS:
		active[debuff_id] = true
	var outcome := Harness.make_outcome("debuff", 1)
	var result := Handler.apply_outcome(stub, outcome, 2, active)
	_reporter.check("debuff all active: still returns one", result.applied_debuffs.size() == 1)
	if result.applied_debuffs.size() == 1:
		_reporter.check("debuff all active: id is a known debuff", result.applied_debuffs[0] in Handler.AVAILABLE_DEBUFFS)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_remove_mod() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	stub.active_mods = {"mod_a": true, "mod_b": true, "mod_c": true}
	var outcome := Harness.make_outcome("remove_mod", 2)
	var result := Handler.apply_outcome(stub, outcome, 4)
	_reporter.check("remove_mod x2: two removed", result.removed_mods.size() == 2)
	for mod_id in result.removed_mods:
		_reporter.check("remove_mod x2: '%s' was active" % mod_id, mod_id in ["mod_a", "mod_b", "mod_c"])
	_reporter.check("remove_mod x2: mom_is_upset", result.mom_is_upset)
	Handler.apply_consequences(stub, result)
	_reporter.check("remove_mod x2: remove_mod_no_refund called per id", stub.removed_mods == result.removed_mods)
	_reporter.check("remove_mod x2: one mod remains", stub.active_mods.size() == 1)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_confiscation_outcome() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	stub.add_power_up("g_pu", "G")
	stub.add_power_up("pg13_pu", "PG-13")
	stub.add_power_up("r_pu", "R")
	stub.add_power_up("nc17_pu", "NC-17")
	# Outcome pseudo-entry is always {max_rating: "NC-17", stack_debuffs: true}.
	var outcome := Harness.make_outcome("confiscate_powerups")
	var result := Handler.apply_outcome(stub, outcome, 4)
	_reporter.check("confiscation: exactly R + NC-17 removed", result.removed_power_ups.size() == 2
		and "r_pu" in result.removed_power_ups and "nc17_pu" in result.removed_power_ups)
	_reporter.check("confiscation: G and PG-13 kept", "g_pu" not in result.removed_power_ups
		and "pg13_pu" not in result.removed_power_ups)
	_reporter.check("confiscation: one debuff stacked per NC-17 item", result.applied_debuffs.size() == 1)
	_reporter.check("confiscation: mom_is_furious on NC-17 find", result.mom_is_furious)
	_reporter.check("confiscation: mom_is_upset", result.mom_is_upset)
	Handler.apply_consequences(stub, result)
	_reporter.check("confiscation: revoked on controller", stub.revoked_power_ups == result.removed_power_ups)
	_reporter.check("confiscation: G and PG-13 remain active", stub.active_power_ups.has("g_pu") and stub.active_power_ups.has("pg13_pu"))
	_reporter.check("confiscation: R and NC-17 gone from active", not stub.active_power_ups.has("r_pu") and not stub.active_power_ups.has("nc17_pu"))
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_confiscation_tier_entry_r_only() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	stub.add_power_up("g_pu", "G")
	stub.add_power_up("pg13_pu", "PG-13")
	stub.add_power_up("r_pu", "R")
	stub.add_power_up("nc17_pu", "NC-17")
	var entry := Harness.make_entry("confiscate_powerups", {"max_rating": "R", "stack_debuffs": false})
	var result := Handler.build_result_from_entries(stub, [entry])
	_reporter.check("confiscation R-only: only R removed", result.removed_power_ups == ["r_pu"])
	_reporter.check("confiscation R-only: NC-17 kept", "nc17_pu" not in result.removed_power_ups)
	_reporter.check("confiscation R-only: no debuffs", result.applied_debuffs.is_empty())
	_reporter.check("confiscation R-only: not furious", not result.mom_is_furious)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_lock_cosmetics_temporary() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	DiceColorManager.colors_enabled = true
	var purchased_before: Dictionary = DiceColorManager.purchased_colors.duplicate()
	var outcome := Harness.make_outcome("lock_cosmetics", 0, 1.0, {"permanent": false})
	var result := Handler.apply_outcome(stub, outcome, 2)
	_reporter.check("lock temp: cosmetics_locked", result.cosmetics_locked)
	_reporter.check("lock temp: not permanent", not result.cosmetics_lock_permanent)
	Handler.apply_consequences(stub, result)
	_reporter.check("lock temp: colors_enabled false", DiceColorManager.colors_enabled == false)
	_reporter.check("lock temp: purchased colors untouched", DiceColorManager.purchased_colors == purchased_before)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_lock_cosmetics_permanent() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	DiceColorManager.colors_enabled = true
	# Guarantee at least one non-zero purchase exists, whatever the autoload's
	# startup state is; _reset_purchased_colors() must wipe it.
	DiceColorManager.purchased_colors[0] = 3
	var outcome := Harness.make_outcome("lock_cosmetics", 0, 1.0, {"permanent": true})
	var result := Handler.apply_outcome(stub, outcome, 2)
	_reporter.check("lock permanent: cosmetics_locked", result.cosmetics_locked)
	_reporter.check("lock permanent: flag set", result.cosmetics_lock_permanent)
	Handler.apply_consequences(stub, result)
	_reporter.check("lock permanent: colors_enabled false", DiceColorManager.colors_enabled == false)
	var all_zero := DiceColorManager.purchased_colors.size() > 0
	for key in DiceColorManager.purchased_colors:
		if int(DiceColorManager.purchased_colors[key]) != 0:
			all_zero = false
	_reporter.check("lock permanent: purchased colors wiped to zero", all_zero)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_reward_money() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	PlayerEconomy.money = 100
	var random_outcome := Harness.make_outcome("reward_money", 0)
	var random_result := Handler.apply_outcome(stub, random_outcome, 0)
	_reporter.check("reward_money default in [50, 150] (got %d)" % random_result.reward_money,
		random_result.reward_money >= 50 and random_result.reward_money <= 150)
	Handler.apply_consequences(stub, random_result)
	_reporter.check("reward_money default: money increased by exactly the grant",
		PlayerEconomy.money == 100 + random_result.reward_money)

	var exact_outcome := Harness.make_outcome("reward_money", 200)
	var exact_result := Handler.apply_outcome(stub, exact_outcome, 0)
	_reporter.check("reward_money magnitude 200 -> exactly 200", exact_result.reward_money == 200)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_reward_consumable() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	var pool: Array = (Handler.TIER_00.entries[1].get("params", {}) as Dictionary).get("pool", [])
	_reporter.check("reward_consumable: tier_00 fallback pool available", pool.size() > 0)
	var outcome := Harness.make_outcome("reward_consumable")
	var result := Handler.apply_outcome(stub, outcome, 0)
	_reporter.check("reward_consumable: id from tier_00 pool", result.reward_consumable_id in pool)
	Handler.apply_consequences(stub, result)
	_reporter.check("reward_consumable: granted on controller", stub.granted_consumables == [result.reward_consumable_id])
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_reward_powerup() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	var pool: Array = (Handler.TIER_00.entries[2].get("params", {}) as Dictionary).get("pool", [])
	_reporter.check("reward_powerup: tier_00 fallback pool available", pool.size() > 0)
	var outcome := Harness.make_outcome("reward_powerup")
	var result := Handler.apply_outcome(stub, outcome, 0)
	_reporter.check("reward_powerup: id from tier_00 pool", result.reward_powerup_id in pool)
	_reporter.check("reward_powerup: no money fallback when pool open", result.reward_money == 0)
	Handler.apply_consequences(stub, result)
	_reporter.check("reward_powerup: granted on controller", stub.granted_power_ups == [result.reward_powerup_id])
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_reward_powerup_pool_exhausted() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	var pool: Array = (Handler.TIER_00.entries[2].get("params", {}) as Dictionary).get("pool", [])
	for power_up_id in pool:
		stub.add_power_up(String(power_up_id), "G")
	var outcome := Harness.make_outcome("reward_powerup")
	var result := Handler.apply_outcome(stub, outcome, 0)
	_reporter.check("reward_powerup exhausted: no power-up id", result.reward_powerup_id == "")
	_reporter.check("reward_powerup exhausted: money fallback in [75, 125] (got %d)" % result.reward_money,
		result.reward_money >= 75 and result.reward_money <= 125)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_storms_off() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	PlayerEconomy.money = 100
	var outcome := Harness.make_outcome("storms_off", 0, 1.0, {"mood_delta": 1, "grudge_delta": 1})
	var result := Handler.apply_outcome(stub, outcome, 3)
	_reporter.check("storms_off: flag set", result.storms_off)
	_reporter.check("storms_off: mom_is_upset", result.mom_is_upset)
	_reporter.check("storms_off: early return, no tier resolved", result.tier_id == -1)
	_reporter.check("storms_off: no fines or rewards", result.fine_amount == 0 and result.reward_money == 0)
	_reporter.check("storms_off: deltas ride the result", result.mood_delta == 1 and result.grudge_delta == 1)
	Handler.apply_consequences(stub, result)
	_reporter.check("storms_off: mood +1 applied", stub.chores_manager.mood_calls == [1])
	_reporter.check("storms_off: grudge +1 applied", stub.chores_manager.grudge_calls == [1])
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_defer_punishment() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	var outcome := Harness.make_outcome("defer_punishment", 0, 1.0, {"grudge_delta": 0})
	var result := Handler.apply_outcome(stub, outcome, 3)
	_reporter.check("defer: deferred flag", result.deferred)
	_reporter.check("defer: grudge_delta raised by 1", result.grudge_delta == 1)
	_reporter.check("defer: no tier resolved now", result.tier_id == -1)
	_reporter.check("defer: mom_is_upset", result.mom_is_upset)
	Handler.apply_consequences(stub, result)
	_reporter.check("defer: register_defer called once", stub.chores_manager.defer_registered == 1)
	_reporter.check("defer: reset_defer_streak NOT called", stub.chores_manager.defer_resets == 0)
	_reporter.check("defer: streak is now 1", stub.chores_manager.defer_streak == 1)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_defer_streak_reset_on_tier() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	PlayerEconomy.money = 1000
	stub.chores_manager.defer_streak = 2
	var outcome := Harness.make_outcome("apply_tier", 1)
	var result := Handler.apply_outcome(stub, outcome, 1)
	_reporter.check("tier applied: tier_id == 1", result.tier_id == 1)
	Handler.apply_consequences(stub, result)
	_reporter.check("tier applied: reset_defer_streak called", stub.chores_manager.defer_resets == 1)
	_reporter.check("tier applied: streak cleared", stub.chores_manager.defer_streak == 0)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_rep_delta_passthrough() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	var rep_before := ProgressManager.get_rep()
	var outcome := Harness.make_outcome("rep_delta", 2)
	var result := Handler.apply_outcome(stub, outcome, 0)
	_reporter.check("rep_delta: rides the result", result.rep_delta == 2)
	_reporter.check("rep_delta: no other mutation", result.fine_amount == 0 and not result.mom_is_upset
		and result.applied_debuffs.is_empty() and result.tier_id == -1)
	Handler.apply_consequences(stub, result)
	_reporter.check("rep_delta: handler does not touch ProgressManager (GameController applies rep)",
		ProgressManager.get_rep() == rep_before)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_mood_and_grudge_deltas() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	stub.chores_manager.mom_mood = 5
	var outcome := Harness.make_outcome("mood_delta", 0, 1.0, {"mood_delta": -2, "grudge_delta": 1})
	var result := Handler.apply_outcome(stub, outcome, 0)
	_reporter.check("mood_delta: rides the result", result.mood_delta == -2 and result.grudge_delta == 1)
	Handler.apply_consequences(stub, result)
	_reporter.check("mood_delta: adjust_mood(-2) called", stub.chores_manager.mood_calls == [-2])
	_reporter.check("mood_delta: mood 5 -> 3", stub.chores_manager.mom_mood == 3)
	_reporter.check("grudge_delta: add_grudge(1) called", stub.chores_manager.grudge_calls == [1])

	var none_outcome := Harness.make_outcome("none")
	var none_result := Handler.apply_outcome(stub, none_outcome, 0)
	_reporter.check("none: empty result", none_result.fine_amount == 0 and none_result.mood_delta == 0
		and none_result.grudge_delta == 0 and none_result.tier_id == -1
		and none_result.applied_debuffs.is_empty() and none_result.removed_power_ups.is_empty())
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_apply_tier_magnitudes() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	PlayerEconomy.money = 1000
	var severity := 2
	var zero := Handler.apply_outcome(stub, Harness.make_outcome("apply_tier", 0), severity)
	_reporter.check("apply_tier magnitude 0 resolves computed severity (2)", zero.tier_id == 2)
	var minus_one := Handler.apply_outcome(stub, Harness.make_outcome("apply_tier", -1), severity)
	_reporter.check("apply_tier magnitude -1 resolves severity + 1 (3)", minus_one.tier_id == 3)
	var exact := Handler.apply_outcome(stub, Harness.make_outcome("apply_tier", 3), severity)
	_reporter.check("apply_tier magnitude 3 resolves exactly tier 3", exact.tier_id == 3)
	var clamped := Handler.apply_outcome(stub, Harness.make_outcome("apply_tier", -1), 5)
	_reporter.check("apply_tier magnitude -1 at severity 5 clamps to 5", clamped.tier_id == 5)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_sass_escalation() -> void:
	var snap := Harness.snapshot_autoloads()
	var stub := _new_stub()
	PlayerEconomy.money = 1000

	# Rep tier 3 (rep >= 35): tier escalates by 3 / 2 = +1.
	ProgressManager.cumulative_stats["rep"] = 35
	_reporter.check("sass setup: rep tier is 3 at rep 35", ProgressManager.get_rep_tier() == 3)
	var sass_tier := Handler.apply_outcome(stub, Harness.make_outcome("apply_tier", 1), 1, {}, true)
	_reporter.check("sass: apply_tier magnitude 1 escalates to tier 2 at rep tier 3", sass_tier.tier_id == 2)
	var calm_tier := Handler.apply_outcome(stub, Harness.make_outcome("apply_tier", 1), 1, {}, false)
	_reporter.check("non-sass: apply_tier magnitude 1 stays tier 1", calm_tier.tier_id == 1)

	# Debuff entries gain +1 debuff at rep tier >= 3 when is_sass.
	var entry := Harness.make_entry("debuff", {"count": 1})
	var sass_debuffs := Handler.build_result_from_entries(stub, [entry], {}, true)
	_reporter.check("sass: debuff entry count 1 applies 2 at rep tier 3", sass_debuffs.applied_debuffs.size() == 2)
	var calm_debuffs := Handler.build_result_from_entries(stub, [entry], {}, false)
	_reporter.check("non-sass: debuff entry count 1 applies 1", calm_debuffs.applied_debuffs.size() == 1)

	# Rep 0: no escalation.
	ProgressManager.cumulative_stats["rep"] = 0
	var floor_tier := Handler.apply_outcome(stub, Harness.make_outcome("apply_tier", 1), 1, {}, true)
	_reporter.check("sass at rep 0: no tier escalation", floor_tier.tier_id == 1)
	var floor_debuffs := Handler.build_result_from_entries(stub, [entry], {}, true)
	_reporter.check("sass at rep 0: no extra debuff", floor_debuffs.applied_debuffs.size() == 1)
	Harness.restore_autoloads(snap)
	_free_stub(stub)


func _check_severity_table() -> void:
	# Base mood bands.
	var expected: Array[int] = [0, 0, 0, 1, 1, 1, 2, 3, 4, 5]
	var bands_ok := true
	for mood in range(1, 11):
		var stub := _new_stub()
		stub.chores_manager.mom_mood = mood
		var got := Handler.compute_severity(stub.chores_manager)
		if got != expected[mood - 1]:
			bands_ok = false
			_reporter.check("severity mood %d -> %d (got %d)" % [mood, expected[mood - 1], got], false)
		_free_stub(stub)
	_reporter.check("severity mood bands 1-10 -> 0,0,0,1,1,1,2,3,4,5", bands_ok)

	# Grudge floor (and consume side-effect).
	var stub := _new_stub()
	stub.chores_manager.mom_mood = 4
	stub.chores_manager.grudge = 3
	var with_grudge := Handler.compute_severity(stub.chores_manager)
	_reporter.check("severity mood 4 + grudge 3 -> 3 (floor)", with_grudge == 3)
	_reporter.check("severity consumed one grudge level (3 -> 2)", stub.chores_manager.grudge == 2)
	_free_stub(stub)

	# Defer streak compounding.
	stub = _new_stub()
	stub.chores_manager.mom_mood = 4
	stub.chores_manager.defer_streak = 2
	_reporter.check("severity mood 4 + defer 2 -> 3 (compounds)", Handler.compute_severity(stub.chores_manager) == 3)
	_free_stub(stub)
	stub = _new_stub()
	stub.chores_manager.mom_mood = 10
	stub.chores_manager.defer_streak = 3
	_reporter.check("severity mood 10 + defer 3 -> 5 (clamped)", Handler.compute_severity(stub.chores_manager) == 5)
	_free_stub(stub)

	# Low-mood-visit escalation path.
	stub = _new_stub()
	stub.chores_manager.mom_mood = 8
	stub.chores_manager.low_mood_visits_this_run = 2
	var escalated := Handler.compute_severity(stub.chores_manager)
	_reporter.check("severity mood 8 + 2 low-mood visits -> 5", escalated == 5)
	_reporter.check("severity >= 3 registers a low-mood visit", stub.chores_manager.low_mood_visits_registered == 1)
	_reporter.check("low-mood visit counter incremented 2 -> 3", stub.chores_manager.low_mood_visits_this_run == 3)
	_free_stub(stub)

	# Below the escalation threshold: no registration.
	stub = _new_stub()
	stub.chores_manager.mom_mood = 4
	var low := Handler.compute_severity(stub.chores_manager)
	_reporter.check("severity mood 4 -> 1 with no low-mood registration", low == 1 and stub.chores_manager.low_mood_visits_registered == 0)
	_free_stub(stub)

	# Severity >= 3 registers itself even without prior visits.
	stub = _new_stub()
	stub.chores_manager.mom_mood = 8
	var plain_high := Handler.compute_severity(stub.chores_manager)
	_reporter.check("severity mood 8 -> 3 and registers itself", plain_high == 3 and stub.chores_manager.low_mood_visits_registered == 1)
	_free_stub(stub)
