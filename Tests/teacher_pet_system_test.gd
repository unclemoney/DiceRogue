extends Node

## teacher_pet_system_test.gd
##
## Exercises the Teacher's Pet systems:
##   1. Tier 1-10 behavior and modifier registration (additive at all tiers,
##      multiplier from tier 5, round-end allowance from tier 8).
##   2. Tier upgrades and live round-end bonus preview changes.
##   3. DebuffManager exclusion from automatic selection.
##   4. GameController cross-buff replacement and same-buff upgrade rules.
##   5. Save/load restoration for active Teacher's Pet tiers.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/TeacherPetSystemTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const TeacherPetBuffScript := preload("res://Scripts/Debuff/teacher_pet_buff.gd")
const DebuffManagerScript := preload("res://Scripts/Managers/DebuffManager.gd")
const GameControllerScript := preload("res://Scripts/Core/game_controller.gd")
const CHORE_UI_SCENE: PackedScene = preload("res://Scenes/UI/chore_ui.tscn")
const TeacherPetDef: DebuffData = preload("res://Scripts/Debuff/TeacherPetBuff.tres")
const RebellionDef: DebuffData = preload("res://Scripts/Debuff/RebellionBuff.tres")
const HalfAdditiveDef: DebuffData = preload("res://Scripts/Debuff/HalfAdditiveDebuff.tres")

var _failures: int = 0


func _ready() -> void:
	print("[TeacherPetSystemTest] Starting")

	_test_activation_odds_floor()
	_test_tier_behavior()
	_test_live_tier_upgrade()
	_test_granted_only_exclusion()
	await _test_game_controller_replacement_and_upgrade()
	await _test_completed_round_cleanup_preserves_teacher_pet_payout()
	await _test_save_load_restore()

	if _failures == 0:
		print("[TeacherPetSystemTest] PASS - all checks passed")
	else:
		print("[TeacherPetSystemTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[TeacherPetSystemTest] OK: " + label)
	else:
		push_error("[TeacherPetSystemTest] FAILED: " + label)
		_failures += 1


func _test_activation_odds_floor() -> void:
	_check("tier chance table covers tiers 1-10", GameControllerScript.TEACHER_PET_TIER_CHANCES.size() == 11)
	_check("tier 1 activation chance >= 50%", GameControllerScript.TEACHER_PET_TIER_CHANCES[1] >= 0.5)
	_check("tier 10 activation chance is 100%", GameControllerScript.TEACHER_PET_TIER_CHANCES[10] >= 1.0)
	var ordered := true
	for tier in range(1, 10):
		if GameControllerScript.TEACHER_PET_TIER_CHANCES[tier] > GameControllerScript.TEACHER_PET_TIER_CHANCES[tier + 1]:
			ordered = false
	_check("Teacher's Pet odds stay tier-ordered", ordered)


func _reset_score_modifiers() -> void:
	var smm = get_node_or_null("/root/ScoreModifierManager")
	if smm == null:
		return
	if smm.has_method("has_additive") and smm.has_method("unregister_additive") and smm.has_additive("teacher_pet"):
		smm.unregister_additive("teacher_pet")
	if smm.has_method("has_multiplier") and smm.has_method("unregister_multiplier") and smm.has_multiplier("teacher_pet"):
		smm.unregister_multiplier("teacher_pet")
	if smm.has_method("has_multiplier") and smm.has_method("unregister_multiplier") and smm.has_multiplier("rebellion"):
		smm.unregister_multiplier("rebellion")


func _make_teacher_pet_buff(tier: int):
	var buff = TeacherPetBuffScript.new()
	add_child(buff)
	var stub_gc = GameControllerScript.new()
	buff.set_meta("stub_gc", stub_gc)
	buff.set_intensity(float(tier))
	buff.target = stub_gc
	buff.start()
	return buff


func _dispose_teacher_pet_buff(buff) -> void:
	if not is_instance_valid(buff):
		return
	buff.end()
	var stub_gc = buff.get_meta("stub_gc", null)
	if is_instance_valid(stub_gc):
		stub_gc.free()
	buff.queue_free()


