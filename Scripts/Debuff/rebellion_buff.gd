extends Debuff
class_name RebellionBuff

## RebellionBuff
##
## A positive "buff" riding the Debuff pipeline: granted by successful sass
## during Mom visits (see GameController._run_mom_dialog_session). It is
## round-scoped like Mom's grounded debuffs - GameController clears it at
## the start of the next round.
##
## Per stack (intensity 1-3, one stack per successful sass):
##   - Score multiplier: 1.0 + 0.15 * stacks (x1.15 / x1.30 / x1.45)
##   - Bonus rolls each turn: +1 at 1 stack, +2 at 2+ stacks

const MULTIPLIER_SOURCE: String = "rebellion"
const BASE_SCORE_BONUS: float = 0.15
const MAX_STACKS: int = 3
const MAX_BONUS_ROLLS: int = 2

var _game_controller: GameController = null
var _turn_tracker: TurnTracker = null


## apply(_target)
##
## Registers the score multiplier and hooks turn_started for bonus rolls.
func apply(_target) -> void:
	self.target = _target
	_game_controller = _target as GameController
	if not _game_controller:
		push_error("[RebellionBuff] Invalid target - expected GameController")
		return

	_turn_tracker = _game_controller.turn_tracker
	_register_multiplier()
	if _turn_tracker:
		if not _turn_tracker.is_connected("turn_started", _on_turn_started):
			_turn_tracker.turn_started.connect(_on_turn_started)
		# Bonus rolls apply to the current turn too, not just future ones
		_grant_bonus_rolls()

	print("[RebellionBuff] Applied - %d stack(s): x%.2f score, +%d rolls/turn" % [
		int(intensity), _score_multiplier(), _bonus_rolls()])


## remove()
##
## Unregisters the multiplier and disconnects from the turn tracker.
func remove() -> void:
	_unregister_multiplier()
	if _turn_tracker and _turn_tracker.is_connected("turn_started", _on_turn_started):
		_turn_tracker.turn_started.disconnect(_on_turn_started)
	_turn_tracker = null
	_game_controller = null
	print("[RebellionBuff] Removed - rebellion is over")


## set_intensity(value)
##
## Stacks are carried on intensity (clamped 1-MAX_STACKS). Refreshes the
## score multiplier when the buff is already live.
func set_intensity(value: float) -> void:
	super.set_intensity(value)
	intensity = minf(intensity, float(MAX_STACKS))
	if is_active:
		_register_multiplier()
		print("[RebellionBuff] Stacked to %d: x%.2f score, +%d rolls/turn" % [
			int(intensity), _score_multiplier(), _bonus_rolls()])


## get_buff_display_suffix() -> String
##
## Returns the compact Chore UI suffix for the current stack count.
func get_buff_display_suffix() -> String:
	return "x%d" % maxi(int(intensity), 1)


## get_buff_effect_summary() -> String
##
## Returns the live Rebellion effect summary for Chore UI and debug views.
func get_buff_effect_summary() -> String:
	return "x%.2f score, +%d bonus roll(s)/turn" % [_score_multiplier(), _bonus_rolls()]


func _score_multiplier() -> float:
	return 1.0 + BASE_SCORE_BONUS * intensity


func _bonus_rolls() -> int:
	return mini(int(intensity), MAX_BONUS_ROLLS)


func _register_multiplier() -> void:
	var smm := get_node_or_null("/root/ScoreModifierManager")
	if smm and smm.has_method("register_multiplier"):
		smm.register_multiplier(MULTIPLIER_SOURCE, _score_multiplier())


func _unregister_multiplier() -> void:
	var smm := get_node_or_null("/root/ScoreModifierManager")
	if smm and smm.has_method("unregister_multiplier"):
		smm.unregister_multiplier(MULTIPLIER_SOURCE)


func _on_turn_started() -> void:
	_grant_bonus_rolls()


func _grant_bonus_rolls() -> void:
	var bonus := _bonus_rolls()
	if bonus > 0 and _turn_tracker:
		_turn_tracker.rolls_left += bonus
		_turn_tracker.emit_signal("rolls_updated", _turn_tracker.rolls_left)
