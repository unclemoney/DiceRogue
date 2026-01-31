extends Node
class_name RoundManager

## RoundManager
##
## Manages the game's round lifecycle: preparing round data, starting rounds,
## signaling when rounds start/complete/fail, and coordinating with the
## TurnTracker, ChallengeManager, DiceHand and Scorecard.
##
## Challenge Selection:
## At game start, challenges are randomly selected based on difficulty tiers (0-5).
## Each round gets one challenge from its corresponding difficulty tier.
## If a tier has no challenges, the system falls back to adjacent tiers.
##
signal round_started(round_number: int)
signal round_completed(round_number: int)
signal all_rounds_completed
signal round_failed(round_number: int)

@export var max_rounds: int = 6
@export var challenge_configs: Array[RoundChallengeConfig] = []  ## Deprecated: kept for backwards compatibility
@export var dice_configs: Array[String] = ["d6", "d6", "d6", "d4", "d6", "d6"]  # Keep as fallback
@export var turn_tracker_path: NodePath
@export var challenge_manager_path: NodePath
@export var dice_hand_path: NodePath
@export var scorecard_path: NodePath
@export var channel_manager_path: NodePath = ^"../ChannelManager"

@onready var turn_tracker: TurnTracker = get_node_or_null(turn_tracker_path)
@onready var challenge_manager: ChallengeManager = get_node_or_null(challenge_manager_path)
@onready var dice_hand: DiceHand = get_node_or_null(dice_hand_path)
@onready var scorecard: Scorecard = get_node_or_null(scorecard_path)
@onready var channel_manager = get_node_or_null(channel_manager_path)

var current_round: int = 0
var current_challenge_id: String = ""
var is_challenge_completed: bool = false
var rounds_data: Array[Dictionary] = []
var game_started: bool = false
var challenge_seed: int = 0  ## Seed used for random challenge selection

## _ready()
##
## Lifecycle method: verifies required node references, connects challenge signals,
## and initializes internal rounds data. Does not auto-start the first round.

func _ready() -> void:
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
	
	print("[RoundManager] Listing challenge config names:")
	for i in range(challenge_configs.size()):
		var config = challenge_configs[i]
		if config:
			print("Challenge", i, ":", config.challenge_id)
		else:
			print("Challenge", i, ": <null>")

	# Connect to challenge signals
	if challenge_manager:
		challenge_manager.challenge_completed.connect(_on_challenge_completed)
		challenge_manager.challenge_failed.connect(_on_challenge_failed)
	
	# Initialize rounds data
	_initialize_rounds_data()
	# Do NOT start the first round automatically

## _initialize_rounds_data()
##
## Prepares the `rounds_data` array based on `max_rounds` using dynamically
## generated challenge sequences. Generates a new seed and selects one challenge
## per difficulty tier (0 through max_rounds-1).
func _initialize_rounds_data() -> void:
	rounds_data.clear()
	
	# Generate random challenge sequence based on difficulty tiers
	var challenge_sequence = _generate_challenge_sequence()
	
	# Create data for each round
	for i in range(max_rounds):
		var round_index = i
		var round_number = i + 1
		
		var challenge_id = ""
		var dice_type = "d6"  # Default
		var target_score = 0
		
		# Get challenge from generated sequence
		if round_index < challenge_sequence.size():
			var challenge_data = challenge_sequence[round_index]
			if challenge_data:
				challenge_id = challenge_data.id
				if not challenge_data.dice_type.is_empty():
					dice_type = challenge_data.dice_type
					print("[RoundManager] Round", round_number, "using dice type from challenge:", dice_type)
				target_score = challenge_data.target_score
				print("[RoundManager] Round", round_number, "challenge:", challenge_id, "target score:", target_score, "difficulty:", challenge_data.difficulty)
		elif round_index < dice_configs.size():
			# Fall back to dice_configs if no challenge
			dice_type = dice_configs[round_index]
		
		var round_data = {
			"round_number": round_number,
			"challenge_id": challenge_id,
			"dice_type": dice_type,
			"target_score": target_score,
			"completed": false,
			"failed": false
		}
		
		rounds_data.append(round_data)
	
	print("[RoundManager] Initialized", rounds_data.size(), "rounds with seed:", challenge_seed)


