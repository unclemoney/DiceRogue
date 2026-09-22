extends Control

## GamingConsoleTest
##
## Comprehensive test scene for all 6 Gaming Consoles.
## Tests: spawning, applying, activation, and console-specific behaviors.
## Run via: Godot editor → Run Current Scene, or command line.

const DiceHandScene := preload("res://Scenes/Dice/dice_hand.tscn")
const ScoreCardScene := preload("res://Scenes/ScoreCard/score_card.tscn")
const GamingConsoleManagerScene := preload("res://Scenes/Managers/gaming_console_manager.tscn")
const GamingConsoleUIScene := preload("res://Scenes/UI/gaming_console_ui.tscn")


class SaturnTestController:
	extends Node

	var active_power_ups: Dictionary = {}
	var dice_hand: DiceHand = null
	var score_card_ui = null
	var _sega_saturn_score_armed: bool = false
	var _sega_saturn_score_active: bool = false
	var _sega_saturn_score_transaction_depth: int = 0

	func _ready() -> void:
		add_to_group("game_controller")

	func arm_sega_saturn_next_score() -> bool:
		if _sega_saturn_score_armed or _sega_saturn_score_active:
			return false
		_sega_saturn_score_armed = true
		return true

	func begin_sega_saturn_score_transaction() -> void:
		if _sega_saturn_score_transaction_depth == 0:
			_sega_saturn_score_active = _sega_saturn_score_armed
		_sega_saturn_score_transaction_depth += 1

	func end_sega_saturn_score_transaction(score_committed: bool = true) -> void:
		if _sega_saturn_score_transaction_depth <= 0:
			return
		_sega_saturn_score_transaction_depth -= 1
		if _sega_saturn_score_transaction_depth > 0:
			return
		if _sega_saturn_score_active and score_committed:
			_sega_saturn_score_armed = false
		_sega_saturn_score_active = false

	func clear_sega_saturn_score_state() -> void:
		_sega_saturn_score_armed = false
		_sega_saturn_score_active = false
		_sega_saturn_score_transaction_depth = 0

	func is_sega_saturn_score_active() -> bool:
		return _sega_saturn_score_active

	func is_sega_saturn_score_armed() -> bool:
		return _sega_saturn_score_armed

	func award_score_time_power_up_money(amount: int, _source_name: String) -> int:
		var resolved_amount = amount
		if _sega_saturn_score_active and amount > 0:
			resolved_amount = amount * 2
		PlayerEconomy.add_money(resolved_amount)
		return resolved_amount

var dice_hand: DiceHand = null
var scorecard: Scorecard = null
var console_manager: GamingConsoleManager = null
var console_ui: GamingConsoleUI = null
var saturn_controller: SaturnTestController = null

var output_label: RichTextLabel = null
var test_results: Array[String] = []
var passed_count: int = 0
var failed_count: int = 0
var _autorun_all: bool = false
var _quit_after_run: bool = false


func _ready() -> void:
	print("[GamingConsoleTest] Starting...")
	_parse_cmdline_args()
	_build_ui()
	_setup_game_systems()
	_log("[color=yellow]Gaming Console Test Scene Ready[/color]")
	_log("Click a button to run individual console tests, or 'Run All' for the full suite.")
	_log("")
	if _autorun_all:
		call_deferred("_autorun_suite")


func _parse_cmdline_args() -> void:
	var user_args := OS.get_cmdline_user_args()
	_autorun_all = user_args.has("--run-all")
	_quit_after_run = user_args.has("--quit-after")


func _autorun_suite() -> void:
	await _run_all_tests()
	if _quit_after_run:
		get_tree().quit(0 if failed_count == 0 else 1)


func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Gaming Console Test Suite"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Button row
	var btn_scroll = ScrollContainer.new()
	btn_scroll.custom_minimum_size = Vector2(0, 50)
	btn_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(btn_scroll)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 6)
	btn_scroll.add_child(btn_hbox)

	_add_button(btn_hbox, "Run All", _run_all_tests)
	_add_button(btn_hbox, "Atari (Save State)", _test_atari)
	_add_button(btn_hbox, "NES (Power Glove)", _test_nes)
	_add_button(btn_hbox, "SNES (Blast Processing)", _test_snes)
	_add_button(btn_hbox, "Sega (Combo System)", _test_sega)
	_add_button(btn_hbox, "PlayStation (Continue?)", _test_playstation)
	_add_button(btn_hbox, "Sega Saturn (Double Action)", _test_sega_saturn)
	_add_button(btn_hbox, "Clear", _clear_output)

	output_label = RichTextLabel.new()
	output_label.bbcode_enabled = true
	output_label.scroll_following = true
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(output_label)


