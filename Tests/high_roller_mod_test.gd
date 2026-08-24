extends Node2D

## High Roller Mod Test
##
## Verifies the HighRollerMod contract against the dice state machine:
## - The modded die is excluded from normal ROLL-button rolls.
## - Clicking the modded die performs a paid manual reroll (no lock toggle).
## - Unmodded dice still lock/unlock and roll normally.
##
## Keys: 1 - Apply High Roller to die 1 | 2 - Remove mod | 3 - Normal roll
##       4 - Click modded die | 5 - Run automated test suite | R - Reset

var dice_hand: DiceHand
var test_label: Label
var _mod_data: ModData = preload("res://Scripts/Mods/HighRollerMod.tres")
var _modded_die: Dice = null
var _pass_count: int = 0
var _fail_count: int = 0

func _ready():
	test_label = $Label

	var dice_hand_scene = preload("res://Scenes/Dice/dice_hand.tscn")
	dice_hand = dice_hand_scene.instantiate()
	add_child(dice_hand)
	dice_hand.position = Vector2(-520, -250)

	dice_hand.dice_spawned.connect(_on_dice_spawned)
	dice_hand.spawn_dice()

	# CLI mode: run the automated suite and quit (-- --auto-test)
	if "--auto-test" in OS.get_cmdline_user_args():
		dice_hand.dice_spawned.connect(_run_auto_then_quit, CONNECT_ONE_SHOT)

	print("[HighRollerModTest] Test scene initialized")

func _run_auto_then_quit() -> void:
	await _run_automated_tests()
	get_tree().quit()

func _on_dice_spawned():
	print("[HighRollerModTest] Dice spawned, ready for testing")
	_update_display()

func _input(event):
	if not event is InputEventKey:
		return
	if not event.pressed:
		return

	match event.keycode:
		KEY_1:
			_apply_mod_to_first_die()
		KEY_2:
			_remove_mod()
		KEY_3:
			_normal_roll()
		KEY_4:
			_click_modded_die()
		KEY_5:
			_run_automated_tests()
		KEY_R:
			dice_hand.set_all_dice_rollable()
			_update_display()
		KEY_ESCAPE:
			get_tree().quit()

func _apply_mod_to_first_die() -> void:
	if dice_hand.dice_list.is_empty():
		print("[HighRollerModTest] No dice available")
		return
	_modded_die = dice_hand.dice_list[0]
	if _modded_die.has_mod(_mod_data.id):
		print("[HighRollerModTest] Mod already applied")
		return
	_modded_die.add_mod(_mod_data)
	print("[HighRollerModTest] Applied High Roller to die 1")
	_update_display()

func _remove_mod() -> void:
	if _modded_die and is_instance_valid(_modded_die) and _modded_die.has_mod(_mod_data.id):
		_modded_die.remove_mod(_mod_data.id)
		print("[HighRollerModTest] Removed High Roller from die 1")
	_update_display()

func _normal_roll() -> void:
	print("[HighRollerModTest] Simulating normal ROLL button press")
	dice_hand.prepare_dice_for_roll()
	dice_hand.roll_all()
	await dice_hand.roll_complete
	_update_display()

func _click_modded_die() -> void:
	if not _modded_die or not is_instance_valid(_modded_die):
		print("[HighRollerModTest] No modded die - apply the mod first (key 1)")
		return
	_simulate_click(_modded_die)
	# Mod click handler is CONNECT_DEFERRED; let it run before updating display
	await get_tree().process_frame
	await get_tree().process_frame
	_update_display()

## _simulate_click(die: Dice)
##
## Sends a synthetic left-click through Dice._input_event, exercising the same
## code path as a real mouse click (signals + built-in lock toggle).
func _simulate_click(die: Dice) -> void:
	var event = InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	die._input_event(null, event, 0)

func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s" % label)

