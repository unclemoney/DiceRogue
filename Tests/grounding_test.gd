extends Control

## grounding_test.gd
##
## Verifies the grounding system: pool separation from debuffs, grounding
## helper selection, the debuff draw-once and boss helpers used by round
## debuff selection, and the three grounding behaviors (Docked Allowance,
## Coupons Revoked, POGS Confiscated).

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


## StubGameController
##
## Minimal stand-in exposing what the groundings touch on GameController.
class StubGameController extends Node:
	var docked_allowance_active: bool = false
	var active_power_ups: Dictionary = {}
	var cleared_consumables_count: int = 0
	var revoked_power_ups: Array[String] = []

	func _clear_all_consumables() -> void:
		cleared_consumables_count += 1

	func revoke_power_up(power_up_id: String) -> void:
		revoked_power_ups.append(power_up_id)
		active_power_ups.erase(power_up_id)


func _ready() -> void:
	print("\n=== GROUNDING TEST ===")
	await get_tree().process_frame
	_run_tests()
	_finish()


func _check(condition: bool, label: String) -> void:
	var status := "PASS" if condition else "FAIL"
	if not condition:
		_failures += 1
	var line := "%s: %s" % [status, label]
	print(line)
	_lines.append(line)


func _make_manager() -> DebuffManager:
	var manager := DebuffManager.new()
	var defs: Array[DebuffData] = [
		load("res://Scripts/Debuff/DockedAllowanceDebuff.tres"),
		load("res://Scripts/Debuff/CouponsRevokedDebuff.tres"),
		load("res://Scripts/Debuff/PogsConfiscatedDebuff.tres"),
		load("res://Scripts/Debuff/WindowShoppingDebuff.tres"),
		load("res://Scripts/Debuff/TooGreedyDebuff.tres"),
		load("res://Scripts/Debuff/FasterChoresDebuff.tres"),
		load("res://Scripts/Debuff/RebellionBuff.tres"),
	]
	manager.debuff_defs = defs
	add_child(manager)
	return manager


