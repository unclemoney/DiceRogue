extends SceneTree

## mom_data_validation_test.gd
##
## Loads every Mom .tres data file and runs its validate() checks.
## Punishment tiers: Resources/Data/Mom/Punishments/
## Dialog nodes:     Resources/Data/Mom/Dialog/ (cross-checked follow-up ids)
##
## Run headless:
##   godot --headless --path . --script Tests/mom_data_validation_test.gd
## Exit code 0 = all valid, 1 = at least one failure.

const PUNISHMENT_DIR := "res://Resources/Data/Mom/Punishments/"
const DIALOG_DIR := "res://Resources/Data/Mom/Dialog/"

var _failures: int = 0


func _init() -> void:
	print("[MomDataValidation] Starting validation")
	_validate_tiers()
	_validate_dialog_nodes()

	if _failures == 0:
		print("[MomDataValidation] PASS - all Mom data files valid")
	else:
		print("[MomDataValidation] FAIL - %d file(s) with errors" % _failures)
	quit(0 if _failures == 0 else 1)


func _list_tres(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[MomDataValidation] Cannot open dir: " + dir_path)
		_failures += 1
		return files
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			files.append(dir_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


func _validate_tiers() -> void:
	var files := _list_tres(PUNISHMENT_DIR)
	if files.is_empty():
		push_error("[MomDataValidation] No punishment tier files found")
		_failures += 1
		return
	var seen_ids: Dictionary = {}
	for path in files:
		var res := load(path)
		if res == null or not res is MomPunishmentTier:
			push_error("[MomDataValidation] Failed to load tier: " + path)
			_failures += 1
			continue
		var tier := res as MomPunishmentTier
		var ok := tier.validate()
		if seen_ids.has(tier.tier_id):
			push_error("[MomDataValidation] Duplicate tier_id %d (%s)" % [tier.tier_id, path])
			ok = false
		seen_ids[tier.tier_id] = true
		if not ok:
			_failures += 1
			print("[MomDataValidation] INVALID: " + path)
		else:
			print("[MomDataValidation] OK: %s (tier %d '%s', %d entries)" % [
				path, tier.tier_id, tier.display_name, tier.entries.size()])


func _validate_dialog_nodes() -> void:
	var files := _list_tres(DIALOG_DIR)
	if files.is_empty():
		push_error("[MomDataValidation] No dialog node files found")
		_failures += 1
		return

	# Load all nodes first so follow-up ids can be cross-checked
	var nodes: Dictionary = {}  # path -> MomDialogNode
	var known_ids: Array[String] = []
	for path in files:
		var res := load(path)
		if res == null or not res is MomDialogNode:
			push_error("[MomDataValidation] Failed to load dialog node: " + path)
			_failures += 1
			continue
		var node := res as MomDialogNode
		nodes[path] = node
		if node.id in known_ids:
			push_error("[MomDataValidation] Duplicate dialog node id: '%s' (%s)" % [node.id, path])
			_failures += 1
		else:
			known_ids.append(node.id)

	for path in nodes:
		var node: MomDialogNode = nodes[path]
		if not node.validate(known_ids):
			_failures += 1
			print("[MomDataValidation] INVALID: " + path)
		else:
			print("[MomDataValidation] OK: %s (id '%s', %d responses)" % [
				path, node.id, node.responses.size()])
