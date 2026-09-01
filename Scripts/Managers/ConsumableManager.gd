extends Node
class_name ConsumableManager

@export var consumable_defs: Array[ConsumableData] = []
var _defs_by_id := {}
signal definitions_loaded

func _ready() -> void:
	print("ConsumableManager: defs count =", consumable_defs.size())
	for i in range(consumable_defs.size()):
		var d = consumable_defs[i]
		if d == null:
			push_error("ConsumableManager: consumable_defs[%d] is null!" % i)
		else:
			print("  slot %d → %s (id='%s')" % [i, d, d.id])
			_defs_by_id[d.id] = d
	emit_signal("definitions_loaded")

## register_consumable_def(data)
##
## Programmatically register a consumable definition. Useful for testing or dynamic content.
func register_consumable_def(data: ConsumableData) -> void:
	if not data:
		push_error("[ConsumableManager] Cannot register null ConsumableData")
		return
		
	if data.id.is_empty():
		push_error("[ConsumableManager] Cannot register ConsumableData with empty ID")
		return
		
	print("[ConsumableManager] Programmatically registering consumable:", data.id)
	_defs_by_id[data.id] = data
	print("[ConsumableManager] Total registered consumables:", _defs_by_id.size())


## get_available_consumables() -> Array[String]
##
## Returns registered consumable ids that are usable with the run's active
## dice set. Defs with required_dice_sides only appear on matching sets and
## defs listing the current set in excluded_dice_sides are hidden.
func get_available_consumables() -> Array[String]:
	print("[ConsumableManager] Getting available consumables")
	var available: Array[String] = []
	var sides := get_current_dice_sides()

	for id in _defs_by_id.keys():
		var def: ConsumableData = _defs_by_id[id]
		if def and def.is_available_for_dice_sides(sides):
			print("Found consumable:", id)
			available.append(id)
		elif def:
			print("[ConsumableManager] Filtering out %s: not available for d%d dice set" % [id, sides])

	print("Available consumables:", available)
	return available

## get_current_dice_sides() -> int
##
## Resolves the side count of the run's active dice set from RoundManager
## (set from ChannelManager.selected_dice_type at run start). Defaults to 6
## when no round manager is available, e.g. before a run starts.
func get_current_dice_sides() -> int:
	if not is_inside_tree():
		return 6
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager:
		var run_type = round_manager.get("run_dice_type")
		if run_type is String and run_type != "":
			return dice_type_to_sides(run_type)
	return 6

## dice_type_to_sides(dice_type: String) -> int
##
## Parses a dice type string like "d4"/"d6" into its side count.
## Returns 6 for anything unparseable.
static func dice_type_to_sides(dice_type: String) -> int:
	var digits := dice_type.trim_prefix("d")
	if digits.is_valid_int():
		return int(digits)
	return 6

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
