extends Node
class_name PowerUpManager

@export var power_up_defs: Array[PowerUpData] = []
var _defs_by_id := {}

func _ready() -> void:
	print("PowerUpManager: defs count =", power_up_defs.size())
	for i in range(power_up_defs.size()):
		var d = power_up_defs[i]
		if d == null:
			push_error("PowerUpManager: power_up_defs[ %d ] is null!" % i)
		else:
			print("  slot %d → %s (id='%s')" % [i, d, d.id])
			_defs_by_id[d.id] = d



func spawn_power_up(id:String, parent:Node2D, pos:Vector2=Vector2.ZERO) -> PowerUp:
	var def = _defs_by_id.get(id, null)
	if def == null:
		push_error("PowerUpManager.spawn_power_up(): no data found for id '%s'" % id)
		return null

	if def.scene == null:
		push_error("PowerUpManager.spawn_power_up(): PowerUpData[%s].scene is null" % id)
		return null

	var inst = def.scene.instantiate() as PowerUp
	if inst == null:
		push_error("PowerUpManager.spawn_power_up(): failed to instantiate scene for '%s'" % id)
		return null

	parent.add_child(inst)
	inst.position = pos
	return inst

func get_def(id: String) -> PowerUpData:
	return _defs_by_id.get(id)
