extends Node
class_name Debuff

@export var id: String
var target: Node
var is_active := false

signal debuff_started
signal debuff_ended

func start() -> void:
	print("[Debuff] Starting debuff:", id)
	is_active = true
	apply(target)
	emit_signal("debuff_started")

func apply(_target) -> void:
	push_error("Debuff.apply() must be overridden")

func remove() -> void:
	push_error("Debuff.remove() must be overridden")

func end() -> void:
	print("[Debuff] Ending debuff:", id)
	is_active = false
	remove()
	emit_signal("debuff_ended")
