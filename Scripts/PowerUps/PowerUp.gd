extends Node2D
class_name PowerUp

signal max_rolls_changed(new_max: int)

@export var id: String

func apply(target) -> void:
	push_error("PowerUp.apply() must be overridden")

func remove(target) -> void:
	pass
