extends Node2D

## Odd/Even Only Mod Test
##
## Verifies the sides-aware parity mods (OddOnlyMod, EvenOnlyMod):
## - For each dice set (d4/d6/d8/d20) and each parity mod, the modded die is
##   rolled 200 times and must always hold a value within 1..sides AND of the
##   required parity.
## - Smoke test: every registered dice mod (all ModData tres files in
##   Scripts/Mods/) is applied to a die and rolled 50 times on d4 and d6,
##   asserting values stay in range (catches hardcoded d6 assumptions like
##   FiveByOneMod forcing a 5 on a d4).
##
## Keys: 1 - Apply Odd Only to die 1 | 2 - Apply Even Only to die 1
##       3 - Remove mods from die 1 | 4 - Cycle dice set
##       5 - Run automated test suite | R - Reset

var dice_hand: DiceHand
var test_label: Label
var _pass_count: int = 0
var _fail_count: int = 0

const DICE_TYPES: Array[String] = ["d4", "d6", "d8", "d20"]
const SMOKE_DICE_TYPES: Array[String] = ["d4", "d6"]
const ROLLS_PER_CONFIG: int = 200
const SMOKE_ROLLS: int = 50
const DICE_SET_CYCLE: Array[String] = ["d4", "d6", "d8", "d12", "d20"]

var _odd_mod_data: ModData = preload("res://Scripts/Mods/OddOnlyMod.tres")
var _even_mod_data: ModData = preload("res://Scripts/Mods/EvenOnlyMod.tres")

func _ready() -> void:
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

	print("[OddEvenOnlyModTest] Test scene initialized")

func _run_auto_then_quit() -> void:
	await _run_automated_tests()
	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _on_dice_spawned() -> void:
	print("[OddEvenOnlyModTest] Dice spawned, ready for testing")
	_update_display()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed:
		return

	match event.keycode:
		KEY_1:
			_apply_mod_to_first_die(_odd_mod_data)
		KEY_2:
			_apply_mod_to_first_die(_even_mod_data)
		KEY_3:
			_remove_mods_from_first_die()
		KEY_4:
			_cycle_dice_set()
		KEY_5:
			_run_automated_tests()
		KEY_R:
			dice_hand.set_all_dice_rollable()
			_update_display()
		KEY_ESCAPE:
			get_tree().quit()

func _apply_mod_to_first_die(mod_data: ModData) -> void:
	if dice_hand.dice_list.is_empty():
		print("[OddEvenOnlyModTest] No dice available")
		return
	var die: Dice = dice_hand.dice_list[0]
	if die.has_mod(mod_data.id):
		print("[OddEvenOnlyModTest] Mod already applied:", mod_data.id)
		return
	die.add_mod(mod_data)
	print("[OddEvenOnlyModTest] Applied %s to die 1" % mod_data.id)
	_update_display()

func _remove_mods_from_first_die() -> void:
	if dice_hand.dice_list.is_empty():
		return
	var die: Dice = dice_hand.dice_list[0]
	for mod_id in die.active_mods.keys():
		die.remove_mod(mod_id)
	print("[OddEvenOnlyModTest] Removed all mods from die 1")
	_update_display()

func _cycle_dice_set() -> void:
	var index := DICE_SET_CYCLE.find(dice_hand.current_dice_type)
	var next_type: String = DICE_SET_CYCLE[(index + 1) % DICE_SET_CYCLE.size()]
	dice_hand.switch_dice_type(next_type)
	print("[OddEvenOnlyModTest] Switched to", next_type)
	_update_display()

func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s" % label)

## _run_automated_tests()
##
## Runs the parity verification matrix and the all-mods smoke test.
## Prints PASS/FAIL per check.
func _run_automated_tests() -> void:
	print("\n=== ODD/EVEN ONLY MOD AUTOMATED TESTS ===")
	_pass_count = 0
	_fail_count = 0

	# Ensure funds (some mods interact with PlayerEconomy)
	PlayerEconomy.add_money(1000)

	_check("OddOnlyMod.tres loaded", _odd_mod_data != null)
	_check("EvenOnlyMod.tres loaded", _even_mod_data != null)
	if not _odd_mod_data or not _even_mod_data:
		return

	# --- Test 1: parity matrix across dice sets ---
	for dice_type in DICE_TYPES:
		dice_hand.switch_dice_type(dice_type)
		var sides: int = dice_hand.default_dice_data.sides
		var die: Dice = dice_hand.dice_list[0]
		await _test_parity_mod(die, _odd_mod_data, sides, false)
		await _test_parity_mod(die, _even_mod_data, sides, true)

	# --- Test 2: smoke test all registered dice mods ---
	await _smoke_test_all_mods()

	print("\n=== RESULTS: %d passed, %d failed ===" % [_pass_count, _fail_count])
	_update_display()

