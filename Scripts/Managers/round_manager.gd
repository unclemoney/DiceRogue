extends Node
class_name RoundManager

## RoundManager
##
## Manages the game's round lifecycle: preparing round data, starting rounds,
## signaling when rounds start/complete/fail, and coordinating with the
## TurnTracker, DiceHand and Scorecard.
##
## Rounds as Stores:
## Each round of a zone is a store. The store name comes from ChannelManager's
## per-run store assignment (get_store_name). The win condition is reaching the
## round's target score (from the channel's RoundDifficultyConfig); the
## Challenge system is deprecated — ChallengeManager survives only as a
## signal hub re-emitting `challenge_completed`/`challenge_failed` for
## existing listeners (power-ups, UI, music, bot).

signal round_started(round_number: int)
signal round_completed(round_number: int)
signal all_rounds_completed
signal round_failed(round_number: int)

@export var max_rounds: int = 6
@export var dice_configs: Array[String] = ["d6", "d6", "d6", "d4", "d6", "d6"]  # Keep as fallback
@export var turn_tracker_path: NodePath
@export var challenge_manager_path: NodePath
@export var dice_hand_path: NodePath
@export var scorecard_path: NodePath
@export var channel_manager_path: NodePath = ^"../ChannelManager"
@export var debuff_manager_path: NodePath = ^"../DebuffManager"

@onready var turn_tracker: TurnTracker = get_node_or_null(turn_tracker_path)
@onready var challenge_manager: ChallengeManager = get_node_or_null(challenge_manager_path)
@onready var dice_hand: DiceHand = get_node_or_null(dice_hand_path)
@onready var scorecard: Scorecard = get_node_or_null(scorecard_path)
@onready var channel_manager = get_node_or_null(channel_manager_path)
@onready var debuff_manager: DebuffManager = get_node_or_null(debuff_manager_path)

var current_round: int = 0
## True once the current round's target score has been reached.
## (Formerly is_challenge_completed; name kept for existing callers.)
var is_challenge_completed: bool = false
var rounds_data: Array[Dictionary] = []
var game_started: bool = false
## Dice set used for every round of the current run, chosen in the Mall Zone
## Selection. Set by GameController.
var run_dice_type: String = "d6"


## set_run_dice_type(type: String) -> void
##
## Sets the dice set for the whole run; applied to all rounds.
func set_run_dice_type(type: String) -> void:
	run_dice_type = type
	print("[RoundManager] Run dice type set to:", run_dice_type)

## _ready()
##
## Lifecycle method: verifies required node references, connects to the
## ChallengeManager signal hub, and initializes internal rounds data.
## Does not auto-start the first round.

func _ready() -> void:
	add_to_group("round_manager")
	print("[RoundManager] Initializing")

	# Ensure all required nodes are available
	if not turn_tracker:
		push_error("[RoundManager] Missing turn_tracker reference")
		return

	if not challenge_manager:
		push_error("[RoundManager] Missing challenge_manager reference")
		return

	if not dice_hand:
		push_error("[RoundManager] Missing dice_hand reference")
		return

	if not scorecard:
		push_error("[RoundManager] Missing scorecard reference")
		return

	# Connect to the ChallengeManager signal hub. With challenges deprecated,
	# GameController emits these when the round target is met or failed.
	if challenge_manager:
		challenge_manager.challenge_completed.connect(_on_challenge_completed)
		challenge_manager.challenge_failed.connect(_on_challenge_failed)

	# Initialize rounds data
	_initialize_rounds_data()
	# Do NOT start the first round automatically

