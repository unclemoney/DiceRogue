extends Control

@export var dice_hand_path:      NodePath
@export var score_card_ui_path:  NodePath
@export var turn_tracker_path:   NodePath
@export var round_manager_path:  NodePath
@export var challenge_manager_path: NodePath 
@onready var challenge_manager: ChallengeManager = get_node_or_null(challenge_manager_path)

@onready var shop_button: Button = $HBoxContainer/ShopButton
@onready var next_round_button: Button = $HBoxContainer/NextRoundButton  
@onready var roll_button: Button = $HBoxContainer/RollButton
@onready var next_turn_button: Button = $HBoxContainer/NextTurnButton  

signal shop_button_pressed
signal next_round_pressed
signal dice_rolled(dice_values: Array) 

var dice_hand
var score_card_ui
var turn_tracker
var round_manager: RoundManager
var scorecard: Scorecard
var is_shop_open: bool = true
var first_roll_done: bool = false


func _ready():
	print("ScoreCardUI ready: ", score_card_ui_path)
	dice_hand      = get_node(dice_hand_path)
	score_card_ui  = get_node(score_card_ui_path)
	turn_tracker   = get_node(turn_tracker_path)
	round_manager  = get_node_or_null(round_manager_path)
	challenge_manager = get_node_or_null(challenge_manager_path)  # Initialize challenge_manager
	
	if not score_card_ui:
		print("Error")
		push_error("GameButtonUI: score_card_ui_path not set or node missing")

	roll_button.pressed.connect(_on_roll_button_pressed)
	next_turn_button.pressed.connect(_on_next_turn_button_pressed)

	dice_hand.roll_complete.connect(_on_dice_roll_complete)
	turn_tracker.rolls_exhausted.connect(func(): roll_button.disabled = true)
	turn_tracker.turn_started.connect(func(): roll_button.disabled = false)
	turn_tracker.connect(
		"game_over",
		Callable(self, "_on_game_over")
	)

	# Godot 4 style: signal name + target Callable
	score_card_ui.connect("hand_scored", Callable(self, "_hand_scored_disable"))
	
	# Shop button is already connected in the scene file, so just configure it
	if shop_button:
		shop_button.disabled = false  # Enabled at the very beginning
		print("Shop button status: ", shop_button.disabled)
	
	if next_round_button:
		next_round_button.pressed.connect(_on_next_round_button_pressed)
		# Start with Next Round button enabled to begin the game
		next_round_button.disabled = false
	
	# Make sure both round_manager and challenge_manager exist before connecting signals
	if round_manager:
		round_manager.round_started.connect(_on_round_started)
		round_manager.round_completed.connect(_on_round_completed)
	
	if challenge_manager:
		challenge_manager.challenge_completed.connect(_on_challenge_completed)
		print("[GameButtonUI] Connected to challenge_completed signal")
	else:
		push_error("GameButtonUI: challenge_manager reference is null")

	# Disable gameplay buttons initially
	roll_button.disabled = true
	next_turn_button.disabled = true


func _on_roll_button_pressed() -> void:
	if not first_roll_done:
		first_roll_done = true
		if shop_button:
			shop_button.disabled = true  # Disable shop after first roll
	if dice_hand.dice_list.is_empty():
		dice_hand.spawn_dice()
	else:
		dice_hand.update_dice_count()
	dice_hand.roll_all()
	print("▶ Roll pressed — using dice_count =", dice_hand.dice_count)
	if dice_hand:
		var dice_values = dice_hand.get_current_dice_values() # dice_hand.roll_dice() returns the values immediately
		#emit_signal("dice_rolled", dice_values)
		print("[GameButtonUI] Dice rolled with values:", dice_values)
	if score_card_ui:
		score_card_ui.update_best_hand_preview(DiceResults.values)
	else:
		push_error("GameButtonUI: score_card_ui reference is null")


func _on_dice_roll_complete() -> void:
	# player may now pick a category…
	# lock UI state for scoring
	score_card_ui.turn_scored = false
	turn_tracker.use_roll()
	
	# Now that dice have settled, get their values and emit signal
	var dice_values = dice_hand.get_current_dice_values()
	emit_signal("dice_rolled", dice_values)

