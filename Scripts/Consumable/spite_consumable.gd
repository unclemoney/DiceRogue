extends Consumable
class_name SpiteConsumable

## SpiteConsumable
##
## Armed-state consumable: registers a score multiplier of
## x(1.0 + 0.5 per active debuff) that applies to the NEXT scored category
## only, then auto-disarms. If the turn ends without a score, it disarms
## unused. Usable only while at least one debuff is active (usability gate
## lives in ConsumableUI/CorkboardUI `_can_use_consumable`, keyed on "spite").
##
## Mom-granted buffs (rebellion, teacher_pet) ride the debuff pipeline but are
## rewards, so they never count toward Spite.

const MULTIPLIER_SOURCE: String = "spite"
const MULTIPLIER_PER_DEBUFF: float = 0.5

signal spite_armed(multiplier: float, debuff_count: int)
signal spite_disarmed(category: String)

var _debug_enabled: bool = OS.is_debug_build()
var is_armed: bool = false
var turn_activated: int = -1
var game_controller_ref: Node = null
var scorecard_ref: Scorecard = null


func _ready() -> void:
	add_to_group("consumables")


## apply(target)
##
## Arms the Spite multiplier against the GameController's scorecard.
## No-ops (without arming) when no debuffs are active.
## @param target: GameController (duck-typed: needs scorecard, turn_tracker,
##   active_debuffs)
func apply(target) -> void:
	var game_controller = target
	if not game_controller or not ("active_debuffs" in game_controller):
		push_error("[SpiteConsumable] Invalid target passed to apply()")
		return

	scorecard_ref = game_controller.get("scorecard")
	if not scorecard_ref:
		push_error("[SpiteConsumable] No scorecard found on target")
		return

	var debuff_count := _count_active_debuffs(game_controller)
	if debuff_count <= 0:
		print("[SpiteConsumable] No active debuffs - Spite fizzles")
		return

	game_controller_ref = game_controller
	is_armed = true

	var turn_tracker = game_controller.get("turn_tracker")
	if turn_tracker:
		turn_activated = turn_tracker.current_turn
		if not turn_tracker.is_connected("turn_started", _on_turn_started):
			turn_tracker.turn_started.connect(_on_turn_started)

	var multiplier := 1.0 + MULTIPLIER_PER_DEBUFF * debuff_count
	var smm := get_node_or_null("/root/ScoreModifierManager")
	if smm and smm.has_method("register_multiplier"):
		smm.register_multiplier(MULTIPLIER_SOURCE, multiplier)

	if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.connect(_on_score_assigned)

	if _debug_enabled:
		print("[SpiteConsumable] Armed: x%.2f for next scored category (%d debuff(s))" % [
			multiplier, debuff_count])
	emit_signal("spite_armed", multiplier, debuff_count)


func _on_score_assigned(_section: int, category: String, _score: int) -> void:
	if not is_armed:
		return
	if _debug_enabled:
		print("[SpiteConsumable] Score assigned to '%s' - disarming" % category)
	_disarm(category)


func _on_turn_started() -> void:
	if not is_armed:
		return
	var turn_tracker = game_controller_ref.get("turn_tracker") if game_controller_ref else null
	if turn_tracker and turn_tracker.current_turn != turn_activated:
		if _debug_enabled:
			print("[SpiteConsumable] Turn changed without scoring - disarming")
		_disarm("")


func _disarm(category: String) -> void:
	if not is_armed:
		return
	is_armed = false

	var smm := get_node_or_null("/root/ScoreModifierManager")
	if smm and smm.has_method("has_multiplier") and smm.has_multiplier(MULTIPLIER_SOURCE):
		smm.unregister_multiplier(MULTIPLIER_SOURCE)

	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)

	var turn_tracker = game_controller_ref.get("turn_tracker") if game_controller_ref else null
	if turn_tracker and turn_tracker.is_connected("turn_started", _on_turn_started):
		turn_tracker.turn_started.disconnect(_on_turn_started)

	game_controller_ref = null
	scorecard_ref = null
	emit_signal("spite_disarmed", category)


func _count_active_debuffs(game_controller) -> int:
	var count := 0
	for debuff_id in game_controller.active_debuffs.keys():
		if debuff_id in DebuffManager.GRANTED_ONLY_IDS:
			continue
		var debuff = game_controller.active_debuffs[debuff_id]
		if is_instance_valid(debuff) and debuff.is_active:
			count += 1
	return count
