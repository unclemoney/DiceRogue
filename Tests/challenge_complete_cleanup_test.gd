extends Control

## challenge_complete_cleanup_test.gd
##
## Verifies that GameController clears round-scoped debuffs immediately when
## a round is completed:
##   1. Automatic round debuffs tracked by DebuffManager are removed.
##   2. Mom-applied grounded debuffs are removed.
##   3. The Rebellion buff chip is removed and its stacks are cached.
##   4. ChallengeUI debuff tags and temporary Mom cosmetic locks are cleared.
##
## Run headless:
##   godot --headless --path . Tests/ChallengeCompleteCleanupTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const GAME_CONTROLLER_SCRIPT := preload("res://Scripts/Core/game_controller.gd")

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


class StubDebuff extends Debuff:
	var removed: bool = false

	func apply(_target) -> void:
		pass

	func remove() -> void:
		removed = true


class StubDebuffManager extends DebuffManager:
	var test_active_ids: Array[String] = []

	func get_active_debuff_ids() -> Array[String]:
		var ids: Array[String] = []
		ids.assign(test_active_ids)
		return ids

	func clear_active_debuffs() -> void:
		test_active_ids.clear()


class StubDebuffUI extends DebuffUI:
	var animated_ids: Array[String] = []
	var removed_ids: Array[String] = []

	func animate_debuff_removal(debuff_id: String, on_finished: Callable) -> void:
		animated_ids.append(debuff_id)
		on_finished.call()

	func remove_debuff(id: String) -> void:
		removed_ids.append(id)


class StubChallengeUI extends ChallengeUI:
	var store_debuff_updates: Array[Array] = []

	func set_store_debuffs(debuff_ids: Array) -> void:
		var ids: Array[String] = []
		ids.assign(debuff_ids)
		store_debuff_updates.append(ids)


class StubChoreUI extends Node:
	var removed_buff_ids: Array[String] = []

	func remove_buff_icon(id: String) -> void:
		removed_buff_ids.append(id)


func _ready() -> void:
	print("\n=== CHALLENGE COMPLETE CLEANUP TEST ===")
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


func _run_tests() -> void:
	var gc = GAME_CONTROLLER_SCRIPT.new()
	var debuff_manager := StubDebuffManager.new()
	var debuff_ui := StubDebuffUI.new()
	var challenge_ui := StubChallengeUI.new()
	var chore_ui := StubChoreUI.new()

	gc.debuff_manager = debuff_manager
	gc.debuff_ui = debuff_ui
	gc.challenge_ui = challenge_ui
	gc.chore_ui = chore_ui

	var auto_debuff := StubDebuff.new()
	auto_debuff.id = "window_shopping"
	var auto_grounding := StubDebuff.new()
	auto_grounding.id = "docked_allowance"
	var grounded_debuff := StubDebuff.new()
	grounded_debuff.id = "lock_dice"
	var rebellion := StubDebuff.new()
	rebellion.id = "rebellion"
	rebellion.intensity = 3.0

	gc.active_debuffs = {
		"window_shopping": auto_debuff,
		"docked_allowance": auto_grounding,
		"lock_dice": grounded_debuff,
		"rebellion": rebellion,
	}
	gc._grounded_debuffs = ["lock_dice"]
	gc._mom_cosmetics_locked = true
	debuff_manager.test_active_ids = ["window_shopping", "docked_allowance"]

	var original_colors_enabled := DiceColorManager.are_colors_enabled()
	DiceColorManager.set_colors_enabled(false)

	gc._expire_completed_round_statuses()

	_check(not gc.is_debuff_active("window_shopping"), "automatic debuff removed from runtime state")
	_check(not gc.is_debuff_active("docked_allowance"), "automatic grounding removed from runtime state")
	_check(not gc.is_debuff_active("lock_dice"), "grounded Mom debuff removed from runtime state")
	_check(not gc.is_debuff_active("rebellion"), "rebellion buff removed from runtime state")
	_check(auto_debuff.removed, "automatic debuff end() called remove()")
	_check(auto_grounding.removed, "automatic grounding end() called remove()")
	_check(grounded_debuff.removed, "grounded debuff end() called remove()")
	_check(rebellion.removed, "rebellion end() called remove()")
	_check(debuff_manager.test_active_ids.is_empty(), "DebuffManager active ids cleared")
	_check(debuff_ui.animated_ids.has("window_shopping") and debuff_ui.animated_ids.has("docked_allowance") and debuff_ui.animated_ids.has("lock_dice"),
		"DebuffUI animated regular and grounded debuff removals")
	_check(debuff_ui.removed_ids.has("window_shopping") and debuff_ui.removed_ids.has("docked_allowance") and debuff_ui.removed_ids.has("lock_dice"),
		"DebuffUI removed regular and grounded debuff icons")
	_check(chore_ui.removed_buff_ids == ["rebellion"], "ChoreUI removed the Rebellion buff chip")
	_check(gc._grounded_debuffs.is_empty(), "grounded debuff registry cleared")
	_check(gc.get_last_completed_round_rebellion_stacks() == 3, "rebellion stacks cached before cleanup")
	_check(not gc._mom_cosmetics_locked, "temporary Mom cosmetic lock cleared")
	_check(DiceColorManager.are_colors_enabled(), "dice colors restored after Mom cosmetic lock")
	_check(not challenge_ui.store_debuff_updates.is_empty() and challenge_ui.store_debuff_updates.back().is_empty(),
		"ChallengeUI debuff tags cleared for the between-round state")

	DiceColorManager.set_colors_enabled(original_colors_enabled)


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[ChallengeCompleteCleanupTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(_failures)