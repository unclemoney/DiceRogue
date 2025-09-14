extends Node

signal money_changed(new_amount: int)

var money: int = 100:
	set(value):
		money = value
		print("[PlayerEconomy] Emitting money_changed:", money)
		print("[PlayerEconomy] Instance ID:", self.get_instance_id())
		emit_signal("money_changed", money)

func _ready() -> void:
	print("[PlayerEconomy] Ready - Starting money:", money)

func add_money(amount: int) -> void:
	print("[PlayerEconomy] Adding money:", amount)
	money += amount

func remove_money(amount: int) -> bool:
	print("[PlayerEconomy] Removing money:", amount)
	money -= amount
	return true

func can_afford(amount: int) -> bool:
	print("[PlayerEconomy] Checking affordability for:", amount)
	return money >= amount

func get_money() -> int:
	return money