func _add_button(parent: HBoxContainer, text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 36)
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _setup_game_systems() -> void:
	# DiceHand
	dice_hand = DiceHandScene.instantiate() as DiceHand
	dice_hand.position = Vector2(0, 500)
	add_child(dice_hand)

	# ScoreCard
	scorecard = ScoreCardScene.instantiate() as Scorecard
	add_child(scorecard)

	# GamingConsoleManager
	console_manager = GamingConsoleManagerScene.instantiate() as GamingConsoleManager
	add_child(console_manager)

	# GamingConsoleUI (not visible in tests, used to verify show/hide)
	console_ui = GamingConsoleUIScene.instantiate() as GamingConsoleUI
	console_ui.position = Vector2(20, 420)
	add_child(console_ui)

	# Minimal GameController-compatible node for Sega Saturn score tests.
	saturn_controller = SaturnTestController.new()
	saturn_controller.dice_hand = dice_hand
	add_child(saturn_controller)

	# Wait for manager definitions to load
	if console_manager._defs_by_id.is_empty():
		await console_manager.definitions_loaded
	_log("[color=green]Systems ready: DiceHand, ScoreCard, GamingConsoleManager, GamingConsoleUI[/color]")
	_log("Console definitions loaded: %s" % str(console_manager.get_available_consoles()))


# ── Helpers ──────────────────────────────────────────────


func _spawn_and_roll_dice() -> void:
	dice_hand.spawn_dice()
	await get_tree().create_timer(0.3).timeout
	dice_hand.roll_all()
	await get_tree().create_timer(0.6).timeout


func _set_dice_pre_roll_state() -> void:
	if dice_hand and not dice_hand.get_all_dice().is_empty():
		dice_hand.set_all_dice_rollable()
	if console_ui and console_ui.visible:
		console_ui.refresh_button_state()


func _get_dice_values() -> Array[int]:
	var values: Array[int] = []
	for die in dice_hand.get_all_dice():
		values.append(die.value)
	return values


func _get_dice_states() -> Array[String]:
	var states: Array[String] = []
	for die in dice_hand.get_all_dice():
		states.append(die.get_state_name())
	return states


func _spawn_console(id: String, target) -> GamingConsole:
	var console = console_manager.spawn_console(id, self)
	if console:
		console.apply(target)
	return console


func _cleanup_console(console: GamingConsole) -> void:
	if console and is_instance_valid(console):
		console.queue_free()


func _reset_saturn_test_state() -> void:
	if ScoreModifierManager and ScoreModifierManager.has_method("reset"):
		ScoreModifierManager.reset()
	if PlayerEconomy and PlayerEconomy.has_method("reset_to_starting_money"):
		PlayerEconomy.reset_to_starting_money()
	if saturn_controller:
		saturn_controller.clear_sega_saturn_score_state()
		saturn_controller.active_power_ups.clear()
	if dice_hand:
		for die in dice_hand.get_all_dice():
			if die.active_mods is Dictionary:
				die.active_mods.clear()
	DiceResults.values.clear()


func _assert_console_ui_rendered(test_prefix: String, expected_button_text: String, expected_disabled: bool, expect_fanned: bool = false) -> void:
	var spine = console_ui._compact_spine
	var vip_card = console_ui._vip_card
	_assert(spine != null, "%s: compact spine exists" % test_prefix)
	_assert(vip_card != null, "%s: vip card exists" % test_prefix)
	if not spine or not vip_card:
		return

	_assert(spine.visible, "%s: spine visible" % test_prefix)
	_assert(spine.data == console_ui._console_data, "%s: spine bound to console data" % test_prefix)
	_assert(spine._title_label.text == console_ui._console_data.display_name.to_upper(), "%s: spine title text" % test_prefix, spine._title_label.text)
	_assert(spine._activate_button.text == expected_button_text, "%s: spine button text" % test_prefix, spine._activate_button.text)
	_assert(spine._activate_button.disabled == expected_disabled, "%s: spine button disabled state" % test_prefix)
	_assert(vip_card.data == console_ui._console_data, "%s: vip card bound to console data" % test_prefix)
	_assert(console_ui._is_fanned == expect_fanned, "%s: fan state matches expectation" % test_prefix)
	_assert(vip_card.visible == expect_fanned, "%s: vip card visibility matches expectation" % test_prefix)
	_assert(console_ui._fan_background.visible == expect_fanned, "%s: fan background visibility matches expectation" % test_prefix)


