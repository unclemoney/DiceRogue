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


## get_state() -> Dictionary
##
## Returns this power-up's running state (counters, totals, remaining uses)
## for the run save. Base implementation returns empty: stateless power-ups
## need no override. Subclasses with mutable runtime state must override.
func get_state() -> Dictionary:
	return {}


## load_state(state)
##
## Restores running state saved by get_state(). Called by GameController
## after the power-up is re-granted during a save load, so apply() has
## already run — overrides must correct any registration apply() made with
## default values (e.g. re-register ScoreModifierManager sources).
func load_state(_state: Dictionary) -> void:
	pass
