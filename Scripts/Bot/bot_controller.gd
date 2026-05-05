extends Node
class_name BotController

## BotController
##
## State machine that drives automated bot play-testing.
## Hooks into the existing game systems via direct method calls and signal listeners.
## Designed to be a child of the test scene root alongside all game nodes.

# Preloads for LSP scope resolution
const BotConfigScript := preload("res://Scripts/Bot/BotConfig.gd")
const BotProfileScript := preload("res://Scripts/Bot/bot_profile.gd")
const BotLoggerScript := preload("res://Scripts/Bot/bot_logger.gd")
const BotStrategyScript := preload("res://Scripts/Bot/bot_strategy.gd")
const BotStatisticsScript := preload("res://Scripts/Bot/bot_statistics.gd")
const BotReportWriterScript := preload("res://Scripts/Bot/bot_report_writer.gd")

enum State {
	IDLE,
	STARTING_RUN,
	WAITING_FOR_ROUND,
	ROLLING,
	LOCKING,
	SCORING,
	WAITING_FOR_NEXT_TURN,
	SHOP_PHASE,
	COMPLETING_ROUND,
	RUN_WON,
	RUN_LOST,
	FINISHED
}

signal bot_run_started(run_id: int)
signal bot_run_ended(run_id: int, outcome: String)
signal bot_all_runs_completed
signal bot_status_changed(message: String)

# Node references — assigned by bot_test.gd after scene is ready
var dice_hand: DiceHand
var score_card: Scorecard
var score_card_ui: Control
var turn_tracker: TurnTracker
var game_button_ui: Control
var game_controller: GameController
var round_manager: RoundManager
var channel_manager: Node
var shop_ui: Control
var chores_manager: Node
var consumable_ui: Node
var consumable_manager: Node
var mod_manager: Node
var round_winner_panel: Node
var bot_results_panel: Node

# Bot components
var config: BotConfig
var profile: BotProfile
var logger: BotLogger
var strategy: BotStrategy
var statistics: BotStatistics
var report_writer: BotReportWriter

# State
var current_state: State = State.IDLE
var current_run_id: int = 0
var current_channel: int = 1
var _action_delay: float = 0.05
var _runs_completed: int = 0
var _attempts_completed: int = 0
var _is_round_active: bool = false
var _is_challenge_done: bool = false
var _is_round_failed: bool = false
var _is_all_rounds_done: bool = false
var _is_game_over: bool = false
var _waiting_for_shop: bool = false
var _budget_pressure: String = "low"
var _pending_chore_selection: bool = false
var _pending_mom_dialog: bool = false
var _challenge_completed_this_round: bool = false
var _chose_early_shop: bool = false
var _audio_was_muted: bool = false
var _run_generation: int = 0  # Incremented each run to invalidate stale coroutines


func _ready() -> void:
	set_process(false)
	strategy = BotStrategyScript.new()
	profile = BotProfileScript.new()
	logger = BotLoggerScript.new()
	statistics = BotStatisticsScript.new()
	report_writer = BotReportWriterScript.new()


## start(bot_config)
##
## Entry point: begins automated play-testing with the given configuration.
func start(bot_config: BotConfig) -> void:
	config = bot_config
	logger.verbose = config.log_verbose
	_action_delay = config.turn_delay if config.visual_mode else 0.05

	# Load or reset profile
	if config.reset_between_runs:
		profile.reset()
	else:
		profile.load_profile()

	_runs_completed = 0
	_attempts_completed = 0
	current_channel = config.channel_min
	statistics.clear()
	logger.clear()

	# Mute all audio during bot runs (if configured)
	if config.mute_audio:
		_mute_audio()

	emit_signal("bot_status_changed", "Bot starting %d attempt(s)..." % config.attempts)
	_start_next_run()


## _start_next_run()
##
## Begins a new channel run within the current attempt.
## If all attempts are done, finalize reports.
func _start_next_run() -> void:
	if _attempts_completed >= config.attempts:
		_finalize()
		return

	current_run_id = _runs_completed + 1
	_run_generation += 1
	# current_channel is managed by _end_current_run (advance on win, reset on loss)

	# Reset per-run flags
	_is_round_active = false
	_is_challenge_done = false
	_is_round_failed = false
	_is_all_rounds_done = false
	_is_game_over = false
	_waiting_for_shop = false
	_budget_pressure = "low"
	_challenge_completed_this_round = false
	_chose_early_shop = false

	logger.set_context(current_run_id, current_channel)
	statistics.start_run(current_run_id, current_channel)
	logger.log_info("Attempt %d/%d — Starting run %d on channel %d" % [_attempts_completed + 1, config.attempts, current_run_id, current_channel])

	if config.reset_between_runs:
		profile.reset()

	emit_signal("bot_run_started", current_run_id)
	emit_signal("bot_status_changed", "Attempt %d/%d — Channel %d (run %d)" % [_attempts_completed + 1, config.attempts, current_channel, current_run_id])

	_set_state(State.STARTING_RUN)
	_connect_signals()
	await _begin_game()


## _connect_signals()
##
## Connects to game signals needed to drive the state machine.
func _connect_signals() -> void:
	# Disconnect any previous connections first
	_disconnect_signals()

	if is_instance_valid(round_manager):
		round_manager.round_started.connect(_on_round_started)
		round_manager.round_completed.connect(_on_round_completed)
		round_manager.round_failed.connect(_on_round_failed)
		round_manager.all_rounds_completed.connect(_on_all_rounds_completed)
		# Connect to challenge_completed via round_manager's challenge_manager
		if is_instance_valid(round_manager.challenge_manager):
			round_manager.challenge_manager.challenge_completed.connect(_on_challenge_completed)
	if is_instance_valid(turn_tracker):
		turn_tracker.game_over.connect(_on_game_over)
		turn_tracker.rolls_exhausted.connect(_on_rolls_exhausted)
	if is_instance_valid(score_card):
		score_card.upper_bonus_achieved.connect(_on_upper_bonus)
	if is_instance_valid(dice_hand):
		dice_hand.roll_complete.connect(_on_roll_complete)
	if is_instance_valid(chores_manager):
		chores_manager.request_chore_selection.connect(_on_bot_chore_selection_requested)
		chores_manager.mom_triggered.connect(_on_bot_mom_triggered)


