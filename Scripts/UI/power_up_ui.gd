# PowerUpUI.gd
extends Control
class_name PowerUpUI

@onready var container := $Container
const PowerUpIconScene := preload("res://Scenes/PowerUp/power_up_icon.tscn")

func _ready() -> void:
	container = get_node_or_null("Container")
	if container == null:
		push_error("PowerUpUI: missing HBoxContainer child named 'Container'")

func add_power_up(data: PowerUpData) -> PowerUpIcon:
	print("[PowerUpUI] add_power_up called. data =", data)
	if container == null:
		push_error("PowerUpUI: 'Container' not found")
		return null

	var icon := PowerUpIconScene.instantiate() as PowerUpIcon
	icon.set_data(data)
	container.add_child(icon)
	return icon


	container.add_child(icon)
	return icon

func add_power_up_data(data: PowerUpData) -> PowerUpIcon:
	return add_power_up(data)

func _populate_powerups(list_of_data: Array[PowerUpData]) -> void:
	for data in list_of_data:
		var icon = PowerUpIconScene.instantiate() as PowerUpIcon
		icon.set_data(data)
		container.add_child(icon)