## _initialize_rounds_data()
##
## Prepares the `rounds_data` array for the current zone: one store per round.
## Store names come from ChannelManager's per-run assignment; target scores
## come from the channel's RoundDifficultyConfig.target_score_override.
## Each round's debuffs (and possible grounding) are pre-selected here from
## the round config so the New Round Panel preview — and the later mall map
## popup — can show exactly what the round will apply.
func _initialize_rounds_data() -> void:
	rounds_data.clear()

	var zone: int = 1
	if is_instance_valid(channel_manager):
		zone = channel_manager.current_channel

	for i in range(max_rounds):
		var round_number = i + 1

		var store_name: String = "Store %d-%d" % [zone, round_number]
		var target_score: int = 0
		var debuff_ids: Array[String] = []
		var grounding_id: String = ""
		if is_instance_valid(channel_manager):
			store_name = channel_manager.get_store_name(zone, round_number)
			var round_config = channel_manager.get_round_config(zone, round_number)
			if round_config:
				if round_config.target_score_override > 0:
					target_score = round_config.target_score_override
				var preselected = _preselect_round_debuffs(round_config)
				debuff_ids = preselected["debuff_ids"]
				grounding_id = preselected["grounding_id"]

		var round_data = {
			"round_number": round_number,
			"store_name": store_name,
			"dice_type": run_dice_type,
			"target_score": target_score,
			"completed": false,
			"failed": false,
			"debuff_ids": debuff_ids,
			"grounding_id": grounding_id
		}

		rounds_data.append(round_data)
		print("[RoundManager] Round %d: store '%s', target %d" % [round_number, store_name, target_score])

	print("[RoundManager] Initialized", rounds_data.size(), "rounds for zone", zone)

## _preselect_round_debuffs(round_config) -> Dictionary
##
## Draws the round's debuffs and grounding from its RoundDifficultyConfig,
## mirroring the selection rules GameController uses at round start:
## boss rounds draw exactly one debuff of boss_debuff_level; other rounds
## draw up to max_debuffs within debuff_difficulty_cap; a grounding is
## rolled separately against grounding_chance. Ids drawn within this round
## exclude each other via used_ids. Returns {"debuff_ids": Array[String],
## "grounding_id": String}; both empty when the debuff manager is missing
## (matches the zero-debuff fallback used when managers are unavailable).
func _preselect_round_debuffs(round_config: RoundDifficultyConfig) -> Dictionary:
	var result = {
		"debuff_ids": [] as Array[String],
		"grounding_id": ""
	}
	if not is_instance_valid(debuff_manager):
		return result

	var used_ids: Array[String] = []
	if round_config.get("is_boss_round") == true:
		# Boss round: exactly one debuff of the configured level
		var boss_id = debuff_manager.select_boss_debuff(round_config.boss_debuff_level, used_ids)
		if not boss_id.is_empty():
			result["debuff_ids"].append(boss_id)
	else:
		var max_debuffs = round_config.max_debuffs if round_config.get("max_debuffs") != null else 0
		var difficulty_cap = round_config.debuff_difficulty_cap if round_config.get("debuff_difficulty_cap") != null else 1
		result["debuff_ids"] = debuff_manager.select_debuffs_for_round(max_debuffs, difficulty_cap, false, used_ids)
	for id in result["debuff_ids"]:
		if id not in used_ids:
			used_ids.append(id)

	# Grounding draw: separate pool, shares the debuff UI slots.
	var grounding_chance = round_config.grounding_chance if round_config.get("grounding_chance") != null else 0.0
	if grounding_chance > 0.0 and randf() < grounding_chance:
		var grounding_id = debuff_manager.select_grounding_for_round(used_ids)
		if not grounding_id.is_empty():
			result["grounding_id"] = grounding_id

	return result

## start_game()
##
## Prepares the manager for gameplay start: resets counters, ensures the turn tracker
## is inactive, and emits a `round_completed` with 0 to enable UI transition for the
## first round. Does not automatically start the round — it signals readiness.
func start_game() -> void:
	print("[RoundManager] Game starting. Initializing rounds for selected channel...")
	current_round = 0
	is_challenge_completed = false
	game_started = true

	# IMPORTANT: Regenerate rounds data NOW that channel is selected
	# so store names and targets match the current zone.
	_initialize_rounds_data()
	print("[RoundManager] Rounds data initialized for channel:", channel_manager.current_channel if channel_manager else "unknown")

	# Reset colored dice purchases for new game session
	if DiceColorManager:
		#DiceColorManager.clear_purchased_colors()
		print("[RoundManager] Cleared colored dice purchases for new game has been disabled here")

	# Make sure turn tracker is in inactive state with no rolls
	if turn_tracker:
		turn_tracker.current_turn = 0
		turn_tracker.rolls_left = 0
		turn_tracker.is_active = false
		turn_tracker.emit_signal("rolls_updated", 0)

	# Enable first round's Next Round button immediately
	emit_signal("round_completed", 0)  # Send signal as round 0 completed

