extends Node

## teacher_pet_system_test.gd
##
## Exercises the Teacher's Pet systems:
##   1. Tier 1/2/3 behavior and modifier registration.
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

	_test_tier_behavior()
	_test_live_tier_upgrade()
	_test_granted_only_exclusion()
	await _test_game_controller_replacement_and_upgrade()
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
	_check("tier 1 has no additive", smm.get_total_additive() == 0)
	_check("tier 1 has neutral multiplier", is_equal_approx(smm.get_total_multiplier(), 1.0))
	_check("tier 1 previews $100 round-end bonus", tier_1.get_pending_round_end_bonus() == 100)
	_check("tier 1 consume returns $100", tier_1.consume_pending_round_end_bonus() == 100)
	_check("tier 1 preview clears after consume", tier_1.get_pending_round_end_bonus() == 0)
	_dispose_teacher_pet_buff(tier_1)

	_reset_score_modifiers()
	var tier_2 = _make_teacher_pet_buff(2)
	_check("tier 2 registers +25 additive", smm.get_total_additive() == 25)
	_check("tier 2 keeps neutral multiplier", is_equal_approx(smm.get_total_multiplier(), 1.0))
	_check("tier 2 has no round-end bonus", tier_2.get_pending_round_end_bonus() == 0)
	_dispose_teacher_pet_buff(tier_2)

	_reset_score_modifiers()
	var tier_3 = _make_teacher_pet_buff(3)
	_check("tier 3 has no additive", smm.get_total_additive() == 0)
	_check("tier 3 registers x2 multiplier", is_equal_approx(smm.get_total_multiplier(), 2.0))
	_dispose_teacher_pet_buff(tier_3)
	_reset_score_modifiers()


func _test_live_tier_upgrade() -> void:
	var smm = get_node_or_null("/root/ScoreModifierManager")
	if smm == null:
		return

	_reset_score_modifiers()
	var buff = _make_teacher_pet_buff(1)
	_check("live tier 1 starts with round-end preview", buff.get_pending_round_end_bonus() == 100)
	buff.set_intensity(2.0)
	_check("upgrade to tier 2 removes round-end preview", buff.get_pending_round_end_bonus() == 0)
	_check("upgrade to tier 2 registers additive", smm.get_total_additive() == 25)
	buff.set_intensity(3.0)
	_check("upgrade to tier 3 clears additive", smm.get_total_additive() == 0)
	_check("upgrade to tier 3 registers multiplier", is_equal_approx(smm.get_total_multiplier(), 2.0))
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

	gc._grant_teacher_pet_buff(3)
	_check("Teacher's Pet replaces Rebellion", gc.is_debuff_active("teacher_pet") and not gc.is_debuff_active("rebellion"))
	_check("Teacher's Pet tier 3 active", int(gc.active_debuffs["teacher_pet"].intensity) == 3)
	var smm = get_node_or_null("/root/ScoreModifierManager")
	_check("Teacher's Pet tier 3 registers x2 multiplier", smm != null and is_equal_approx(smm.get_total_multiplier(), 2.0))

	gc._grant_rebellion_buff(1)
	_check("Rebellion replaces Teacher's Pet", gc.is_debuff_active("rebellion") and not gc.is_debuff_active("teacher_pet"))
	_check("Rebellion replacement restores x1.15", smm != null and is_equal_approx(smm.get_total_multiplier(), 1.15))

	gc._grant_teacher_pet_buff(1)
	gc._grant_teacher_pet_buff(2)
	gc._grant_teacher_pet_buff(1)
	_check("Teacher's Pet keeps highest granted tier", gc.is_debuff_active("teacher_pet") and int(gc.active_debuffs["teacher_pet"].intensity) == 2)
	_check("Teacher's Pet tier 2 registers +25 additive", smm != null and smm.get_total_additive() == 25)
	_check("Teacher's Pet tier 2 keeps multiplier neutral", smm != null and is_equal_approx(smm.get_total_multiplier(), 1.0))

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
	gc._grant_teacher_pet_buff(2)
	var tier_2_save = gc.get_save_state().get("game_controller", {})
	_check("save state captures Teacher's Pet tier 2", tier_2_save.get("granted_buff_intensities", {}).get("teacher_pet", 0) == 2)
	gc._clear_active_debuffs()
	_reset_score_modifiers()
	gc.apply_debuff("teacher_pet", true)
	gc._restore_mom_granted_buff_intensities(tier_2_save)
	var smm = get_node_or_null("/root/ScoreModifierManager")
	_check("load restores Teacher's Pet active", gc.is_debuff_active("teacher_pet"))
	_check("load restores Teacher's Pet tier 2", gc.is_debuff_active("teacher_pet") and int(gc.active_debuffs["teacher_pet"].intensity) == 2)
	_check("load restores Teacher's Pet additive", smm != null and smm.get_total_additive() == 25)
	_check("load keeps tier 2 round-end preview at 0", gc._get_round_end_buff_bonus_preview() == 0)

	gc._clear_active_debuffs()
	_reset_score_modifiers()
	gc._grant_teacher_pet_buff(1)
	var tier_1_save = gc.get_save_state().get("game_controller", {})
	_check("save state captures Teacher's Pet tier 1", tier_1_save.get("granted_buff_intensities", {}).get("teacher_pet", 0) == 1)
	gc._clear_active_debuffs()
	_reset_score_modifiers()
	gc.apply_debuff("teacher_pet", true)
	gc._restore_mom_granted_buff_intensities(tier_1_save)
	_check("load restores Teacher's Pet tier 1", gc.is_debuff_active("teacher_pet") and int(gc.active_debuffs["teacher_pet"].intensity) == 1)
	_check("load restores tier 1 round-end preview", gc._get_round_end_buff_bonus_preview() == 100)

	await _cleanup_harness(gc, harness)