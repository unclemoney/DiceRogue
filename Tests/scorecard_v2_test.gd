extends Control

## ScorecardV2Test
## Phase 2 test scene for the flat row-list scorecard UI (Scenes/UI/Scorecard/).
## Manual bind, mirroring the ScorecardUpgradeJuiceTest pattern.

@onready var score_card: Scorecard = $ScoreCard
@onready var score_card_ui: ScoreCardUI = $ScoreCardUI
@onready var test_output: RichTextLabel = $VBoxContainer/TestOutput


func _ready() -> void:
	score_card_ui.bind_scorecard(score_card)
	score_card_ui.hand_scored.connect(_on_hand_scored)
	add_log("ScorecardV2 Phase 2 test ready")
	add_log("Roll fake dice, then score / upgrade / reset via the buttons")
	if "--auto-test" in OS.get_cmdline_user_args():
		_run_auto_checks.call_deferred()


var _fail_count := 0


## _run_auto_checks()
##
## Headless self-test (`-- --auto-test`): ghosts, scoring lock, double mode.
## Quits with exit code 0 on pass, 1 on fail.
func _run_auto_checks() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("=== ScorecardV2 auto checks ===")

	# 1. Ghost previews after a fake roll of [3, 3, 3, 5, 6]
	_on_roll_fake_dice_pressed()
	var threes_row: ScorecardRow = score_card_ui.rows[&"threes"]
	_auto_assert(threes_row._has_ghost, "threes row shows ghost after roll")
	_auto_assert(threes_row.score_label.text == "9", "threes ghost is 9 (got '%s')" % threes_row.score_label.text)
	var toak_row: ScorecardRow = score_card_ui.rows[&"three_of_a_kind"]
	_auto_assert(toak_row._has_ghost, "three_of_a_kind row shows ghost after roll")
	_auto_assert(toak_row.score_label.text == "20", "three_of_a_kind ghost is 20 (got '%s')" % toak_row.score_label.text)
	var ones_row: ScorecardRow = score_card_ui.rows[&"ones"]
	_auto_assert(not ones_row._has_ghost, "ones row shows no ghost (no 1s rolled)")

	# 2. Score three_of_a_kind -> SCORED state, ghosts cleared, turn locked
	score_card_ui.on_category_selected(Scorecard.Section.LOWER, "three_of_a_kind")
	_auto_assert(score_card_ui.turn_scored, "turn_scored after scoring")
	_auto_assert(toak_row.state == ScorecardRow.State.SCORED, "three_of_a_kind row is SCORED")
	_auto_assert(toak_row.disabled, "scored row is disabled")
	_auto_assert(not threes_row._has_ghost, "ghosts cleared once turn is scored")
	var scored_value = score_card.lower_scores["three_of_a_kind"]
	_auto_assert(scored_value != null and int(scored_value) > 0, "three_of_a_kind has a positive score (got %s)" % str(scored_value))

	# 3. Double mode: scored rows re-enable, score doubles, mode clears
	score_card_ui.activate_score_double()
	_auto_assert(score_card_ui.is_double_mode, "double mode active")
	_auto_assert(not toak_row.disabled, "scored row re-enabled in double mode")
	score_card_ui.on_category_selected(Scorecard.Section.LOWER, "three_of_a_kind")
	var doubled = score_card.lower_scores["three_of_a_kind"]
	_auto_assert(int(doubled) == int(scored_value) * 2, "score doubled to %d (got %s)" % [int(scored_value) * 2, str(doubled)])
	_auto_assert(not score_card_ui.is_double_mode, "double mode cleared after use")

	# 4. Reset restores AVAILABLE rows
	_on_reset_pressed()
	_auto_assert(toak_row.state == ScorecardRow.State.AVAILABLE, "row back to AVAILABLE after reset")
	_auto_assert(not score_card_ui.turn_scored, "turn_scored cleared after reset")

	# 5. Power-up highlight facade
	var highlight_ok: bool = score_card_ui.set_power_up_highlight(Scorecard.Section.LOWER, "yahtzee")
	_auto_assert(highlight_ok, "set_power_up_highlight returns true for yahtzee")
	var yahtzee_row: ScorecardRow = score_card_ui.rows[&"yahtzee"]
	_auto_assert(yahtzee_row.highlight_active, "yahtzee row highlight_active set")
	await get_tree().create_timer(0.4).timeout
	_auto_assert(yahtzee_row._highlight_pulse.visible, "pulse visible after fade-in")
	var strength: float = yahtzee_row._highlight_material.get_shader_parameter("effect_strength")
	_auto_assert(strength == 1.0, "effect_strength settled at 1.0 (got %s)" % strength)
	score_card_ui.clear_power_up_highlight()
	_auto_assert(not yahtzee_row.highlight_active, "highlight_active cleared")
	await get_tree().create_timer(0.4).timeout
	_auto_assert(not yahtzee_row._highlight_pulse.visible, "pulse hidden after fade-out")
	var bad: bool = score_card_ui.set_power_up_highlight(Scorecard.Section.UPPER, "bogus_category")
	_auto_assert(not bad, "set_power_up_highlight returns false for bogus category")

	# 6. Highlight is force-cleared when the row becomes SCORED
	score_card_ui.set_power_up_highlight(Scorecard.Section.LOWER, "yahtzee")
	yahtzee_row.set_state_scored()
	_auto_assert(not yahtzee_row.highlight_active, "highlight force-cleared on SCORED")
	yahtzee_row.reset_to_available()
	score_card_ui.clear_power_up_highlight()

	# 6b. Chip fill ramp: Lv.1 grey vs Lv.20 gold, per-instance stylebox
	var ones_chip: LevelChip = score_card_ui.rows[&"ones"].level_chip
	ones_chip.set_level(1)
	var chip_stylebox: StyleBoxFlat = ones_chip.get_theme_stylebox("panel")
	var color_lv1 := chip_stylebox.bg_color
	ones_chip.set_level(20)
	var color_lv20 := chip_stylebox.bg_color
	_auto_assert(color_lv1 != color_lv20, "chip fill differs between Lv.1 and Lv.20")
	ones_chip.set_level(1)
	var twos_chip: LevelChip = score_card_ui.rows[&"twos"].level_chip
	_auto_assert(chip_stylebox != twos_chip.get_theme_stylebox("panel"), "chip styleboxes are per-instance")

	# 6c. Score label position stability: ghost -> hover -> scored (same row)
	_on_roll_fake_dice_pressed()
	var pos_ghost := threes_row.score_label.position.x
	threes_row._on_mouse_entered()
	var pos_hover := threes_row.score_label.position.x
	threes_row._on_mouse_exited()
	score_card_ui.on_category_selected(Scorecard.Section.UPPER, "threes")
	await get_tree().process_frame
	var pos_scored := threes_row.score_label.position.x
	_auto_assert(pos_ghost == pos_hover and pos_hover == pos_scored, "score label x stable across ghost/hover/scored (%.1f/%.1f/%.1f)" % [pos_ghost, pos_hover, pos_scored])
	_on_reset_pressed()

	# 6d. Score dance scales with score
	threes_row.set_score(12)
	threes_row.play_score_lock()
	var low_intensity: float = threes_row.last_lock_intensity
	threes_row.set_score(960)
	threes_row.play_score_lock()
	var high_intensity: float = threes_row.last_lock_intensity
	_auto_assert(high_intensity > low_intensity, "dance intensity scales with score (%.2f vs %.2f)" % [low_intensity, high_intensity])
	await get_tree().create_timer(0.6).timeout
	_auto_assert(threes_row.score_label.rotation_degrees == 0.0, "score label rotation settles at 0")
	threes_row.reset_to_available()

	# 6e. Best-hand pulse: exactly one row, and it persists through hover
	_on_roll_fake_dice_pressed()
	var pulse_count := 0
	var best_key := ""
	for rkey in score_card_ui.rows.keys():
		var r: ScorecardRow = score_card_ui.rows[rkey]
		if r._is_best:
			pulse_count += 1
			best_key = String(rkey)
	_auto_assert(pulse_count == 1, "exactly one row carries the best pulse (got %d)" % pulse_count)
	_auto_assert(best_key == "three_of_a_kind", "best row is three_of_a_kind at 20 (got %s)" % best_key)
	toak_row._on_mouse_entered()
	_auto_assert(toak_row._best_tween != null and toak_row._best_tween.is_valid(), "best pulse persists through hover")
	toak_row._on_mouse_exited()
	_on_reset_pressed()

	# 6f. Pre-layout score leaves no transform residue (regression: the hop
	# tween once captured a stale position before the first container sort)
	var fresh_ui: ScoreCardUI = preload("res://Scenes/UI/Scorecard/scorecard.tscn").instantiate()
	add_child(fresh_ui)
	var fresh_model := Scorecard.new()
	add_child(fresh_model)
	fresh_ui.bind_scorecard(fresh_model)
	fresh_model.set_score(Scorecard.Section.UPPER, "ones", 50)
	await get_tree().process_frame
	await get_tree().process_frame
	var fresh_scored: ScorecardRow = fresh_ui.rows[&"ones"]
	var fresh_open: ScorecardRow = fresh_ui.rows[&"twos"]
	_auto_assert(fresh_scored.score_label.scale == Vector2.ONE, "pre-layout score: scale settled at 1")
	_auto_assert(fresh_scored.score_label.rotation_degrees == 0.0, "pre-layout score: rotation 0")
	_auto_assert(fresh_scored.score_label.position.y == fresh_open.score_label.position.y, "pre-layout score: y matches unscored row (%.1f vs %.1f)" % [fresh_scored.score_label.position.y, fresh_open.score_label.position.y])
	fresh_ui.queue_free()
	fresh_model.queue_free()

	# 7. Blinds depopulate -> covered; populate -> revealed + interactive
	score_card_ui.play_depopulate()
	await get_tree().create_timer(1.2).timeout
	_auto_assert(ones_row._blinds_material.get_shader_parameter("progress") == 0.0, "depopulate leaves rows covered")
	_auto_assert(ones_row._blinds_mask.visible, "blinds mask visible while covered")
	score_card_ui.play_populate()
	await get_tree().create_timer(1.5).timeout
	_auto_assert(ones_row._blinds_material.get_shader_parameter("progress") == 1.0, "populate leaves rows revealed")
	_auto_assert(not ones_row._blinds_mask.visible, "blinds mask hidden at full reveal")
	_auto_assert(ones_row.interactive, "row interactive after populate")
	_auto_assert(score_card_ui.upper_header.modulate.a == 1.0, "headers faded in with populate")

	# 8. Upgrade/downgrade chain on the yahtzee chip
	var chip: LevelChip = score_card_ui.rows[&"yahtzee"].level_chip
	score_card.upgrade_category(Scorecard.Section.LOWER, "yahtzee")
	await get_tree().create_timer(0.6).timeout
	_auto_assert(chip.level == 2, "chip numeral ticked up to 2")
	_auto_assert(chip.scale == Vector2.ONE, "chip scale settled after upgrade")
	var downgrade_done := [false]
	chip.downgrade_finished.connect(func(): downgrade_done[0] = true, CONNECT_ONE_SHOT)
	score_card.downgrade_category(Scorecard.Section.LOWER, "yahtzee")
	var waited := 0.0
	while not downgrade_done[0] and waited < 2.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	_auto_assert(downgrade_done[0], "downgrade_finished emitted within timeout")
	_auto_assert(chip.level == 1, "chip numeral ticked back down to 1")

	if _fail_count > 0:
		print("=== ScorecardV2 auto checks: FAIL (%d) ===" % _fail_count)
		get_tree().quit(1)
	else:
		print("=== ScorecardV2 auto checks: PASS ===")
		get_tree().quit(0)