func _run_tests() -> void:
	# 1. Resource flags
	var docked: DebuffData = load("res://Scripts/Debuff/DockedAllowanceDebuff.tres")
	var coupons: DebuffData = load("res://Scripts/Debuff/CouponsRevokedDebuff.tres")
	var pogs: DebuffData = load("res://Scripts/Debuff/PogsConfiscatedDebuff.tres")
	var window: DebuffData = load("res://Scripts/Debuff/WindowShoppingDebuff.tres")
	_check(docked and docked.is_grounding, "Docked Allowance flagged is_grounding")
	_check(coupons and coupons.is_grounding, "Coupons Revoked flagged is_grounding")
	_check(pogs and pogs.is_grounding, "POGS Confiscated flagged is_grounding")
	_check(window and not window.is_grounding, "Window Shopping is NOT a grounding")

	# 2. Pool separation
	var manager := _make_manager()
	var groundings := manager.get_groundings()
	_check(groundings.size() == 3, "get_groundings() returns 3 groundings")
	var debuff_pool := manager.get_debuffs_by_difficulty(5)
	var debuff_ids: Array[String] = []
	for def in debuff_pool:
		debuff_ids.append(def.id)
	_check("docked_allowance" not in debuff_ids, "groundings excluded from debuff pool (docked)")
	_check("coupons_revoked" not in debuff_ids, "groundings excluded from debuff pool (coupons)")
	_check("pogs_confiscated" not in debuff_ids, "groundings excluded from debuff pool (pogs)")
	_check("rebellion" not in debuff_ids, "rebellion still excluded from debuff pool")
	_check("window_shopping" in debuff_ids, "window_shopping present in debuff pool")
	_check("too_greedy" in debuff_ids, "too_greedy present in debuff pool")

	# 3. Grounding helper selection
	var g1 := manager.select_grounding_for_round()
	_check(g1 in ["docked_allowance", "coupons_revoked", "pogs_confiscated"], "select_grounding_for_round returns a grounding")
	var g2 := manager.select_grounding_for_round(["docked_allowance", "coupons_revoked"])
	_check(g2 == "pogs_confiscated", "exclusion list respected (only pogs left)")
	var g3 := manager.select_grounding_for_round(["docked_allowance", "coupons_revoked", "pogs_confiscated"])
	_check(g3 == "", "returns empty when all groundings excluded")

	# 4. Per-zone draw-once pool (level cap 1 -> window_shopping + faster_chores only)
	var draw1 := manager.select_debuffs_for_round(1, 1)
	_check(draw1.size() == 1, "first draw returns 1 debuff")
	var draw2 := manager.select_debuffs_for_round(1, 1)
	_check(draw2.size() == 1 and draw2[0] != draw1[0], "second draw does not repeat (draw-once)")
	var draw3 := manager.select_debuffs_for_round(1, 1)
	_check(draw3.is_empty(), "pool exhausted after both L1 debuffs drawn")
	manager.reset_zone_pool()
	var draw4 := manager.select_debuffs_for_round(1, 1)
	_check(draw4.size() == 1, "pool refills after reset_zone_pool()")

	# 5. Boss exact-level draw
	manager.reset_zone_pool()
	var boss := manager.select_boss_debuff(5)
	_check(boss == "too_greedy", "boss draw at level 5 returns too_greedy (only L5 in pool)")
	var boss2 := manager.select_boss_debuff(5)
	_check(boss2 == "", "boss draw-once: second L5 draw empty")
	var boss4 := manager.select_boss_debuff(4)
	_check(boss4 == "", "boss draw at level 4 empty (no L4 in test pool)")

	# 6. Docked Allowance flag behavior
	var stub := StubGameController.new()
	stub.name = "StubGameController"
	stub.add_to_group("game_controller")
	add_child(stub)

	var docked_inst = docked.scene.instantiate()
	add_child(docked_inst)
	docked_inst.apply(stub)
	_check(stub.docked_allowance_active, "Docked Allowance sets docked_allowance_active")
	docked_inst.remove()
	_check(not stub.docked_allowance_active, "Docked Allowance remove() clears the flag")
	docked_inst.queue_free()

	# 7. Coupons Revoked clears held coupons
	var coupons_inst = coupons.scene.instantiate()
	add_child(coupons_inst)
	coupons_inst.apply(stub)
	_check(stub.cleared_consumables_count == 1, "Coupons Revoked calls _clear_all_consumables once")
	coupons_inst.queue_free()

	# 8. POGS Confiscated revokes POGs scaled by REP tier (count read-only vs live REP)
	stub.active_power_ups = {"pu_a": Node.new(), "pu_b": Node.new(), "pu_c": Node.new()}
	var pogs_inst = pogs.scene.instantiate()
	add_child(pogs_inst)
	var expected_count: int = mini(pogs_inst.get_confiscation_count(), 3)
	_check(expected_count >= 1 and expected_count <= 3, "confiscation count within 1-3 for current REP tier")
	pogs_inst.apply(stub)
	_check(stub.revoked_power_ups.size() == expected_count, "confiscated count matches REP-tier count")
	_check(stub.active_power_ups.size() == 3 - expected_count, "confiscated POGs removed from active_power_ups")
	pogs_inst.queue_free()

	stub.remove_from_group("game_controller")
	stub.queue_free()
	manager.queue_free()

	# 9. End-of-round panel: docked allowance zeroes the total
	var panel_scene: PackedScene = load("res://Scenes/UI/EndOfRoundStatsPanel.tscn")
	_check(panel_scene != null, "EndOfRoundStatsPanel.tscn loads")
	if panel_scene:
		var panel = panel_scene.instantiate()
		add_child(panel)
		panel.show_stats({"challenge_reward": 100, "docked_allowance": false})
		_check(panel.get_total_bonus() == 100, "panel total is 100 without grounding")
		panel.show_stats({"challenge_reward": 100, "docked_allowance": true})
		_check(panel.get_total_bonus() == 0, "panel total is 0 when allowance docked")
		_check(panel.total_text_label.text == "ALLOWANCE DOCKED:", "panel shows ALLOWANCE DOCKED label")
		panel.queue_free()


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[GroundingTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(_failures)