## _generate_challenge_sequence() -> Array[ChallengeData]
##
## Generates a random sequence of challenges for the game session.
## Uses channel config difficulty ranges to select challenges for each round.
## Falls back to tier=round_index if no channel config is available.
## Uses seeded random for reproducibility.
## @return: Array of ChallengeData resources in round order
func _generate_challenge_sequence() -> Array[ChallengeData]:
	var result: Array[ChallengeData] = []
	
	if not challenge_manager:
		push_error("[RoundManager] Cannot generate challenge sequence - ChallengeManager is null")
		return result
	
	# Generate seed from time if not already set
	if challenge_seed == 0:
		challenge_seed = Time.get_ticks_msec()
	
	print("[RoundManager] Generating challenge sequence with seed:", challenge_seed)
	
	# Create seeded random number generator
	var rng = RandomNumberGenerator.new()
	rng.seed = challenge_seed
	
	# Group challenges by difficulty tier
	var challenges_by_difficulty: Dictionary = {}
	for tier in range(6):
		challenges_by_difficulty[tier] = []
	
	# Get all challenge definitions and sort by difficulty
	var all_challenges = challenge_manager.get_all_defs()
	for challenge_data in all_challenges:
		var difficulty = challenge_data.difficulty
		if difficulty >= 0 and difficulty <= 5:
			challenges_by_difficulty[difficulty].append(challenge_data)
			print("[RoundManager] Challenge '", challenge_data.id, "' added to difficulty tier", difficulty)
	
	# Select one challenge per round based on channel config's difficulty ranges
	for round_index in range(max_rounds):
		var difficulty_range: Vector2i = _get_difficulty_range_for_round(round_index)
		var selected_challenge: ChallengeData = _select_challenge_in_range(difficulty_range, challenges_by_difficulty, rng)
		if selected_challenge:
			result.append(selected_challenge)
			print("[RoundManager] Round", round_index + 1, "selected challenge:", selected_challenge.id, "(difficulty", selected_challenge.difficulty, ", range:", difficulty_range, ")")
		else:
			push_warning("[RoundManager] No challenge found for round", round_index + 1, "with range", difficulty_range, "- round will have no challenge")
	
	return result


## _get_difficulty_range_for_round(round_index) -> Vector2i
##
## Gets the difficulty range for a specific round from the channel config.
## Falls back to (round_index, round_index) if no channel config is available.
## @param round_index: The round index (0-based)
## @return: Vector2i with (min_difficulty, max_difficulty)
func _get_difficulty_range_for_round(round_index: int) -> Vector2i:
	var round_number = round_index + 1  # Convert to 1-based
	if channel_manager and channel_manager.has_method("get_challenge_difficulty_range"):
		# Pass -1 for channel to use current_channel, and round_number (1-based)
		return channel_manager.get_challenge_difficulty_range(-1, round_number)
	
	# Fallback: use round_index as the exact tier (original behavior)
	var tier = clampi(round_index, 0, 5)
	return Vector2i(tier, tier)


## _select_challenge_in_range(difficulty_range, challenges_by_difficulty, rng) -> ChallengeData
##
## Selects a random challenge within the given difficulty range.
## Collects all challenges in the range, then picks one randomly.
## Falls back to expanding the range if no challenges are found.
## @param difficulty_range: Vector2i with (min_difficulty, max_difficulty)
## @param challenges_by_difficulty: Dictionary mapping tiers to challenge arrays
## @param rng: RandomNumberGenerator instance for seeded selection
## @return: Selected ChallengeData or null if none available
func _select_challenge_in_range(difficulty_range: Vector2i, challenges_by_difficulty: Dictionary, rng: RandomNumberGenerator) -> ChallengeData:
	var min_tier = clampi(difficulty_range.x, 0, 5)
	var max_tier = clampi(difficulty_range.y, 0, 5)
	
	# Collect all challenges within the range
	var valid_challenges: Array[ChallengeData] = []
	for tier in range(min_tier, max_tier + 1):
		var tier_challenges = challenges_by_difficulty.get(tier, [])
		for challenge in tier_challenges:
			valid_challenges.append(challenge)
	
	# If we found valid challenges, pick one randomly
	if valid_challenges.size() > 0:
		var index = rng.randi_range(0, valid_challenges.size() - 1)
		return valid_challenges[index]
	
	# Fallback: expand search outward from the range
	for offset in range(1, 6):
		# Try below min_tier
		var lower_tier = min_tier - offset
		if lower_tier >= 0:
			var lower_challenges = challenges_by_difficulty.get(lower_tier, [])
			if lower_challenges.size() > 0:
				var index = rng.randi_range(0, lower_challenges.size() - 1)
				print("[RoundManager] Range", difficulty_range, "empty, using fallback from tier", lower_tier)
				return lower_challenges[index]
		
		# Try above max_tier
		var higher_tier = max_tier + offset
		if higher_tier <= 5:
			var higher_challenges = challenges_by_difficulty.get(higher_tier, [])
			if higher_challenges.size() > 0:
				var index = rng.randi_range(0, higher_challenges.size() - 1)
				print("[RoundManager] Range", difficulty_range, "empty, using fallback from tier", higher_tier)
				return higher_challenges[index]
	
	return null