## _disconnect_signals()
func _disconnect_signals() -> void:
	if is_instance_valid(round_manager):
		if round_manager.round_started.is_connected(_on_round_started):
			round_manager.round_started.disconnect(_on_round_started)
		if round_manager.round_completed.is_connected(_on_round_completed):
			round_manager.round_completed.disconnect(_on_round_completed)
		if round_manager.round_failed.is_connected(_on_round_failed):
			round_manager.round_failed.disconnect(_on_round_failed)
		if round_manager.all_rounds_completed.is_connected(_on_all_rounds_completed):
			round_manager.all_rounds_completed.disconnect(_on_all_rounds_completed)
		if is_instance_valid(round_manager.challenge_manager):
			if round_manager.challenge_manager.challenge_completed.is_connected(_on_challenge_completed):
				round_manager.challenge_manager.challenge_completed.disconnect(_on_challenge_completed)
	if is_instance_valid(turn_tracker):
		if turn_tracker.game_over.is_connected(_on_game_over):
			turn_tracker.game_over.disconnect(_on_game_over)
		if turn_tracker.rolls_exhausted.is_connected(_on_rolls_exhausted):
			turn_tracker.rolls_exhausted.disconnect(_on_rolls_exhausted)
	if is_instance_valid(score_card):
		if score_card.upper_bonus_achieved.is_connected(_on_upper_bonus):
			score_card.upper_bonus_achieved.disconnect(_on_upper_bonus)
	if is_instance_valid(dice_hand):
		if dice_hand.roll_complete.is_connected(_on_roll_complete):
			dice_hand.roll_complete.disconnect(_on_roll_complete)
	if is_instance_valid(chores_manager):
		if chores_manager.request_chore_selection.is_connected(_on_bot_chore_selection_requested):
			chores_manager.request_chore_selection.disconnect(_on_bot_chore_selection_requested)
		if chores_manager.mom_triggered.is_connected(_on_bot_mom_triggered):
			chores_manager.mom_triggered.disconnect(_on_bot_mom_triggered)


## _begin_game()
##
## Sets the channel and kicks off the game via the normal flow.
## Also unlocks all items so the bot has access to everything in the shop.
func _begin_game() -> void:
	var gen := _run_generation
	# Unlock all items in ProgressManager so the shop is fully stocked
	unlock_all_items()

	# Set channel
	if is_instance_valid(channel_manager) and channel_manager.has_method("set_channel"):
		channel_manager.set_channel(current_channel)
		logger.log_info("Channel set to %d" % current_channel)

	# Start game via round manager (mirrors what GameController._on_game_start does)
	if is_instance_valid(round_manager):
		round_manager.start_game()
		logger.log_info("Game started via RoundManager")

	# Wait for round_completed(0) signal — that means we can start round 1
	await get_tree().create_timer(0.2).timeout
	if _run_generation != gen:
		return

	# Skip channel selector UI if it exists
	if is_instance_valid(channel_manager) and channel_manager.has_method("select_channel"):
		channel_manager.select_channel()

	# Trigger round 1 start (mirrors clicking "Next Round" button at game start)
	_set_state(State.WAITING_FOR_ROUND)
	await _delay()
	if _run_generation != gen:
		return
	_start_first_round()


## _start_first_round()
func _start_first_round() -> void:
	if is_instance_valid(round_manager):
		# Clear dice and scorecard before first round (mirrors _on_next_round_button_pressed)
		if is_instance_valid(dice_hand):
			dice_hand.clear_dice()
		if is_instance_valid(score_card):
			score_card.reset_scores_preserve_levels()
		if is_instance_valid(score_card_ui) and score_card_ui.has_method("update_all"):
			score_card_ui.update_all()
		round_manager.start_round(1)
		logger.log_info("Round 1 started")


# ─── Signal Handlers ───

func _on_round_started(round_number: int) -> void:
	var gen := _run_generation
	logger.set_context(current_run_id, current_channel, round_number)
	logger.log_info("Round %d started" % round_number)
	_is_round_active = true
	_is_challenge_done = false
	_is_round_failed = false
	_challenge_completed_this_round = false
	_chose_early_shop = false
	statistics.record_round_completed()

	# Update chores manager with current round info
	if is_instance_valid(chores_manager):
		chores_manager.update_round(round_number)
		chores_manager.reset_round_tracking()

	# Wait for dice to spawn, then begin turn loop
	await get_tree().create_timer(0.5).timeout
	if _run_generation != gen:
		return
	_play_turn_loop()


func _on_round_completed(round_number: int) -> void:
	if round_number == 0:
		return  # Initial game setup signal
	logger.log_info("Round %d completed" % round_number)
	_is_round_active = false
	statistics.record_round_score(round_number, score_card.get_total_score() if is_instance_valid(score_card) else 0)


func _on_round_failed(round_number: int) -> void:
	logger.log_warning("Round %d failed" % round_number)
	_is_round_failed = true
	_is_round_active = false
	statistics.record_round_failed(round_number)


