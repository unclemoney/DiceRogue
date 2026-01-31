extends Node
class_name DebuffManager

## DebuffManager
##
## Manages spawning and configuration of debuff instances.
## Applies channel difficulty intensity multiplier to debuffs when spawning.
## Supports automatic debuff selection based on round configuration.

signal debuffs_applied(debuff_ids: Array)

@export var debuff_defs: Array[DebuffData] = []
var _defs_by_id := {}
var _active_debuff_ids: Array[String] = []
var _verbose_mode: bool = false


func _ready() -> void:
	print("[DebuffManager] Loading definitions...")
	_load_definitions()
	# Print registered debuffs
	for id in _defs_by_id:
		print("[DebuffManager] Registered debuff:", id)


func _load_definitions() -> void:
	print("DebuffManager: defs count =", debuff_defs.size())
	print("DebuffManager: loading definitions...", debuff_defs)
	for i in range(debuff_defs.size()):
		var d = debuff_defs[i]
		if d == null:
			push_error("DebuffManager: debuff_defs[%d] is null!" % i)
		else:
			print("  slot %d → %s (id='%s')" % [i, d, d.id])
			_defs_by_id[d.id] = d


## spawn_debuff(id, target) -> Debuff
##
## Spawns a debuff instance with channel difficulty intensity applied.
## The intensity multiplier is retrieved from ChannelManager.
## @param id: String identifier of the debuff
## @param target: Node to attach the debuff to
## @return Debuff: The spawned debuff instance or null on failure
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

	# Apply channel difficulty intensity before adding to tree
	var intensity = _get_debuff_intensity()
	if debuff.has_method("set_intensity"):
		debuff.set_intensity(intensity)
		print("[DebuffManager] Applied intensity %.2f to debuff '%s'" % [intensity, id])

	target.add_child(debuff)
	debuff.id = id
	return debuff


## _get_debuff_intensity() -> float
##
## Gets the debuff intensity multiplier from ChannelManager.
## @return float: The intensity multiplier (1.0 if ChannelManager not found)
func _get_debuff_intensity() -> float:
	var channel_manager = _find_channel_manager()
	if channel_manager and channel_manager.has_method("get_debuff_intensity_multiplier"):
		return channel_manager.get_debuff_intensity_multiplier()
	return 1.0


## _find_channel_manager() -> Node
##
## Locates the ChannelManager in the scene tree.
## @return Node: The ChannelManager or null if not found
func _find_channel_manager():
	# Try to find via the scene root
	var root = get_tree().current_scene
	if root:
		var channel_manager = root.get_node_or_null("ChannelManager")
		if channel_manager:
			return channel_manager
	
	# Try to find via game controller
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		var parent = game_controller.get_parent()
		if parent:
			var channel_manager = parent.get_node_or_null("ChannelManager")
			if channel_manager:
				return channel_manager
	
	return null


func get_def(id: String) -> DebuffData:
	return _defs_by_id.get(id)


## ============== AUTOMATIC DEBUFF SELECTION ==============


## set_verbose_mode(enabled: bool) -> void
##
## Enables or disables verbose logging for debugging.
func set_verbose_mode(enabled: bool) -> void:
	_verbose_mode = enabled
	print("[DebuffManager] Verbose mode:", "ON" if enabled else "OFF")


## get_debuffs_by_difficulty(max_difficulty: int) -> Array[DebuffData]
##
## Returns all registered debuffs with difficulty_rating <= max_difficulty.
## @param max_difficulty: Maximum difficulty rating (1-5)
## @return Array of DebuffData that meet the criteria
func get_debuffs_by_difficulty(max_difficulty: int) -> Array[DebuffData]:
	var result: Array[DebuffData] = []
	for id in _defs_by_id:
		var def = _defs_by_id[id] as DebuffData
		if def and def.difficulty_rating <= max_difficulty:
			result.append(def)
	if _verbose_mode:
		print("[DebuffManager] Found %d debuffs with difficulty <= %d" % [result.size(), max_difficulty])
	return result


