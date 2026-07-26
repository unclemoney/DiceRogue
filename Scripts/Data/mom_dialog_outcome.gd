extends Resource
class_name MomDialogOutcome

## MomDialogOutcome Resource
##
## One weighted possible result of a MomDialogResponse.
## When the player picks a response, MomLogicHandler draws one outcome by
## weight and applies it: mood/grudge shifts, a direct punishment effect,
## a follow-up dialog node, or ending the visit.
##
## Effect values reuse MomPunishmentTier.VALID_EFFECTS for direct
## punishments/rewards, plus these dialog-only effects:
##   "apply_tier"  - resolve a full punishment tier. magnitude selects it:
##                   magnitude >= 1  -> exact tier_id (e.g. 2 = Grounded Lite)
##                   magnitude == 0  -> tier computed from visit severity
##                   magnitude == -1 -> computed severity + 1 (escalation)
##   "storms_off"  - Mom leaves angry: NO punishment this visit, but the
##                   grudge_delta (usually +1) raises next visit's severity
##                   floor. Should always set ends_visit = true.
##
## NOTE: the @export_enum literal below must stay in sync with
## MomPunishmentTier.VALID_EFFECTS plus the dialog-only effects above.

## Relative draw weight within the parent response. Must be > 0.
@export var weight: float = 1.0

## What happens when this outcome is drawn.
@export_enum("none", "fine", "debuff", "confiscate_powerups", "remove_mod",
	"lock_cosmetics", "mood_delta", "reward_money", "reward_consumable",
	"reward_powerup",
	"apply_tier", "storms_off", "grudge_delta") var effect: String = "none"

## Effect-specific magnitude. Meaning depends on `effect`:
##   "fine"/"reward_money": exact dollar amount (0 = random $50-150)
##   "debuff"/"remove_mod": count (0 = 1)
##   "apply_tier":          >= 1 exact tier_id, 0 = computed severity,
##                          -1 = computed severity + 1
@export var magnitude: int = 0

## Mood shift applied to Mom (positive = angrier, negative = happier).
@export var mood_delta: int = 0

## Grudge shift (positive = she holds a grudge into the next visit).
@export var grudge_delta: int = 0

## For punishment effects: false = lasts until round end, true = permanent.
@export var permanent: bool = false

## ID of the MomDialogNode to continue to. Empty = no follow-up.
@export var followup_node_id: String = ""

## Mom's reply line after this outcome resolves. Supports BBCode.
## Empty = keep the current dialog text.
@export_multiline var result_text: String = ""

## Mom's expression after this outcome. Empty = keep current expression.
## Valid values: "", "happy", "neutral", "upset"
@export var result_expression: String = ""

## Whether this outcome ends the visit (dialog shows OK button).
## False requires followup_node_id to continue the conversation.
@export var ends_visit: bool = true


## has_followup() -> bool
##
## Returns: bool - true if this outcome chains to another dialog node
func has_followup() -> bool:
	return not followup_node_id.is_empty()


## validate() -> bool
##
## Checks the outcome for data errors. Logs errors but does not throw.
##
## Returns: bool - true if the outcome is well-formed
func validate() -> bool:
	var all_valid := true

	if weight <= 0.0:
		push_error("[MomDialogOutcome] weight must be > 0, got %f" % weight)
		all_valid = false

	var valid_effects: Array[String] = MomPunishmentTier.VALID_EFFECTS.duplicate()
	valid_effects.append_array(["apply_tier", "storms_off", "mood_delta", "grudge_delta"])
	if effect not in valid_effects:
		push_error("[MomDialogOutcome] invalid effect: '%s'" % effect)
		all_valid = false

	if effect == "apply_tier" and magnitude < -1:
		push_error("[MomDialogOutcome] apply_tier requires magnitude >= -1 (see class doc)")
		all_valid = false

	if effect == "storms_off" and not ends_visit:
		push_error("[MomDialogOutcome] storms_off must end the visit (ends_visit = true)")
		all_valid = false

	if not ends_visit and followup_node_id.is_empty() and result_text.is_empty():
		push_error("[MomDialogOutcome] outcome does not end visit but has no follow-up or reply text")
		all_valid = false

	return all_valid