func _on_all_rounds_completed() -> void:
	var gen := _run_generation
	logger.log_info("All rounds completed — run won!")
	_is_all_rounds_done = true
	# Dismiss the You Win panel if it appears
	await get_tree().create_timer(0.5).timeout
	if _run_generation != gen:
		return
	await _dismiss_winner_panel()
	if _run_generation != gen:
		return
	_end_current_run("win")


func _on_game_over() -> void:
	logger.log_info("Game over — turn 13 reached")
	_is_game_over = true


func _on_rolls_exhausted() -> void:
	# No more rolls this turn — proceed to scoring
	pass


func _on_roll_complete() -> void:
	# Dice finished rolling — used to know animation is done
	pass


func _on_upper_bonus(_bonus: int) -> void:
	statistics.record_upper_bonus()
	logger.log_info("Upper bonus achieved!")


func _on_challenge_completed(_challenge_id: String) -> void:
	logger.log_info("Challenge completed mid-round: %s" % _challenge_id)
	_challenge_completed_this_round = true


## _on_bot_chore_selection_requested()
##
## Called when ChoresManager rotates tasks and needs EASY/HARD selection.
## Bot picks randomly via strategy, then accepts the selection directly.
## Also dismisses the ChoreSelectionPopup UI if it was shown.
func _on_bot_chore_selection_requested() -> void:
	var gen := _run_generation
	_pending_chore_selection = true
	var pick_hard: bool = strategy.choose_chore_difficulty()
	var label := "HARD" if pick_hard else "EASY"
	logger.log_info("Chore selection requested — bot chose: %s" % label)
	if is_instance_valid(chores_manager):
		chores_manager.accept_chore_selection(pick_hard)
	statistics.record_chore_selected(pick_hard)
	# Dismiss the ChoreSelectionPopup if it's visible
	await get_tree().create_timer(0.3).timeout
	if _run_generation != gen:
		_pending_chore_selection = false
		return
	_dismiss_chore_selection_popup()
	_pending_chore_selection = false


## _on_bot_mom_triggered()
##
## Called when chore progress reaches the threshold and Mom appears.
## Bot dismisses the dialog automatically after a brief delay.
func _on_bot_mom_triggered() -> void:
	var gen := _run_generation
	_pending_mom_dialog = true
	logger.log_info("Mom triggered — bot will dismiss dialog")
	statistics.record_mom_visit()
	# Give the game controller time to show the dialog
	await get_tree().create_timer(0.3).timeout
	if _run_generation != gen:
		_pending_mom_dialog = false
		return
	# Find and dismiss any Mom dialog popup in the scene tree
	var mom_dialog = _find_mom_dialog()
	if is_instance_valid(mom_dialog) and mom_dialog.has_method("close_dialog"):
		mom_dialog.close_dialog()
		logger.log_info("Mom dialog dismissed")
	else:
		logger.log_warning("Could not find Mom dialog to dismiss")
	_pending_mom_dialog = false


## _find_mom_dialog() -> Node
##
## Searches the scene tree for the Mom dialog popup node.
func _find_mom_dialog() -> Node:
	var root = get_tree().root
	return _find_node_by_class_recursive(root, "MomCharacter")


func _find_node_by_class_recursive(node: Node, target_class: String) -> Node:
	if not is_instance_valid(node):
		return null
	if node.get_class() == target_class:
		return node
	# Also check script class name
	if node.get_script() and node.has_method("close_dialog"):
		return node
	for child in node.get_children():
		var result = _find_node_by_class_recursive(child, target_class)
		if result:
			return result
	return null


## _handle_pending_chore_events()
##
## Waits for any pending chore selection or Mom dialog to resolve.
func _handle_pending_chore_events() -> void:
	var safety := 0
	while (_pending_chore_selection or _pending_mom_dialog) and safety < 50:
		await get_tree().create_timer(0.1).timeout
		safety += 1
	if safety >= 50:
		logger.log_warning("Timed out waiting for chore/mom events")
		_pending_chore_selection = false
		_pending_mom_dialog = false


# ─── Turn Loop ───

## _play_turn_loop()
##
## Plays through all 13 turns of the current round.
## After challenge completion, the bot has a 50/50 chance each turn to
## stop early and go to the shop instead of finishing all 13 turns.
func _play_turn_loop() -> void:
	var gen := _run_generation
	for turn_num in range(1, 14):  # Turns 1-13
		if _is_round_failed or _is_all_rounds_done:
			break
		if _run_generation != gen:
			return

		# After challenge is done, 50/50 chance to stop and go to shop
		if _challenge_completed_this_round and turn_num > 1:
			var go_to_shop := randf() < 0.5
			if go_to_shop:
				logger.log_info("Challenge done — bot chose to leave early at turn %d" % turn_num)
				_chose_early_shop = true
				break
			else:
				logger.log_info("Challenge done — bot chose to play turn %d" % turn_num)

		logger.set_context(current_run_id, current_channel, round_manager.get_current_round_number() if is_instance_valid(round_manager) else -1, turn_num)
		statistics.record_turn()

		# Use any available consumables at the start of each turn (before rolling)
		await _bot_use_consumables()
		if _run_generation != gen:
			return

		await _play_single_turn(turn_num)
		await _delay()
		if _run_generation != gen:
			return

		# Check if game over triggered (turn 13 complete)
		if _is_game_over:
			break

	# After all turns, handle round outcome
	await _delay()
	if _run_generation != gen:
		return
	await _handle_post_round()