## start_round(round_number)
##
## Begins the specified round number (1-based). Validates the number, resets
## trackers, configures dice and scorecard, and emits `round_started` so the
## rest of the system can set up the round target.
func start_round(round_number: int) -> void:
	print("[RoundManager] Starting round", round_number)
	if round_number < 1 or round_number > max_rounds:
		push_error("[RoundManager] Invalid round number:", round_number)
		return

	current_round = round_number - 1  # Convert to 0-based index
	is_challenge_completed = false

	# Reset turn tracker
	if turn_tracker:
		turn_tracker.reset()

	# Get data for this round
	var round_data = rounds_data[current_round]

	print("[RoundManager] Starting Round", round_number)
	print("[RoundManager] Setting dice type to", round_data.dice_type)
	print("[RoundManager] Store:", round_data.get("store_name", "?"), "Target:", round_data.get("target_score", 0))

	# Set the dice type
	if dice_hand:
		dice_hand.switch_dice_type(round_data.dice_type)

		# Propagate dice sides to scoring systems for dynamic upper section
		var dice_sides = dice_hand.default_dice_data.sides if dice_hand.default_dice_data else 6
		if scorecard:
			scorecard.set_dice_type(dice_sides)
		ScoreEvaluatorSingleton.set_dice_sides(dice_sides)

		# Update ScoreCardUI category labels for the active dice set
		var score_card_ui = get_tree().get_first_node_in_group("scorecard_ui")
		if is_instance_valid(score_card_ui) and score_card_ui.has_method("update_dice_set_category_labels"):
			score_card_ui.update_dice_set_category_labels()

		print("[RoundManager] Propagated dice sides (%d) to scorecard and evaluator" % dice_sides)

	# Reset the scorecard scores but preserve category levels (upgrades persist across rounds)
	if scorecard:
		scorecard.reset_scores_preserve_levels()

	# Clear dice color effects for new round (but preserve PowerUp/Consumable effects)
	if DiceColorManager:
		DiceColorManager.clear_color_effects()
		print("[RoundManager] Dice color effects cleared for round", round_number)

	emit_signal("round_started", round_number)

## complete_round()
##
## Marks the current round as completed, emits `round_completed`, and emits
## `all_rounds_completed` if it was the final round.
func complete_round() -> void:
	var round_number = current_round + 1  # Convert to 1-based
	print("[RoundManager] Completing Round", round_number, "(current_round index:", current_round, ")")

	# Mark current round as completed
	if current_round < rounds_data.size():
		rounds_data[current_round].completed = true

	emit_signal("round_completed", round_number)

	# Check if this was the last round
	if round_number >= max_rounds:
		print("[RoundManager] All rounds completed!")
		emit_signal("all_rounds_completed")
	else:
		# Ready for next round
		print("[RoundManager] Ready for next round")

## fail_round()
##
## Marks the current round as failed and emits `round_failed`.
func fail_round() -> void:
	var round_number = current_round + 1  # Convert to 1-based
	print("[RoundManager] Failed Round", round_number)

	# Mark current round as failed
	if current_round < rounds_data.size():
		rounds_data[current_round].failed = true

	emit_signal("round_failed", round_number)

## get_current_round_number()
##
## Returns the current round number (1-based). Useful for UI and external systems.
func get_current_round_number() -> int:
	return current_round + 1  # Convert to 1-based

## get_current_round_data()
##
## Returns the current round's data dictionary or an empty dictionary when none.
func get_current_round_data() -> Dictionary:
	if current_round >= 0 and current_round < rounds_data.size():
		return rounds_data[current_round]
	push_warning("[RoundManager] current_round out of bounds, returning empty dict")
	return {}

## can_proceed_to_next_round()
##
## Returns true when the current round's target is met and there remains another round.
func can_proceed_to_next_round() -> bool:
	return is_challenge_completed and current_round < max_rounds - 1

