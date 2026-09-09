extends Control

## debuff_fuel_test.gd
##
## Verifies the four debuff-fueled items:
## - Defiance PowerUp: registers x(1.0 + 0.25 per active debuff), recomputes on
##   debuff_applied/debuff_ended, unregisters on remove().
## - Spite consumable: arms x(1.0 + 0.5 per active debuff), disarms after one score.
## - Antidote consumable: cleanses the highest-intensity active debuff.
## - Immunity consumable: sets/clears the DebuffManager next-round immunity flag.

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


## StubGameController
##
## Minimal stand-in exposing what the debuff-fueled items touch on
## GameController: active_debuffs, scorecard, turn_tracker, debuff_manager,
## the debuff_applied signal, and disable_debuff.
class StubGameController extends Node:
	signal debuff_applied(id: String, debuff: Debuff)

	var active_debuffs: Dictionary = {}
	var scorecard: Scorecard = null
	var turn_tracker = null
	var debuff_manager: DebuffManager = null
	var disabled_ids: Array[String] = []

	func disable_debuff(id: String, _clear_runtime_state_immediately: bool = false) -> void:
		disabled_ids.append(id)
		var debuff = active_debuffs.get(id)
		if debuff:
			debuff.is_active = false
			debuff.emit_signal("debuff_ended")
		active_debuffs.erase(id)


func _ready() -> void:
	print("\n=== DEBUFF FUEL TEST ===")
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


func _make_mock_debuff(id: String, intensity: float) -> Debuff:
	var debuff := Debuff.new()
	debuff.id = id
	debuff.set_intensity(intensity)
	debuff.is_active = true
	return debuff


func _smm():
	return get_node_or_null("/root/ScoreModifierManager")


func _run_tests() -> void:
	_test_resource_files()
	_test_defiance()
	_test_spite()
	_test_antidote()
	_test_immunity()


func _test_resource_files() -> void:
	var defiance: PowerUpData = load("res://Scripts/PowerUps/DefiancePowerUp.tres")
	_check(defiance != null, "DefiancePowerUp.tres loads")
	if defiance:
		_check(defiance.id == "defiance", "defiance tres id")
		_check(defiance.display_name == "Defiance", "defiance tres display_name")
		_check(defiance.scene != null, "defiance tres has scene")

	var spite: ConsumableData = load("res://Scripts/Consumable/SpiteConsumable.tres")
	_check(spite != null, "SpiteConsumable.tres loads")
	if spite:
		_check(spite.id == "spite", "spite tres id")
		_check(spite.display_name == "Spite", "spite tres display_name")
		_check(spite.scene != null, "spite tres has scene")

	var antidote: ConsumableData = load("res://Scripts/Consumable/AntidoteConsumable.tres")
	_check(antidote != null, "AntidoteConsumable.tres loads")
	if antidote:
		_check(antidote.id == "antidote", "antidote tres id")
		_check(antidote.display_name == "Antidote", "antidote tres display_name")

	var immunity: ConsumableData = load("res://Scripts/Consumable/ImmunityConsumable.tres")
	_check(immunity != null, "ImmunityConsumable.tres loads")
	if immunity:
		_check(immunity.id == "immunity", "immunity tres id")
		_check(immunity.display_name == "Immunity", "immunity tres display_name")


func _test_defiance() -> void:
	var smm = _smm()
	_check(smm != null, "ScoreModifierManager autoload available")
	if not smm:
		return
	smm.reset()

	var stub := StubGameController.new()
	stub.name = "StubGameController"
	stub.add_to_group("game_controller")
	add_child(stub)

	var defiance := DefiancePowerUp.new()
	add_child(defiance)
	defiance.apply(null)

	# 0 debuffs -> x1.00
	_check(smm.has_multiplier("defiance"), "Defiance registers multiplier on apply")
	_check(is_equal_approx(smm.get_multiplier("defiance"), 1.0), "Defiance x1.00 with 0 debuffs")

	# 1 debuff -> x1.25
	var d1 := _make_mock_debuff("mock_a", 1.0)
	stub.active_debuffs["mock_a"] = d1
	stub.emit_signal("debuff_applied", "mock_a", d1)
	_check(is_equal_approx(smm.get_multiplier("defiance"), 1.25), "Defiance x1.25 with 1 debuff")

	# 3 debuffs -> x1.75
	var d2 := _make_mock_debuff("mock_b", 2.0)
	var d3 := _make_mock_debuff("mock_c", 1.5)
	stub.active_debuffs["mock_b"] = d2
	stub.emit_signal("debuff_applied", "mock_b", d2)
	stub.active_debuffs["mock_c"] = d3
	stub.emit_signal("debuff_applied", "mock_c", d3)
	_check(is_equal_approx(smm.get_multiplier("defiance"), 1.75), "Defiance x1.75 with 3 debuffs")

	# One debuff ends -> x1.50 (is_active is false when debuff_ended emits)
	d2.is_active = false
	d2.emit_signal("debuff_ended")
	_check(is_equal_approx(smm.get_multiplier("defiance"), 1.5), "Defiance x1.50 after a debuff ends")

	# Mom-granted buffs never count
	var buff := _make_mock_debuff("rebellion", 1.0)
	stub.active_debuffs["rebellion"] = buff
	stub.emit_signal("debuff_applied", "rebellion", buff)
	_check(is_equal_approx(smm.get_multiplier("defiance"), 1.5), "Defiance ignores Mom-granted buffs")

	# Remove -> unregisters
	defiance.remove(null)
	_check(not smm.has_multiplier("defiance"), "Defiance unregisters multiplier on remove")

	defiance.queue_free()
	stub.remove_from_group("game_controller")
	stub.queue_free()
	d1.free()
	d2.free()
	d3.free()
	buff.free()