## _play_single_turn(turn_num)
##
## Executes one complete turn: roll → (optional lock + reroll) → score.
func _play_single_turn(turn_num: int) -> void:
	_set_state(State.ROLLING)

	# First roll
	await _bot_roll()
	await _delay()

	# Decide whether to reroll (up to max rerolls)
	var values := _get_dice_values()
	while strategy.should_use_reroll(turn_tracker, score_card, values):
		_set_state(State.LOCKING)
		# Lock strategic dice
		var lock_indices = strategy.choose_dice_to_lock(score_card, dice_hand.dice_list, values)
		_apply_locks(lock_indices, values)
		await _delay()

		# Reroll
		_set_state(State.ROLLING)
		await _bot_roll()
		await _delay()
		values = _get_dice_values()

	# Score the best category
	_set_state(State.SCORING)
	await _bot_score(values)
	await _delay()

	# Advance to next turn (unless it was the last)
	if turn_num < 13:
		_set_state(State.WAITING_FOR_NEXT_TURN)
		_bot_next_turn()
		await _delay()


## _bot_roll()
##
## Simulates pressing the Roll button.
func _bot_roll() -> void:
	statistics.record_roll()

	if not is_instance_valid(dice_hand):
		return

	if dice_hand.dice_list.is_empty():
		await dice_hand.spawn_dice()
		await get_tree().create_timer(0.1).timeout

	dice_hand.prepare_dice_for_roll()
	dice_hand.roll_all()

	# Use a roll on the turn tracker
	if is_instance_valid(turn_tracker):
		turn_tracker.use_roll()

	# Give signals time to propagate
	await get_tree().create_timer(0.1).timeout

	var values = _get_dice_values()
	logger.log_info("Rolled: %s (rolls left: %d)" % [str(values), turn_tracker.rolls_left if is_instance_valid(turn_tracker) else -1])

	# Increment chore progress on each roll (mirrors GameController behavior)
	if is_instance_valid(chores_manager):
		chores_manager.increment_progress(1)


## _apply_locks(lock_indices, values)
##
## Locks dice at the given indices.
func _apply_locks(lock_indices: Array[int], values: Array[int]) -> void:
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		if lock_indices.has(i):
			if die.current_state != Dice.DiceState.LOCKED:
				die.set_state(Dice.DiceState.LOCKED)
		else:
			# Unlock dice not in lock list (they were previously locked)
			if die.current_state == Dice.DiceState.LOCKED:
				die.set_state(Dice.DiceState.ROLLED)

	var locked_vals := []
	for idx in lock_indices:
		if idx < values.size():
			locked_vals.append(values[idx])
	logger.log_info("Locked dice: %s" % str(locked_vals))


## _bot_score(values)
##
## Uses the strategy engine to pick the best category and scores it.
func _bot_score(values: Array[int]) -> void:
	var choice = strategy.choose_best_category(score_card, values)
	if choice.is_empty():
		logger.log_edge_case("No unscored categories remaining!")
		return

	var section: int = choice.section
	var category: String = choice.category
	var score_value: int = choice.score

	# Use the scorecard's on_category_selected to go through the full scoring pipeline
	if is_instance_valid(score_card):
		score_card.on_category_selected(section, category)

	# Mark UI as scored
	if is_instance_valid(score_card_ui) and "turn_scored" in score_card_ui:
		score_card_ui.turn_scored = true
	if is_instance_valid(score_card_ui) and score_card_ui.has_method("update_all"):
		score_card_ui.update_all()

	logger.log_info("Scored %s = %d pts (total: %d)" % [category, score_value, score_card.get_total_score() if is_instance_valid(score_card) else 0])

	# Check if chore task was completed by this scoring action
	if is_instance_valid(chores_manager):
		var dice_values = _get_dice_values()
		var context = {
			"category": category,
			"dice_values": dice_values,
			"score": score_value,
			"was_yahtzee": category == "yahtzee" and score_value > 0,
			"consumable_used": false,
			"locked_count": 0,
			"was_scratch": score_value == 0
		}
		chores_manager.check_task_completion(context)

	# Handle any pending chore selection or Mom dialog before continuing
	await _handle_pending_chore_events()

	# Animate dice exit after scoring
	if is_instance_valid(dice_hand):
		dice_hand.set_all_dice_disabled()

	await get_tree().create_timer(0.1).timeout


## _bot_next_turn()
##
## Advances to the next turn (mirrors _on_next_turn_button_pressed logic).
func _bot_next_turn() -> void:
	if is_instance_valid(turn_tracker):
		turn_tracker.start_new_turn()
	if is_instance_valid(score_card_ui) and "turn_scored" in score_card_ui:
		score_card_ui.turn_scored = false
	if is_instance_valid(score_card_ui) and score_card_ui.has_method("enable_all_score_buttons"):
		score_card_ui.enable_all_score_buttons()
	if is_instance_valid(dice_hand):
		dice_hand.set_all_dice_rollable()


# ─── Post-Round and Shop ───

## _handle_post_round()
##
## After all 13 turns, decide whether to shop and advance to the next round.
func _handle_post_round() -> void:
	var gen := _run_generation
	var round_num := round_manager.get_current_round_number() if is_instance_valid(round_manager) else 0
	var total_score := score_card.get_total_score() if is_instance_valid(score_card) else 0
	statistics.record_round_score(round_num, total_score)

	logger.log_info("Round %d ended — score: %d" % [round_num, total_score])

	# If all rounds done, the _on_all_rounds_completed handler will end the run
	if _is_all_rounds_done:
		return

	# Check challenge result directly — the bot never calls fail_round()
	# and game_over signal doesn't fire, so check the actual state.
	if is_instance_valid(round_manager) and round_manager.is_challenge_completed:
		logger.log_info("Challenge completed for round %d" % round_num)
	else:
		logger.log_info("Challenge NOT completed for round %d — run lost" % round_num)
		statistics.record_round_failed(round_num)
		_end_current_run("loss")
		return

	# Award end-of-round bonuses (the bot skips the stats panel, so we calculate manually)
	_bot_award_round_bonuses()

	# Shop phase (between rounds)
	await _bot_shop_phase()
	if _run_generation != gen:
		return

	# Advance to next round
	_set_state(State.COMPLETING_ROUND)
	await _delay()
	if _run_generation != gen:
		return
	_advance_to_next_round()


