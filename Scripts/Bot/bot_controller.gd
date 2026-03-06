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
var _is_round_active: bool = false
var _is_challenge_done: bool = false
var _is_round_failed: bool = false
var _is_all_rounds_done: bool = false
var _is_game_over: bool = false
var _waiting_for_shop: bool = false
var _pending_chore_selection: bool = false
var _pending_mom_dialog: bool = false


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
	statistics.clear()
	logger.clear()

	emit_signal("bot_status_changed", "Bot starting %d run(s)..." % config.attempts)
	_start_next_run()


## _start_next_run()
##
## Begins a new run. If all runs are done, finalize reports.
func _start_next_run() -> void:
	if _runs_completed >= config.attempts:
		_finalize()
		return

	current_run_id = _runs_completed + 1
	current_channel = config.channel_min + ((_runs_completed) % (config.channel_max - config.channel_min + 1))

	# Reset per-run flags
	_is_round_active = false
	_is_challenge_done = false
	_is_round_failed = false
	_is_all_rounds_done = false
	_is_game_over = false
	_waiting_for_shop = false

	logger.set_context(current_run_id, current_channel)
	statistics.start_run(current_run_id, current_channel)
	logger.log_info("Starting run %d on channel %d" % [current_run_id, current_channel])

	if config.reset_between_runs:
		profile.reset()

	emit_signal("bot_run_started", current_run_id)
	emit_signal("bot_status_changed", "Run %d/%d — Channel %d" % [current_run_id, config.attempts, current_channel])

	_set_state(State.STARTING_RUN)
	_connect_signals()
	await _begin_game()


## _connect_signals()
##
## Connects to game signals needed to drive the state machine.
func _connect_signals() -> void:
	# Disconnect any previous connections first
	_disconnect_signals()

	if round_manager:
		round_manager.round_started.connect(_on_round_started)
		round_manager.round_completed.connect(_on_round_completed)
		round_manager.round_failed.connect(_on_round_failed)
		round_manager.all_rounds_completed.connect(_on_all_rounds_completed)
	if turn_tracker:
		turn_tracker.game_over.connect(_on_game_over)
		turn_tracker.rolls_exhausted.connect(_on_rolls_exhausted)
	if score_card:
		score_card.upper_bonus_achieved.connect(_on_upper_bonus)
	if dice_hand:
		dice_hand.roll_complete.connect(_on_roll_complete)
	if chores_manager:
		chores_manager.request_chore_selection.connect(_on_bot_chore_selection_requested)
		chores_manager.mom_triggered.connect(_on_bot_mom_triggered)


## _disconnect_signals()
func _disconnect_signals() -> void:
	if round_manager:
		if round_manager.round_started.is_connected(_on_round_started):
			round_manager.round_started.disconnect(_on_round_started)
		if round_manager.round_completed.is_connected(_on_round_completed):
			round_manager.round_completed.disconnect(_on_round_completed)
		if round_manager.round_failed.is_connected(_on_round_failed):
			round_manager.round_failed.disconnect(_on_round_failed)
		if round_manager.all_rounds_completed.is_connected(_on_all_rounds_completed):
			round_manager.all_rounds_completed.disconnect(_on_all_rounds_completed)
	if turn_tracker:
		if turn_tracker.game_over.is_connected(_on_game_over):
			turn_tracker.game_over.disconnect(_on_game_over)
		if turn_tracker.rolls_exhausted.is_connected(_on_rolls_exhausted):
			turn_tracker.rolls_exhausted.disconnect(_on_rolls_exhausted)
	if score_card:
		if score_card.upper_bonus_achieved.is_connected(_on_upper_bonus):
			score_card.upper_bonus_achieved.disconnect(_on_upper_bonus)
	if dice_hand:
		if dice_hand.roll_complete.is_connected(_on_roll_complete):
			dice_hand.roll_complete.disconnect(_on_roll_complete)
	if chores_manager:
		if chores_manager.request_chore_selection.is_connected(_on_bot_chore_selection_requested):
			chores_manager.request_chore_selection.disconnect(_on_bot_chore_selection_requested)
		if chores_manager.mom_triggered.is_connected(_on_bot_mom_triggered):
			chores_manager.mom_triggered.disconnect(_on_bot_mom_triggered)