func _assert_console_ui_fan_cycle(test_prefix: String) -> void:
	var vip_card = console_ui._vip_card
	var open_click := InputEventMouseButton.new()
	open_click.button_index = MOUSE_BUTTON_LEFT
	open_click.pressed = true
	open_click.position = Vector2(8.0, 8.0)
	console_ui._gui_input(open_click)
	await get_tree().create_timer(0.05).timeout
	_assert(console_ui._is_fanned, "%s: fan state opened" % test_prefix)
	_assert(console_ui._fan_background.visible, "%s: fan background visible" % test_prefix)
	_assert(console_ui._fan_background.color.a >= 0.8, "%s: fan background opacity" % test_prefix, str(console_ui._fan_background.color.a))
	if vip_card:
		_assert(vip_card.visible, "%s: vip card visible" % test_prefix)
		_assert(vip_card._description_label.text == console_ui._get_console_description(), "%s: vip card description synced" % test_prefix)
		var viewport_size = get_viewport_rect().size
		_assert(vip_card.size.x <= viewport_size.x * 0.25, "%s: vip card width bounded" % test_prefix, str(vip_card.size.x))
		_assert(vip_card.size.y <= viewport_size.y * 0.60, "%s: vip card height bounded" % test_prefix, str(vip_card.size.y))

	var click_away := InputEventMouseButton.new()
	click_away.button_index = MOUSE_BUTTON_LEFT
	click_away.pressed = true
	click_away.position = Vector2(4.0, 4.0)
	console_ui._unhandled_input(click_away)
	await get_tree().create_timer(0.35).timeout
	_assert(not console_ui._is_fanned, "%s: fan state closed" % test_prefix)
	if vip_card:
		_assert(not vip_card.visible, "%s: vip card hidden after close" % test_prefix)


func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		passed_count += 1
		var msg = "[color=green]PASS[/color] — %s" % test_name
		if detail != "":
			msg += " (%s)" % detail
		_log(msg)
		test_results.append("PASS: " + test_name)
	else:
		failed_count += 1
		var msg = "[color=red]FAIL[/color] — %s" % test_name
		if detail != "":
			msg += " (%s)" % detail
		_log(msg)
		test_results.append("FAIL: " + test_name)


func _log(text: String) -> void:
	if output_label:
		output_label.append_text(text + "\n")
	print("[GamingConsoleTest] " + text.replace("[color=green]", "").replace("[color=red]", "").replace("[color=yellow]", "").replace("[color=cyan]", "").replace("[/color]", ""))


func _clear_output() -> void:
	if output_label:
		output_label.clear()
	test_results.clear()
	passed_count = 0
	failed_count = 0


func _print_summary() -> void:
	_log("")
	_log("[color=yellow]═══ TEST SUMMARY ═══[/color]")
	_log("[color=green]Passed: %d[/color]" % passed_count)
	if failed_count > 0:
		_log("[color=red]Failed: %d[/color]" % failed_count)
	else:
		_log("[color=green]All tests passed![/color]")


# ── Run All ──────────────────────────────────────────────


func _run_all_tests() -> void:
	_clear_output()
	_log("[color=yellow]═══ RUNNING ALL GAMING CONSOLE TESTS ═══[/color]")
	_log("")

	await _test_atari()
	await _test_nes()
	await _test_snes()
	await _test_sega()
	await _test_playstation()
	await _test_sega_saturn()

	_print_summary()


# ── Atari: Save State ──────────────────────────────────


