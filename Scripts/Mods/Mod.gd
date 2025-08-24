extends Node
class_name Mod

@export var id: String
var target: Node

signal mod_applied
signal mod_removed

func _ready() -> void:
	add_to_group("mods")

func apply(_target) -> void:
	push_error("Mod.apply() must be overridden")

func remove() -> void:
	push_error("Mod.remove() must be overridden")
