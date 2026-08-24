extends RefCounted
class_name MomLogicHandler

## MomLogicHandler
##
## Static handler for Mom's visits: severity computation, data-driven
## punishment tier resolution, dialog-tree outcome resolution, and
## consequence application.
##
## Visit flow (driven by GameController):
##   1. compute_severity(chores_manager) - mood bands + grudge floor + escalation
##   2. GameController walks a MomDialogNode tree (see Resources/Data/Mom/Dialog)
##   3. resolve_response() picks a weighted MomDialogOutcome per response
##   4. apply_outcome() converts the outcome into a MomCheckResult
##   5. apply_consequences() executes the result on the game state
##
## Punishments come from MomPunishmentTier .tres files - no hardcoded
## branches here. Lighter tiers are temporary (round-scoped debuffs,
## cosmetic locks); harsher tiers are permanent (confiscation, mod removal).

const AVAILABLE_DEBUFFS: Array[String] = ["lock_dice", "costly_roll", "disabled_twos", "roll_score_minus_one", "the_division"]

## Sass-failure escalation (Rebellion): punished SASSY responses scale with
## the player's persistent Rep tier (0-4). Every SASS_REP_TIER_STEP Rep
## tiers add +1 punishment tier; at SASS_REP_EXTRA_DEBUFF_MIN_TIER or
## higher, debuff entries apply one extra debuff.
const SASS_REP_TIER_STEP: int = 2
const SASS_REP_EXTRA_DEBUFF_MIN_TIER: int = 3

## Default dollar range when a reward_money outcome/effect has no amount.
const DEFAULT_REWARD_MIN: int = 50
const DEFAULT_REWARD_MAX: int = 150

## Bot response policy: tone -> relative weight (see pick_response_index).
const BOT_TONE_WEIGHTS: Dictionary = {"polite": 6.0, "neutral": 3.0, "sassy": 1.0}

const TIER_00 := preload("res://Resources/Data/Mom/Punishments/tier_00_reward.tres")
const TIER_01 := preload("res://Resources/Data/Mom/Punishments/tier_01_disappointed.tres")
const TIER_02 := preload("res://Resources/Data/Mom/Punishments/tier_02_grounded_lite.tres")
const TIER_03 := preload("res://Resources/Data/Mom/Punishments/tier_03_confiscation.tres")
const TIER_04 := preload("res://Resources/Data/Mom/Punishments/tier_04_no_fun.tres")
const TIER_05 := preload("res://Resources/Data/Mom/Punishments/tier_05_furious.tres")

const NODE_CHECKIN_NEUTRAL := preload("res://Resources/Data/Mom/Dialog/checkin_neutral.tres")
const NODE_CHECKIN_SUSPICIOUS := preload("res://Resources/Data/Mom/Dialog/checkin_suspicious.tres")
const NODE_SASS_STORM_OFF := preload("res://Resources/Data/Mom/Dialog/sass_storm_off.tres")
const NODE_VISIT_PUNISHMENT := preload("res://Resources/Data/Mom/Dialog/visit_punishment.tres")
const NODE_VISIT_REWARD := preload("res://Resources/Data/Mom/Dialog/visit_reward.tres")
const NODE_VISIT_SILENT := preload("res://Resources/Data/Mom/Dialog/visit_silent_treatment.tres")
const NODE_CHECKIN_CAUGHT := preload("res://Resources/Data/Mom/Dialog/checkin_caught_nc17.tres")
const NODE_CHECKIN_WARNING := preload("res://Resources/Data/Mom/Dialog/checkin_warning.tres")
const NODE_CHECKIN_COOL := preload("res://Resources/Data/Mom/Dialog/checkin_cool_mom.tres")

## Chance a severity 1-2 meter visit becomes a silent-treatment visit.
const SILENT_TREATMENT_CHANCE: float = 0.10
## Chance a check-in at mood <= 3 becomes a "cool mom" event.
const COOL_MOM_CHANCE: float = 0.05