func _test_atari() -> void:
	_log("")
	_log("[color=cyan]━━━ ATARI — Save State ━━━[/color]")

	# Test 1: Spawn and apply
	var console = _spawn_console("atari_console", dice_hand)
	_assert(console != null, "Atari: spawn", "console is not null")
	if not console:
		return

	var atari = console as AtariConsole
	_assert(atari != null, "Atari: type cast", "is AtariConsole")
	_assert(atari.is_active, "Atari: is_active after apply")
	_assert(atari.uses_remaining == 1, "Atari: uses_remaining", "expected 1, got %d" % atari.uses_remaining)
	_assert(atari.dice_hand_ref == dice_hand, "Atari: dice_hand_ref set")
	_assert(not atari.is_passive(), "Atari: not passive")

	# Test 2: can_activate before rolling (should be false — no rolled dice)
	_assert(not atari.can_activate(), "Atari: can_activate false before roll")

	# Test 3: Spawn and roll dice, then check activation
	await _spawn_and_roll_dice()
	var values_before = _get_dice_values()
	_log("  Dice values after roll: %s" % str(values_before))
	_assert(atari.can_activate(), "Atari: can_activate true after roll")

	var def = console_manager.get_def("atari_console")
	console_ui.show_console(def, atari)
	_assert(console_ui.visible, "Atari: UI visible after show_console")
	_assert_console_ui_rendered("Atari", "READY", false)
	await _assert_console_ui_fan_cycle("Atari")

	# Test 4: Activate (SAVE mode)
	_assert(atari.current_mode == AtariConsole.SaveMode.SAVE, "Atari: starts in SAVE mode")
	console_ui._compact_spine._on_activate_button_pressed()
	_assert(atari.current_mode == AtariConsole.SaveMode.LOAD, "Atari: switched to LOAD after save")
	_assert(atari.saved_values.size() > 0, "Atari: saved_values populated", "saved %d values" % atari.saved_values.size())
	_assert(atari.uses_remaining == 1, "Atari: uses_remaining still 1 after SAVE", "uses: %d" % atari.uses_remaining)
	_assert_console_ui_rendered("Atari after SAVE", "RESTORE", false)
	_log("  Saved values: %s" % str(atari.saved_values))

	# Test 5: Roll again to change values, then LOAD
	dice_hand.set_all_dice_rollable()
	dice_hand.roll_all()
	await get_tree().create_timer(0.6).timeout
	var values_after_reroll = _get_dice_values()
	_log("  Dice values after re-roll: %s" % str(values_after_reroll))

	_assert(atari.can_activate(), "Atari: can_activate true for LOAD")
	console_ui._open_vip_card()
	await get_tree().create_timer(0.05).timeout
	console_ui._vip_card._on_activate_button_pressed()
	var values_after_load = _get_dice_values()
	_log("  Dice values after LOAD: %s" % str(values_after_load))
	_assert(values_after_load == values_before, "Atari: values restored", "expected %s, got %s" % [str(values_before), str(values_after_load)])
	_assert(atari.uses_remaining == 0, "Atari: uses_remaining 0 after LOAD")
	_assert(atari.current_mode == AtariConsole.SaveMode.SAVE, "Atari: reset to SAVE mode")
	_assert_console_ui_rendered("Atari after LOAD", "USED", true, true)
	console_ui._close_vip_card()
	await get_tree().create_timer(0.35).timeout
	# Note: SAVE mode can_activate doesn't check uses_remaining (save is free)
	# LOAD mode blocks on uses_remaining == 0
	_assert(atari.can_activate(), "Atari: SAVE mode can_activate ignores uses")

	# Test 6: Reset for new round
	atari.reset_for_new_round()
	_assert(atari.uses_remaining == 1, "Atari: uses restored after reset")
	_assert_console_ui_rendered("Atari after reset", "READY", false)
	console_ui.hide_console()
	_assert(not console_ui.visible, "Atari: UI hidden after hide_console")

	_cleanup_console(console)
	_log("[color=cyan]━━━ Atari tests complete ━━━[/color]")


# ── NES: Power Glove ────────────────────────────────────


