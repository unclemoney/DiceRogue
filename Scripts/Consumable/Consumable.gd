extends Node
class_name Consumable

@export var id: String

func apply(target) -> void:
	push_error("Consumable.apply() must be overridden")

func consume() -> void:
	queue_free()