func _test_tier_behavior() -> void:
	var smm = get_node_or_null("/root/ScoreModifierManager")
	_check("ScoreModifierManager autoload available", smm != null)
	if smm == null:
		return

	_reset_score_modifiers()
	var tier_1 = _make_teacher_pet_buff(1)
	_check("tier 1 registers +5 additive", smm.get_total_additive() == 5)
	_check("tier 1 has neutral multiplier", is_equal_approx(smm.get_total_multiplier(), 1.0))
	_check("tier 1 has no round-end bonus", tier_1.get_pending_round_end_bonus() == 0)
	_dispose_teacher_pet_buff(tier_1)

	_reset_score_modifiers()
	var tier_5 = _make_teacher_pet_buff(5)
	_check("tier 5 registers +25 additive", smm.get_total_additive() == 25)
	_check("tier 5 registers x1.5 multiplier", is_equal_approx(smm.get_total_multiplier(), 1.5))
	_check("tier 5 has no round-end bonus", tier_5.get_pending_round_end_bonus() == 0)
	_dispose_teacher_pet_buff(tier_5)

	_reset_score_modifiers()
	var tier_8 = _make_teacher_pet_buff(8)
	_check("tier 8 registers +40 additive", smm.get_total_additive() == 40)
	_check("tier 8 registers x2.25 multiplier", is_equal_approx(smm.get_total_multiplier(), 2.25))
	_check("tier 8 previews $50 round-end bonus", tier_8.get_pending_round_end_bonus() == 50)
	_dispose_teacher_pet_buff(tier_8)

	_reset_score_modifiers()
	var tier_10 = _make_teacher_pet_buff(10)
	_check("tier 10 registers +50 additive", smm.get_total_additive() == 50)
	_check("tier 10 registers x3 multiplier", is_equal_approx(smm.get_total_multiplier(), 3.0))
	_check("tier 10 previews $100 round-end bonus", tier_10.get_pending_round_end_bonus() == 100)
	_check("tier 10 consume returns $100", tier_10.consume_pending_round_end_bonus() == 100)
	_check("tier 10 preview clears after consume", tier_10.get_pending_round_end_bonus() == 0)
	_dispose_teacher_pet_buff(tier_10)
	_reset_score_modifiers()


func _test_live_tier_upgrade() -> void:
	var smm = get_node_or_null("/root/ScoreModifierManager")
	if smm == null:
		return

	_reset_score_modifiers()
	var buff = _make_teacher_pet_buff(1)
	_check("live tier 1 starts with +5 additive", smm.get_total_additive() == 5)
	_check("live tier 1 has no round-end preview", buff.get_pending_round_end_bonus() == 0)
	buff.set_intensity(5.0)
	_check("upgrade to tier 5 raises additive to +25", smm.get_total_additive() == 25)
	_check("upgrade to tier 5 registers x1.5 multiplier", is_equal_approx(smm.get_total_multiplier(), 1.5))
	_check("upgrade to tier 5 still has no round-end preview", buff.get_pending_round_end_bonus() == 0)
	buff.set_intensity(8.0)
	_check("upgrade to tier 8 raises additive to +40", smm.get_total_additive() == 40)
	_check("upgrade to tier 8 raises multiplier to x2.25", is_equal_approx(smm.get_total_multiplier(), 2.25))
	_check("upgrade to tier 8 adds $50 round-end preview", buff.get_pending_round_end_bonus() == 50)
	buff.set_intensity(10.0)
	_check("upgrade to tier 10 raises additive to +50", smm.get_total_additive() == 50)
	_check("upgrade to tier 10 raises multiplier to x3", is_equal_approx(smm.get_total_multiplier(), 3.0))
	_check("upgrade to tier 10 raises round-end preview to $100", buff.get_pending_round_end_bonus() == 100)
	_dispose_teacher_pet_buff(buff)
	_reset_score_modifiers()


