extends Node
class_name ConsumableManager

@export var consumable_defs: Array[ConsumableData] = []
var _defs_by_id := {}

func _ready() -> void:
	print("ConsumableManager: defs count =", consumable_defs.size())
	for i in range(consumable_defs.size()):
		var d = consumable_defs[i]
		if d == null:
			push_error("ConsumableManager: consumable_defs[%d] is null!" % i)
		else:
			print("  slot %d → %s (id='%s')" % [i, d, d.id])
			_defs_by_id[d.id] = d

func spawn_consumable(id: String, parent: Node) -> Consumable:
	print("ConsumableManager.spawn_consumable(): id='%s', parent='%s'" % [id, parent.name])
	var def = _defs_by_id.get(id, null)
	if def == null:
		push_error("ConsumableManager.spawn_consumable(): no data found for id '%s'" % id)
		return null

	if def.scene == null:
		push_error("ConsumableManager.spawn_consumable(): ConsumableData[%s].scene is null" % id)
		print("  Scene path:", def.scene.resource_path if def.scene else "null")
		return null

	print("Attempting to instantiate scene:", def.scene.resource_path)
	print("Scene validity check:", def.scene.can_instantiate())
	
	var inst = def.scene.instantiate()
	print("Raw instance type:", inst.get_class())
	print("Script path:", inst.get_script().resource_path)
	print("Parent script:", inst.get_script().get_base_script().resource_path if inst.get_script().get_base_script() else "null")
	
	var consumable_inst = inst as Consumable
	if consumable_inst == null:
		push_error("ConsumableManager.spawn_consumable(): failed to instantiate scene for '%s'" % id)
		print("  Instantiation failed, scene might not inherit from Consumable")
		return null

	parent.add_child(consumable_inst)
	return consumable_inst

func get_def(id: String) -> ConsumableData:
	return _defs_by_id.get(id)