## Flavor check-in pool: when no priority trigger fires (restricted loot,
## cool-mom event), the check-in root is a weighted pick from these small
## talk trees. Weights are relative draw chances.
const CHECKIN_FLAVOR_POOL: Dictionary = {
	"checkin_neutral": 4.0,
	"checkin_nostalgia": 2.0,
	"checkin_gossip": 2.0,
	"checkin_bargain": 2.0,
	"checkin_zone_flavor": 1.0,
}

static var _tiers: Dictionary = {}  # tier_id -> MomPunishmentTier
static var _nodes: Dictionary = {}  # node id -> MomDialogNode


## Result of Mom's visit: everything apply_consequences() will execute.
## Legacy fields (mom_is_upset etc.) kept for existing UI/callers.
class MomCheckResult:
	var removed_power_ups: Array[String] = []
	var removed_mods: Array[String] = []
	var applied_debuffs: Array[String] = []
	var fine_amount: int = 0
	var reward_money: int = 0
	var reward_consumable_id: String = ""
	var reward_powerup_id: String = ""
	var cosmetics_locked: bool = false
	var cosmetics_lock_permanent: bool = false
	var mood_delta: int = 0
	var grudge_delta: int = 0
	var storms_off: bool = false
	var deferred: bool = false  # defer_punishment: no tier now, compounds via defer_streak
	var rep_delta: int = 0  # Rebellion Rep change (applied by GameController via ProgressManager)
	var rebellion_granted: bool = false  # successful sass -> Rebellion buff next round
	var tier_id: int = -1
	var mom_is_upset: bool = false
	var mom_is_furious: bool = false  # NC-17 found
	var no_chores_penalty: bool = false
	var dialog_text: String = ""
	var expression: String = "neutral"


# ─── Data access ───

static func _ensure_data_loaded() -> void:
	if not _tiers.is_empty():
		return
	for tier in [TIER_00, TIER_01, TIER_02, TIER_03, TIER_04, TIER_05]:
		_tiers[tier.tier_id] = tier
	for node in [NODE_CHECKIN_NEUTRAL, NODE_CHECKIN_SUSPICIOUS, NODE_SASS_STORM_OFF,
			NODE_VISIT_PUNISHMENT, NODE_VISIT_REWARD, NODE_VISIT_SILENT,
			NODE_CHECKIN_CAUGHT, NODE_CHECKIN_WARNING, NODE_CHECKIN_COOL]:
		_nodes[node.id] = node
	_scan_dialog_dir()


## _scan_dialog_dir()
##
## Registers every MomDialogNode found in Resources/Data/Mom/Dialog/
## that wasn't already preloaded above. Cast/story trees (sightings,
## story beats, flag nodes) live there as data - no new preloads needed.
## The data validation test scans the same directory, so the loader and
## the test can never drift apart.
static func _scan_dialog_dir() -> void:
	var dir := DirAccess.open("res://Resources/Data/Mom/Dialog/")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load("res://Resources/Data/Mom/Dialog/" + file_name)
		if res is MomDialogNode and not _nodes.has(res.id):
			_nodes[res.id] = res


## get_tier(tier_id) -> MomPunishmentTier
##
## Returns the punishment tier for the given severity (0-5), clamped to
## the available range. Returns null only if data failed to load.
static func get_tier(tier_id: int) -> MomPunishmentTier:
	_ensure_data_loaded()
	var clamped: int = clampi(tier_id, 0, 5)
	return _tiers.get(clamped)


## get_dialog_node(node_id) -> MomDialogNode
##
## Returns the dialog node with the given id, or null if unknown.
static func get_dialog_node(node_id: String) -> MomDialogNode:
	_ensure_data_loaded()
	return _nodes.get(node_id)


## get_visit_tree_id(mom_mood) -> String
##
## Picks the root dialog node id for a meter-full visit at the given mood.
static func get_visit_tree_id(mom_mood: int) -> String:
	if mom_mood <= 3:
		return "visit_reward"
	return "visit_punishment"


