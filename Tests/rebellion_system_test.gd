extends Node

## rebellion_system_test.gd
##
## Exercises the Rebellion systems (Sass Incentives):
##   1. RebellionBuff: score multiplier + bonus rolls per stack, stacking,
##      cleanup on remove().
##   2. DebuffManager: "rebellion" is excluded from automatic round selection.
##   3. ProgressManager Rep: clamp, tier thresholds, stage thresholds.
##   4. PowerUpData.rating_rank ordering.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/RebellionSystemTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const RebellionBuffScript := preload("res://Scripts/Debuff/rebellion_buff.gd")
const DebuffManagerScript := preload("res://Scripts/Managers/DebuffManager.gd")
const TurnTrackerScript := preload("res://Scripts/Core/turn_tracker.gd")
const RebellionDef := preload("res://Scripts/Debuff/RebellionBuff.tres")
const HalfAdditiveDef := preload("res://Scripts/Debuff/HalfAdditiveDebuff.tres")

var _failures: int = 0


func _ready() -> void:
	print("[RebellionSystemTest] Starting")

	_test_buff_multiplier_and_rolls()
	_test_buff_stacking()
	_test_buff_cleanup()
	_test_granted_only_exclusion()
	_test_rep_stat()
	_test_rating_rank()

	if _failures == 0:
		print("[RebellionSystemTest] PASS - all checks passed")
	else:
		print("[RebellionSystemTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[RebellionSystemTest] OK: " + label)
	else:
		push_error("[RebellionSystemTest] FAILED: " + label)
		_failures += 1


func _make_buff(intensity: float = 1.0) -> RebellionBuff:
	var buff := RebellionBuffScript.new()
	add_child(buff)
	buff.set_intensity(intensity)
	return buff


func _test_buff_multiplier_and_rolls() -> void:
	var smm = get_node_or_null("/root/ScoreModifierManager")
	_check("ScoreModifierManager autoload available", smm != null)
	if smm == null:
		return

	var tracker: TurnTracker = TurnTrackerScript.new()
	add_child(tracker)
	tracker.MAX_ROLLS = 3
	tracker.max_turns = 13
	tracker.start_new_turn()

	var buff := _make_buff(1.0)
	buff._turn_tracker = tracker
	buff._register_multiplier()
	_check("1 stack registers x1.15 multiplier", is_equal_approx(smm.get_total_multiplier(), 1.15))

	tracker.rolls_left = 3
	buff._on_turn_started()
	_check("1 stack grants +1 roll", tracker.rolls_left == 4)

	buff._unregister_multiplier()
	tracker.queue_free()
	buff.queue_free()


func _test_buff_stacking() -> void:
	var smm = get_node_or_null("/root/ScoreModifierManager")
	if smm == null:
		return

	var buff := _make_buff(1.0)
	buff.is_active = true  # simulate a started buff so set_intensity refreshes
	buff._register_multiplier()

	buff.set_intensity(buff.intensity + 1.0)
	_check("2 stacks -> x1.30 multiplier", is_equal_approx(smm.get_total_multiplier(), 1.30))
	_check("2 stacks -> +2 rolls", buff._bonus_rolls() == 2)

	buff.set_intensity(buff.intensity + 1.0)
	_check("3 stacks -> x1.45 multiplier", is_equal_approx(smm.get_total_multiplier(), 1.45))

	buff.set_intensity(buff.intensity + 1.0)
	_check("stacks clamp at 3", int(buff.intensity) == 3)
	_check("4th stack keeps x1.45", is_equal_approx(smm.get_total_multiplier(), 1.45))
	_check("rolls clamp at +2", buff._bonus_rolls() == 2)

	buff._unregister_multiplier()
	buff.queue_free()


func _test_buff_cleanup() -> void:
	var smm = get_node_or_null("/root/ScoreModifierManager")
	if smm == null:
		return

	var buff := _make_buff(2.0)
	buff._register_multiplier()
	buff._unregister_multiplier()
	_check("remove unregisters multiplier", is_equal_approx(smm.get_total_multiplier(), 1.0))
	buff.queue_free()


func _test_granted_only_exclusion() -> void:
	var manager := DebuffManagerScript.new()
	manager.debuff_defs = [RebellionDef, HalfAdditiveDef]
	add_child(manager)  # triggers _ready -> _load_definitions

	_check("rebellion def registered", manager.get_def("rebellion") != null)
	var eligible := manager.get_debuffs_by_difficulty(5)
	var ids: Array = []
	for def in eligible:
		ids.append(def.id)
	_check("rebellion excluded from auto-selection", "rebellion" not in ids)
	_check("normal debuffs still eligible", "half_additive" in ids)

	# The buff scene must instantiate through the DebuffManager spawn path
	var container := Node.new()
	add_child(container)
	var spawned := manager.spawn_debuff("rebellion", container)
	_check("rebellion buff spawns via manager", spawned is RebellionBuff)
	if spawned:
		_check("spawned buff has id", spawned.id == "rebellion")

	manager.queue_free()


func _test_rep_stat() -> void:
	var pm = get_node_or_null("/root/ProgressManager")
	_check("ProgressManager autoload available", pm != null)
	if pm == null:
		return

	var original_rep: int = pm.get_rep()

	pm.cumulative_stats["rep"] = 0
	_check("tier 1 at rep 0 (G+PG open)", pm.get_rep_tier() == 1)
	pm.cumulative_stats["rep"] = 14
	_check("tier 1 below 15", pm.get_rep_tier() == 1)
	pm.cumulative_stats["rep"] = 15
	_check("tier 2 at rep 15", pm.get_rep_tier() == 2)
	pm.cumulative_stats["rep"] = 35
	_check("tier 3 at rep 35", pm.get_rep_tier() == 3)
	pm.cumulative_stats["rep"] = 60
	_check("tier 4 at rep 60", pm.get_rep_tier() == 4)
	_check("stage names progress", pm.get_rep_stage_name() == "Banned from the Mall")

	pm.cumulative_stats["rep"] = 0
	pm.adjust_rep(3)
	_check("adjust_rep adds", pm.get_rep() == 3)
	pm.adjust_rep(-10)
	_check("adjust_rep clamps at 0", pm.get_rep() == 0)
	pm.adjust_rep(200)
	_check("adjust_rep clamps at MAX_REP", pm.get_rep() == pm.MAX_REP)

	pm.cumulative_stats["rep"] = original_rep
	pm.save_progress()


func _test_rating_rank() -> void:
	_check("G rank 0", PowerUpData.rating_rank("G") == 0)
	_check("PG rank 1", PowerUpData.rating_rank("PG") == 1)
	_check("PG-13 rank 2", PowerUpData.rating_rank("PG-13") == 2)
	_check("R rank 3", PowerUpData.rating_rank("R") == 3)
	_check("NC-17 rank 4", PowerUpData.rating_rank("NC-17") == 4)
	_check("unknown defaults to G", PowerUpData.rating_rank("XXX") == 0)
