extends Control

## DiceSetSelectionTest
##
## Test scene to verify the Mall Zone dice set selection feature:
## - DiceData resources carry description + unlock_item_id metadata
## - Carousel default is d6; locked sets don't commit; unlocked sets do
## - ChannelManager.set_selected_dice_type guards locked sets
## - RoundManager.run_dice_type overrides per-round dice_type
## - d4 "Fours+" scoring rule in Scorecard and ScoreEvaluator
## - d8/d12/d20 dynamic sixth slot still works
##
## Restores ProgressManager dice-set unlock state when finished.

const ChannelManagerScript = preload("res://Scripts/Managers/channel_manager.gd")
const RoundManagerScript = preload("res://Scripts/Managers/round_manager.gd")
const ScorecardScript = preload("res://Scenes/ScoreCard/score_card.gd")

const DICE_SET_ITEM_IDS := ["dice_set_d4", "dice_set_d8", "dice_set_d12", "dice_set_d20"]

var channel_manager: Node
var channel_manager_ui: Control
var output_label: RichTextLabel
var test_results: Array[String] = []
var _saved_unlock_state: Dictionary = {}


func _ready() -> void:
	print("[DiceSetSelectionTest] Starting tests...")
	_build_test_ui()
	_snapshot_unlock_state()
	_create_managers()
	_run_tests()
	_restore_unlock_state()


func _build_test_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 20)
	add_child(vbox)

	var title = Label.new()
	title.text = "Dice Set Selection Test Suite"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	output_label = RichTextLabel.new()
	output_label.bbcode_enabled = true
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.add_theme_font_size_override("normal_font_size", 16)
	vbox.add_child(output_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)

	var btn_show_selector = Button.new()
	btn_show_selector.text = "Show Selector (manual)"
	btn_show_selector.pressed.connect(func(): channel_manager_ui.show_channel_selector())
	btn_hbox.add_child(btn_show_selector)

	var btn_run_tests = Button.new()
	btn_run_tests.text = "Run All Tests"
	btn_run_tests.pressed.connect(_on_rerun_tests)
	btn_hbox.add_child(btn_run_tests)


func _create_managers() -> void:
	channel_manager = ChannelManagerScript.new()
	channel_manager.name = "ChannelManager"
	add_child(channel_manager)

	var ui_scene = preload("res://Scenes/Managers/ChannelManagerUI.tscn")
	channel_manager_ui = ui_scene.instantiate()
	add_child(channel_manager_ui)
	channel_manager_ui.set_channel_manager(channel_manager)


func _snapshot_unlock_state() -> void:
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		return
	for item_id in DICE_SET_ITEM_IDS:
		_saved_unlock_state[item_id] = progress_manager.is_item_unlocked(item_id)


func _restore_unlock_state() -> void:
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		return
	for item_id in DICE_SET_ITEM_IDS:
		if not _saved_unlock_state.has(item_id):
			continue
		if _saved_unlock_state[item_id]:
			progress_manager.debug_unlock_item(item_id)
		else:
			progress_manager.debug_lock_item(item_id)
	print("[DiceSetSelectionTest] Restored dice-set unlock state")


func _on_rerun_tests() -> void:
	test_results.clear()
	output_label.text = ""
	_snapshot_unlock_state()
	_run_tests()
	_restore_unlock_state()


func _log_result(passed: bool, message: String) -> void:
	var line := ("[color=green]PASS[/color] " if passed else "[color=red]FAIL[/color] ") + message
	test_results.append(line)
	output_label.text = "\n".join(test_results)
	print("[DiceSetSelectionTest] " + ("PASS " if passed else "FAIL ") + message)


func _run_tests() -> void:
	_test_dice_data_metadata()
	_test_carousel_default()
	_test_locked_set_does_not_commit()
	_test_unlocked_set_commits()
	_test_carousel_wraps()
	_test_manager_guards_locked_set()
	_test_run_dice_type_overrides_rounds()
	_test_fours_plus_scoring()
	_test_dynamic_sixth_slot()


func _test_dice_data_metadata() -> void:
	var d4: DiceData = load("res://Scripts/Dice/d4_dice.tres")
	_log_result(d4 != null and d4.sides == 4, "d4_dice.tres loads with 4 sides")
	_log_result(not d4.description.is_empty(), "d4 description present: \"%s\"" % d4.description)
	_log_result(d4.unlock_item_id == "dice_set_d4", "d4 unlock_item_id is dice_set_d4")
	var d6: DiceData = load("res://Scripts/Dice/d6_dice.tres")
	_log_result(d6.unlock_item_id.is_empty(), "d6 has no unlock item (always available)")
	for path in ["d8", "d12", "d20"]:
		var data: DiceData = load("res://Scripts/Dice/%s_dice.tres" % path)
		var ok: bool = data != null and data.textures.size() == data.sides
		_log_result(ok, "%s_dice.tres loads with %d face textures" % [path, data.sides if data else -1])


func _test_carousel_default() -> void:
	channel_manager.reset()
	channel_manager_ui.show_channel_selector()
	_log_result(channel_manager.selected_dice_type == "d6", "Default selected dice set is d6")
	var data: DiceData = channel_manager_ui.DICE_SETS[channel_manager_ui._dice_set_index]
	_log_result(data.id == "d6", "Carousel rests on d6 after show_channel_selector")
	channel_manager_ui.hide_channel_selector()