## _bot_award_round_bonuses()
##
## Calculates and awards end-of-round bonuses that the player normally gets
## via the stats panel. The bot bypasses the stats panel UI entirely.
## Bonuses: challenge reward + chore reward + empty categories + score above target.
func _bot_award_round_bonuses() -> void:
	var challenge_reward: int = 0
	var chore_reward: int = 0
	var empty_bonus: int = 0
	var score_above: int = 0

	# Challenge reward — stored in game_controller when challenge_completed fires
	if is_instance_valid(game_controller):
		challenge_reward = game_controller._challenge_reward_this_round

	# Chore reward — total reward value from chores completed this round
	if is_instance_valid(chores_manager) and chores_manager.has_method("get_chore_rewards_this_round"):
		chore_reward = chores_manager.get_chore_rewards_this_round()

	# Empty categories bonus — count unscored categories × $10
	if is_instance_valid(score_card):
		var empty_count := _count_empty_scorecard_categories()
		empty_bonus = empty_count * 10  # EMPTY_CATEGORY_BONUS

	# Score above target bonus — points above challenge target × $1
	if is_instance_valid(round_manager) and is_instance_valid(score_card):
		var target: int = round_manager.get_current_challenge_target_score()
		var final_score: int = score_card.get_total_score()
		var above: int = max(0, final_score - target)
		score_above = above * 1  # POINTS_ABOVE_TARGET_BONUS

	var total_bonus: int = challenge_reward + chore_reward + empty_bonus + score_above

	if total_bonus > 0:
		PlayerEconomy.add_money(total_bonus)
		logger.log_info("Awarded round bonuses: $%d (challenge: $%d, chores: $%d, empty: $%d, score: $%d)" % [total_bonus, challenge_reward, chore_reward, empty_bonus, score_above])
		statistics.record_end_of_round_bonus(total_bonus)
		if challenge_reward > 0:
			statistics.record_challenge_reward(challenge_reward)
	else:
		logger.log_info("No round bonuses to award")


## _count_empty_scorecard_categories() -> int
##
## Counts the number of unscored (null) categories in the scorecard.
func _count_empty_scorecard_categories() -> int:
	var count: int = 0
	if score_card.upper_scores:
		for category in score_card.upper_scores.keys():
			if score_card.upper_scores[category] == null:
				count += 1
	if score_card.lower_scores:
		for category in score_card.lower_scores.keys():
			if score_card.lower_scores[category] == null:
				count += 1
	return count


## _bot_shop_phase()
##
## Opens the shop, buys items based on strategy, then closes.
## Also has a 25% chance to buy a mod or color dice.
func _bot_shop_phase() -> void:
	_set_state(State.SHOP_PHASE)

	if not is_instance_valid(shop_ui):
		logger.log_info("No shop UI — skipping shop phase")
		return

	var money = PlayerEconomy.get_money() if PlayerEconomy else 0
	if money <= 0:
		logger.log_info("No money — skipping shop")
		return

	logger.log_info("Shop phase — money: $%d" % money)

	# Estimate budget pressure for remaining rounds
	_budget_pressure = "low"
	if is_instance_valid(channel_manager) and is_instance_valid(round_manager):
		var ch_config = channel_manager.get_channel_config(current_channel)
		var cur_round: int = round_manager.get_current_round_number()
		if ch_config:
			var budget_info: Dictionary = strategy.estimate_remaining_budget(ch_config, channel_manager, cur_round, money)
			_budget_pressure = budget_info.get("budget_pressure", "low")
			logger.log_info("Economy: pressure=%s, gap=%d pts, $/pt=%.1f" % [_budget_pressure, budget_info.get("points_gap", 0), budget_info.get("dollars_per_point_needed", 0.0)])
			statistics.record_economy_estimate(cur_round, budget_info)

	# Show shop if in visual mode
	if config.visual_mode and is_instance_valid(shop_ui) and shop_ui.has_method("show"):
		shop_ui.show()
		await _delay()

	# Find purchasable items
	var shop_items := _get_shop_items()
	var to_buy = strategy.choose_shop_purchases(shop_items, money)

	# Reroll loop: if no good upgrades available, try rerolling
	var reroll_count := 0
	var max_rerolls: int = config.max_rerolls_per_shop if config else 5
	var owned_power_ups: Dictionary = game_controller.active_power_ups if is_instance_valid(game_controller) else {}
	while to_buy.is_empty() and reroll_count < max_rerolls:
		var current_money: int = PlayerEconomy.get_money() if PlayerEconomy else 0
		var current_reroll_cost: int = shop_ui.reroll_cost if "reroll_cost" in shop_ui else 25
		if not strategy.should_reroll_shop(shop_items, owned_power_ups, current_money, current_reroll_cost):
			break
		# Ensure we're on the PowerUps tab (tab 0) for reroll
		if "tab_container" in shop_ui and shop_ui.tab_container:
			shop_ui.tab_container.current_tab = 0
		logger.log_info("Rerolling shop (cost: $%d, money: $%d)" % [current_reroll_cost, current_money])
		shop_ui._on_reroll_button_pressed()
		statistics.record_shop_reroll()
		reroll_count += 1
		# Wait for reroll to populate and cooldown to pass
		await get_tree().create_timer(0.6).timeout
		# Re-gather items and evaluate
		shop_items = _get_shop_items()
		current_money = PlayerEconomy.get_money() if PlayerEconomy else 0
		to_buy = strategy.choose_shop_purchases(shop_items, current_money)

	for item in to_buy:
		if not PlayerEconomy.can_afford(item.price):
			break
		# Under high/critical budget pressure, skip low-rarity powerups
		if _budget_pressure == "high" or _budget_pressure == "critical":
			if "item_type" in item and item.item_type == "power_up":
				if item.item_data and "rarity" in item.item_data:
					var rarity_str: String = item.item_data.rarity
					var rarity_val: int = strategy.RARITY_ORDER.get(rarity_str, 0)
					if rarity_val <= 1:
						logger.log_info("Skipping low-rarity %s (budget pressure: %s)" % [item.item_id, _budget_pressure])
						continue
		logger.log_info("Buying: %s (%s) for $%d" % [item.item_id, item.item_type, item.price])
		item._on_buy_button_pressed()
		statistics.record_purchase(item.item_id, item.item_type, item.price)
		await get_tree().create_timer(0.1).timeout

	# 25% chance to buy a mod or color dice
	await _bot_buy_mod_or_color_dice()

	# Hide shop
	if config.visual_mode and is_instance_valid(shop_ui) and shop_ui.has_method("hide"):
		shop_ui.hide()
		await _delay()


