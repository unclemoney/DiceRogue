extends SceneTree

## mom_data_validation_test.gd
##
## Loads every Mom .tres data file and runs its validate() checks.
## Punishment tiers: Resources/Data/Mom/Punishments/
## Dialog nodes:     Resources/Data/Mom/Dialog/ (cross-checked follow-up ids)
## Cast + arcs:      Resources/Data/Mom/Cast/ (cross-checked against Dialog/
##                   node ids, channel zone names, and beat flag references)
##
## Run headless:
##   godot --headless --path . --script Tests/mom_data_validation_test.gd
## Exit code 0 = all valid, 1 = at least one failure.

const PUNISHMENT_DIR := "res://Resources/Data/Mom/Punishments/"
const DIALOG_DIR := "res://Resources/Data/Mom/Dialog/"
const CAST_DIR := "res://Resources/Data/Mom/Cast/"
const CHANNELS_DIR := "res://Resources/Data/Channels/"

var _failures: int = 0


func _init() -> void:
	print("[MomDataValidation] Starting validation")
	_validate_tiers()
	var known_ids := _validate_dialog_nodes()
	_validate_cast(known_ids)

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


func _validate_dialog_nodes() -> Array[String]:
	var files := _list_tres(DIALOG_DIR)
	if files.is_empty():
		push_error("[MomDataValidation] No dialog node files found")
		_failures += 1
		return []

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

	return known_ids


## _validate_cast(known_dialog_ids)
##
## Validates CastCharacter and MomStoryArc resources:
##   - characters: validate() + zone_affinity against the channel table
##   - arcs: validate() + character exists + every beat's dialog node
##     exists in Dialog/ + every requires_flag is set by some beat or is
##     a "flag_*" node id
func _validate_cast(known_dialog_ids: Array[String]) -> void:
	var files := _list_tres(CAST_DIR)
	if files.is_empty():
		push_error("[MomDataValidation] No cast files found")
		_failures += 1
		return

	# Channel zone names for zone_affinity cross-checks
	var zone_names: Array[String] = []
	for channel_path in _list_tres(CHANNELS_DIR):
		var channel_res := load(channel_path)
		if channel_res is ChannelDifficultyData and channel_res.mall_zone_name != "":
			zone_names.append(channel_res.mall_zone_name)

	var character_ids: Array[String] = []
	var arcs: Dictionary = {}  # path -> MomStoryArc

	for path in files:
		var res := load(path)
		if res is CastCharacter:
			var character := res as CastCharacter
			var ok := character.validate()
			if character.id in character_ids:
				push_error("[MomDataValidation] Duplicate character id: '%s' (%s)" % [character.id, path])
				ok = false
			else:
				character_ids.append(character.id)
			for zone in character.zone_affinity:
				if zone not in zone_names:
					push_error("[MomDataValidation] %s: unknown zone_affinity '%s'" % [path, zone])
					ok = false
			if ok:
				print("[MomDataValidation] OK: %s (character '%s')" % [path, character.id])
			else:
				_failures += 1
				print("[MomDataValidation] INVALID: " + path)
		elif res is MomStoryArc:
			arcs[path] = res
		else:
			push_error("[MomDataValidation] Failed to load cast resource: " + path)
			_failures += 1

	# Collect every flag that beats can set (sets_flag + "flag_*" nodes)
	var settable_flags: Array[String] = []
	for node_id in known_dialog_ids:
		if node_id.begins_with("flag_"):
			settable_flags.append(node_id)

	var arc_ids: Array[String] = []
	for path in arcs:
		var arc: MomStoryArc = arcs[path]
		var ok := arc.validate()
		if arc.id in arc_ids:
			push_error("[MomDataValidation] Duplicate arc id: '%s' (%s)" % [arc.id, path])
			ok = false
		else:
			arc_ids.append(arc.id)
		if arc.character_id not in character_ids:
			push_error("[MomDataValidation] %s: unknown character_id '%s'" % [path, arc.character_id])
			ok = false
		for beat in arc.beats:
			if beat == null:
				continue
			if beat.dialog_node_id not in known_dialog_ids:
				push_error("[MomDataValidation] %s: beat node '%s' not in Dialog/" % [path, beat.dialog_node_id])
				ok = false
			if beat.sets_flag != "" and beat.sets_flag not in settable_flags:
				settable_flags.append(beat.sets_flag)
		for beat in arc.beats:
			if beat == null or beat.requires_flag == "":
				continue
			if beat.requires_flag not in settable_flags:
				push_error("[MomDataValidation] %s: requires_flag '%s' is never set" % [path, beat.requires_flag])
				ok = false
		if ok:
			print("[MomDataValidation] OK: %s (arc '%s', %d beats)" % [path, arc.id, arc.beats.size()])
		else:
			_failures += 1
			print("[MomDataValidation] INVALID: " + path)
