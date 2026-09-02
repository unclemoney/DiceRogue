extends Node

## SynergyHaloTest
##
## Validates the synergy halo visuals: KioskTile / PowerUpIcon set_synergy_halo
## API and PowerUpUI slot-border halo mapping (matching set, rainbow override,
## clearing on deactivation).
##
## Run with: & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/SynergyHaloTest.tscn
## Run headless with `-- --quit-after` to exit with the failure count.

var _test_failures: int = 0
var _power_up_ui: PowerUpUI
var _synergy_manager: SynergyManager

const POWER_UP_UI_SCENE := preload("res://Scenes/UI/power_up_ui.tscn")
const KIOSK_TILE_SCENE := preload("res://Scenes/PowerUp/kiosk_tile.tscn")


func _ready() -> void:
	print("=== Synergy Halo Test Scene Ready ===")
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_tests()
	_quit_if_requested()


func _run_tests() -> void:
	print("\n[TEST 1] KioskTile halo API...")
	var tile: KioskTile = KIOSK_TILE_SCENE.instantiate()
	add_child(tile)
	await get_tree().process_frame
	if tile.synergy_halo and not tile.synergy_halo.visible:
		print("  ✓ Tile halo node exists and starts hidden")
	else:
		_fail_test("Tile halo should exist and start hidden")
	tile.set_synergy_halo(PowerUpData.SynergyHaloMode.SET, PowerUpData.get_rating_color("R"))
	var tile_mat := tile.synergy_halo.material as ShaderMaterial
	var expected := PowerUpData.get_rating_color("R")
	if tile.synergy_halo.visible and tile_mat and tile_mat.get_shader_parameter("glow_color") == expected:
		print("  ✓ Tile SET mode applies rating color")
	else:
		_fail_test("Tile SET mode should apply rating color")
	tile.set_synergy_halo(PowerUpData.SynergyHaloMode.RAINBOW)
	if tile.synergy_halo.visible and tile_mat.get_shader_parameter("rainbow_mode") == 1.0:
		print("  ✓ Tile RAINBOW mode enables rainbow_mode")
	else:
		_fail_test("Tile RAINBOW mode should set rainbow_mode to 1")
	tile.set_synergy_halo(PowerUpData.SynergyHaloMode.NONE)
	if not tile.synergy_halo.visible:
		print("  ✓ Tile NONE mode hides halo")
	else:
		_fail_test("Tile NONE mode should hide halo")
	tile.queue_free()

	print("\n[TEST 2] PowerUpUI slot halo mapping...")
	_power_up_ui = POWER_UP_UI_SCENE.instantiate()
	add_child(_power_up_ui)
	_synergy_manager = SynergyManager.new()
	add_child(_synergy_manager)
	await get_tree().process_frame
	await get_tree().process_frame
	_power_up_ui._connect_synergy_manager()

	if _power_up_ui._synergy_manager == _synergy_manager:
		print("  ✓ PowerUpUI connected to SynergyManager")
	else:
		_fail_test("PowerUpUI failed to connect to SynergyManager")
		return

	if _power_up_ui._slot_halo_modes.size() == PowerUpUI.COMPACT_SLOT_COUNT:
		print("  ✓ Slot halo state tracked for all %d slots" % PowerUpUI.COMPACT_SLOT_COUNT)
	else:
		_fail_test("Expected %d slot halo states, got %d" % [PowerUpUI.COMPACT_SLOT_COUNT, _power_up_ui._slot_halo_modes.size()])
		return

	# Add 5 PG-13 power-ups and activate the PG-13 matching set.
	for i in range(5):
		var data := PowerUpData.new()
		data.id = "halo_test_%d" % i
		data.display_name = "Halo Test %d" % i
		data.rating = "PG-13"
		_power_up_ui.add_power_up(data)
	await get_tree().process_frame

	_synergy_manager._rating_counts["PG-13"] = 5
	_synergy_manager._active_synergies["synergy_PG_13_sets"] = 50
	_power_up_ui._update_synergy_halos()

	var set_ok := true
	for slot_index in range(5):
		if _power_up_ui._slot_halo_modes[slot_index] != PowerUpData.SynergyHaloMode.SET:
			set_ok = false
	# 6th slot is empty (no overflow) and must stay halo-free.
	if _power_up_ui._slot_halo_modes[PowerUpUI.COMPACT_SLOT_COUNT - 1] != PowerUpData.SynergyHaloMode.NONE:
		set_ok = false
	if set_ok:
		print("  ✓ All 5 occupied slots glow; empty slot stays clear")
	else:
		_fail_test("Expected SET glow on 5 occupied slots only")

	var expected_color := PowerUpData.get_rating_color("PG-13")
	if _power_up_ui._slot_halo_colors[0] == expected_color:
		print("  ✓ Slot glow uses the PG-13 rating color")
	else:
		_fail_test("Slot glow should use the PG-13 rating color")

	var style := _power_up_ui._slot_cells[0].get_theme_stylebox("panel") as StyleBoxFlat
	if style and style.border_color == expected_color and is_equal_approx(style.bg_color.a, 0.35):
		print("  ✓ Slot stylebox glows with rating color (background fill, no icon overlap)")
	else:
		_fail_test("Slot stylebox should use rating-color border and translucent fill")

	# Rainbow overrides the per-rating set glow.
	for rating in SynergyManager.ALL_RATINGS:
		_synergy_manager._rating_counts[rating] = max(1, _synergy_manager._rating_counts.get(rating, 0))
	_synergy_manager._active_synergies["synergy_rainbow"] = SynergyManager.RAINBOW_MULTIPLIER
	_power_up_ui._update_synergy_halos()

	var rainbow_ok := true
	for slot_index in range(5):
		if _power_up_ui._slot_halo_modes[slot_index] != PowerUpData.SynergyHaloMode.RAINBOW:
			rainbow_ok = false
	if rainbow_ok:
		print("  ✓ Rainbow bonus overrides SET glow on all occupied slots")
	else:
		_fail_test("Expected RAINBOW glow on all occupied slots")

	# Deactivation clears glows.
	_synergy_manager._active_synergies.clear()
	_synergy_manager._rating_counts["PG-13"] = 0
	_power_up_ui._update_synergy_halos()

	var cleared_ok := true
	for mode in _power_up_ui._slot_halo_modes:
		if mode != PowerUpData.SynergyHaloMode.NONE:
			cleared_ok = false
	if cleared_ok:
		print("  ✓ Slot glows cleared after synergy deactivation")
	else:
		_fail_test("Expected slot glows cleared after deactivation")

	# Below-threshold counts produce no glow.
	_synergy_manager._rating_counts["PG-13"] = 4
	_power_up_ui._update_synergy_halos()
	var below_ok := true
	for mode in _power_up_ui._slot_halo_modes:
		if mode != PowerUpData.SynergyHaloMode.NONE:
			below_ok = false
	if below_ok:
		print("  ✓ 4/5 rating count produces no glow (active-only)")
	else:
		_fail_test("Expected no glow at 4/5 count")

	print("\n=== Tests complete: %d failure(s) ===" % _test_failures)


func _fail_test(message: String) -> void:
	_test_failures += 1
	print("  ❌ FAIL: %s" % message)


func _quit_if_requested() -> void:
	if OS.get_cmdline_user_args().has("--quit-after"):
		print("[SynergyHaloTest] Quitting with %d failure(s)" % _test_failures)
		get_tree().quit(_test_failures)