## should_silent_treatment(severity) -> bool
##
## Silent-treatment visits: a rare, unnerving replacement for low-severity
## meter visits. Mom just stares. No punishment, but her mood worsens.
static func should_silent_treatment(severity: int) -> bool:
	if severity < 1 or severity > 2:
		return false
	return GameRNG.randf() < SILENT_TREATMENT_CHANCE


## get_checkin_tree_id(game_controller, mom_mood) -> String
##
## Picks the root dialog node for a random check-in:
##   - NC-17 item in inventory -> caught red-handed (confiscation visit)
##   - R or PG-13 item in inventory -> warning
##   - mood <= 3 with a lucky roll -> rare "cool mom" event
##   - otherwise -> weighted pick from CHECKIN_FLAVOR_POOL
static func get_checkin_tree_id(game_controller: Node, mom_mood: int) -> String:
	var ratings := scan_inventory_ratings(game_controller)
	if ratings["nc17"] > 0:
		return "checkin_caught_nc17"
	if ratings["r"] > 0 or ratings["pg13"] > 0:
		return "checkin_warning"
	if mom_mood <= 3 and GameRNG.randf() < COOL_MOM_CHANCE:
		return "checkin_cool_mom"
	return _pick_flavor_checkin()


## _pick_flavor_checkin() -> String
##
## Weighted random pick over CHECKIN_FLAVOR_POOL. Unknown ids (missing
## data) are skipped; falls back to "checkin_neutral".
static func _pick_flavor_checkin() -> String:
	_ensure_data_loaded()
	var total := 0.0
	for node_id in CHECKIN_FLAVOR_POOL:
		if _nodes.has(node_id):
			total += CHECKIN_FLAVOR_POOL[node_id]
	if total <= 0.0:
		return "checkin_neutral"
	var roll := GameRNG.randf() * total
	for node_id in CHECKIN_FLAVOR_POOL:
		if not _nodes.has(node_id):
			continue
		roll -= CHECKIN_FLAVOR_POOL[node_id]
		if roll <= 0.0:
			return node_id
	return "checkin_neutral"


## get_checkin_severity(tree_id) -> int
##
## Check-ins are non-punishment by default (severity 0). The NC-17 catch
## converts the visit into a Confiscation-tier incident.
static func get_checkin_severity(tree_id: String) -> int:
	if tree_id == "checkin_caught_nc17":
		return 3
	return 0


## scan_inventory_ratings(game_controller) -> Dictionary
##
## Counts owned PowerUps by POG rating band. Used to let Mom react to
## restricted items during check-ins.
##
## Returns: Dictionary {"nc17": int, "r": int, "pg13": int}
static func scan_inventory_ratings(game_controller: Node) -> Dictionary:
	var counts := {"nc17": 0, "r": 0, "pg13": 0}
	if game_controller == null:
		return counts
	var power_up_manager = game_controller.get("pu_manager")
	var active_power_ups: Dictionary = game_controller.get("active_power_ups")
	if active_power_ups == null or power_up_manager == null:
		return counts
	if not power_up_manager.has_method("get_def"):
		return counts

	for power_up_id in active_power_ups.keys():
		# Untyped on purpose: test stubs and PowerUpData both duck-type here
		var def = power_up_manager.get_def(power_up_id)
		if def == null:
			continue
		var rating = def.get("rating")
		if rating == null:
			rating = "G"
		var upper: String = rating.to_upper()
		if PowerUpData.is_rating_nc17(upper):
			counts["nc17"] += 1
		elif upper == "R":
			counts["r"] += 1
		elif upper == "PG-13":
			counts["pg13"] += 1

	return counts


# ─── Severity ───

