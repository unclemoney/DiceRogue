extends Node2D
class_name PowerUp

signal max_rolls_changed(new_max: int)

@export var id: String

func apply(_target) -> void:
	pass

func remove(_target) -> void:
	pass


func is_replica_instance() -> bool:
	return id.find("_replica") != -1


func get_runtime_modifier_source_name(default_source: String) -> String:
	if id != "" and is_replica_instance():
		return id
	return default_source


func get_runtime_power_up_id(default_id: String = "") -> String:
	if id != "":
		return id
	return default_id
