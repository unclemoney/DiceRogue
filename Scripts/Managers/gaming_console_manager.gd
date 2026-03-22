extends Node
class_name GamingConsoleManager

## GamingConsoleManager
##
## Manages gaming console definitions and spawning, following the
## same pattern as PowerUpManager.

signal definitions_loaded

@export var console_defs: Array[GamingConsoleData]

var _defs_by_id := {}


func _ready() -> void:
	for def in console_defs:
		if def and def.id != "":
			_defs_by_id[def.id] = def
	print("[GamingConsoleManager] Loaded %d console definitions" % _defs_by_id.size())
	emit_signal("definitions_loaded")


## get_def(id) -> GamingConsoleData
##
## Returns the data resource for the given console ID, or null.
func get_def(id: String) -> GamingConsoleData:
	return _defs_by_id.get(id, null)


## get_available_consoles() -> Array[String]
##
## Returns all registered console IDs.
func get_available_consoles() -> Array[String]:
	var ids: Array[String] = []
	for key in _defs_by_id.keys():
		ids.append(key)
	return ids


## spawn_console(id, parent, pos) -> GamingConsole
##
## Instantiates a console scene from the definition and adds it to the parent.
func spawn_console(id: String, parent: Node, pos: Vector2 = Vector2.ZERO) -> GamingConsole:
	var def = get_def(id)
	if not def:
		push_error("[GamingConsoleManager] No definition found for id: %s" % id)
		return null
	if not def.scene:
		push_error("[GamingConsoleManager] No scene set for console: %s" % id)
		return null

	var instance = def.scene.instantiate() as GamingConsole
	if not instance:
		push_error("[GamingConsoleManager] Failed to instantiate console: %s" % id)
		return null

	instance.position = pos
	parent.add_child(instance)
	print("[GamingConsoleManager] Spawned console: %s" % id)
	return instance