## compute_severity(chores_manager) -> int
##
## Maps Mom's mood to a severity (0 = reward, 1-5 = punishment tiers):
##   mood 1-3 -> 0, 4-6 -> 1, 7 -> 2, 8 -> 3, 9 -> 4, 10 -> 5
## Grudge raises the severity floor (and is consumed/decayed here).
## The defer streak (successful defer_punishment outcomes) compounds on
## top of that floor, so deferred punishments come back harsher.
## Severity >= 3 visits also add the run's low-mood-visit count and
## register themselves for future escalation.
##
## Side-effects: consumes one grudge level; may register a low-mood visit.
static func compute_severity(chores_manager) -> int:
	var mood: int = chores_manager.get("mom_mood")
	var severity := 0
	if mood >= 10:
		severity = 5
	elif mood == 9:
		severity = 4
	elif mood == 8:
		severity = 3
	elif mood == 7:
		severity = 2
	elif mood >= 4:
		severity = 1

	if chores_manager.has_method("consume_grudge"):
		var grudge: int = chores_manager.consume_grudge()
		if grudge > 0:
			severity = maxi(severity, grudge)

	# Deferred punishments compound: each successful defer raises the
	# severity of the eventual resolution.
	var defer_streak := int(chores_manager.get("defer_streak")) if chores_manager.get("defer_streak") != null else 0
	if defer_streak > 0:
		severity = mini(severity + defer_streak, 5)

	if severity >= 3:
		severity += int(chores_manager.get("low_mood_visits_this_run"))
		severity = mini(severity, 5)
		if chores_manager.has_method("register_low_mood_visit"):
			chores_manager.register_low_mood_visit()

	return clampi(severity, 0, 5)


# ─── Weighted drawing ───