## _get_shop_items() -> Array
##
## Gathers all visible ShopItem nodes from the shop UI.
func _get_shop_items() -> Array:
	var items := []
	if not is_instance_valid(shop_ui):
		return items

	# ShopUI has grid containers for each tab
	for child in shop_ui.get_children():
		_collect_shop_items_recursive(child, items)

	return items


func _collect_shop_items_recursive(node: Node, items: Array) -> void:
	if not is_instance_valid(node):
		return
	# Check if this node is a ShopItem (has item_id property)
	if "item_id" in node and "item_data" in node and "price" in node:
		items.append(node)
	for child in node.get_children():
		_collect_shop_items_recursive(child, items)


## _advance_to_next_round()
##
## Mirrors _on_next_round_button_pressed logic.
func _advance_to_next_round() -> void:
	if not is_instance_valid(round_manager):
		logger.log_error("No RoundManager — cannot advance round")
		return

	var current_round = round_manager.get_current_round_number()
	var next_round = current_round + 1

	if next_round > round_manager.max_rounds:
		logger.log_info("No more rounds to play — completing final round")
		round_manager.complete_round()
		return

	# Clear dice and reset scorecard for new round
	if is_instance_valid(dice_hand):
		dice_hand.clear_dice()
	if is_instance_valid(score_card):
		score_card.reset_scores_preserve_levels()
	if is_instance_valid(score_card_ui) and score_card_ui.has_method("update_all"):
		score_card_ui.update_all()

	round_manager.complete_round()
	round_manager.start_round(next_round)

	logger.log_info("Advanced to round %d" % next_round)

	# Wait for the round_started signal handler to kick off the turn loop
	await get_tree().create_timer(0.3).timeout


# ─── Run Lifecycle ───

## _end_current_run(outcome)
##
## Handles run completion. On win: advance to next channel (or complete attempt).
## On loss: end the attempt and reset to channel 1 for the next attempt.
func _end_current_run(outcome: String) -> void:
	var final_score := score_card.get_total_score() if is_instance_valid(score_card) else 0

	if outcome == "win":
		_set_state(State.RUN_WON)
		profile.record_channel_win(current_channel)
		profile.data["total_games_won"] = profile.data.get("total_games_won", 0) + 1
		statistics.record_highest_channel(current_channel)
	else:
		_set_state(State.RUN_LOST)
		profile.data["total_games_lost"] = profile.data.get("total_games_lost", 0) + 1

	profile.increment_games()
	profile.data["last_played"] = Time.get_datetime_string_from_system()
	profile.save_profile()

	statistics.end_run(outcome, final_score)
	_runs_completed += 1

	logger.log_info("Run %d finished: %s (score: %d, channel: %d)" % [current_run_id, outcome, final_score, current_channel])
	emit_signal("bot_run_ended", current_run_id, outcome)
	emit_signal("bot_status_changed", "Attempt %d — Ch %d: %s (score: %d)" % [_attempts_completed + 1, current_channel, outcome.to_upper(), final_score])

	_disconnect_signals()

	# Determine next action based on outcome
	if outcome == "win" and current_channel < config.channel_max:
		# Channel won but more channels remain — advance channel, continue attempt
		current_channel += 1
		logger.log_info("Channel won — advancing to channel %d" % current_channel)
		await _delay()
		await _reset_game_state()
		await _delay()
		_start_next_run()
	else:
		# Attempt is over: either all channels beaten (full win) or a loss
		var attempt_outcome := "full_win" if outcome == "win" else "loss"
		statistics.end_attempt(attempt_outcome, current_channel)
		_attempts_completed += 1

		if attempt_outcome == "full_win":
			logger.log_info("Attempt %d COMPLETE — all channels beaten!" % _attempts_completed)
		else:
			logger.log_info("Attempt %d FAILED at channel %d" % [_attempts_completed, current_channel])

		# Reset to channel 1 for next attempt
		current_channel = config.channel_min
		await _delay()
		await _reset_game_state()
		await _delay()
		_start_next_run()


