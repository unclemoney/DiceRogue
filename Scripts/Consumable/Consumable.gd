extends Node
class_name Consumable

@export var id: String

var apply_succeeded: bool = true

func apply(_target) -> void:
	push_error("Consumable.apply() must be overridden")

func consume() -> void:
	queue_free()