extends Debuff
class_name TeacherPetBuff

## TeacherPetBuff
##
## A positive Mom-granted buff that rides the Debuff pipeline like
## Rebellion. It is round-scoped and stores its active tier on
## `intensity`:
##   - Tier 1: +$100 at round end
##   - Tier 2: +25 additive score per hand
##   - Tier 3: x2.0 score multiplier per hand

const SOURCE_NAME: String = "teacher_pet"
const MAX_TIER: int = 3
const TIER_ALLOWANCE: int = 1
const TIER_ADDITIVE: int = 2
const TIER_MULTIPLIER: int = 3

const ROUND_END_ALLOWANCE: int = 100
const HAND_ADDITIVE: int = 25
const HAND_MULTIPLIER: float = 2.0

var _game_controller: GameController = null
var _round_end_bonus_consumed: bool = false


## apply(_target)
##
## Registers the active Teacher's Pet tier effects.
func apply(_target) -> void:
	self.target = _target
	_game_controller = _target as GameController
	if not _game_controller:
		push_error("[TeacherPetBuff] Invalid target - expected GameController")
		return

	_round_end_bonus_consumed = false
	_sync_effects()
	print("[TeacherPetBuff] Applied - %s: %s" % [get_buff_display_suffix(), get_buff_effect_summary()])


## remove()
##
## Unregisters any active additive or multiplier effects.
func remove() -> void:
	_unregister_effects()
	_game_controller = null
	print("[TeacherPetBuff] Removed - teacher's pet status expired")


## set_intensity(value)
##
## Clamps Teacher's Pet to the supported tier range (1-3) and refreshes
## its active effect if already live.
func set_intensity(value: float) -> void:
	super.set_intensity(value)
	intensity = float(clampi(roundi(intensity), TIER_ALLOWANCE, MAX_TIER))
	_round_end_bonus_consumed = false
	if is_active:
		_sync_effects()
		print("[TeacherPetBuff] Updated - %s: %s" % [get_buff_display_suffix(), get_buff_effect_summary()])


## get_tier() -> int
##
## Returns the active Teacher's Pet tier from intensity.
func get_tier() -> int:
	return clampi(int(roundi(intensity)), TIER_ALLOWANCE, MAX_TIER)


## get_buff_display_suffix() -> String
##
## Returns the compact Chore UI label suffix for the active tier.
func get_buff_display_suffix() -> String:
	return "Tier %d" % get_tier()


## get_buff_effect_summary() -> String
##
## Returns a one-line summary of the currently active Teacher's Pet bonus.
func get_buff_effect_summary() -> String:
	match get_tier():
		TIER_ALLOWANCE:
			return "+$%d at round end" % ROUND_END_ALLOWANCE
		TIER_ADDITIVE:
			return "+%d additive score per hand" % HAND_ADDITIVE
		TIER_MULTIPLIER:
			return "x%.2f score per hand" % HAND_MULTIPLIER
	return "No bonus"


## get_pending_round_end_bonus() -> int
##
## Exposes the round-end preview/consume contract expected by
## GameController. Only tier 1 pays out money at round end.
func get_pending_round_end_bonus() -> int:
	if get_tier() == TIER_ALLOWANCE and not _round_end_bonus_consumed:
		return ROUND_END_ALLOWANCE
	return 0


## consume_pending_round_end_bonus() -> int
##
## Returns the current round-end Teacher's Pet payout.
func consume_pending_round_end_bonus() -> int:
	var amount := get_pending_round_end_bonus()
	if amount > 0:
		_round_end_bonus_consumed = true
	return amount


func _sync_effects() -> void:
	_unregister_effects()
	var smm := get_node_or_null("/root/ScoreModifierManager")
	if smm == null:
		return

	match get_tier():
		TIER_ADDITIVE:
			if smm.has_method("register_additive"):
				smm.register_additive(SOURCE_NAME, HAND_ADDITIVE)
		TIER_MULTIPLIER:
			if smm.has_method("register_multiplier"):
				smm.register_multiplier(SOURCE_NAME, HAND_MULTIPLIER)


func _unregister_effects() -> void:
	var smm := get_node_or_null("/root/ScoreModifierManager")
	if smm == null:
		return
	if smm.has_method("has_additive") and smm.has_method("unregister_additive") and smm.has_additive(SOURCE_NAME):
		smm.unregister_additive(SOURCE_NAME)
	if smm.has_method("has_multiplier") and smm.has_method("unregister_multiplier") and smm.has_multiplier(SOURCE_NAME):
		smm.unregister_multiplier(SOURCE_NAME)