## _pick_weighted_index(weights) -> int
##
## Draws an index proportionally to weights via GameRNG.
static func _pick_weighted_index(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return 0
	var roll := GameRNG.randf() * total
	var acc := 0.0
	for i in range(weights.size()):
		acc += float(weights[i])
		if roll < acc:
			return i
	return weights.size() - 1


## draw_entries(tier) -> Array[Dictionary]
##
## Draws `tier.picks` entries from the tier without replacement,
## proportionally to entry weights.
static func draw_entries(tier: MomPunishmentTier) -> Array:
	var pool: Array = tier.entries.duplicate()
	var drawn: Array = []
	var picks: int = mini(tier.picks, pool.size())
	for i in range(picks):
		var weights: Array = []
		for entry in pool:
			weights.append(float(entry.get("weight", 0.0)))
		var idx := _pick_weighted_index(weights)
		drawn.append(pool[idx])
		pool.remove_at(idx)
	return drawn


## resolve_response(response) -> MomDialogOutcome
##
## Draws one weighted outcome from a player-picked dialog response.
static func resolve_response(response: MomDialogResponse) -> MomDialogOutcome:
	if response == null or response.outcomes.is_empty():
		return null
	var weights: Array = []
	for outcome in response.outcomes:
		weights.append(outcome.weight if outcome else 0.0)
	return response.outcomes[_pick_weighted_index(weights)]


## pick_response_index(node) -> int
##
## Bot policy: picks a response index by tone-weighted random
## (mostly polite, sometimes neutral, rarely sassy). Returns -1 for
## terminal nodes.
static func pick_response_index(node: MomDialogNode) -> int:
	if node == null or node.responses.is_empty():
		return -1
	var weights: Array = []
	for response in node.responses:
		weights.append(float(BOT_TONE_WEIGHTS.get(response.tone, 1.0)))
	return _pick_weighted_index(weights)


# ─── Result building ───

## apply_outcome(game_controller, outcome, severity, active_debuffs, is_sass) -> MomCheckResult
##
## Converts a drawn dialog outcome into consequences. Dialog-only deltas
## (mood/grudge) ride on the result; "apply_tier" resolves a full
## punishment tier; direct effects become single pseudo-entries.
##
## Parameters:
##   severity: int - the visit's computed severity (for apply_tier 0 / -1)
##   is_sass: bool - true for sassy-tone responses; punished outcomes then
##     escalate with the player's Rep tier (SASS_REP_* consts)
static func apply_outcome(game_controller: Node, outcome: MomDialogOutcome, severity: int, active_debuffs: Dictionary = {}, is_sass: bool = false) -> MomCheckResult:
	var result := MomCheckResult.new()
	if outcome == null:
		return result

	result.mood_delta = outcome.mood_delta
	result.grudge_delta = outcome.grudge_delta
	result.dialog_text = outcome.result_text
	if outcome.result_expression != "":
		result.expression = outcome.result_expression
	if outcome.effect == "storms_off":
		result.storms_off = true
		result.mom_is_upset = true
		return result

	if outcome.effect == "defer_punishment":
		# Successful sass pushes the pending punishment to a later visit.
		# No tier now; grudge +1 and ChoresManager.register_defer() (called
		# from apply_consequences) compound the eventual severity.
		result.deferred = true
		result.mom_is_upset = true
		result.grudge_delta += 1
		return result

	match outcome.effect:
		"none", "mood_delta", "grudge_delta":
			pass  # Field deltas already recorded above
		"rep_delta":
			# Story-beat Rep shift (applied via ProgressManager downstream)
			result.rep_delta += outcome.magnitude
		"apply_tier":
			var tier_id := outcome.magnitude
			if tier_id == 0:
				tier_id = severity
			elif tier_id == -1:
				tier_id = mini(severity + 1, 5)
			if is_sass:
				# Sass escalation: every SASS_REP_TIER_STEP Rep tiers add
				# +1 punishment tier (clamped to the valid 0-5 range).
				tier_id = mini(tier_id + ProgressManager.get_rep_tier() / SASS_REP_TIER_STEP, 5)
			var tier := get_tier(tier_id)
			if tier:
				result.tier_id = tier_id
				var entry_result := build_result_from_entries(game_controller, draw_entries(tier), active_debuffs, is_sass)
				_merge_result(result, entry_result)
		_:
			# Direct punishment/reward effect on the outcome itself
			var pseudo_entry := _outcome_to_entry(outcome)
			var entry_result := build_result_from_entries(game_controller, [pseudo_entry], active_debuffs, is_sass)
			_merge_result(result, entry_result)

	return result


## _outcome_to_entry(outcome) -> Dictionary
##
## Converts a direct-effect outcome into the tier-entry Dictionary schema.
static func _outcome_to_entry(outcome: MomDialogOutcome) -> Dictionary:
	var params: Dictionary = {}
	match outcome.effect:
		"fine":
			var amount := outcome.magnitude if outcome.magnitude > 0 else DEFAULT_REWARD_MIN
			params = {"min": amount, "max": amount}
		"debuff":
			params = {"count": maxi(outcome.magnitude, 1)}
		"remove_mod":
			params = {"count": maxi(outcome.magnitude, 1)}
		"confiscate_powerups":
			params = {"max_rating": "NC-17", "stack_debuffs": true}
		"reward_money":
			if outcome.magnitude > 0:
				params = {"min": outcome.magnitude, "max": outcome.magnitude}
			else:
				params = {"min": DEFAULT_REWARD_MIN, "max": DEFAULT_REWARD_MAX}
		"reward_consumable", "reward_powerup":
			params = {"pool": []}  # Empty pool falls back to the tier-0 pools
	return {
		"effect": outcome.effect,
		"weight": 1.0,
		"params": params,
		"permanent": outcome.permanent,
	}


## build_result_from_entries(game_controller, entries, active_debuffs, is_sass) -> MomCheckResult
##
## Resolves drawn tier entries into a MomCheckResult. This is the only
## place effect strings are interpreted.
static func build_result_from_entries(game_controller: Node, entries: Array, active_debuffs: Dictionary = {}, is_sass: bool = false) -> MomCheckResult:
	var result := MomCheckResult.new()
	for entry in entries:
		_resolve_entry(game_controller, entry, active_debuffs, result, is_sass)
	return result


static func _resolve_entry(game_controller: Node, entry: Dictionary, active_debuffs: Dictionary, result: MomCheckResult, is_sass: bool = false) -> void:
	var effect: String = entry.get("effect", "none")
	var params: Dictionary = entry.get("params", {})
	var permanent: bool = entry.get("permanent", false)

	match effect:
		"none":
			pass
		"fine":
			_resolve_fine(int(params.get("min", 0)), int(params.get("max", 0)), active_debuffs, result)
		"debuff":
			var count := int(params.get("count", 1))
			if is_sass and ProgressManager.get_rep_tier() >= SASS_REP_EXTRA_DEBUFF_MIN_TIER:
				count += 1
			for i in range(count):
				var debuff := _get_random_non_active_debuff(active_debuffs, result.applied_debuffs)
				if debuff != "":
					result.applied_debuffs.append(debuff)
			result.mom_is_upset = result.mom_is_upset or count > 0
		"confiscate_powerups":
			_resolve_confiscation(game_controller, params, result)
		"remove_mod":
			_resolve_mod_removal(game_controller, int(params.get("count", 1)), result)
		"lock_cosmetics":
			result.cosmetics_locked = true
			result.cosmetics_lock_permanent = permanent
			result.mom_is_upset = true
		"mood_delta":
			result.mood_delta += int(params.get("delta", 0))
		"reward_money":
			var low := int(params.get("min", DEFAULT_REWARD_MIN))
			var high := int(params.get("max", DEFAULT_REWARD_MAX))
			result.reward_money += GameRNG.randi_range(mini(low, high), maxi(low, high))
		"reward_consumable":
			var pool: Array = params.get("pool", [])
			if pool.is_empty():
				pool = TIER_00.entries[1]["params"]["pool"]  # tier-0 consumable pool
			if not pool.is_empty():
				result.reward_consumable_id = pool[GameRNG.random_index(pool)]
		"reward_powerup":
			_resolve_powerup_reward(game_controller, params, result)


## _resolve_fine(min_amount, max_amount, active_debuffs, result)
##
## Fines the player; substitutes a debuff when they cannot pay
## (legacy behavior from the no-chores fine).
static func _resolve_fine(min_amount: int, max_amount: int, active_debuffs: Dictionary, result: MomCheckResult) -> void:
	var amount := GameRNG.randi_range(min_amount, max_amount)
	var economy = _get_autoload("PlayerEconomy")
	var can_pay := false
	if economy and economy.has_method("can_afford"):
		can_pay = economy.can_afford(amount)
	if can_pay:
		result.fine_amount += amount
	else:
		var debuff := _get_random_non_active_debuff(active_debuffs, result.applied_debuffs)
		if debuff != "":
			result.applied_debuffs.append(debuff)
	result.mom_is_upset = true


## _resolve_confiscation(game_controller, params, result)
##
## Removes power-ups up to max_rating ("R" = R-rated only, "NC-17" = R and
## NC-17). With stack_debuffs, each NC-17 item also stacks a debuff
## (legacy grounding behavior).
static func _resolve_confiscation(game_controller: Node, params: Dictionary, result: MomCheckResult) -> void:
	var max_rating: String = params.get("max_rating", "R")
	var stack_debuffs: bool = params.get("stack_debuffs", false)
	var power_up_manager = game_controller.get("pu_manager")
	var active_power_ups: Dictionary = game_controller.get("active_power_ups")
	if active_power_ups == null:
		return

	var nc17_count := 0
	for power_up_id in active_power_ups.keys():
		var def := _get_power_up_def(power_up_manager, power_up_id)
		if def == null:
			continue
		var rating = def.get("rating") if def else "G"
		if rating == null:
			rating = "G"

		var take := false
		if PowerUpData.is_rating_nc17(rating):
			take = max_rating == "NC-17"
			if take:
				nc17_count += 1
				result.mom_is_furious = true
		elif PowerUpData.is_rating_restricted(rating):
			take = true  # Both "R" and "NC-17" max ratings cover R-rated items

		if take:
			result.removed_power_ups.append(power_up_id)
			result.mom_is_upset = true

	if stack_debuffs:
		for i in range(nc17_count):
			var debuff := _get_random_non_active_debuff({}, result.applied_debuffs)
			if debuff != "":
				result.applied_debuffs.append(debuff)


## _resolve_mod_removal(game_controller, count, result)
##
## Picks random active mods for permanent removal.
static func _resolve_mod_removal(game_controller: Node, count: int, result: MomCheckResult) -> void:
	var active_mods: Dictionary = game_controller.get("active_mods")
	if active_mods == null or active_mods.is_empty():
		return
	var pool: Array = active_mods.keys()
	for i in range(count):
		if pool.is_empty():
			break
		var idx := GameRNG.random_index(pool)
		result.removed_mods.append(pool[idx])
		pool.remove_at(idx)
	if not result.removed_mods.is_empty():
		result.mom_is_upset = true


## _resolve_powerup_reward(game_controller, params, result)
##
## Grants a safe power-up from the pool; falls back to money when the
## player already owns everything in the pool (legacy behavior).
static func _resolve_powerup_reward(game_controller: Node, params: Dictionary, result: MomCheckResult) -> void:
	var pool: Array = params.get("pool", [])
	if pool.is_empty():
		pool = TIER_00.entries[2]["params"]["pool"]  # tier-0 power-up pool
	var active_power_ups: Dictionary = game_controller.get("active_power_ups")
	if active_power_ups == null:
		active_power_ups = {}
	var candidates: Array = []
	for id in pool:
		if not active_power_ups.has(id):
			candidates.append(id)
	if candidates.is_empty():
		result.reward_money += GameRNG.randi_range(75, 125)
	else:
		result.reward_powerup_id = candidates[GameRNG.random_index(candidates)]


## _merge_result(target, source)
##
## Merges a partially built result into the target (outcome deltas and
## dialog text on the target are preserved).
static func _merge_result(target: MomCheckResult, source: MomCheckResult) -> void:
	target.removed_power_ups.append_array(source.removed_power_ups)
	target.removed_mods.append_array(source.removed_mods)
	target.applied_debuffs.append_array(source.applied_debuffs)
	target.fine_amount += source.fine_amount
	target.reward_money += source.reward_money
	if source.reward_consumable_id != "":
		target.reward_consumable_id = source.reward_consumable_id
	if source.reward_powerup_id != "":
		target.reward_powerup_id = source.reward_powerup_id
	target.cosmetics_locked = target.cosmetics_locked or source.cosmetics_locked
	target.cosmetics_lock_permanent = target.cosmetics_lock_permanent or source.cosmetics_lock_permanent
	target.mom_is_upset = target.mom_is_upset or source.mom_is_upset
	target.mom_is_furious = target.mom_is_furious or source.mom_is_furious
	target.deferred = target.deferred or source.deferred
	target.rep_delta += source.rep_delta


# ─── Consequence application ───

## apply_consequences(game_controller, result)
##
## Executes a MomCheckResult on the game state: removes power-ups and
## mods, deducts fines, applies debuffs, locks cosmetics, grants rewards,
## and applies mood/grudge deltas. Called by GameController after the
## dialog closes.
static func apply_consequences(game_controller: Node, result: MomCheckResult) -> void:
	# Remove power-ups
	for power_up_id in result.removed_power_ups:
		if game_controller.has_method("revoke_power_up"):
			game_controller.revoke_power_up(power_up_id)
		print("[MomLogicHandler] Removed power-up: %s" % power_up_id)

	# Remove mods (permanent, no refund - Mom is not a pawn shop)
	for mod_id in result.removed_mods:
		if game_controller.has_method("remove_mod_no_refund"):
			game_controller.remove_mod_no_refund(mod_id)
		print("[MomLogicHandler] Removed mod: %s" % mod_id)

	# Apply fine if any
	if result.fine_amount > 0:
		var economy = _get_autoload("PlayerEconomy")
		if economy and economy.has_method("remove_money"):
			economy.remove_money(result.fine_amount, "mom_fine")
			print("[MomLogicHandler] Fined player $%d" % result.fine_amount)

	# Apply debuffs
	for debuff_id in result.applied_debuffs:
		if game_controller.has_method("enable_debuff"):
			game_controller.enable_debuff(debuff_id)
		print("[MomLogicHandler] Applied debuff: %s" % debuff_id)

	# Lock cosmetics (dice colors). Temporary locks are re-enabled by
	# GameController at round end; permanent locks also wipe purchases.
	if result.cosmetics_locked:
		var dcm = _get_autoload("DiceColorManager")
		if dcm:
			if result.cosmetics_lock_permanent and dcm.has_method("_reset_purchased_colors"):
				dcm._reset_purchased_colors()
				print("[MomLogicHandler] Purchased dice colors confiscated (permanent)")
			if dcm.has_method("set_colors_enabled"):
				dcm.set_colors_enabled(false)
			print("[MomLogicHandler] Dice colors locked")

	# Grant rewards
	var economy = _get_autoload("PlayerEconomy")
	if result.reward_money > 0 and economy and economy.has_method("add_money"):
		economy.add_money(result.reward_money)
		print("[MomLogicHandler] Mom gave allowance: $%d" % result.reward_money)
	if result.reward_consumable_id != "" and game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable(result.reward_consumable_id)
		print("[MomLogicHandler] Mom gave consumable: %s" % result.reward_consumable_id)
	if result.reward_powerup_id != "" and game_controller.has_method("grant_power_up"):
		game_controller.grant_power_up(result.reward_powerup_id)
		print("[MomLogicHandler] Mom gave power-up: %s" % result.reward_powerup_id)

	# Apply mood/grudge deltas
	var chores_manager = game_controller.get("chores_manager")
	if chores_manager:
		if result.mood_delta != 0 and chores_manager.has_method("adjust_mood"):
			chores_manager.adjust_mood(result.mood_delta)
			print("[MomLogicHandler] Mood delta applied: %+d" % result.mood_delta)
		if result.grudge_delta != 0 and chores_manager.has_method("add_grudge"):
			chores_manager.add_grudge(result.grudge_delta)
			print("[MomLogicHandler] Grudge delta applied: %+d" % result.grudge_delta)

		# Defer streak bookkeeping: a successful defer compounds; actually
		# applying a punishment tier pays the bill and clears the streak.
		if result.deferred and chores_manager.has_method("register_defer"):
			chores_manager.register_defer()
		elif result.tier_id >= 1 and chores_manager.has_method("reset_defer_streak"):
			chores_manager.reset_defer_streak()


# ─── Helpers ───

## _get_random_non_active_debuff(active_debuffs, already_applied) -> String
##
## Returns a random debuff ID that is not currently active. Returns ""
## only when the pool itself is empty (never, with the current list).
static func _get_random_non_active_debuff(active_debuffs: Dictionary, already_applied: Array) -> String:
	var available: Array[String] = []
	for debuff_id in AVAILABLE_DEBUFFS:
		if not active_debuffs.has(debuff_id) and debuff_id not in already_applied:
			available.append(debuff_id)

	if available.is_empty():
		# All debuffs already active, pick a random one anyway (will stack or do nothing)
		return AVAILABLE_DEBUFFS[GameRNG.random_index(AVAILABLE_DEBUFFS)]

	return available[GameRNG.random_index(available)]


static func _get_power_up_def(power_up_manager: Node, id: String) -> PowerUpData:
	if power_up_manager == null:
		return null
	if power_up_manager.has_method("get_def"):
		return power_up_manager.get_def(id)
	return null


## _get_autoload(autoload_name) -> Node
##
## Safely fetches an autoload by name from the scene tree root.
static func _get_autoload(autoload_name: String) -> Node:
	var scene_tree = Engine.get_main_loop()
	if scene_tree and scene_tree.root:
		return scene_tree.root.get_node_or_null(autoload_name)
	return null
