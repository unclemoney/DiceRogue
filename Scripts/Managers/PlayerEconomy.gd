extends Node

## PlayerEconomy
##
## Simple player economy manager. Tracks the player's money and emits
## `money_changed(new_amount)` whenever the balance is modified. Public API
## includes `add_money`, `remove_money`, `can_afford`, and `get_money`.

signal money_changed(new_amount: float, change: float)

## Current money balance in dollars. Mutated by add_money/remove_money.
var money: float = 1.0

## Piggy Bank savings that persist across mall zone changes (the PowerUp
## node is freed on zone change; this value is not). Reset only on a full
## new game via reset_piggy_bank_savings().
var piggy_bank_savings: float = 0.0

## _ready()
##
## Lifecycle: logs starting money to the console.
func _ready() -> void:
	print("[PlayerEconomy] Ready - Starting money:", money)

## add_money(amount)
##
## Adds `amount` to the player's balance and emits `money_changed`.
## Also tracks the earning in statistics.
func add_money(amount: float) -> void:
	money = snappedf(money + amount, 0.01)

	# Track the earning in statistics
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		stats.add_money_earned(amount)

	emit_signal("money_changed", money, amount)

## remove_money(amount, category) -> bool
##
## Subtracts `amount` from the player's balance and emits `money_changed`.
## Optionally tracks spending by category in statistics.
## Returns true on success (keeps original behavior).
func remove_money(amount: float, category: String = "") -> bool:
	print("[PlayerEconomy] Removing money:", amount, "category:", category)
	money = snappedf(money - amount, 0.01)

	# Track the spending in statistics
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		stats.spend_money(amount, category)

	print("[PlayerEconomy] Emitting money_changed:", money)
	emit_signal("money_changed", money, -amount)
	return true

## can_afford(amount) -> bool
##
## Returns true if the player has at least `amount` money.
func can_afford(amount: float) -> bool:
	return money + 0.000001 >= amount

## get_money() -> float
##
## Returns the current money balance.
func get_money() -> float:
	return money


## reset_to_starting_money() -> void
##
## Resets money to the starting amount (1.0). Called on new channel start.
## Does NOT touch piggy_bank_savings — those persist across zone changes.
func reset_to_starting_money() -> void:
	var starting_money := 1.0
	var change := starting_money - money
	money = starting_money
	print("[PlayerEconomy] Reset to starting money:", money)
	emit_signal("money_changed", money, change)

## reset_piggy_bank_savings() -> void
##
## Clears persisted Piggy Bank savings. Called on a full new game.
func reset_piggy_bank_savings() -> void:
	piggy_bank_savings = 0.0
	print("[PlayerEconomy] Piggy Bank savings reset")

## get_state() -> Dictionary
##
## Returns the current economy state for saving.
func get_state() -> Dictionary:
	return {"money": money, "piggy_bank_savings": piggy_bank_savings}


## load_state(state)
##
## Restores the economy state from a saved dictionary.
func load_state(state: Dictionary) -> void:
	money = float(state.get("money", 1.0))
	piggy_bank_savings = float(state.get("piggy_bank_savings", 0.0))
	emit_signal("money_changed", money, 0.0)
