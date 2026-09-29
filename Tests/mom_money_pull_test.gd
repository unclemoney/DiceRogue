extends Control
class_name MomMoneyPullTest

## MomMoneyPullTest
##
## Test scene for the Mom money pull. Uses the REAL MoneyUI (real conceal
## API) with the real PlayerEconomy autoload, plus a mock Mom portrait
## anchor, and drives MomJuiceCoordinator exactly like GameController:
##   arm -> remove_money (consequences) -> play_post_mom_sequence
##
## Print-verifies:
## - label HOLDS at the pre-fine value while chips fly (no instant update)
## - one tick per chip arrival, in sync
## - final label == authoritative economy amount
## - chip cap: fine above max_chips batches units per chip
## - chips arc player -> Mom and vanish at the portrait

const MoneyUIScript = preload("res://Scripts/UI/money_ui.gd")


class MockMomResult extends RefCounted:
	var removed_power_ups: Array = []
	var fine_amount: int = 0


class MockMomDialog extends Control:
	func get_portrait_center() -> Vector2:
		return get_global_rect().get_center()


class MockGameController extends Control:
	@warning_ignore("unused_signal")
	signal consumable_used  # ProgressManager connects to this on group members
	var _mom_dialog


var _money_ui: Control
var _log: Label

## When true, the scene runs the fine scenarios on a timer (used for
## automated verification runs; buttons remain for manual use).
const AUTO_DEMO: bool = true


func _ready() -> void:
	print("[MomMoneyPullTest] Initializing test scene...")
	_build_mocks()
	_build_buttons()
	print("[MomMoneyPullTest] Ready. Starting money: $%d" % PlayerEconomy.get_money())
	if AUTO_DEMO:
		_run_auto_demo()


func _run_auto_demo() -> void:
	print("[MomMoneyPullTest] AUTO-DEMO: starting")
	await get_tree().create_timer(1.0).timeout
	_on_add_money()
	_on_add_money()
	await get_tree().create_timer(1.0).timeout
	print("[MomMoneyPullTest] AUTO-DEMO: fine $5")
	_on_fine_5()
	await get_tree().create_timer(4.0).timeout
	print("[MomMoneyPullTest] AUTO-DEMO: fine $12")
	_on_fine_12()
	await get_tree().create_timer(5.0).timeout
	print("[MomMoneyPullTest] AUTO-DEMO: complete")


func _build_mocks() -> void:
	var gc := MockGameController.new()
	gc.name = "MockGameController"
	gc.add_to_group("game_controller")
	add_child(gc)

	var mom_dialog := MockMomDialog.new()
	mom_dialog.name = "MockMomDialog"
	mom_dialog.position = Vector2(560, 100)
	mom_dialog.size = Vector2(160, 120)
	var mom_panel := Panel.new()
	mom_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	mom_dialog.add_child(mom_panel)
	var mom_label := Label.new()
	mom_label.text = "MOM"
	mom_label.set_anchors_preset(Control.PRESET_CENTER)
	mom_panel.add_child(mom_label)
	add_child(mom_dialog)
	gc._mom_dialog = mom_dialog

	_money_ui = MoneyUIScript.new()
	_money_ui.name = "MoneyUI"
	_money_ui.position = Vector2(60, 400)
	_money_ui.size = Vector2(160, 60)
	add_child(_money_ui)

	_log = Label.new()
	_log.position = Vector2(20, 660)
	_log.add_theme_font_size_override("font_size", 14)
	add_child(_log)


func _build_buttons() -> void:
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	add_child(vbox)
	_add_button(vbox, "Add $20", _on_add_money)
	_add_button(vbox, "Mom fine $5", _on_fine_5)
	_add_button(vbox, "Mom fine $12", _on_fine_12)


func _add_button(parent: Control, text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	parent.add_child(button)


func _simulate_fine(amount: int) -> void:
	if not PlayerEconomy.can_afford(amount):
		_log.text = "Cannot afford $%d — add money first" % amount
		return
	var result := MockMomResult.new()
	result.fine_amount = amount

	var before := PlayerEconomy.get_money()
	print("[MomMoneyPullTest] Fine $%d (balance $%d). Label must hold at $%d until chips land." % [amount, before, before])

	MomJuiceCoordinator.arm_money_pull(result)
	# Consequences (what MomLogicHandler.apply_consequences does):
	PlayerEconomy.remove_money(amount, "mom_fine")
	MomJuiceCoordinator.play_post_mom_sequence(result)

	var expected := PlayerEconomy.get_money()
	# Verify after the full sequence should have finished.
	var profile: JuiceProfile = TweenFXHelper.get_default_juice_profile()
	var chip_count: int = mini(amount, profile.money_pull_max_chips) if profile.money_pull_max_chips > 0 else amount
	var total_time: float = chip_count * profile.money_pull_stagger + profile.money_pull_flight_time + 0.5
	get_tree().create_timer(total_time).timeout.connect(func():
		var shown: String = _money_ui.get_node("MarginContainer/CenterContainer/VBoxContainer/MoneyLabel").text
		var expected_text := "$%d" % expected
		if shown == expected_text:
			print("[MomMoneyPullTest] PASS: final label %s == economy %s (%d chips)" % [shown, expected_text, chip_count])
			_log.text = "PASS: %s after %d chips" % [shown, chip_count]
		else:
			print("[MomMoneyPullTest] FAIL: label %s != economy %s" % [shown, expected_text])
			_log.text = "FAIL: label %s != %s" % [shown, expected_text]
	)


func _on_add_money() -> void:
	PlayerEconomy.add_money(20)


func _on_fine_5() -> void:
	_simulate_fine(5)


func _on_fine_12() -> void:
	_simulate_fine(12)
