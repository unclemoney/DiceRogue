extends Node

## PlayerEconomy
##
## Simple player economy manager. Tracks the player's money and emits
## `money_changed(new_amount)` whenever the balance is modified. Public API
## includes `add_money`, `remove_money`, `can_afford`, and `get_money`.

signal money_changed(new_amount: int)

## Current money balance (int). Mutated by add_money/remove_money.
var money: int = 500

## _ready()
##
## Lifecycle: logs starting money to the console.
func _ready() -> void:
	print("[PlayerEconomy] Ready - Starting money:", money)

## add_money(amount)
##
## Adds `amount` to the player's balance and emits `money_changed`.
func add_money(amount: int) -> void:
	print("[PlayerEconomy] Adding money:", amount)
	money += amount
	print("[PlayerEconomy] Emitting money_changed:", money)
	print("[PlayerEconomy] Instance ID:", self.get_instance_id())
	emit_signal("money_changed", money)

## remove_money(amount) -> bool
##
## Subtracts `amount` from the player's balance and emits `money_changed`.
## Returns true on success (keeps original behavior).
func remove_money(amount: int) -> bool:
	print("[PlayerEconomy] Removing money:", amount)
	money -= amount
	print("[PlayerEconomy] Emitting money_changed:", money)
	print("[PlayerEconomy] Instance ID:", self.get_instance_id())
	emit_signal("money_changed", money)
	return true

## can_afford(amount) -> bool
##
## Returns true if the player has at least `amount` money.
func can_afford(amount: int) -> bool:
	print("[PlayerEconomy] Checking affordability for:", amount)
	return money >= amount

## get_money() -> int
##
## Returns the current money balance.
func get_money() -> int:
	return money