## _reset_game_state()
##
## Resets all game systems to prepare for a new run.
## Mirrors game_controller._restart_game_for_new_channel() logic,
## properly freeing instances and clearing UI via the game_controller's methods.
func _reset_game_state() -> void:
	# Reset economy
	if PlayerEconomy:
		PlayerEconomy.reset_to_starting_money()

	# Clear dice
	if is_instance_valid(dice_hand):
		dice_hand.clear_dice()

	# Clear all power-ups (frees instances and clears UI)
	if is_instance_valid(game_controller):
		game_controller._clear_all_power_ups()

	# Clear all consumables (frees instances and clears UI)
	if is_instance_valid(game_controller):
		game_controller._clear_all_consumables()

	# Clear active challenges (frees instances and clears UI)
	if is_instance_valid(game_controller):
		game_controller._clear_active_challenges()

	# Clear active debuffs (frees instances and clears UI)
	if is_instance_valid(game_controller):
		game_controller._clear_active_debuffs()

	# Also clear grounded debuffs
	if is_instance_valid(game_controller):
		game_controller._grounded_debuffs.clear()

	# Clear remaining dictionaries the game_controller may not have emptied
	if is_instance_valid(game_controller):
		game_controller.consumable_counts.clear()
		game_controller.active_mods.clear()

	# Reset ScoreModifierManager
	if ScoreModifierManager:
		ScoreModifierManager.reset()

	# Reset scorecard completely (including levels)
	if is_instance_valid(score_card):
		score_card.reset_scores()

	# Reset turn tracker — back to default MAX_ROLLS
	if is_instance_valid(turn_tracker):
		turn_tracker.MAX_ROLLS = 3
		turn_tracker.reset()

	# Reset shop reroll cost and expansions
	if is_instance_valid(shop_ui):
		if shop_ui.has_method("reset_reroll_cost"):
			shop_ui.reset_reroll_cost()
		if shop_ui.has_method("reset_shop_expansions"):
			shop_ui.reset_shop_expansions()

	# Reset round manager to round 0
	if is_instance_valid(round_manager):
		round_manager.current_round = 0

	# Reset game-ended flag
	if is_instance_valid(game_controller):
		game_controller._game_ended = false
		game_controller._end_of_round_stats_shown = false
		game_controller._goal_mode_locked = false

	# Reset chores system for new run
	if is_instance_valid(chores_manager):
		chores_manager.reset_for_new_game()

	# Clean up challenge celebration particles to prevent accumulation
	if is_instance_valid(game_controller) and game_controller._challenge_celebration:
		game_controller._challenge_celebration.cleanup_all()

	# Wait a full frame so all queue_free'd objects are actually freed
	await get_tree().process_frame

	logger.log_info("Game state reset for next run")


## _finalize()
##
## Saves all reports and signals completion.
## Dismisses any overlapping panels before showing results.
func _finalize() -> void:
	_set_state(State.FINISHED)

	# Dismiss any panels that might overlay the results
	await _dismiss_all_overlays()

	# Ensure results panel is visible and on top
	if bot_results_panel and is_instance_valid(bot_results_panel):
		bot_results_panel.visible = true
		bot_results_panel.z_index = 200

	# Save reports
	var report_path = report_writer.write_report(statistics, config)
	var log_path = logger.save_log()

	var agg = statistics.get_aggregate()
	var summary = "Bot completed %d attempts — Full clears: %d/%d (%.1f%%) — Highest ch: %d" % [
		agg.total_attempts,
		agg.full_clears,
		agg.total_attempts,
		agg.attempt_clear_rate * 100.0,
		agg.highest_channel_reached
	]

	logger.log_info(summary)
	emit_signal("bot_status_changed", summary)
	emit_signal("bot_all_runs_completed")

	# Restore audio
	if config.mute_audio:
		_unmute_audio()

	print("[BotController] === FINAL REPORT ===")
	print("[BotController] %s" % summary)
	print("[BotController] Report: %s" % report_path)
	print("[BotController] Log: %s" % log_path)
	print("[BotController] Errors: %d | Edge cases: %d" % [logger.get_error_count(), logger.get_edge_case_count()])


# ─── Helpers ───

func _set_state(new_state: State) -> void:
	current_state = new_state


func _delay() -> void:
	await get_tree().create_timer(_action_delay).timeout


## _mute_audio()
##
## Mutes the Master audio bus so SFX and music don't play during bot runs.
func _mute_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	_audio_was_muted = AudioServer.is_bus_mute(master_idx)
	if not _audio_was_muted:
		AudioServer.set_bus_mute(master_idx, true)
		logger.log_info("Audio muted for bot run")


## _unmute_audio()
##
## Restores the Master audio bus mute state to what it was before the bot ran.
func _unmute_audio() -> void:
	if not _audio_was_muted:
		var master_idx := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(master_idx, false)
		logger.log_info("Audio restored after bot run")


func _get_dice_values() -> Array[int]:
	if is_instance_valid(dice_hand):
		return dice_hand.get_current_dice_values()
	return []


# ─── Consumable Usage ───

## List of consumable IDs that can be auto-used without UI interaction.
## These are "fire and forget" — apply their effect immediately.
const AUTO_USE_CONSUMABLES: Array[String] = [
	"quick_cash", "three_more_rolls", "free_chores", "all_chores",
	"power_up_shop_num", "add_max_power_up", "one_extra_dice",
	"dice_surge", "stat_cashout", "score_amplifier", "bonus_collector",
	"upper_section_boost", "lower_section_boost", "score_streak",
	"ones_upgrade", "twos_upgrade", "threes_upgrade", "fours_upgrade",
	"fives_upgrade", "sixes_upgrade", "three_of_a_kind_upgrade",
	"four_of_a_kind_upgrade", "full_house_upgrade", "small_straight_upgrade",
	"large_straight_upgrade", "yahtzee_upgrade", "chance_upgrade",
	"all_categories_upgrade", "random_power_up_uncommon",
	"green_envy", "poor_house", "empty_shelves", "double_or_nothing",
	"the_rarities", "the_pawn_shop", "go_broke_or_go_home",
	"one_free_mod", "visit_the_shop", "lucky_upgrade",
]