func _test_granted_only_exclusion() -> void:
	var manager := DebuffManagerScript.new()
	manager.debuff_defs = [TeacherPetDef, RebellionDef, HalfAdditiveDef]
	add_child(manager)

	_check("teacher_pet def registered", manager.get_def("teacher_pet") != null)
	var eligible := manager.get_debuffs_by_difficulty(5)
	var ids: Array = []
	for def in eligible:
		ids.append(def.id)
	_check("teacher_pet excluded from auto-selection", "teacher_pet" not in ids)
	_check("rebellion excluded from auto-selection", "rebellion" not in ids)
	_check("normal debuffs still eligible", "half_additive" in ids)

	var container := Node.new()
	add_child(container)
	var spawned = manager.spawn_debuff("teacher_pet", container)
	_check("teacher_pet spawns via manager", spawned != null and spawned.get_script() == TeacherPetBuffScript)
	if spawned:
		_check("spawned Teacher's Pet has id", spawned.id == "teacher_pet")

	manager.queue_free()
	container.queue_free()


func _spawn_harness() -> Dictionary:
	var debuff_container := Node.new()
	add_child(debuff_container)
	var chore_ui = CHORE_UI_SCENE.instantiate()
	add_child(chore_ui)
	var manager := DebuffManagerScript.new()
	manager.debuff_defs = [TeacherPetDef, RebellionDef, HalfAdditiveDef]
	add_child(manager)
	var gc = GameControllerScript.new()
	gc.debuff_container = debuff_container
	gc.chore_ui = chore_ui
	gc.debuff_manager = manager
	gc.active_debuffs = {}
	await get_tree().process_frame
	return {
		"game_controller": gc,
		"debuff_container": debuff_container,
		"chore_ui": chore_ui,
		"debuff_manager": manager,
	}


func _cleanup_harness(gc, harness: Dictionary) -> void:
	if is_instance_valid(gc) and gc.has_method("_clear_active_debuffs"):
		gc._clear_active_debuffs()
	_reset_score_modifiers()
	for key in ["debuff_manager", "chore_ui", "debuff_container"]:
		var node = harness.get(key)
		if is_instance_valid(node):
			node.queue_free()
	if is_instance_valid(gc):
		gc.free()
	await get_tree().process_frame


func _test_game_controller_replacement_and_upgrade() -> void:
	var harness = await _spawn_harness()
	var gc = harness.get("game_controller") if not harness.is_empty() else null
	_check("minimal harness exposes GameController", gc != null)
	if not is_instance_valid(gc):
		await _cleanup_harness(gc, harness)
		return

	gc._clear_active_debuffs()
	_reset_score_modifiers()

	gc._grant_rebellion_buff(2)
	_check("grant rebellion activates rebellion", gc.is_debuff_active("rebellion"))
	_check("grant rebellion keeps Teacher's Pet inactive", not gc.is_debuff_active("teacher_pet"))
	_check("rebellion granted at 2 stacks", int(gc.active_debuffs["rebellion"].intensity) == 2)

	gc._grant_teacher_pet_buff(7)
	_check("Teacher's Pet replaces Rebellion", gc.is_debuff_active("teacher_pet") and not gc.is_debuff_active("rebellion"))
	_check("Teacher's Pet tier 7 active", int(gc.active_debuffs["teacher_pet"].intensity) == 7)
	var smm = get_node_or_null("/root/ScoreModifierManager")
	_check("Teacher's Pet tier 7 registers x2 multiplier", smm != null and is_equal_approx(smm.get_total_multiplier(), 2.0))

	gc._grant_rebellion_buff(1)
	_check("Rebellion replaces Teacher's Pet", gc.is_debuff_active("rebellion") and not gc.is_debuff_active("teacher_pet"))
	_check("Rebellion replacement restores x1.15", smm != null and is_equal_approx(smm.get_total_multiplier(), 1.15))

	gc._grant_teacher_pet_buff(4)
	gc._grant_teacher_pet_buff(7)
	gc._grant_teacher_pet_buff(4)
	_check("Teacher's Pet keeps highest granted tier", gc.is_debuff_active("teacher_pet") and int(gc.active_debuffs["teacher_pet"].intensity) == 7)
	_check("Teacher's Pet tier 7 registers +35 additive", smm != null and smm.get_total_additive() == 35)
	_check("Teacher's Pet tier 7 registers x2 multiplier", smm != null and is_equal_approx(smm.get_total_multiplier(), 2.0))

	await _cleanup_harness(gc, harness)