## _test_parity_mod(die, mod_data, sides, want_even)
##
## Applies the mod, rolls the die ROLLS_PER_CONFIG times, and checks that every
## roll stays within 1..sides and has the required parity.
func _test_parity_mod(die: Dice, mod_data: ModData, sides: int, want_even: bool) -> void:
	var dice_type := dice_hand.current_dice_type
	print("[Test] %s on %s (%d rolls)" % [mod_data.id, dice_type, ROLLS_PER_CONFIG])
	die.add_mod(mod_data)

	var range_failures := 0
	var parity_failures := 0
	for i in range(ROLLS_PER_CONFIG):
		die.make_rollable()
		die.roll()
		if die.value < 1 or die.value > sides:
			range_failures += 1
		if want_even:
			if die.value % 2 != 0:
				parity_failures += 1
		else:
			if die.value % 2 != 1:
				parity_failures += 1

	die.remove_mod(mod_data.id)
	_check("%s/%s: all %d values within 1..%d (%d bad)" % [mod_data.id, dice_type, ROLLS_PER_CONFIG, sides, range_failures], range_failures == 0)
	_check("%s/%s: all %d values correct parity (%d bad)" % [mod_data.id, dice_type, ROLLS_PER_CONFIG, parity_failures], parity_failures == 0)
	await get_tree().process_frame

## _smoke_test_all_mods()
##
## Applies every ModData resource found in Scripts/Mods/ to a die and rolls it
## SMOKE_ROLLS times on the smallest and default dice sets, asserting values
## always stay within 1..sides. Catches hardcoded d6 assumptions.
func _smoke_test_all_mods() -> void:
	print("\n=== ALL MODS SMOKE TEST (%d rolls each) ===" % SMOKE_ROLLS)
	var mod_datas := _load_all_mod_data()
	_check("Found ModData resources in Scripts/Mods", not mod_datas.is_empty())

	for dice_type in SMOKE_DICE_TYPES:
		dice_hand.switch_dice_type(dice_type)
		var sides: int = dice_hand.default_dice_data.sides
		var die: Dice = dice_hand.dice_list[0]
		for mod_data in mod_datas:
			print("[Smoke] %s on %s" % [mod_data.id, dice_type])
			die.add_mod(mod_data)
			var failures := 0
			for i in range(SMOKE_ROLLS):
				die.make_rollable()
				die.roll()
				if die.value < 1 or die.value > sides:
					failures += 1
			die.remove_mod(mod_data.id)
			_check("smoke %s/%s: all %d values within 1..%d (%d bad)" % [mod_data.id, dice_type, SMOKE_ROLLS, sides, failures], failures == 0)
			await get_tree().process_frame

	# Return to the default dice set
	dice_hand.switch_dice_type("d6")

## _load_all_mod_data() -> Array[ModData]
##
## Enumerates every ModData tres in Scripts/Mods/ (same set the ModManager
## registers) so the smoke test covers all dice mods automatically.
func _load_all_mod_data() -> Array[ModData]:
	var result: Array[ModData] = []
	var dir := DirAccess.open("res://Scripts/Mods")
	if not dir:
		push_error("[OddEvenOnlyModTest] Cannot open res://Scripts/Mods")
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with("Mod.tres"):
			var res := load("res://Scripts/Mods/" + file_name)
			if res is ModData and res.scene:
				result.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _update_display() -> void:
	if not dice_hand or not test_label:
		return

	var display_text := "Odd/Even Only Mod Test\n"
	display_text += "1 - Apply Odd Only to die 1\n"
	display_text += "2 - Apply Even Only to die 1\n"
	display_text += "3 - Remove mods from die 1\n"
	display_text += "4 - Cycle dice set (current: %s)\n" % dice_hand.current_dice_type
	display_text += "5 - Run automated test suite\n"
	display_text += "R - Reset all dice | ESC - Exit\n\n"

	display_text += "=== Dice States ===\n"
	for i in range(dice_hand.dice_list.size()):
		var die: Dice = dice_hand.dice_list[i]
		var mods := ", ".join(die.active_mods.keys()) if die.active_mods.size() > 0 else "none"
		display_text += "Die %d: %s (value: %d, mods: %s)\n" % [i + 1, die.get_state_name(), die.value, mods]

	if _pass_count + _fail_count > 0:
		display_text += "\nLast run: %d passed, %d failed\n" % [_pass_count, _fail_count]

	test_label.text = display_text