## _begin_game()
##
## Sets the channel and kicks off the game via the normal flow.
func _begin_game() -> void:
	# Set channel
	if channel_manager and channel_manager.has_method("set_channel"):
		channel_manager.set_channel(current_channel)
		logger.log_info("Channel set to %d" % current_channel)

	# Start game via round manager (mirrors what GameController._on_game_start does)
	if round_manager:
		round_manager.start_game()
		logger.log_info("Game started via RoundManager")

	# Wait for round_completed(0) signal — that means we can start round 1
	await get_tree().create_timer(0.2).timeout

	# Skip channel selector UI if it exists
	if channel_manager and channel_manager.has_method("select_channel"):
		channel_manager.select_channel()

	# Trigger round 1 start (mirrors clicking "Next Round" button at game start)
	_set_state(State.WAITING_FOR_ROUND)
	await _delay()
	_start_first_round()


## _start_first_round()
func _start_first_round() -> void:
	if round_manager:
		# Clear dice and scorecard before first round (mirrors _on_next_round_button_pressed)
		if dice_hand:
			dice_hand.clear_dice()
		if score_card:
			score_card.reset_scores_preserve_levels()
		if score_card_ui and score_card_ui.has_method("update_all"):
			score_card_ui.update_all()
		round_manager.start_round(1)
		logger.log_info("Round 1 started")


# ─── Signal Handlers ───

func _on_round_started(round_number: int) -> void:
	logger.set_context(current_run_id, current_channel, round_number)
	logger.log_info("Round %d started" % round_number)
	_is_round_active = true
	_is_challenge_done = false
	_is_round_failed = false
	statistics.record_round_completed()

	# Update chores manager with current round info
	if chores_manager:
		chores_manager.update_round(round_number)
		chores_manager.reset_round_tracking()

	# Wait for dice to spawn, then begin turn loop
	await get_tree().create_timer(0.5).timeout
	_play_turn_loop()


func _on_round_completed(round_number: int) -> void:
	if round_number == 0:
		return  # Initial game setup signal
	logger.log_info("Round %d completed" % round_number)
	_is_round_active = false
	statistics.record_round_score(round_number, score_card.get_total_score() if score_card else 0)


func _on_round_failed(round_number: int) -> void:
	logger.log_warning("Round %d failed" % round_number)
	_is_round_failed = true
	_is_round_active = false
	statistics.record_round_failed(round_number)


func _on_all_rounds_completed() -> void:
	logger.log_info("All rounds completed — run won!")
	_is_all_rounds_done = true
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


## _on_bot_chore_selection_requested()
##
## Called when ChoresManager rotates tasks and needs EASY/HARD selection.
## Bot picks randomly via strategy, then accepts the selection directly.
func _on_bot_chore_selection_requested() -> void:
	_pending_chore_selection = true
	var pick_hard: bool = strategy.choose_chore_difficulty()
	var label := "HARD" if pick_hard else "EASY"
	logger.log_info("Chore selection requested — bot chose: %s" % label)
	chores_manager.accept_chore_selection(pick_hard)
	statistics.record_chore_selected(pick_hard)
	_pending_chore_selection = false


## _on_bot_mom_triggered()
##
## Called when chore progress reaches the threshold and Mom appears.
## Bot dismisses the dialog automatically after a brief delay.
func _on_bot_mom_triggered() -> void:
	_pending_mom_dialog = true
	logger.log_info("Mom triggered — bot will dismiss dialog")
	statistics.record_mom_visit()
	# Give the game controller time to show the dialog
	await get_tree().create_timer(0.3).timeout
	# Find and dismiss any Mom dialog popup in the scene tree
	var mom_dialog = _find_mom_dialog()
	if mom_dialog and mom_dialog.has_method("close_dialog"):
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
func _play_turn_loop() -> void:
	for turn_num in range(1, 14):  # Turns 1-13
		if _is_round_failed or _is_all_rounds_done:
			break

		logger.set_context(current_run_id, current_channel, round_manager.get_current_round_number() if round_manager else -1, turn_num)
		statistics.record_turn()

		await _play_single_turn(turn_num)
		await _delay()

		# Check if game over triggered (turn 13 complete)
		if _is_game_over:
			break

	# After all turns, handle round outcome
	await _delay()
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

	if dice_hand.dice_list.is_empty():
		await dice_hand.spawn_dice()
		await get_tree().create_timer(0.1).timeout

	dice_hand.prepare_dice_for_roll()
	dice_hand.roll_all()

	# Use a roll on the turn tracker
	if turn_tracker:
		turn_tracker.use_roll()

	# Give signals time to propagate
	await get_tree().create_timer(0.1).timeout

	var values = _get_dice_values()
	logger.log_info("Rolled: %s (rolls left: %d)" % [str(values), turn_tracker.rolls_left if turn_tracker else -1])

	# Increment chore progress on each roll (mirrors GameController behavior)
	if chores_manager:
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
	score_card.on_category_selected(section, category)

	# Mark UI as scored
	if score_card_ui and "turn_scored" in score_card_ui:
		score_card_ui.turn_scored = true
	if score_card_ui and score_card_ui.has_method("update_all"):
		score_card_ui.update_all()

	logger.log_info("Scored %s = %d pts (total: %d)" % [category, score_value, score_card.get_total_score()])

	# Check if chore task was completed by this scoring action
	if chores_manager:
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
	if dice_hand:
		dice_hand.set_all_dice_disabled()

	await get_tree().create_timer(0.1).timeout