func _test_completed_round_cleanup_preserves_teacher_pet_payout() -> void:
	var harness = await _spawn_harness()
	var gc = harness.get("game_controller") if not harness.is_empty() else null
	_check("cleanup harness exposes GameController", gc != null)
	if not is_instance_valid(gc):
		await _cleanup_harness(gc, harness)
		return

	gc._clear_active_debuffs()
	_reset_score_modifiers()
	gc._grant_teacher_pet_buff(8)
	_check("Teacher's Pet tier 8 preview exists before cleanup", gc._get_round_end_buff_bonus_preview() == 50)

	gc._expire_completed_round_statuses()
	_check("completed-round cleanup keeps Teacher's Pet active", gc.is_debuff_active("teacher_pet"))
	_check("completed-round cleanup preserves Teacher's Pet preview", gc._get_round_end_buff_bonus_preview() == 50)

	gc._clear_grounded_debuffs()
	_check("shop transition clears Teacher's Pet after payout window", not gc.is_debuff_active("teacher_pet"))
	_check("shop transition clears Teacher's Pet preview", gc._get_round_end_buff_bonus_preview() == 0)

	await _cleanup_harness(gc, harness)


func _test_save_load_restore() -> void:
	var harness = await _spawn_harness()
	var gc = harness.get("game_controller") if not harness.is_empty() else null
	_check("save/load harness exposes GameController", gc != null)
	if not is_instance_valid(gc):
		await _cleanup_harness(gc, harness)
		return

	gc._clear_active_debuffs()
	_reset_score_modifiers()
	gc._grant_teacher_pet_buff(5)
	var tier_5_save = gc.get_save_state().get("game_controller", {})
	_check("save state captures Teacher's Pet tier 5", tier_5_save.get("granted_buff_intensities", {}).get("teacher_pet", 0) == 5)
	gc._clear_active_debuffs()
	_reset_score_modifiers()
	gc.apply_debuff("teacher_pet", true)
	gc._restore_mom_granted_buff_intensities(tier_5_save)
	var smm = get_node_or_null("/root/ScoreModifierManager")
	_check("load restores Teacher's Pet active", gc.is_debuff_active("teacher_pet"))
	_check("load restores Teacher's Pet tier 5", gc.is_debuff_active("teacher_pet") and int(gc.active_debuffs["teacher_pet"].intensity) == 5)
	_check("load restores Teacher's Pet additive", smm != null and smm.get_total_additive() == 25)
	_check("load restores Teacher's Pet multiplier", smm != null and is_equal_approx(smm.get_total_multiplier(), 1.5))
	_check("load keeps tier 5 round-end preview at 0", gc._get_round_end_buff_bonus_preview() == 0)

	gc._clear_active_debuffs()
	_reset_score_modifiers()
	gc._grant_teacher_pet_buff(8)
	var tier_8_save = gc.get_save_state().get("game_controller", {})
	_check("save state captures Teacher's Pet tier 8", tier_8_save.get("granted_buff_intensities", {}).get("teacher_pet", 0) == 8)
	gc._clear_active_debuffs()
	_reset_score_modifiers()
	gc.apply_debuff("teacher_pet", true)
	gc._restore_mom_granted_buff_intensities(tier_8_save)
	_check("load restores Teacher's Pet tier 8", gc.is_debuff_active("teacher_pet") and int(gc.active_debuffs["teacher_pet"].intensity) == 8)
	_check("load restores tier 8 round-end preview", gc._get_round_end_buff_bonus_preview() == 50)

	await _cleanup_harness(gc, harness)