## _bot_use_consumables()
##
## Scans game_controller.active_consumables for any items the bot can use.
## Auto-uses safe consumables, sells interactive ones the bot can't handle.
## Called at the beginning of each turn when turn_tracker is active.
func _bot_use_consumables() -> void:
	var gen := _run_generation
	if not is_instance_valid(game_controller):
		return

	# Ensure the turn is active so game_controller won't block usage
	if is_instance_valid(turn_tracker) and not turn_tracker.is_active:
		return

	var consumable_ids := game_controller.active_consumables.keys().duplicate()
	if consumable_ids.is_empty():
		return

	for consumable_id in consumable_ids:
		# Re-check — a previous consumable might have removed others
		if not is_instance_valid(game_controller):
			return
		if not game_controller.active_consumables.has(consumable_id):
			continue
		# Guard: ensure the consumable object itself hasn't been freed
		var consumable_obj = game_controller.active_consumables[consumable_id]
		if not is_instance_valid(consumable_obj):
			continue

		if consumable_id in AUTO_USE_CONSUMABLES:
			logger.log_info("Using consumable: %s" % consumable_id)
			game_controller._on_consumable_used(consumable_id)
			statistics.record_consumable_used(consumable_id)
			await get_tree().create_timer(0.15).timeout
			if _run_generation != gen:
				return
		else:
			# Interactive consumable the bot can't handle — sell it
			logger.log_info("Selling unusable consumable: %s" % consumable_id)
			game_controller._on_consumable_sold(consumable_id)
			statistics.record_consumable_sold(consumable_id)
			await get_tree().create_timer(0.1).timeout
			if _run_generation != gen:
				return


# ─── Panel Dismissal ───

## _dismiss_chore_selection_popup()
##
## Finds and hides the ChoreSelectionPopup that GameController creates.
func _dismiss_chore_selection_popup() -> void:
	if not is_instance_valid(game_controller):
		return
	var popup = game_controller._chore_selection_popup
	if popup and is_instance_valid(popup) and popup.visible:
		popup.visible = false
		# Clean up children to match _on_animation_finished behavior
		for child in popup.get_children():
			child.queue_free()
		logger.log_info("Chore selection popup dismissed")


## _dismiss_winner_panel()
##
## Finds and hides the RoundWinnerPanel so it doesn't block the results.
func _dismiss_winner_panel() -> void:
	if is_instance_valid(round_winner_panel):
		if round_winner_panel.visible:
			round_winner_panel.hide_panel()
			logger.log_info("Round winner panel dismissed")
			await get_tree().create_timer(0.5).timeout
			return
	# Fallback: search game_controller's round_winner_panel
	if is_instance_valid(game_controller) and is_instance_valid(game_controller.round_winner_panel):
		var panel = game_controller.round_winner_panel
		if panel.visible:
			panel.hide_panel()
			logger.log_info("Round winner panel dismissed (via game_controller)")
			await get_tree().create_timer(0.5).timeout


## _dismiss_all_overlays()
##
## Hides all overlay panels that might block the results panel.
func _dismiss_all_overlays() -> void:
	await _dismiss_winner_panel()
	_dismiss_chore_selection_popup()
	_dismiss_game_over_popup()
	if is_instance_valid(shop_ui) and shop_ui.visible:
		shop_ui.hide()


## _dismiss_game_over_popup()
##
## Finds and frees the GameController's game over popup if present.
func _dismiss_game_over_popup() -> void:
	if not is_instance_valid(game_controller):
		return
	if is_instance_valid(game_controller._game_over_popup):
		game_controller._game_over_popup.queue_free()
		game_controller._game_over_popup = null
		logger.log_info("Game over popup dismissed")


# ─── Mod and Color Dice Purchasing ───

## _bot_buy_mod_or_color_dice()
##
## 25% chance to buy either 1 mod or 1 color dice from the shop.
## Searches the shop items for available mods/color dice and picks one randomly.
func _bot_buy_mod_or_color_dice() -> void:
	if randf() > 0.05:
		return  # 75% chance to skip

	var money = PlayerEconomy.get_money() if PlayerEconomy else 0
	if money <= 0:
		return

	var shop_items := _get_shop_items()
	var mod_items := []
	var color_items := []

	for item in shop_items:
		if not "item_type" in item:
			continue
		if item.item_type == "mod" and item.price <= money:
			mod_items.append(item)
		elif item.item_type == "colored_dice" and item.price <= money:
			color_items.append(item)

	# Randomly decide: mod or color dice
	var combined := mod_items + color_items
	if combined.is_empty():
		return

	var pick = combined[randi() % combined.size()]
	logger.log_info("Buying %s: %s for $%d" % [pick.item_type, pick.item_id, pick.price])
	pick._on_buy_button_pressed()
	statistics.record_purchase(pick.item_id, pick.item_type, pick.price)
	await get_tree().create_timer(0.1).timeout


# ─── Item Unlock Management ───

## unlock_all_items()
##
## Unlocks all items in ProgressManager so the bot can see everything in the shop.
## Called at the start of each run.
func unlock_all_items() -> void:
	if not ProgressManager:
		logger.log_warning("ProgressManager not found — cannot unlock items")
		return
	var count := 0
	for item_id in ProgressManager.unlockable_items:
		var item = ProgressManager.unlockable_items[item_id]
		if not item.is_unlocked:
			ProgressManager.debug_unlock_item(item_id)
			count += 1
	if count > 0:
		logger.log_info("Unlocked %d items in ProgressManager" % count)
