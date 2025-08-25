extends Node
class_name ModManager

@export var mod_defs: Array[ModData] = []
var _defs_by_id := {}
signal definitions_loaded

func _ready() -> void:
	print("ModManager: defs count =", mod_defs.size())
	for mod in mod_defs:
		if mod:
			print("ModManager: Registering mod:", mod.id)
			_defs_by_id[mod.id] = mod
		else:
			push_error("ModManager: Found null mod definition")
	emit_signal("definitions_loaded")

func get_available_mods() -> Array[String]:
	print("[ModManager] Getting available mods")
	var available: Array[String] = []
	
	for id in _defs_by_id.keys():
		print("Found mod:", id)
		available.append(id)
		
	print("Available mods:", available)
	return available

func spawn_mod(id: String, target: Node) -> Mod:
	print("ModManager.spawn_mod(): id='%s', target='%s'" % [id, target.name])
	var def = _defs_by_id.get(id)
	if not def:
		push_error("ModManager: No mod found for id: %s" % id)
		return null
		
	if def.scene == null:
		push_error("ModManager: ModData[%s].scene is null" % id)
		return null

	print("Attempting to instantiate scene:", def.scene.resource_path)
	var mod = def.scene.instantiate() as Mod
	if not mod:
		push_error("ModManager: Failed to instantiate scene for '%s'" % id)
		return null
		
	mod.id = id
	return mod

func get_def(id: String) -> ModData:
	return _defs_by_id.get(id)