func _test_nes() -> void:
	_log("")
	_log("[color=cyan]━━━ NES — Power Glove ━━━[/color]")

	var console = _spawn_console("nes_console", dice_hand)
	_assert(console != null, "NES: spawn")
	if not console:
		return

	var nes = console as NesConsole
	_assert(nes != null, "NES: type cast")
	_assert(nes.is_active, "NES: is_active after apply")
	_assert(nes.uses_remaining == 1, "NES: uses_remaining", "expected 1, got %d" % nes.uses_remaining)
	_assert(not nes.is_passive(), "NES: not passive")

	# can_activate before rolling
	_set_dice_pre_roll_state()
	_assert(not nes.can_activate(), "NES: can_activate false before roll")

	# Roll dice
	await _spawn_and_roll_dice()
	var values = _get_dice_values()
	_log("  Dice values: %s" % str(values))
	_assert(nes.can_activate(), "NES: can_activate true after roll")

	var def = console_manager.get_def("nes_console")
	console_ui.show_console(def, nes)
	_assert(console_ui.visible, "NES: UI visible")
	_assert_console_ui_rendered("NES", "ACTIVATE", false)
	await _assert_console_ui_fan_cycle("NES")

	# Activate (enters waiting for die click mode)
	console_ui._open_vip_card()
	await get_tree().create_timer(0.05).timeout
	console_ui._vip_card._on_activate_button_pressed()
	_assert(nes._waiting_for_die, "NES: waiting_for_die after activate")
	_assert(not nes.can_activate(), "NES: can_activate false while waiting")
	_assert_console_ui_rendered("NES waiting", "PICK DIE", true, true)
	console_ui._close_vip_card()
	await get_tree().create_timer(0.35).timeout

	# Simulate die click — pick the first rolled die
	var target_die: Dice = null
	for die in dice_hand.get_all_dice():
		if die.get_state() == Dice.DiceState.ROLLED or die.get_state() == Dice.DiceState.LOCKED:
			target_die = die
			break
	_assert(target_die != null, "NES: found target die for selection")

	if target_die:
		var original_value = target_die.value
		_log("  Selected die value: %d" % original_value)

		# Simulate the clicked signal handler
		nes._on_die_clicked(target_die)
		_assert(not nes._waiting_for_die, "NES: waiting cleared after die click")
		_assert(nes._selected_die == target_die, "NES: selected_die set")

		# Test adjust_die +1
		nes.adjust_die(1)
		var expected_up = clampi(original_value + 1, 1, target_die.dice_data.sides)
		_assert(target_die.value == expected_up, "NES: adjust +1", "expected %d, got %d" % [expected_up, target_die.value])
		_assert(nes.uses_remaining == 0, "NES: uses_remaining 0 after adjust")
		_assert(nes._selected_die == null, "NES: selected_die cleared")
		_assert_console_ui_rendered("NES after use", "USED", true)

	# Reset for new round
	nes.reset_for_new_round()
	_set_dice_pre_roll_state()
	_assert(nes.uses_remaining == 1, "NES: uses restored after reset")
	_assert_console_ui_rendered("NES after reset", "ACTIVATE", true)

	# Test adjust_die -1 path
	dice_hand.set_all_dice_rollable()
	dice_hand.roll_all()
	await get_tree().create_timer(0.6).timeout
	_assert(nes.can_activate(), "NES: can_activate after reset+roll")

	nes.activate()
	var die2: Dice = null
	for die in dice_hand.get_all_dice():
		if die.get_state() == Dice.DiceState.ROLLED or die.get_state() == Dice.DiceState.LOCKED:
			die2 = die
			break
	if die2:
		var orig2 = die2.value
		nes._on_die_clicked(die2)
		nes.adjust_die(-1)
		var expected_down = clampi(orig2 - 1, 1, die2.dice_data.sides)
		_assert(die2.value == expected_down, "NES: adjust -1", "expected %d, got %d" % [expected_down, die2.value])

	console_ui.hide_console()
	_assert(not console_ui.visible, "NES: UI hidden after hide_console")

	_cleanup_console(console)
	_log("[color=cyan]━━━ NES tests complete ━━━[/color]")


# ── SNES: Blast Processing ──────────────────────────────


func _test_snes() -> void:
	_log("")
	_log("[color=cyan]━━━ SNES — Blast Processing ━━━[/color]")

	var console = _spawn_console("snes_console", scorecard)
	_assert(console != null, "SNES: spawn")
	if not console:
		return

	var snes = console as SnesConsole
	_assert(snes != null, "SNES: type cast")
	_assert(snes.is_active, "SNES: is_active after apply")
	_assert(snes.is_passive(), "SNES: is passive")
	_assert(not snes.can_activate(), "SNES: can_activate false (passive)")
	_assert(snes.scorecard_ref == scorecard, "SNES: scorecard_ref set")
	_assert(snes.categories_scored == 0, "SNES: categories_scored starts 0")

	var def = console_manager.get_def("snes_console")
	console_ui.show_console(def, snes)
	_assert(console_ui.visible, "SNES: UI visible")
	_assert_console_ui_rendered("SNES passive", "ACTIVE", true)
	await _assert_console_ui_fan_cycle("SNES")

	# Simulate scoring categories
	snes._on_score_assigned(Scorecard.Section.UPPER, "ones", 3)
	_assert(snes.categories_scored == 1, "SNES: categories_scored = 1 after 1st score")

	snes._on_score_assigned(Scorecard.Section.UPPER, "twos", 6)
	_assert(snes.categories_scored == 2, "SNES: categories_scored = 2")

	# 3rd category → blast multiplier should activate
	snes._on_score_assigned(Scorecard.Section.UPPER, "threes", 9)
	_assert(snes.categories_scored == 3, "SNES: categories_scored = 3")
	var has_mult = ScoreModifierManager.has_multiplier(snes.modifier_source_name)
	_assert(has_mult, "SNES: blast multiplier registered after 3rd score")
	_assert_console_ui_rendered("SNES blast ready", "1.5x READY", true)
	_log("  Blast multiplier active: %s" % str(has_mult))

	# 4th category → multiplier consumed (unregistered)
	snes._on_score_assigned(Scorecard.Section.LOWER, "three_of_a_kind", 15)
	_assert(snes.categories_scored == 4, "SNES: categories_scored = 4")
	var mult_cleared = not ScoreModifierManager.has_multiplier(snes.modifier_source_name)
	_assert(mult_cleared, "SNES: multiplier cleared after non-blast score")
	_assert_console_ui_rendered("SNES after consume", "ACTIVE", true)
	console_ui.hide_console()
	_assert(not console_ui.visible, "SNES: UI hidden after hide_console")

	# Cleanup
	if ScoreModifierManager.has_multiplier(snes.modifier_source_name):
		ScoreModifierManager.unregister_multiplier(snes.modifier_source_name)
	_cleanup_console(console)
	_log("[color=cyan]━━━ SNES tests complete ━━━[/color]")