## _bot_next_turn()
##
## Advances to the next turn (mirrors _on_next_turn_button_pressed logic).
func _bot_next_turn() -> void:
	if turn_tracker:
		turn_tracker.start_new_turn()
	if score_card_ui and "turn_scored" in score_card_ui:
		score_card_ui.turn_scored = false
	if score_card_ui and score_card_ui.has_method("enable_all_score_buttons"):
		score_card_ui.enable_all_score_buttons()
	if dice_hand:
		dice_hand.set_all_dice_rollable()


# ─── Post-Round and Shop ───

## _handle_post_round()
##
## After all 13 turns, decide whether to shop and advance to the next round.
func _handle_post_round() -> void:
	var round_num := round_manager.get_current_round_number() if round_manager else 0
	var total_score := score_card.get_total_score() if score_card else 0
	statistics.record_round_score(round_num, total_score)

	logger.log_info("Round %d ended — score: %d" % [round_num, total_score])

	# Check if challenge was completed or failed
	if round_manager and round_manager.is_challenge_completed:
		logger.log_info("Challenge completed for round %d" % round_num)
	elif _is_round_failed:
		logger.log_info("Challenge failed for round %d — run lost" % round_num)
		_end_current_run("loss")
		return

	# If game over was triggered (turn 13 reached and challenge checked)
	# Check the challenge result
	if _is_game_over:
		if round_manager and not round_manager.is_challenge_completed:
			logger.log_info("Game over without completing challenge — run lost")
			_end_current_run("loss")
			return

	# If all rounds done, the _on_all_rounds_completed handler will end the run
	if _is_all_rounds_done:
		return

	# Shop phase (between rounds)
	await _bot_shop_phase()

	# Advance to next round
	_set_state(State.COMPLETING_ROUND)
	await _delay()
	_advance_to_next_round()


## _bot_shop_phase()
##
## Opens the shop, buys items based on strategy, then closes.
func _bot_shop_phase() -> void:
	_set_state(State.SHOP_PHASE)

	if not shop_ui:
		logger.log_info("No shop UI — skipping shop phase")
		return

	var money = PlayerEconomy.get_money() if PlayerEconomy else 0
	if money <= 0:
		logger.log_info("No money — skipping shop")
		return

	logger.log_info("Shop phase — money: $%d" % money)

	# Show shop if in visual mode
	if config.visual_mode and shop_ui.has_method("show"):
		shop_ui.show()
		await _delay()

	# Find purchasable items
	var shop_items := _get_shop_items()
	var to_buy = strategy.choose_shop_purchases(shop_items, money)

	for item in to_buy:
		if not PlayerEconomy.can_afford(item.price):
			break
		# Simulate buying
		logger.log_info("Buying: %s (%s) for $%d" % [item.item_id, item.item_type, item.price])
		item._on_buy_button_pressed()
		statistics.record_purchase(item.item_id, item.item_type, item.price)
		await get_tree().create_timer(0.1).timeout

	# Hide shop
	if config.visual_mode and shop_ui.has_method("hide"):
		shop_ui.hide()
		await _delay()


