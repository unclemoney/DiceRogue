extends PowerUp
class_name DefiancePowerUp

## DefiancePowerUp
##
## +0.25x score multiplier per active debuff. The multiplier is registered
## with ScoreModifierManager and recomputed whenever a debuff is applied or
## ends while this PowerUp is owned.
##
## Mom-granted buffs (rebellion, teacher_pet) ride the debuff pipeline but are
## rewards, not punishments, so they never count toward Defiance.

const BASE_SOURCE_NAME: String = "defiance"
const MULTIPLIER_PER_DEBUFF: float = 0.25

var _debug_enabled: bool = OS.is_debug_build()
var _game_controller: Node = null
var _tracked_debuffs: Array = []


func _ready() -> void:
	add_to_group("power_ups")


## apply(_target)
##
## Finds the GameController via the "game_controller" group, hooks its
## debuff_applied signal plus debuff_ended on every currently active debuff,
## and registers the initial multiplier.
## Side-effects: registers a multiplier on /root/ScoreModifierManager.
func apply(_target) -> void:
	_game_controller = get_tree().get_first_node_in_group("game_controller")
	if not _game_controller or not _game_controller.has_signal("debuff_applied"):
		push_error("[DefiancePowerUp] No GameController found in 'game_controller' group")
		return

	if not _game_controller.is_connected("debuff_applied", _on_debuff_applied):
		_game_controller.debuff_applied.connect(_on_debuff_applied)

	for debuff in _game_controller.active_debuffs.values():
		_track_debuff(debuff)

	_refresh_multiplier()

	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

	if _debug_enabled:
		print("[DefiancePowerUp] Applied - %d active debuff(s): x%.2f score" % [
			_count_active_debuffs(), _current_multiplier()])


## remove(_target)
##
## Unregisters the multiplier and disconnects all debuff tracking.
func remove(_target) -> void:
	_cleanup()
	if _debug_enabled:
		print("[DefiancePowerUp] Removed")


## get_current_description() -> String
##
## Returns the live effect summary for hover UI and debug views.
func get_current_description() -> String:
	var count := _count_active_debuffs()
	return "+0.25x score per active debuff\nActive debuffs: %d (x%.2f)" % [count, _current_multiplier()]


func _on_debuff_applied(_debuff_id: String, debuff: Debuff) -> void:
	_track_debuff(debuff)
	_refresh_multiplier()


func _on_debuff_ended() -> void:
	# Debuff.is_active is already false when debuff_ended emits, so the count
	# read here already excludes the debuff that just ended.
	_refresh_multiplier()


func _track_debuff(debuff) -> void:
	if not is_instance_valid(debuff):
		return
	if not debuff.has_signal("debuff_ended"):
		return
	if not debuff.is_connected("debuff_ended", _on_debuff_ended):
		debuff.debuff_ended.connect(_on_debuff_ended)
	if not debuff in _tracked_debuffs:
		_tracked_debuffs.append(debuff)


func _count_active_debuffs() -> int:
	var count := 0
	if not _game_controller:
		return 0
	for debuff_id in _game_controller.active_debuffs.keys():
		if debuff_id in DebuffManager.GRANTED_ONLY_IDS:
			continue
		var debuff = _game_controller.active_debuffs[debuff_id]
		if is_instance_valid(debuff) and debuff.is_active:
			count += 1
	return count


func _current_multiplier() -> float:
	return 1.0 + MULTIPLIER_PER_DEBUFF * _count_active_debuffs()


func _source_name() -> String:
	return get_runtime_modifier_source_name(BASE_SOURCE_NAME)


func _refresh_multiplier() -> void:
	var smm := get_node_or_null("/root/ScoreModifierManager")
	if smm and smm.has_method("register_multiplier"):
		smm.register_multiplier(_source_name(), _current_multiplier())
		if _debug_enabled:
			print("[DefiancePowerUp] Multiplier refreshed: x%.2f (%d debuff(s))" % [
				_current_multiplier(), _count_active_debuffs()])


func _cleanup() -> void:
	var smm := get_node_or_null("/root/ScoreModifierManager")
	if smm and smm.has_method("unregister_multiplier"):
		smm.unregister_multiplier(_source_name())

	if _game_controller and _game_controller.is_connected("debuff_applied", _on_debuff_applied):
		_game_controller.debuff_applied.disconnect(_on_debuff_applied)

	for debuff in _tracked_debuffs:
		if is_instance_valid(debuff) and debuff.is_connected("debuff_ended", _on_debuff_ended):
			debuff.debuff_ended.disconnect(_on_debuff_ended)
	_tracked_debuffs.clear()
	_game_controller = null


func _on_tree_exiting() -> void:
	_cleanup()
