extends Control

## _roll_scale_watchdog_test.gd (temporary verification)
##
## Reproduces the Roll button frozen-scale bug and verifies the scale watchdog:
##  1. Starts the idle pulse (breathe) and stops it mid-flight — the shell
##     freezes at a non-ONE scale (the original bug).
##  2. Drives the real rolls_exhausted path (negative_hit on the frozen shell).
##  3. Samples scale before the watchdog fires (expect still frozen) and after
##     (expect restored to ONE, disabled modulate preserved at alpha 0.88).
## Run windowed (NOT headless):
##   godot --path . Tests/_roll_scale_watchdog_test.tscn

const RollButtonUIScene = preload("res://Scenes/UI/roll_button_ui.tscn")
const TurnTrackerScript = preload("res://Scripts/Core/turn_tracker.gd")

var _roll_ui: RollButtonUI
var _tracker: TurnTracker


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	call_deferred("_run")


func _run() -> void:
	_tracker = TurnTrackerScript.new()
	_tracker.name = "TurnTracker"
	_tracker.add_to_group("turn_tracker")
	add_child(_tracker)

	_roll_ui = RollButtonUIScene.instantiate()
	add_child(_roll_ui)
	await get_tree().process_frame
	await get_tree().process_frame

	_tracker.rolls_left = 3
	_roll_ui.enable_roll()
	_roll_ui.start_pulse()
	print("[ScaleWatchdogTest] pulse started, scale=", _roll_ui.roll_button_shell.scale)

	# Breathe period is 2.0s; peak (+5.5%) at 1.0s. Stop there to freeze mid-flight.
	await get_tree().create_timer(1.0).timeout
	_roll_ui.stop_pulse()
	var frozen: Vector2 = _roll_ui.roll_button_shell.scale
	print("[ScaleWatchdogTest] frozen mid-breathe scale=", frozen)

	# Real exhaustion path: emits rolls_exhausted -> negative_hit on frozen shell.
	_tracker.rolls_left = 1
	_tracker.use_roll()

	# 0.45s: negative_hit done (0.4s), watchdog (0.6s) not yet fired.
	await get_tree().create_timer(0.45).timeout
	var pre_watchdog: Vector2 = _roll_ui.roll_button_shell.scale
	print("[ScaleWatchdogTest] pre-watchdog scale=", pre_watchdog)

	# 1.65s total: watchdog fired at 0.6s, restore (0.15s) complete.
	await get_tree().create_timer(1.2).timeout
	var final_scale: Vector2 = _roll_ui.roll_button_shell.scale
	var final_modulate: Color = _roll_ui.roll_button_shell.modulate
	print("[ScaleWatchdogTest] final scale=", final_scale, " modulate=", final_modulate)

	var ok := true
	if frozen.distance_to(Vector2.ONE) < 0.015:
		print("[ScaleWatchdogTest] FAIL: freeze sample too close to ONE - bug not reproduced")
		ok = false
	if final_scale.distance_to(Vector2.ONE) > 0.005:
		print("[ScaleWatchdogTest] FAIL: scale not restored: ", final_scale)
		ok = false
	if not final_modulate.is_equal_approx(Color(1.0, 1.0, 1.0, 0.88)):
		print("[ScaleWatchdogTest] FAIL: disabled modulate not preserved: ", final_modulate)
		ok = false

	print("[ScaleWatchdogTest] ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