func _on_next_turn_button_pressed() -> void:
	# 1) Auto-score if needed
	if not score_card_ui.turn_scored:
		print("[GameButtonUI] About to trigger autoscoring...")
		score_card_ui.scorecard.auto_score_best(dice_hand.get_current_dice_values())
		score_card_ui.turn_scored = true
		print("[GameButtonUI] Autoscoring completed, calling update_all()...")
		score_card_ui.update_all()
		print("[GameButtonUI] Manual update_all() completed")

	# 2) Proceed with turn advancement
	turn_tracker.start_new_turn()
	score_card_ui.turn_scored = false
	score_card_ui.enable_all_score_buttons()
	for die in dice_hand.dice_list:
		die.unlock()
	roll_button.disabled = false
	_on_roll_button_pressed()

func _on_auto_score_assigned(section, category, score):
	print("Auto-assigned", category, "in", section, "for", score, "points")
	# maybe flash the label or play a sound

func _on_game_over() -> void:
	# Disable all controls
	roll_button.disabled = true
	next_turn_button.disabled = true
	if shop_button:
		shop_button.disabled = true

func _hand_scored_disable() -> void:
	print("🏁 Hand scored—disabling Roll button")
	roll_button.disabled = true

func _on_shop_button_pressed() -> void:
	print("[GameButtonUI] Shop button pressed")
	is_shop_open = !is_shop_open  # Toggle shop state
	emit_signal("shop_button_pressed")
	print("[GameButtonUI] Signal emitted")

func _on_round_started(_round_number: int) -> void:
	print("[GameButtonUI] Round", _round_number, "started")
	
	if next_round_button:
		next_round_button.disabled = true
	
	if shop_button:
		print("[GameButtonUI] Round started - disabling shop button")
		shop_button.disabled = true  # Disable shop at the start of each round
	
	# Enable gameplay buttons when round starts
	roll_button.disabled = false
	next_turn_button.disabled = false
	
	# Always spawn dice when a round starts
	if dice_hand:
		# Since we've just cleared the dice, dice_list should be empty
		print("[GameButtonUI] Spawning dice for round", _round_number)
		dice_hand.spawn_dice()
		
		# Wait a short moment for dice to appear and animate in
		await get_tree().create_timer(0.3).timeout
		
		# Now trigger the roll
		_on_roll_button_pressed()

func _on_round_completed(_round_number: int) -> void:
	if shop_button:
		shop_button.disabled = false  # Enable shop after round is completed
	
	if _round_number == 0:  # Initial game state - don't enable next round button yet
		if next_round_button:
			next_round_button.disabled = false

func _on_challenge_completed(challenge_id: String) -> void:
	print("[GameButtonUI] Challenge completed:", challenge_id)
	print("[GameButtonUI] round_manager:", round_manager)
	print("[GameButtonUI] round_manager.current_challenge_id:", round_manager.current_challenge_id)
	
	if round_manager and challenge_id != "":
		if round_manager.current_challenge_id == challenge_id or round_manager.current_challenge_id == "":
			print("[GameButtonUI] Enabling Next Round button")
			if next_round_button:
				next_round_button.disabled = false
			if shop_button:
				shop_button.disabled = false  # Enable shop when challenge is completed
		else:
			print("[GameButtonUI] Challenge ID mismatch:", challenge_id, "vs", round_manager.current_challenge_id)

func _on_next_round_button_pressed() -> void:
	print("[GameButtonUI] Next Round button pressed")
	
	# Clear dice first
	if dice_hand:
		dice_hand.clear_dice()
	
	# Reset all scores on the scorecard and update UI
	if score_card_ui and score_card_ui.scorecard:
		score_card_ui.scorecard.reset_scores()
		score_card_ui.update_all()
	
	# After clearing dice, proceed with round management
	if round_manager:
		var current_round = round_manager.get_current_round_number()
		
		# If this is the initial state (no round started yet)
		if current_round == 1 and not first_roll_done:
			print("[GameButtonUI] Starting first round")
			round_manager.start_round(1)
		else:
			# Normal round advancement
			round_manager.complete_round()
			round_manager.start_round(current_round + 1)
		
		emit_signal("next_round_pressed")
