extends Node
class_name PowerUp

@export var id: String

func apply(target) -> void:
	push_error("PowerUp.apply() must be overridden")

func remove(target) -> void:
	pass
