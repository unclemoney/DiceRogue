extends Node

## PlayerEconomy
##
## Simple player economy manager. Tracks the player's money and emits
## `money_changed(new_amount)` whenever the balance is modified. Public API
## includes `add_money`, `remove_money`, `can_afford`, and `get_money`.

signal money_changed(new_amount: int, change: int)

## Current money balance (int). Mutated by add_money/remove_money.
var money: int = 100

## _ready()
##
## Lifecycle: logs starting money to the console.
func _ready() -> void:
	print("[PlayerEconomy] Ready - Starting money:", money)

## add_money(amount)
##
## Adds `amount` to the player's balance and emits `money_changed`.
## Also tracks the earning in statistics.
func add_money(amount: int) -> void:
	#print("[PlayerEconomy] Adding money:", amount)
	money += amount
	
	# Track the earning in statistics
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		stats.add_money_earned(amount)
	
	#print("[PlayerEconomy] Emitting money_changed:", money)
	#print("[PlayerEconomy] Instance ID:", self.get_instance_id())
	emit_signal("money_changed", money, amount)

## remove_money(amount, category) -> bool
##
## Subtracts `amount` from the player's balance and emits `money_changed`.
## Optionally tracks spending by category in statistics.
## Returns true on success (keeps original behavior).
func remove_money(amount: int, category: String = "") -> bool:
	print("[PlayerEconomy] Removing money:", amount, "category:", category)
	money -= amount
	
	# Track the spending in statistics
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		stats.spend_money(amount, category)
	
	print("[PlayerEconomy] Emitting money_changed:", money)
	print("[PlayerEconomy] Instance ID:", self.get_instance_id())
	emit_signal("money_changed", money, -amount)
	return true

## can_afford(amount) -> bool
##
## Returns true if the player has at least `amount` money.
func can_afford(amount: int) -> bool:
	#print("[PlayerEconomy] Checking affordability for:", amount)
	return money >= amount

## get_money() -> int
##
## Returns the current money balance.
func get_money() -> int:
	return money


## reset_to_starting_money() -> void
##
## Resets money to the starting amount (100). Called on new channel start.
func reset_to_starting_money() -> void:
	var starting_money := 100
	var change := starting_money - money
	money = starting_money
	print("[PlayerEconomy] Reset to starting money:", money)
	emit_signal("money_changed", money, change)