func _test_spite() -> void:
	var smm = _smm()
	if not smm:
		_check(false, "ScoreModifierManager autoload available (spite)")
		return
	smm.reset()

	# Case 1: no debuffs -> does not arm
	var stub_empty := StubGameController.new()
	stub_empty.scorecard = Scorecard.new()
	var spite_empty := SpiteConsumable.new()
	add_child(spite_empty)
	spite_empty.apply(stub_empty)
	_check(not spite_empty.is_armed, "Spite does not arm with 0 debuffs")
	_check(not smm.has_multiplier("spite"), "Spite registers nothing with 0 debuffs")
	spite_empty.free()
	stub_empty.scorecard.free()
	stub_empty.free()

	# Case 2: 2 debuffs -> arms at x2.00, disarms on first score
	var stub := StubGameController.new()
	stub.scorecard = Scorecard.new()
	stub.active_debuffs["mock_a"] = _make_mock_debuff("mock_a", 1.0)
	stub.active_debuffs["mock_b"] = _make_mock_debuff("mock_b", 3.0)

	var spite := SpiteConsumable.new()
	add_child(spite)
	spite.apply(stub)
	_check(spite.is_armed, "Spite arms with active debuffs")
	_check(is_equal_approx(smm.get_multiplier("spite"), 2.0), "Spite x2.00 with 2 debuffs")

	stub.scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 20)
	_check(not spite.is_armed, "Spite disarms after one scored category")
	_check(not smm.has_multiplier("spite"), "Spite unregisters multiplier after disarm")

	for debuff in stub.active_debuffs.values():
		debuff.free()
	spite.free()
	stub.scorecard.free()
	stub.free()


func _test_antidote() -> void:
	# Case 1: picks the highest-intensity active debuff
	var stub := StubGameController.new()
	var low := _make_mock_debuff("mock_low", 1.0)
	var high := _make_mock_debuff("mock_high", 2.5)
	var mid := _make_mock_debuff("mock_mid", 1.5)
	stub.active_debuffs["mock_low"] = low
	stub.active_debuffs["mock_high"] = high
	stub.active_debuffs["mock_mid"] = mid

	var antidote := AntidoteConsumable.new()
	antidote.apply(stub)
	_check(stub.disabled_ids == ["mock_high"], "Antidote cleanses highest-intensity debuff")
	_check(not stub.active_debuffs.has("mock_high"), "Antidote target removed from active_debuffs")
	_check(stub.active_debuffs.has("mock_low") and stub.active_debuffs.has("mock_mid"), "Antidote leaves other debuffs active")

	low.free()
	high.free()
	mid.free()
	stub.free()

	# Case 2: no debuffs -> no-op without error
	var stub_empty := StubGameController.new()
	var antidote_empty := AntidoteConsumable.new()
	antidote_empty.apply(stub_empty)
	_check(stub_empty.disabled_ids.is_empty(), "Antidote no-ops with 0 debuffs")
	antidote_empty.free()
	stub_empty.free()

	# Case 3: Mom-granted buffs are never cleansed
	var stub_buff := StubGameController.new()
	var buff := _make_mock_debuff("rebellion", 3.0)
	stub_buff.active_debuffs["rebellion"] = buff
	var antidote_buff := AntidoteConsumable.new()
	antidote_buff.apply(stub_buff)
	_check(stub_buff.disabled_ids.is_empty(), "Antidote never cleanses Mom-granted buffs")
	buff.free()
	antidote_buff.free()
	stub_buff.free()


func _test_immunity() -> void:
	var manager := DebuffManager.new()
	add_child(manager)

	var stub := StubGameController.new()
	stub.debuff_manager = manager

	_check(not manager.has_immunity_next_round(), "Immunity flag starts clear")

	var immunity := ImmunityConsumable.new()
	immunity.apply(stub)
	_check(manager.has_immunity_next_round(), "Immunity consumable sets the flag")

	_check(manager.consume_immunity_next_round(), "First consume returns true")
	_check(not manager.has_immunity_next_round(), "Consume clears the flag")
	_check(not manager.consume_immunity_next_round(), "Second consume returns false (already cleared)")

	immunity.free()
	stub.free()
	manager.queue_free()


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[DebuffFuelTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	if _failures == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)