## _run_automated_tests()
##
## Full verification of the High Roller contract. Prints PASS/FAIL per check.
func _run_automated_tests() -> void:
	print("\n=== HIGH ROLLER AUTOMATED TESTS ===")
	_pass_count = 0
	_fail_count = 0

	# Ensure funds for paid rerolls
	PlayerEconomy.add_money(1000)

	# Setup: apply mod and perform an initial roll so dice are ROLLED
	_apply_mod_to_first_die()
	await _normal_roll()

	var die = _modded_die
	_check("Mod applied to die", die.has_mod("high_roller"))
	_check("locking_disabled flag set", die.locking_disabled)
	_check("excluded_from_normal_rolls flag set", die.excluded_from_normal_rolls)
	_check("Modded die in ROLLED state after roll", die.current_state == Dice.DiceState.ROLLED)

	# --- Test 1: normal ROLL must not reroll the modded die ---
	print("[Test 1] Normal roll excludes modded die")
	die.value = 1
	die.update_visual()
	await _normal_roll()
	_check("Modded die kept its value (1)", die.value == 1)
	_check("Modded die still ROLLED (not re-rolled)", die.current_state == Dice.DiceState.ROLLED)
	var others_rolled = true
	for i in range(1, dice_hand.dice_list.size()):
		if dice_hand.dice_list[i].current_state != Dice.DiceState.ROLLED:
			others_rolled = false
	_check("All other dice rolled normally", others_rolled)

	# --- Test 2: clicking the modded die rerolls it without locking ---
	print("[Test 2] Click performs paid manual reroll")
	var mod = die.get_mod("high_roller")
	var cost_index_before = mod._current_cost_index
	_simulate_click(die)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("Click did not lock the die", die.current_state == Dice.DiceState.ROLLED)
	_check("Click did not set is_locked", not die.is_locked)
	_check("Reroll happened (back to ROLLED via roll())", die.current_state == Dice.DiceState.ROLLED)
	_check("Cost index incremented after reroll", mod._current_cost_index == cost_index_before + 1)

	# --- Test 3: Fibonacci cost is charged ---
	print("[Test 3] Escalating cost is charged")
	var money_before = PlayerEconomy.money
	_simulate_click(die)
	await get_tree().process_frame
	await get_tree().process_frame
	# First reroll was free (fib[0] = 0), second costs fib[1] = 1
	_check("Second reroll charged $1", PlayerEconomy.money == money_before - 1)

	# --- Test 4: unmodded dice still lock/unlock on click ---
	print("[Test 4] Unmodded die lock toggle unaffected")
	var plain_die = dice_hand.dice_list[1]
	_simulate_click(plain_die)
	_check("Plain die locked on click", plain_die.current_state == Dice.DiceState.LOCKED)
	_simulate_click(plain_die)
	_check("Plain die unlocked on second click", plain_die.current_state == Dice.DiceState.ROLLED)

	# --- Test 5: normal roll still respects locks on other dice ---
	print("[Test 5] Locked unmodded die preserved on normal roll")
	plain_die.lock()
	plain_die.value = 6
	plain_die.update_visual()
	await _normal_roll()
	_check("Locked die kept its value (6)", plain_die.value == 6)
	_check("Modded die still excluded", die.value != 0)

	# --- Test 5b: new-turn reset preserves the held value ---
	print("[Test 5b] set_all_dice_rollable preserves excluded die value")
	die.value = 2
	die.update_visual()
	dice_hand.set_all_dice_rollable()
	_check("Modded die keeps value (2) on new turn", die.value == 2)
	_check("Modded die stays ROLLED on new turn", die.current_state == Dice.DiceState.ROLLED)
	_check("Other dice reset to ROLLABLE", dice_hand.dice_list[2].current_state == Dice.DiceState.ROLLABLE)

	# --- Test 6: removal restores normal behavior ---
	print("[Test 6] Mod removal restores locking and normal rolls")
	_remove_mod()
	_check("locking_disabled cleared", not die.locking_disabled)
	_check("excluded_from_normal_rolls cleared", not die.excluded_from_normal_rolls)
	_simulate_click(die)
	_check("Die locks on click after removal", die.current_state == Dice.DiceState.LOCKED)

	print("\n=== RESULTS: %d passed, %d failed ===" % [_pass_count, _fail_count])
	_update_display()

func _update_display():
	if not dice_hand or not test_label:
		return

	var display_text = "High Roller Mod Test\n"
	display_text += "1 - Apply High Roller to die 1\n"
	display_text += "2 - Remove mod from die 1\n"
	display_text += "3 - Simulate normal ROLL\n"
	display_text += "4 - Click modded die (manual reroll)\n"
	display_text += "5 - Run automated test suite\n"
	display_text += "R - Reset all dice | ESC - Exit\n\n"

	display_text += "=== Dice States ===\n"
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		var mods = ", ".join(die.active_mods.keys()) if die.active_mods.size() > 0 else "none"
		display_text += "Die %d: %s (value: %d, mods: %s)\n" % [i + 1, die.get_state_name(), die.value, mods]

	if _modded_die and is_instance_valid(_modded_die) and _modded_die.has_mod("high_roller"):
		var mod = _modded_die.get_mod("high_roller")
		display_text += "\nHigh Roller: %s\n" % mod.get_current_cost_display()

	if _pass_count + _fail_count > 0:
		display_text += "\nLast run: %d passed, %d failed\n" % [_pass_count, _fail_count]

	test_label.text = display_text