## _on_challenge_completed(_id)
##
## Signal hub handler: the round target has been met (emitted by GameController
## through ChallengeManager). Sets `is_challenge_completed` so the UI can progress.
func _on_challenge_completed(_id: String) -> void:
	print("[RoundManager] Round target met - setting is_challenge_completed = true")
	is_challenge_completed = true

## _on_challenge_failed(_id)
##
## Signal hub handler: the round has failed (scorecard full below target).
func _on_challenge_failed(_id: String) -> void:
	print("[RoundManager] Round failed")
	fail_round()


## calculate_empty_category_bonus(scorecard_ref: Scorecard) -> int
##
## Calculates the bonus for unscored categories on the scorecard.
## Awards $5 per empty (null) category in both upper and lower sections.
## @param scorecard_ref: Reference to the Scorecard node
## @return: Total bonus amount for empty categories
func calculate_empty_category_bonus(scorecard_ref) -> int:
	const EMPTY_CATEGORY_BONUS: int = 5
	var empty_count: int = 0

	# Count upper section empty categories
	if scorecard_ref and scorecard_ref.upper_scores:
		for category in scorecard_ref.upper_scores.keys():
			if scorecard_ref.upper_scores[category] == null:
				empty_count += 1
				print("[RoundManager] Empty upper category:", category)

	# Count lower section empty categories
	if scorecard_ref and scorecard_ref.lower_scores:
		for category in scorecard_ref.lower_scores.keys():
			if scorecard_ref.lower_scores[category] == null:
				empty_count += 1
				print("[RoundManager] Empty lower category:", category)

	var bonus = empty_count * EMPTY_CATEGORY_BONUS
	print("[RoundManager] Empty category count:", empty_count, "Bonus:", bonus)
	return bonus


## calculate_score_above_target_bonus(final_score: int, target_score: int) -> int
##
## Calculates the bonus for scoring above the round target.
## Awards $1 per point above the target score, capped at $100.
## @param final_score: The player's final score for the round
## @param target_score: The round's target score to beat
## @return: Total bonus amount for points above target
func calculate_score_above_target_bonus(final_score: int, target_score: int) -> int:
	const POINTS_ABOVE_BONUS: int = 1
	const MAX_POINTS_ABOVE_BONUS: int = 100
	var points_above = max(0, final_score - target_score)
	var bonus = min(MAX_POINTS_ABOVE_BONUS, points_above * POINTS_ABOVE_BONUS)
	print("[RoundManager] Final score:", final_score, "Target:", target_score, "Points above:", points_above, "Bonus:", bonus)
	return bonus


## get_current_challenge_target_score() -> int
##
## Returns the target score for the current round.
func get_current_challenge_target_score() -> int:
	if current_round >= 0 and current_round < rounds_data.size():
		return rounds_data[current_round].get("target_score", 0)
	return 0


## set_current_challenge_target_score(new_target: int) -> void
##
## Updates the target score for the current round.
## Used by GameController to apply channel difficulty scaling.
func set_current_challenge_target_score(new_target: int) -> void:
	if current_round >= 0 and current_round < rounds_data.size():
		rounds_data[current_round]["target_score"] = new_target
		print("[RoundManager] Updated current round target score to:", new_target)


## get_state() -> Dictionary
##
## Returns the current round manager state for saving.
func get_state() -> Dictionary:
	return {
		"current_round": current_round,
		"is_challenge_completed": is_challenge_completed,
		"game_started": game_started,
		"max_rounds": max_rounds,
		"rounds_data": rounds_data.duplicate(true)
	}


## load_state(state)
##
## Restores the round manager state from a saved dictionary.
func load_state(state: Dictionary) -> void:
	current_round = state.get("current_round", 0)
	is_challenge_completed = state.get("is_challenge_completed", false)
	game_started = state.get("game_started", false)
	max_rounds = state.get("max_rounds", 6)
	var loaded_rounds = state.get("rounds_data", [])
	rounds_data.assign(loaded_rounds)
	print("[RoundManager] State loaded - round:", current_round)