# In round_manager.gd - Update start_game to explicitly set turn_tracker to inactive state
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
	# This ensures challenge difficulty ranges match the selected channel
	challenge_seed = 0  # Reset seed for new random sequence
	_initialize_rounds_data()
	print("[RoundManager] Rounds data initialized for channel:", channel_manager.current_channel if channel_manager else "unknown")

	# Reset colored dice purchases for new game session
	if DiceColorManager:
		DiceColorManager.clear_purchased_colors()
		print("[RoundManager] Cleared colored dice purchases for new game")

	# Make sure turn tracker is in inactive state with no rolls
	if turn_tracker:
		turn_tracker.current_turn = 0
		turn_tracker.rolls_left = 0
		turn_tracker.is_active = false
		turn_tracker.emit_signal("rolls_updated", 0)

	# Enable first round's Next Round button immediately
	emit_signal("round_completed", 0)  # Send signal as round 0 completed

	# Pre-load the challenge ID for the first round
	if rounds_data.size() > 0:
		current_challenge_id = rounds_data[0].challenge_id
		print("[RoundManager] Prepared first round challenge ID:", current_challenge_id)

## start_round(round_number)
##
## Begins the specified round number (1-based). Validates the number, resets
## trackers, configures dice and scorecard, and emits `round_started` so the
## rest of the system can activate the challenge.
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
	current_challenge_id = round_data.challenge_id

	print("[RoundManager] Starting Round", round_number)
	print("[RoundManager] Setting dice type to", round_data.dice_type)
	print("[RoundManager] Challenge ID:", current_challenge_id)

	# Set the dice type
	if dice_hand:
		dice_hand.switch_dice_type(round_data.dice_type)

	# Reset the scorecard scores but preserve category levels (upgrades persist across rounds)
	if scorecard:
		scorecard.reset_scores_preserve_levels()

	# Clear dice color effects for new round (but preserve PowerUp/Consumable effects)
	if DiceColorManager:
		DiceColorManager.clear_color_effects()
		print("[RoundManager] Dice color effects cleared for round", round_number)

	# Reset all multipliers for new round
	#ScoreModifierManager.reset()
	#print("[RoundManager] All multipliers reset for round", round_number)

	# Activate the challenge
	if challenge_manager and not current_challenge_id.is_empty():
		# Let the game controller handle challenge activation
		emit_signal("round_started", round_number)
	else:
		push_error("[RoundManager] No challenge configured for round", round_number)
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
## Returns true when the current challenge is completed and there remains another round.
func can_proceed_to_next_round() -> bool:
	return is_challenge_completed and current_round < max_rounds - 1

## _on_challenge_completed(challenge_id)
##
## Signal handler: marks the round as challenge-completed if the ID matches the
## current challenge. Sets `is_challenge_completed` to true so the UI can progress.
func _on_challenge_completed(challenge_id: String) -> void:
	print("[RoundManager] _on_challenge_completed received:", challenge_id)
	print("[RoundManager] current_challenge_id is:", current_challenge_id)
	if challenge_id == current_challenge_id:
		print("[RoundManager] ✓ Current challenge completed - setting is_challenge_completed = true")
		is_challenge_completed = true
	else:
		print("[RoundManager] ✗ Challenge ID mismatch - expected:", current_challenge_id, "got:", challenge_id)

## _on_challenge_failed(challenge_id)
##
## Signal handler: if the currently-active challenge fails, marks the round as failed.
func _on_challenge_failed(challenge_id: String) -> void:
	if challenge_id == current_challenge_id:
		print("[RoundManager] Current challenge failed:", challenge_id)
		fail_round()
	else:
		print("[RoundManager] Different challenge failed:", challenge_id)


## calculate_empty_category_bonus(scorecard_ref: Scorecard) -> int
##
## Calculates the bonus for unscored categories on the scorecard.
## Awards $25 per empty (null) category in both upper and lower sections.
## @param scorecard_ref: Reference to the Scorecard node
## @return: Total bonus amount for empty categories
func calculate_empty_category_bonus(scorecard_ref) -> int:
	const EMPTY_CATEGORY_BONUS: int = 25
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
## Calculates the bonus for scoring above the challenge target.
## Awards $1 per point above the target score.
## @param final_score: The player's final score for the round
## @param target_score: The challenge's target score to beat
## @return: Total bonus amount for points above target
func calculate_score_above_target_bonus(final_score: int, target_score: int) -> int:
	const POINTS_ABOVE_BONUS: int = 1
	var points_above = max(0, final_score - target_score)
	var bonus = points_above * POINTS_ABOVE_BONUS
	print("[RoundManager] Final score:", final_score, "Target:", target_score, "Points above:", points_above, "Bonus:", bonus)
	return bonus


## get_current_challenge_target_score() -> int
##
## Returns the target score for the current round's challenge.
func get_current_challenge_target_score() -> int:
	if current_round >= 0 and current_round < rounds_data.size():
		return rounds_data[current_round].get("target_score", 0)
	return 0


## set_current_challenge_target_score(new_target: int) -> void
##
## Updates the target score for the current round's challenge.
## Used by GameController to apply channel difficulty scaling.
func set_current_challenge_target_score(new_target: int) -> void:
	if current_round >= 0 and current_round < rounds_data.size():
		rounds_data[current_round]["target_score"] = new_target
		print("[RoundManager] Updated current round target score to:", new_target)
