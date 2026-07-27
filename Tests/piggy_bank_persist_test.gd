extends Node

## piggy_bank_persist_test.gd
##
## Verifies ThePiggyBankPowerUp savings persistence via PlayerEconomy:
##   1. apply() restores accumulated_savings from PlayerEconomy.piggy_bank_savings.
##   2. Each roll writes the new total back to PlayerEconomy.
##   3. Selling pays out the savings and zeroes the persisted amount.
##   4. PlayerEconomy.get_state()/load_state() round-trips the savings.
## The autoload's money/savings are preserved and restored after the test.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/PiggyBankPersistTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const PIGGY_SCENE: PackedScene = preload("res://Scenes/PowerUp/ThePiggyBankPowerUp.tscn")

var _failures: int = 0
var _saved_savings: int = 0
var _saved_money: int = 0


## Minimal DiceHand stand-in exposing the roll_complete signal.
class FakeDiceHand extends Node:
	signal roll_complete


func _ready() -> void:
	print("[PiggyBankPersistTest] Starting")
	_saved_savings = PlayerEconomy.piggy_bank_savings
	_saved_money = PlayerEconomy.money

	_test_apply_restores_savings()
	_test_roll_write_back()
	_test_sale_zeroes_savings()
	_test_state_round_trip()

	# Restore autoload state
	PlayerEconomy.piggy_bank_savings = _saved_savings
	PlayerEconomy.money = _saved_money

	if _failures == 0:
		print("[PiggyBankPersistTest] PASS - all checks passed")
	else:
		print("[PiggyBankPersistTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[PiggyBankPersistTest] OK: " + label)
	else:
		push_error("[PiggyBankPersistTest] FAILED: " + label)
		_failures += 1


func _make_piggy(target: Node) -> Node:
	var piggy = PIGGY_SCENE.instantiate()
	add_child(piggy)
	piggy.apply(target)
	return piggy


func _test_apply_restores_savings() -> void:
	var hand := FakeDiceHand.new()
	add_child(hand)

	PlayerEconomy.piggy_bank_savings = 0
	var fresh = _make_piggy(hand)
	_check("fresh run restores $0", fresh.accumulated_savings == 0)
	fresh.queue_free()

	PlayerEconomy.piggy_bank_savings = 42
	var restored = _make_piggy(hand)
	_check("apply() restores persisted $42", restored.accumulated_savings == 42)
	restored.queue_free()
	hand.queue_free()


func _test_roll_write_back() -> void:
	var hand := FakeDiceHand.new()
	add_child(hand)

	PlayerEconomy.piggy_bank_savings = 42
	var piggy = _make_piggy(hand)
	hand.roll_complete.emit()
	_check("roll adds $3 to savings", piggy.accumulated_savings == 45)
	_check("roll writes $45 back to PlayerEconomy", PlayerEconomy.piggy_bank_savings == 45)
	hand.roll_complete.emit()
	_check("second roll writes $48 back", PlayerEconomy.piggy_bank_savings == 48)

	piggy.queue_free()
	hand.queue_free()


func _test_sale_zeroes_savings() -> void:
	var hand := FakeDiceHand.new()
	add_child(hand)

	PlayerEconomy.piggy_bank_savings = 48
	var money_before: int = PlayerEconomy.money
	var piggy = _make_piggy(hand)

	piggy._on_power_up_sold("other_powerup")
	_check("selling another PowerUp pays nothing", PlayerEconomy.money == money_before)
	_check("selling another PowerUp keeps savings", PlayerEconomy.piggy_bank_savings == 48)

	piggy._on_power_up_sold("the_piggy_bank")
	_check("sale pays out the $48 savings", PlayerEconomy.money == money_before + 48)
	_check("sale zeroes the persisted savings", PlayerEconomy.piggy_bank_savings == 0)

	piggy.queue_free()
	hand.queue_free()


func _test_state_round_trip() -> void:
	PlayerEconomy.piggy_bank_savings = 77
	var state: Dictionary = PlayerEconomy.get_state()
	_check("get_state() includes piggy_bank_savings", state.has("piggy_bank_savings"))
	_check("get_state() saves $77", int(state.get("piggy_bank_savings", -1)) == 77)

	PlayerEconomy.piggy_bank_savings = 0
	PlayerEconomy.load_state(state)
	_check("load_state() restores $77", PlayerEconomy.piggy_bank_savings == 77)

	PlayerEconomy.load_state({})
	_check("load_state() defaults missing savings to $0", PlayerEconomy.piggy_bank_savings == 0)
