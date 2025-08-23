extends Node
class_name DebuffManager

@export var debuff_defs: Array[DebuffData] = []
var _defs_by_id := {}

func _ready() -> void:
	print("DebuffManager: defs count =", debuff_defs.size())
	for i in range(debuff_defs.size()):
		var d = debuff_defs[i]
		if d == null:
			push_error("DebuffManager: debuff_defs[%d] is null!" % i)
		else:
			print("  slot %d → %s (id='%s')" % [i, d, d.id])
			_defs_by_id[d.id] = d

func spawn_debuff(id: String, target: Node) -> Debuff:
	print("DebuffManager.spawn_debuff(): id='%s', target='%s'" % [id, target.name])
	var def = _defs_by_id.get(id)
	if not def:
		push_error("DebuffManager: No debuff found for id: %s" % id)
		return null
		
	if def.scene == null:
		push_error("DebuffManager: DebuffData[%s].scene is null" % id)
		return null

	print("Attempting to instantiate scene:", def.scene.resource_path)
	var debuff = def.scene.instantiate() as Debuff
	if not debuff:
		push_error("DebuffManager: Failed to instantiate scene for '%s'" % id)
		return null

	target.add_child(debuff)
	debuff.id = id
	return debuff

func get_def(id: String) -> DebuffData:
	return _defs_by_id.get(id)