## select_debuffs_for_round(max_count, difficulty_cap, allow_duplicates, exclude_ids) -> Array[String]
##
## Randomly selects debuffs for a round respecting count and difficulty limits.
## @param max_count: Maximum number of debuffs to select
## @param difficulty_cap: Maximum difficulty rating allowed
## @param allow_duplicates: If true, can select debuffs already active
## @param exclude_ids: Array of debuff IDs to exclude from selection
## @return Array of debuff IDs to apply
func select_debuffs_for_round(max_count: int, difficulty_cap: int, allow_duplicates: bool = false, exclude_ids: Array = []) -> Array[String]:
	if max_count <= 0:
		if _verbose_mode:
			print("[DebuffManager] max_count is 0, no debuffs selected")
		return []
	
	# Get eligible debuffs
	var eligible = get_debuffs_by_difficulty(difficulty_cap)
	
	# Filter out excluded and already active (if not allowing duplicates)
	var filtered: Array[DebuffData] = []
	for def in eligible:
		if def.id in exclude_ids:
			continue
		if not allow_duplicates and def.id in _active_debuff_ids:
			continue
		filtered.append(def)
	
	if _verbose_mode:
		print("[DebuffManager] Eligible after filtering: %d debuffs" % filtered.size())
		for def in filtered:
			print("  - %s (difficulty %d)" % [def.id, def.difficulty_rating])
	
	if filtered.is_empty():
		if _verbose_mode:
			print("[DebuffManager] No eligible debuffs available")
		return []
	
	# Randomly select up to max_count
	var selected: Array[String] = []
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var pool = filtered.duplicate()
	while selected.size() < max_count and pool.size() > 0:
		var index = rng.randi_range(0, pool.size() - 1)
		var chosen = pool[index]
		selected.append(chosen.id)
		pool.remove_at(index)
		if _verbose_mode:
			print("[DebuffManager] Selected: %s" % chosen.id)
	
	return selected


## apply_round_debuffs(target, round_config, channel_number) -> Array[Debuff]
##
## Automatically selects and applies debuffs for a round based on config.
## Called after challenge reveal so player knows what they're facing.
## @param target: Node to attach debuffs to
## @param round_config: RoundDifficultyConfig with max_debuffs and debuff_difficulty_cap
## @param channel_number: Current channel (for intensity scaling)
## @return Array of spawned Debuff instances
func apply_round_debuffs(target: Node, round_config, channel_number: int) -> Array[Debuff]:
	var spawned: Array[Debuff] = []
	
	if not round_config:
		push_error("[DebuffManager] apply_round_debuffs called with null round_config")
		return spawned
	
	var max_debuffs = round_config.max_debuffs if round_config.get("max_debuffs") != null else 0
	var difficulty_cap = round_config.debuff_difficulty_cap if round_config.get("debuff_difficulty_cap") != null else 1
	
	# Check if channel allows duplicates (channels 16+ allow duplicates for brutality)
	var allow_duplicates = channel_number >= 16
	
	if _verbose_mode:
		print("[DebuffManager] Applying round debuffs:")
		print("  Channel: %d, Max Debuffs: %d, Difficulty Cap: %d, Allow Duplicates: %s" % [
			channel_number, max_debuffs, difficulty_cap, str(allow_duplicates)
		])
	
	# Select debuffs
	var selected_ids = select_debuffs_for_round(max_debuffs, difficulty_cap, allow_duplicates)
	
	# Spawn each selected debuff
	for id in selected_ids:
		var debuff = spawn_debuff(id, target)
		if debuff:
			spawned.append(debuff)
			_active_debuff_ids.append(id)
			print("[DebuffManager] Applied debuff: %s" % id)
	
	# Emit signal for UI/logging
	if spawned.size() > 0:
		emit_signal("debuffs_applied", selected_ids)
	
	return spawned


## clear_active_debuffs() -> void
##
## Clears the tracking of active debuffs. Call at round end.
func clear_active_debuffs() -> void:
	if _verbose_mode:
		print("[DebuffManager] Clearing %d active debuff IDs" % _active_debuff_ids.size())
	_active_debuff_ids.clear()


## get_active_debuff_ids() -> Array[String]
##
## Returns the list of currently active debuff IDs.
func get_active_debuff_ids() -> Array[String]:
	return _active_debuff_ids.duplicate()


## get_all_debuff_info() -> Array[Dictionary]
##
## Returns info about all registered debuffs for debug display.
func get_all_debuff_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	for id in _defs_by_id:
		var def = _defs_by_id[id] as DebuffData
		if def:
			info.append({
				"id": def.id,
				"name": def.display_name,
				"description": def.description,
				"difficulty": def.difficulty_rating,
				"active": def.id in _active_debuff_ids
			})
	return info