func _auto_assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail_count += 1
		push_error("[ScorecardV2Test] FAIL: %s" % message)
		print("FAIL: %s" % message)


func add_log(text: String) -> void:
	test_output.text += text + "\n"


func _on_hand_scored() -> void:
	add_log("hand_scored emitted")


func _on_roll_fake_dice_pressed() -> void:
	# set_values returns the evaluation Dictionary; we only need the values stored
	DiceResults.set_values([3, 3, 3, 5, 6])
	score_card_ui.update_best_hand_preview(DiceResults.values)
	add_log("Rolled fake dice [3, 3, 3, 5, 6] — ghost previews refreshed")


func _on_score_random_pressed() -> void:
	if score_card_ui.turn_scored:
		add_log("Turn already scored — press Reset first")
		return
	if DiceResults.values.is_empty():
		DiceResults.set_values([3, 3, 3, 5, 6])
	for def in ScoreCardUI.CATEGORY_DEFS:
		var key: String = def["key"]
		var scores: Dictionary
		if def["section"] == Scorecard.Section.UPPER:
			scores = score_card.upper_scores
		else:
			scores = score_card.lower_scores
		if scores[key] == null:
			add_log("Scoring '%s' with %s" % [key, str(DiceResults.values)])
			score_card_ui.on_category_selected(def["section"], key)
			return
	add_log("All categories scored — press Reset")


