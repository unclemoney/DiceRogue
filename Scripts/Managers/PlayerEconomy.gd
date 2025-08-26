extends Node

signal money_changed(new_amount: int)

var money: int = 500:
	set(value):
		money = value
		emit_signal("money_changed", money)

func _ready() -> void:
	print("[PlayerEconomy] Ready - Starting money:", money)

func add_money(amount: int) -> void:
	print("[PlayerEconomy] Adding money:", amount)
	money += amount

func remove_money(amount: int) -> bool:
	if can_afford(amount):
		print("[PlayerEconomy] Removing money:", amount)
		money -= amount
		return true
	print("[PlayerEconomy] Cannot afford amount:", amount)
	return false

func can_afford(amount: int) -> bool:
	return money >= amount