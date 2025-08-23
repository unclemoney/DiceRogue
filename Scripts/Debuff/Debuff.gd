extends Node
class_name Debuff

@export var id: String
var target: Node

signal debuff_started
signal debuff_ended

func start() -> void:
	apply(target)
	emit_signal("debuff_started")

func apply(_target) -> void:
	push_error("Debuff.apply() must be overridden")

func remove() -> void:
	push_error("Debuff.remove() must be overridden")

func end() -> void:
	remove()
	emit_signal("debuff_ended")
	queue_free()