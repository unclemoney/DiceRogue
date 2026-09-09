extends Consumable
class_name ScratchTicketConsumable

## ScratchTicketConsumable
##
## "Scratch Ticket" coupon: if the player's last score was a true zero, the
## next score is doubled. True-zero detection mirrors SegaConsole: it reads
## Scorecard.last_base_score (base score before modifiers, updated only by
## real scoring), so a 0 produced by modifiers does not qualify.
## Arms a one-shot 2x multiplier on ScoreModifierManager and disarms on the
## next score_assigned. Refuses when no score is placed or the last base
## score was not 0 (gated in ConsumableUI._can_use_consumable).

signal scratch_ticket_armed
signal scratch_ticket_denied(reason: String)
signal scratch_ticket_triggered(category: String, score: int)

const SCORE_MULTIPLIER := 2.0
const MODIFIER_SOURCE := "scratch_ticket"

var is_active: bool = false
var scorecard_ref: Scorecard = null
var _debug_enabled: bool = OS.is_debug_build()


func _ready() -> void:
	add_to_group("consumables")
	if _debug_enabled:
		print("[ScratchTicketConsumable] Ready")


## apply(target)
##
## Entry point called by GameController with the GameController as target.
## Refuses (scratch_ticket_denied) unless the last score was a true zero.
func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[ScratchTicketConsumable] Invalid target passed to apply()")
		return

	var scorecard: Scorecard = game_controller.scorecard
	if not can_arm(scorecard):
		if _debug_enabled:
			print("[ScratchTicketConsumable] Denied - last score was not a true zero")
		emit_signal("scratch_ticket_denied", "last_score_not_zero")
		return

	arm(scorecard)


## can_arm(scorecard) -> bool
##
## True when a score exists and the most recent base score was 0.
## The initial last_base_score of 0 does not qualify until a real score
## has been placed.
static func can_arm(scorecard: Scorecard) -> bool:
	if not scorecard:
		return false
	if not scorecard.has_any_scores():
		return false
	return scorecard.last_base_score == 0


## arm(scorecard)
##
## Registers the 2x multiplier and listens for the next score_assigned to
## disarm. Exposed separately from apply() so tests can drive it directly.
func arm(scorecard: Scorecard) -> void:
	scorecard_ref = scorecard
	is_active = true
	ScoreModifierManager.register_multiplier(MODIFIER_SOURCE, SCORE_MULTIPLIER)
	if not scorecard.score_assigned.is_connected(_on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
	if _debug_enabled:
		print("[ScratchTicketConsumable] Armed - next score is doubled")
	emit_signal("scratch_ticket_armed")


## disarm()
##
## Removes the multiplier and disconnects. Safe to call when not armed.
func disarm() -> void:
	if not is_active:
		return
	is_active = false
	if ScoreModifierManager.has_multiplier(MODIFIER_SOURCE):
		ScoreModifierManager.unregister_multiplier(MODIFIER_SOURCE)
	if scorecard_ref and scorecard_ref.score_assigned.is_connected(_on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	scorecard_ref = null
	if _debug_enabled:
		print("[ScratchTicketConsumable] Disarmed")


func _on_score_assigned(_section: Scorecard.Section, category: String, score: int) -> void:
	if not is_active:
		return
	if _debug_enabled:
		print("[ScratchTicketConsumable] Triggered on %s (score %d) - disarming" % [category, score])
	emit_signal("scratch_ticket_triggered", category, score)
	disarm()


func _exit_tree() -> void:
	# Never leak the multiplier if the consumable is freed while armed
	disarm()