## _get_shop_items() -> Array
##
## Gathers all visible ShopItem nodes from the shop UI.
func _get_shop_items() -> Array:
	var items := []
	if not shop_ui:
		return items

	# ShopUI has grid containers for each tab
	for child in shop_ui.get_children():
		_collect_shop_items_recursive(child, items)

	return items


func _collect_shop_items_recursive(node: Node, items: Array) -> void:
	# Check if this node is a ShopItem (has item_id property)
	if "item_id" in node and "item_data" in node and "price" in node:
		items.append(node)
	for child in node.get_children():
		_collect_shop_items_recursive(child, items)


## _advance_to_next_round()
##
## Mirrors _on_next_round_button_pressed logic.
func _advance_to_next_round() -> void:
	if not round_manager:
		logger.log_error("No RoundManager — cannot advance round")
		return

	var current_round = round_manager.get_current_round_number()
	var next_round = current_round + 1

	if next_round > round_manager.max_rounds:
		logger.log_info("No more rounds to play — completing final round")
		round_manager.complete_round()
		return

	# Clear dice and reset scorecard for new round
	if dice_hand:
		dice_hand.clear_dice()
	if score_card:
		score_card.reset_scores_preserve_levels()
	if score_card_ui and score_card_ui.has_method("update_all"):
		score_card_ui.update_all()

	round_manager.complete_round()
	round_manager.start_round(next_round)

	logger.log_info("Advanced to round %d" % next_round)

	# Wait for the round_started signal handler to kick off the turn loop
	await get_tree().create_timer(0.3).timeout


# ─── Run Lifecycle ───

## _end_current_run(outcome)
func _end_current_run(outcome: String) -> void:
	var final_score := score_card.get_total_score() if score_card else 0

	if outcome == "win":
		_set_state(State.RUN_WON)
		profile.record_channel_win(current_channel)
		profile.data["total_games_won"] = profile.data.get("total_games_won", 0) + 1
	else:
		_set_state(State.RUN_LOST)
		profile.data["total_games_lost"] = profile.data.get("total_games_lost", 0) + 1

	profile.increment_games()
	profile.data["last_played"] = Time.get_datetime_string_from_system()
	profile.save_profile()

	statistics.end_run(outcome, final_score)
	_runs_completed += 1

	logger.log_info("Run %d finished: %s (score: %d)" % [current_run_id, outcome, final_score])
	emit_signal("bot_run_ended", current_run_id, outcome)
	emit_signal("bot_status_changed", "Run %d: %s (score: %d)" % [current_run_id, outcome.to_upper(), final_score])

	_disconnect_signals()

	# Reset game state for next run
	await _delay()
	_reset_game_state()
	await _delay()
	_start_next_run()


## _reset_game_state()
##
## Resets all game systems to prepare for a new run.
func _reset_game_state() -> void:
	# Reset economy
	if PlayerEconomy:
		PlayerEconomy.reset_to_starting_money()

	# Clear dice
	if dice_hand:
		dice_hand.clear_dice()

	# Reset scorecard
	if score_card:
		score_card.reset_scores_preserve_levels()

	# Reset turn tracker
	if turn_tracker:
		turn_tracker.reset()

	# Clear active items from game controller
	if game_controller:
		game_controller.active_power_ups.clear()
		game_controller.active_consumables.clear()
		game_controller.consumable_counts.clear()
		game_controller.active_debuffs.clear()
		game_controller.active_mods.clear()
		game_controller.active_challenges.clear()

	# Reset chores system for new run
	if chores_manager:
		chores_manager.reset_for_new_game()

	logger.log_info("Game state reset for next run")


## _finalize()
##
## Saves all reports and signals completion.
func _finalize() -> void:
	_set_state(State.FINISHED)

	# Save reports
	var report_path = report_writer.write_report(statistics, config)
	var log_path = logger.save_log()

	var agg = statistics.get_aggregate()
	var summary = "Bot completed %d runs — Win rate: %.1f%% — Avg score: %d" % [
		agg.total_runs,
		agg.win_rate * 100.0,
		agg.average_score
	]

	logger.log_info(summary)
	emit_signal("bot_status_changed", summary)
	emit_signal("bot_all_runs_completed")

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


func _get_dice_values() -> Array[int]:
	if dice_hand:
		return dice_hand.get_current_dice_values()
	return []
