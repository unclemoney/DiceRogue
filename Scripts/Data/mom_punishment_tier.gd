extends Resource
class_name MomPunishmentTier

## MomPunishmentTier Resource
##
## Defines one severity tier of Mom's punishment table.
## Punishment selection is data-driven: MomLogicHandler computes a severity
## (1-5, or 0 for rewards), picks the matching tier, then draws `picks`
## entries from `entries` by weight. No hardcoded branches in the handler.
##
## Each entry in `entries` is a Dictionary with these keys:
##   effect: String    - one of VALID_EFFECTS
##   weight: float     - relative draw weight (must be > 0)
##   params: Dictionary - effect-specific parameters:
##       "fine":               {"min": int, "max": int}
##       "debuff":             {"count": int}
##       "confiscate_powerups": {"max_rating": String,  # "R" or "NC-17"
##                               "stack_debuffs": bool}  # NC-17 grounding debuffs
##       "remove_mod":         {"count": int}
##       "lock_cosmetics":     {}  (colors locked; `permanent` sets duration)
##       "mood_delta":         {"delta": int}  (positive = angrier)
##       "reward_money":       {"min": int, "max": int}
##       "reward_consumable":  {"pool": Array[String]}  (consumable ids)
##       "reward_powerup":     {"pool": Array[String]}  (safe power-up ids)
##   permanent: bool   - false = lasts until round end (lighter tiers),
##                       true = permanent loss (harsher tiers)

## Canonical list of punishment/reward effect types.
## MomDialogOutcome reuses these for direct effects from dialog responses.
const VALID_EFFECTS: Array[String] = [
	"none",
	"fine",
	"debuff",
	"confiscate_powerups",
	"remove_mod",
	"lock_cosmetics",
	"mood_delta",
	"reward_money",
	"reward_consumable",
	"reward_powerup",
]

## Severity tier identifier. 0 = reward tier, 1-5 = punishment tiers.
@export var tier_id: int = 0

## Display name for debugging and editor UI (e.g. "Disappointed", "Furious").
@export var display_name: String = ""

## Minimum severity that selects this tier. Tiers are matched by
## highest min_severity <= computed severity.
@export var min_severity: int = 1

## Number of entries drawn (without replacement) when this tier fires.
@export var picks: int = 1

## Weighted punishment/reward entries. See class doc for the Dictionary schema.
@export var entries: Array[Dictionary] = []


## get_total_weight() -> float
##
## Sums all entry weights. Used for weighted random selection.
func get_total_weight() -> float:
	var total := 0.0
	for entry in entries:
		total += float(entry.get("weight", 0.0))
	return total


## validate() -> bool
##
## Checks the tier for data errors. Logs errors but does not throw.
## Intended for test scenes and editor-time validation.
##
## Returns: bool - true if the tier is well-formed
func validate() -> bool:
	var all_valid := true

	if display_name.is_empty():
		push_error("[MomPunishmentTier:%d] display_name is empty" % tier_id)
		all_valid = false

	if picks < 1:
		push_error("[MomPunishmentTier:%d] picks must be >= 1, got %d" % [tier_id, picks])
		all_valid = false

	if entries.is_empty():
		push_error("[MomPunishmentTier:%d] entries is empty" % tier_id)
		all_valid = false

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var effect: String = entry.get("effect", "")
		if effect not in VALID_EFFECTS:
			push_error("[MomPunishmentTier:%d] entry %d has invalid effect: '%s'" % [tier_id, i, effect])
			all_valid = false
		if float(entry.get("weight", 0.0)) <= 0.0:
			push_error("[MomPunishmentTier:%d] entry %d has non-positive weight" % [tier_id, i])
			all_valid = false

	return all_valid