func _test_locked_set_does_not_commit() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	progress_manager.debug_lock_item("dice_set_d4")
	channel_manager.reset()
	channel_manager_ui._sync_dice_set_from_manager()
	# Cycle from d6 (index 1) back to d4 (index 0)
	channel_manager_ui._cycle_dice_set(-1)
	var browsed: DiceData = channel_manager_ui.DICE_SETS[channel_manager_ui._dice_set_index]
	_log_result(browsed.id == "d4", "Carousel browses to locked d4")
	_log_result(channel_manager.selected_dice_type == "d6", "Locked d4 does not commit selection")
	_log_result(channel_manager_ui._dice_lock_label.visible, "Lock indicator shown for locked d4")
	_log_result(channel_manager_ui.start_button.disabled, "START disabled while browsing locked d4")


func _test_unlocked_set_commits() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	progress_manager.debug_unlock_item("dice_set_d4")
	channel_manager.reset()
	channel_manager_ui._sync_dice_set_from_manager()
	channel_manager_ui._cycle_dice_set(-1)  # d6 -> d4
	_log_result(channel_manager.selected_dice_type == "d4", "Unlocked d4 commits selection")
	_log_result(not channel_manager_ui._dice_lock_label.visible, "Lock indicator hidden for unlocked d4")
	_log_result(not channel_manager_ui.start_button.disabled, "START enabled for unlocked d4")
	channel_manager_ui._cycle_dice_set(1)  # back to d6
	_log_result(channel_manager.selected_dice_type == "d6", "Cycling back to d6 commits d6")


func _test_carousel_wraps() -> void:
	channel_manager_ui._dice_set_index = 0
	channel_manager_ui._cycle_dice_set(-1)
	var data: DiceData = channel_manager_ui.DICE_SETS[channel_manager_ui._dice_set_index]
	_log_result(data.id == "d20", "Carousel wraps backward from d4 to d20")
	channel_manager_ui._cycle_dice_set(1)
	data = channel_manager_ui.DICE_SETS[channel_manager_ui._dice_set_index]
	_log_result(data.id == "d4", "Carousel wraps forward from d20 to d4")


func _test_manager_guards_locked_set() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	progress_manager.debug_lock_item("dice_set_d20")
	channel_manager.reset()
	channel_manager.set_selected_dice_type("d20")
	_log_result(channel_manager.selected_dice_type == "d6", "ChannelManager rejects locked d20")
	progress_manager.debug_unlock_item("dice_set_d20")
	channel_manager.set_selected_dice_type("d20")
	_log_result(channel_manager.selected_dice_type == "d20", "ChannelManager accepts unlocked d20")
	channel_manager.reset()
	_log_result(channel_manager.selected_dice_type == "d6", "reset() restores d6")


func _test_run_dice_type_overrides_rounds() -> void:
	var round_manager = RoundManagerScript.new()
	round_manager.set_run_dice_type("d12")
	round_manager._initialize_rounds_data()
	var all_match: bool = round_manager.rounds_data.size() > 0
	for round_data in round_manager.rounds_data:
		if round_data.dice_type != "d12":
			all_match = false
	_log_result(all_match, "run_dice_type overrides every round's dice_type (%d rounds)" % round_manager.rounds_data.size())
	round_manager.free()


func _test_fours_plus_scoring() -> void:
	ScoreEvaluatorSingleton.set_dice_sides(4)
	var results: Dictionary = ScoreEvaluatorSingleton.evaluate_normal([4, 4, 4, 2, 1])
	_log_result(results["sixes"] == 24, "Fours+ scores 3x4x2=24 (got %d)" % results["sixes"])
	_log_result(results["fours"] == 12, "Fours row unaffected (got %d)" % results["fours"])
	ScoreEvaluatorSingleton.set_dice_sides(6)
	var d6_results: Dictionary = ScoreEvaluatorSingleton.evaluate_normal([6, 6, 6, 2, 1])
	_log_result(d6_results["sixes"] == 18, "d6 Sixes unchanged (got %d)" % d6_results["sixes"])


func _test_dynamic_sixth_slot() -> void:
	var scorecard = ScorecardScript.new()
	scorecard.set_dice_type(4)
	_log_result(scorecard.get_sixth_slot_display_name() == "Fours+", "d4 sixth slot named Fours+")
	_log_result(scorecard.sixth_slot_multiplier == 2, "d4 sixth slot multiplier is 2")
	_log_result(scorecard.calculate_upper_bonus_base_threshold() == 30, "d4 upper bonus threshold is 30")
	scorecard.set_dice_type(8)
	_log_result(scorecard.get_sixth_slot_display_name() == "Eights", "d8 sixth slot named Eights")
	scorecard.set_dice_type(12)
	_log_result(scorecard.get_sixth_slot_display_name() == "Twelves", "d12 sixth slot named Twelves")
	scorecard.set_dice_type(20)
	_log_result(scorecard.get_sixth_slot_display_name() == "Twenties", "d20 sixth slot named Twenties")
	_log_result(scorecard.calculate_upper_bonus_base_threshold() == 105, "d20 upper bonus threshold is 105")
	scorecard.set_dice_type(6)
	_log_result(scorecard.get_sixth_slot_display_name() == "Sixes", "d6 sixth slot named Sixes")
	# Save/load round-trip preserves the multiplier
	scorecard.set_dice_type(4)
	var state: Dictionary = scorecard.get_state()
	scorecard.set_dice_type(6)
	scorecard.load_state(state)
	_log_result(scorecard.sixth_slot_multiplier == 2, "sixth_slot_multiplier survives save/load")
	scorecard.free()