func _on_upgrade_yahtzee_pressed() -> void:
	score_card.upgrade_category(Scorecard.Section.LOWER, "yahtzee")
	add_log("Upgraded 'yahtzee' (chip only; juice lands in Phase 4)")


func _on_reset_pressed() -> void:
	score_card.reset_scores_preserve_levels()
	score_card_ui.turn_scored = false
	score_card_ui.enable_all_score_buttons()
	score_card_ui.update_all()
	add_log("Scores reset (levels preserved)")


func _on_repopulate_pressed() -> void:
	score_card_ui.play_populate()
	add_log("play_populate() — blinds wipe in")


func _on_depopulate_pressed() -> void:
	score_card_ui.play_depopulate()
	add_log("play_depopulate() — blinds wipe out")


func _on_downgrade_yahtzee_pressed() -> void:
	score_card.downgrade_category(Scorecard.Section.LOWER, "yahtzee")
	add_log("Downgraded 'yahtzee' (chip chain + row flicker)")


func _on_highlight_yahtzee_pressed() -> void:
	var ok: bool = score_card_ui.set_power_up_highlight(Scorecard.Section.LOWER, "yahtzee")
	add_log("Highlight yahtzee: %s" % str(ok))


func _on_highlight_trigger_pressed() -> void:
	score_card_ui.play_power_up_highlight_trigger(Scorecard.Section.LOWER, "yahtzee")
	add_log("Highlight trigger burst played")


func _on_clear_highlight_pressed() -> void:
	score_card_ui.clear_power_up_highlight()
	add_log("Highlight cleared")