# ── Sega: Combo System ──────────────────────────────────


func _test_sega() -> void:
	_log("")
	_log("[color=cyan]━━━ SEGA — Combo System ━━━[/color]")

	var console = _spawn_console("sega_console", scorecard)
	_assert(console != null, "Sega: spawn")
	if not console:
		return

	var sega = console as SegaConsole
	_assert(sega != null, "Sega: type cast")
	_assert(sega.is_active, "Sega: is_active after apply")
	_assert(sega.is_passive(), "Sega: is passive")
	_assert(sega.scorecard_ref == scorecard, "Sega: scorecard_ref set")
	_assert(sega.combo_count == 0, "Sega: combo starts at 0")

	var def = console_manager.get_def("sega_console")
	console_ui.show_console(def, sega)
	_assert(console_ui.visible, "Sega: UI visible")
	_assert_console_ui_rendered("Sega passive", "ACTIVE", true)
	await _assert_console_ui_fan_cycle("Sega")

	# Score non-zero to build combo
	scorecard.last_base_score = 3
	sega._on_score_assigned(Scorecard.Section.UPPER, "ones", 3)
	_assert(sega.combo_count == 1, "Sega: combo = 1 after score > 0")

	scorecard.last_base_score = 6
	sega._on_score_assigned(Scorecard.Section.UPPER, "twos", 6)
	_assert(sega.combo_count == 2, "Sega: combo = 2")

	var has_bonus = ScoreModifierManager.has_additive(sega.modifier_source_name)
	_assert(has_bonus, "Sega: additive bonus registered", "combo 2 × 3 = +6")

	# Score 0 → combo breaks
	scorecard.last_base_score = 0
	sega._on_score_assigned(Scorecard.Section.LOWER, "yahtzee", 0)
	_assert(sega.combo_count == 0, "Sega: combo reset to 0 after scoring 0")
	var bonus_cleared = not ScoreModifierManager.has_additive(sega.modifier_source_name)
	_assert(bonus_cleared, "Sega: bonus cleared on combo break")

	# Rebuild combo
	scorecard.last_base_score = 9
	sega._on_score_assigned(Scorecard.Section.UPPER, "threes", 9)
	_assert(sega.combo_count == 1, "Sega: combo rebuilt to 1")
	console_ui.hide_console()
	_assert(not console_ui.visible, "Sega: UI hidden after hide_console")

	# Cleanup
	if ScoreModifierManager.has_additive(sega.modifier_source_name):
		ScoreModifierManager.unregister_additive(sega.modifier_source_name)
	_cleanup_console(console)
	_log("[color=cyan]━━━ Sega tests complete ━━━[/color]")


# ── PlayStation: Continue? ───────────────────────────────


