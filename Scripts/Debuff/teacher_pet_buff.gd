extends Debuff
class_name TeacherPetBuff

## TeacherPetBuff
##
## A positive Mom-granted buff that rides the Debuff pipeline like
## Rebellion. It is round-scoped and stores its active tier on
## `intensity`. Ten tiers map directly to Mom's mood (tier = 11 - mood,
## so mood 10 = maddest grants Tier 1 and mood 1 = happiest grants
## Tier 10). Effects stack as they unlock:
##   - Tiers 1-3:  additive score per hand only (+5 to +15)
##   - Tiers 4-6:  additive plus a round-end allowance ($25 to $75)
##   - Tiers 7-10: additive, allowance, and a score multiplier
##                 (x1.5 to x3.0), peaking at +50 / x3.0 / $200 on Tier 10

const SOURCE_NAME: String = "teacher_pet"
const MAX_TIER: int = 10

## Per-tier additive score per hand (index 0 unused; tiers 1-10).
const TIER_ADDITIVES: Array[int] = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
## Per-tier score multiplier (1.0 = none; tiers 7+ only).
const TIER_MULTIPLIERS: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.5, 1.75, 2.0, 3.0]
## Per-tier round-end allowance payout (tiers 4+ only).
const TIER_ALLOWANCES: Array[int] = [0, 0, 0, 0, 25, 50, 75, 100, 150, 175, 200]

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
## Clamps Teacher's Pet to the supported tier range (1-10) and refreshes
## its active effect if already live.
func set_intensity(value: float) -> void:
	super.set_intensity(value)
	intensity = float(clampi(roundi(intensity), 1, MAX_TIER))
	_round_end_bonus_consumed = false
	if is_active:
		_sync_effects()
		print("[TeacherPetBuff] Updated - %s: %s" % [get_buff_display_suffix(), get_buff_effect_summary()])


## get_tier() -> int
##
## Returns the active Teacher's Pet tier from intensity.
func get_tier() -> int:
	return clampi(int(roundi(intensity)), 1, MAX_TIER)


## get_tier_additive(tier) -> int
##
## Returns the additive score per hand granted by the given tier.
static func get_tier_additive(tier: int) -> int:
	return TIER_ADDITIVES[clampi(tier, 1, MAX_TIER)]


## get_tier_multiplier(tier) -> float
##
## Returns the score multiplier granted by the given tier (1.0 = none).
static func get_tier_multiplier(tier: int) -> float:
	return TIER_MULTIPLIERS[clampi(tier, 1, MAX_TIER)]


## get_tier_allowance(tier) -> int
##
## Returns the round-end allowance payout granted by the given tier.
static func get_tier_allowance(tier: int) -> int:
	return TIER_ALLOWANCES[clampi(tier, 1, MAX_TIER)]


## get_buff_display_suffix() -> String
##
## Returns the compact Chore UI label suffix for the active tier.
func get_buff_display_suffix() -> String:
	return "Tier %d" % get_tier()


## get_buff_effect_lines() -> Array[String]
##
## Returns each active Teacher's Pet bonus as its own line (additive,
## multiplier, allowance), so UI fan-outs can show every attribute.
func get_buff_effect_lines() -> Array[String]:
	var tier := get_tier()
	var parts: Array[String] = []
	var additive := get_tier_additive(tier)
	if additive > 0:
		parts.append("+%d additive per hand" % additive)
	var multiplier := get_tier_multiplier(tier)
	if multiplier > 1.0:
		parts.append("x%.2f score" % multiplier)
	var allowance := get_tier_allowance(tier)
	if allowance > 0:
		parts.append("+$%d at round end" % allowance)
	return parts


## get_buff_effect_summary() -> String
##
## Returns a one-line summary of the currently active Teacher's Pet
## bonuses, composed from whichever effects the tier has unlocked.
func get_buff_effect_summary() -> String:
	var parts := get_buff_effect_lines()
	if parts.is_empty():
		return "No bonus"
	return ", ".join(parts)


## get_pending_round_end_bonus() -> int
##
## Exposes the round-end preview/consume contract expected by
## GameController. Only tiers with an allowance (4+) pay out money.
func get_pending_round_end_bonus() -> int:
	if _round_end_bonus_consumed:
		return 0
	return get_tier_allowance(get_tier())


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

	var tier := get_tier()
	var additive := get_tier_additive(tier)
	if additive > 0 and smm.has_method("register_additive"):
		smm.register_additive(SOURCE_NAME, additive)
	var multiplier := get_tier_multiplier(tier)
	if multiplier > 1.0 and smm.has_method("register_multiplier"):
		smm.register_multiplier(SOURCE_NAME, multiplier)


func _unregister_effects() -> void:
	var smm := get_node_or_null("/root/ScoreModifierManager")
	if smm == null:
		return
	if smm.has_method("has_additive") and smm.has_method("unregister_additive") and smm.has_additive(SOURCE_NAME):
		smm.unregister_additive(SOURCE_NAME)
	if smm.has_method("has_multiplier") and smm.has_method("unregister_multiplier") and smm.has_multiplier(SOURCE_NAME):
		smm.unregister_multiplier(SOURCE_NAME)
