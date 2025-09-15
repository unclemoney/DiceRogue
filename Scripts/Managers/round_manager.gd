extends Node
class_name RoundManager

signal round_started(round_number: int)
signal round_completed(round_number: int)
signal all_rounds_completed
signal round_failed(round_number: int)

@export var max_rounds: int = 6
@export var challenge_configs: Array[RoundChallengeConfig] = []
@export var dice_configs: Array[String] = ["d6", "d6", "d6", "d4", "d6", "d6"]  # Keep as fallback
@export var turn_tracker_path: NodePath
@export var challenge_manager_path: NodePath
@export var dice_hand_path: NodePath
@export var scorecard_path: NodePath

@onready var turn_tracker: TurnTracker = get_node_or_null(turn_tracker_path)
@onready var challenge_manager: ChallengeManager = get_node_or_null(challenge_manager_path)
@onready var dice_hand: DiceHand = get_node_or_null(dice_hand_path)
@onready var scorecard: Scorecard = get_node_or_null(scorecard_path)

var current_round: int = 0
var current_challenge_id: String = ""
var is_challenge_completed: bool = false
var rounds_data: Array[Dictionary] = []
var game_started: bool = false

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

func _initialize_rounds_data() -> void:
	rounds_data.clear()
	
	# Create data for each round
	for i in range(max_rounds):
		var round_index = i
		var round_number = i + 1
		
		var challenge_id = ""
		var dice_type = "d6"  # Default
		var target_score = 0
		
		# Set challenge if available in configs
		if round_index < challenge_configs.size():
			var config = challenge_configs[round_index]
			if config:
				challenge_id = config.challenge_id
				
				# Get dice type and target_score from ChallengeData if available
				var challenge_data = challenge_manager.get_def(challenge_id) if challenge_manager else null
				if challenge_data:
					if not challenge_data.dice_type.is_empty():
						dice_type = challenge_data.dice_type
						print("[RoundManager] Round", round_number, "using dice type from challenge:", dice_type)
					target_score = challenge_data.target_score * round_number 
					print("[RoundManager] Round", round_number, "target score set to:", target_score)
				elif round_index < dice_configs.size():
					# Fall back to dice_configs if no challenge-specific dice type
					dice_type = dice_configs[round_index]
					print("[RoundManager] Round", round_number, "using fallback dice type:", dice_type)
		elif round_index < dice_configs.size():
			# If no challenge config but we have a dice config, use that
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
	
	print("[RoundManager] Initialized", rounds_data.size(), "rounds")

func start_game() -> void:
	print("[RoundManager] Game is ready. Waiting for player to start the first round.")
	current_round = 0
	is_challenge_completed = false
	game_started = true
	
	# Enable first round's Next Round button immediately
	emit_signal("round_completed", 0)  # Send signal as round 0 completed
	
	# Pre-load the challenge ID for the first round
	if rounds_data.size() > 0:
		current_challenge_id = rounds_data[0].challenge_id
		print("[RoundManager] Prepared first round challenge ID:", current_challenge_id)

func start_round(round_number: int) -> void:
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
	
	# Reset the scorecard
	if scorecard:
		scorecard.reset_scores()
	
	# Activate the challenge
	if challenge_manager and not current_challenge_id.is_empty():
		# Let the game controller handle challenge activation
		emit_signal("round_started", round_number)
	else:
		push_error("[RoundManager] No challenge configured for round", round_number)
		emit_signal("round_started", round_number)

func complete_round() -> void:
	var round_number = current_round + 1  # Convert to 1-based
	print("[RoundManager] Completing Round", round_number)
	
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

func fail_round() -> void:
	var round_number = current_round + 1  # Convert to 1-based
	print("[RoundManager] Failed Round", round_number)
	
	# Mark current round as failed
	if current_round < rounds_data.size():
		rounds_data[current_round].failed = true
	
	emit_signal("round_failed", round_number)

func get_current_round_number() -> int:
	return current_round + 1  # Convert to 1-based

func get_current_round_data() -> Dictionary:
	if current_round >= 0 and current_round < rounds_data.size():
		return rounds_data[current_round]
	return {}

func can_proceed_to_next_round() -> bool:
	return is_challenge_completed and current_round < max_rounds - 1

func _on_challenge_completed(challenge_id: String) -> void:
	if challenge_id == current_challenge_id:
		print("[RoundManager] Current challenge completed:", challenge_id)
		is_challenge_completed = true
	else:
		print("[RoundManager] Different challenge completed:", challenge_id)

func _on_challenge_failed(challenge_id: String) -> void:
	if challenge_id == current_challenge_id:
		print("[RoundManager] Current challenge failed:", challenge_id)
		fail_round()
	else:
		print("[RoundManager] Different challenge failed:", challenge_id)