func _test_playstation() -> void:
	_log("")
	_log("[color=cyan]━━━ PlayStation — Continue? ━━━[/color]")

	# PlayStation apply() safely handles targets without round_manager/turn_tracker
	var console = _spawn_console("playstation_console", self)
	_assert(console != null, "PS1: spawn")
	if not console:
		return

	var ps1 = console as PlaystationConsole
	_assert(ps1 != null, "PS1: type cast")
	_assert(ps1.is_active, "PS1: is_active after apply")
	_assert(ps1.is_passive(), "PS1: is passive")
	_assert(not ps1.can_activate(), "PS1: can_activate false (passive)")
	_assert(ps1.uses_remaining == 1, "PS1: uses_remaining", "expected 1, got %d" % ps1.uses_remaining)
	_assert(not ps1._continued_this_round, "PS1: _continued_this_round false initially")

	var def = console_manager.get_def("playstation_console")
	console_ui.show_console(def, ps1)
	_assert(console_ui.visible, "PS1: UI visible")
	_assert_console_ui_rendered("PS1 passive", "ACTIVE", true)
	await _assert_console_ui_fan_cycle("PS1")

	# round_manager_ref will be null (no real GameController)
	_log("  round_manager_ref is null: %s — testing internal state" % str(ps1.round_manager_ref == null))

	# Direct _trigger_continue test
	ps1._trigger_continue()
	_assert(ps1._continued_this_round, "PS1: _continued_this_round true after trigger")
	_assert(ps1.uses_remaining == 0, "PS1: uses_remaining 0 after continue")

	# Test reset
	ps1.reset_for_new_round()
	_assert(not ps1._continued_this_round, "PS1: continued flag reset")
	_assert(ps1.uses_remaining == 1, "PS1: uses restored after reset")

	# Test description
	var desc = ps1.get_power_description()
	_assert("Continue?" in desc, "PS1: description contains Continue?", desc)
	console_ui.hide_console()
	_assert(not console_ui.visible, "PS1: UI hidden after hide_console")

	_cleanup_console(console)
	_log("[color=cyan]━━━ PlayStation tests complete ━━━[/color]")


# ── Sega Saturn: Double Action ───────────────────────────


func _test_sega_saturn() -> void:
	_log("")
	_log("[color=cyan]━━━ Sega Saturn — Double Action ━━━[/color]")
	_reset_saturn_test_state()

	if saturn_controller == null:
		_assert(false, "Saturn: test controller exists")
		return

	saturn_controller.active_power_ups["chance520"] = Node.new()

	var console = _spawn_console("sega_saturn_console", saturn_controller)
	_assert(console != null, "Saturn: spawn")
	if not console:
		return

	var saturn = console as SegaSaturnConsole
	_assert(saturn != null, "Saturn: type cast")
	_assert(saturn.is_active, "Saturn: is_active after apply")
	_assert(saturn.uses_remaining == 1, "Saturn: uses_remaining", "expected 1, got %d" % saturn.uses_remaining)
	_assert(not saturn.is_passive(), "Saturn: not passive")
	_assert(saturn.game_controller_ref == saturn_controller, "Saturn: controller ref set")
	_assert(saturn.can_activate(), "Saturn: can_activate with held powerups")

	var def = console_manager.get_def("sega_saturn_console")
	console_ui.show_console(def, saturn)
	_assert(console_ui.visible, "Saturn: UI visible")
	_assert_console_ui_rendered("Saturn", "ACTIVATE", false)
	await _assert_console_ui_fan_cycle("Saturn")

	# Activate -> armed state
	console_ui._compact_spine._on_activate_button_pressed()
	_assert(saturn_controller.is_sega_saturn_score_armed(), "Saturn: armed after activate")
	_assert(not saturn.can_activate(), "Saturn: cannot reactivate while armed")
	_assert(saturn.uses_remaining == 0, "Saturn: uses_remaining 0 after activation")
	_assert_console_ui_rendered("Saturn armed", "ARMED", true)

	# Transaction without commit should keep Saturn armed.
	saturn_controller.begin_sega_saturn_score_transaction()
	saturn_controller.end_sega_saturn_score_transaction(false)
	_assert(saturn_controller.is_sega_saturn_score_armed(), "Saturn: remains armed after uncommitted transaction")

	# Additive doubling
	ScoreModifierManager.register_additive("chance520", 20)
	saturn_controller.begin_sega_saturn_score_transaction()
	var additive_breakdown: Dictionary = scorecard.calculate_score_with_breakdown("full_house", [2, 2, 3, 3, 3], false)
	saturn_controller.end_sega_saturn_score_transaction(true)
	var additive_info: Dictionary = additive_breakdown.get("breakdown_info", {})
	_assert(additive_breakdown.get("base_score", 0) == 25, "Saturn: additive case base score 25")
	_assert(additive_breakdown.get("final_score", 0) == 65, "Saturn: additive case final score doubled to 65", str(additive_breakdown))
	_assert(additive_info.get("regular_additive", 0) == 40, "Saturn: additive doubled from 20 to 40")
	_assert(additive_info.get("saturn_adjusted_additive_sources", []).has("chance520"), "Saturn: additive source marked as Saturn-adjusted")
	_assert(not saturn_controller.is_sega_saturn_score_armed(), "Saturn: consumed after committed score")
	ScoreModifierManager.reset()
	console_ui.refresh_button_state()
	_assert_console_ui_rendered("Saturn after additive score", "USED", true)

	# Multiplier doubling uses the raw-value rule: 1.5x -> 3.0x.
	saturn.reset_for_new_round()
	_assert(saturn.uses_remaining == 1, "Saturn: uses restored after reset")
	saturn_controller.active_power_ups.clear()
	saturn_controller.active_power_ups["money_bags"] = Node.new()
	console_ui.refresh_button_state()
	_assert(saturn.can_activate(), "Saturn: can_activate after reset with held multiplier powerup")
	saturn.activate()
	_assert(saturn_controller.is_sega_saturn_score_armed(), "Saturn: armed for multiplier case")
	ScoreModifierManager.register_multiplier("money_bags", 1.5)
	saturn_controller.begin_sega_saturn_score_transaction()
	var multiplier_breakdown: Dictionary = scorecard.calculate_score_with_breakdown("chance", [1, 2, 3, 4, 6], false)
	saturn_controller.end_sega_saturn_score_transaction(true)
	var multiplier_info: Dictionary = multiplier_breakdown.get("breakdown_info", {})
	_assert(multiplier_breakdown.get("final_score", 0) == 48, "Saturn: multiplier case final score 48", str(multiplier_breakdown))
	_assert(is_equal_approx(float(multiplier_info.get("raw_regular_multiplier", 1.0)), 3.0), "Saturn: raw multiplier doubled from 1.5 to 3.0")
	_assert(multiplier_info.get("saturn_adjusted_multiplier_sources", []).has("money_bags"), "Saturn: multiplier source marked as Saturn-adjusted")
	ScoreModifierManager.reset()

	# Score-time money should double only during the active score transaction.
	if dice_hand.get_all_dice().is_empty():
		await _spawn_and_roll_dice()
	var mod_money = ModMoneyPowerUp.new()
	add_child(mod_money)
	saturn.reset_for_new_round()
	PlayerEconomy.reset_to_starting_money()
	saturn_controller.active_power_ups.clear()
	saturn_controller.active_power_ups["mod_money"] = mod_money
	dice_hand.get_all_dice()[0].active_mods["unit_test_mod"] = true
	saturn.activate()
	var money_before_mod = PlayerEconomy.get_money()
	saturn_controller.begin_sega_saturn_score_transaction()
	mod_money._on_about_to_score(Scorecard.Section.UPPER, "ones", [])
	saturn_controller.end_sega_saturn_score_transaction(true)
	var mod_money_delta = PlayerEconomy.get_money() - money_before_mod
	_assert(mod_money_delta == 16, "Saturn: pre-score money doubled from 8 to 16", str(mod_money_delta))
	mod_money.queue_free()
	for die in dice_hand.get_all_dice():
		die.active_mods.clear()

	var full_house_power = FullHousePowerUp.new()
	add_child(full_house_power)
	saturn.reset_for_new_round()
	PlayerEconomy.reset_to_starting_money()
	saturn_controller.active_power_ups.clear()
	saturn_controller.active_power_ups["full_house_bonus"] = full_house_power
	DiceResults.values = [2, 2, 3, 3, 3]
	saturn.activate()
	var money_before_full_house = PlayerEconomy.get_money()
	saturn_controller.begin_sega_saturn_score_transaction()
	full_house_power._on_score_assigned(Scorecard.Section.LOWER, "full_house", 25)
	saturn_controller.end_sega_saturn_score_transaction(true)
	var full_house_delta = PlayerEconomy.get_money() - money_before_full_house
	_assert(full_house_delta == 14, "Saturn: post-score money doubled from 7 to 14", str(full_house_delta))
	full_house_power.queue_free()

	# Out-of-scope calls should not double after the score transaction ends.
	var out_of_scope_money = saturn_controller.award_score_time_power_up_money(8, "control")
	_assert(out_of_scope_money == 8, "Saturn: helper does not double outside active transaction")

	console_ui.hide_console()
	_assert(not console_ui.visible, "Saturn: UI hidden after hide_console")

	_reset_saturn_test_state()
	_cleanup_console(console)
	_log("[color=cyan]━━━ Sega Saturn tests complete ━━━[/color]")
