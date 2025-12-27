# GameController.gd
extends Node
class_name GameController

signal power_up_granted(id: String, power_up: PowerUp)
signal power_up_revoked(id: String)
signal consumable_used(id: String, consumable: Consumable)
#signal dice_rolled(dice_values: Array)

# Active power-ups and consumables in the game dictionaries
var active_power_ups: Dictionary = {}  # id -> PowerUp
var active_consumables: Dictionary = {}  # id -> Consumable
var consumable_counts: Dictionary = {}  # id -> int (count of instances)
var active_debuffs: Dictionary = {}  # id -> Debuff
var active_mods: Dictionary = {}  # id -> Mod
var active_challenges: Dictionary = {}  # id -> Challenge

const SCORE_CARD_UI_SCRIPT := preload("res://Scripts/UI/score_card_ui.gd")
const DEBUFF_MANAGER_SCRIPT := preload("res://Scripts/Managers/DebuffManager.gd")
const DEBUFF_UI_SCRIPT := preload("res://Scripts/UI/debuff_ui.gd")
const ScoreCard := preload("res://Scenes/ScoreCard/score_card.gd")
const ScoringAnimationControllerScript := preload("res://Scripts/Effects/scoring_animation_controller.gd")
const ChoresManagerScript := preload("res://Scripts/Managers/ChoresManager.gd")
const ChoreUIScript := preload("res://Scripts/UI/chore_ui.gd")
const MomCharacterScript := preload("res://Scripts/UI/mom_character.gd")
const MomLogicHandlerScript := preload("res://Scripts/Core/mom_logic_handler.gd")
const ChallengeCelebrationScript := preload("res://Scripts/Effects/challenge_celebration.gd")
const RANDOM_POWER_UP_UNCOMMON_CONSUMABLE_DEF := preload("res://Scripts/Consumable/RandomPowerUpUncommonConsumable.tres")
const GREEN_ENVY_CONSUMABLE_DEF := preload("res://Scripts/Consumable/GreenEnvyConsumable.tres")
const POOR_HOUSE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/PoorHouseConsumable.tres")
const EMPTY_SHELVES_CONSUMABLE_DEF := preload("res://Scripts/Consumable/EmptyShelvesConsumable.tres")
const THE_RARITIES_CONSUMABLE_DEF := preload("res://Scripts/Consumable/TheRaritiesConsumable.tres")
const THE_PAWN_SHOP_CONSUMABLE_DEF := preload("res://Scripts/Consumable/ThePawnShopConsumable.tres")
const ONE_EXTRA_DICE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/OneExtraDiceConsumable.tres")
const GO_BROKE_OR_GO_HOME_CONSUMABLE_DEF := preload("res://Scripts/Consumable/GoBrokeOrGoHomeConsumable.tres")
# Score card upgrade consumables
const ONES_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/OnesUpgradeConsumable.tres")
const TWOS_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/TwosUpgradeConsumable.tres")
const THREES_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/ThreesUpgradeConsumable.tres")
const FOURS_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/FoursUpgradeConsumable.tres")
const FIVES_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/FivesUpgradeConsumable.tres")
const SIXES_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/SixesUpgradeConsumable.tres")
const THREE_OF_A_KIND_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/ThreeOfAKindUpgradeConsumable.tres")
const FOUR_OF_A_KIND_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/FourOfAKindUpgradeConsumable.tres")
const FULL_HOUSE_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/FullHouseUpgradeConsumable.tres")
const SMALL_STRAIGHT_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/SmallStraightUpgradeConsumable.tres")
const LARGE_STRAIGHT_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/LargeStraightUpgradeConsumable.tres")
const YAHTZEE_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/YahtzeeUpgradeConsumable.tres")
const CHANCE_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/ChanceUpgradeConsumable.tres")
const ALL_CATEGORIES_UPGRADE_CONSUMABLE_DEF := preload("res://Scripts/Consumable/AllCategoriesUpgradeConsumable.tres")

# Centralized, explicit NodePaths (tweak in Inspector if scene changes)
@export var dice_hand_path: NodePath            = ^"../DiceHand"
@export var turn_tracker_path: NodePath         = ^"../TurnTracker"
@export var power_up_manager_path: NodePath     = ^"../PowerUpManager"
@export var power_up_ui_path: NodePath          = ^"../PowerUpUI"
@export var power_up_container_path: NodePath   = ^"PowerUpContainer"
@export var consumable_manager_path: NodePath   = ^"../ConsumableManager"
@export var consumable_ui_path: NodePath        = ^"../ConsumableUI"
@export var consumable_container_path: NodePath = ^"ConsumableContainer"
@export var score_card_ui_path: NodePath        = ^"../ScoreCardUI"
@export var debuff_ui_path: NodePath            = ^"../DebuffUI"
@export var debuff_container_path: NodePath     = ^"DebuffContainer"
@export var debuff_manager_path: NodePath       = ^"../DebuffManager"
@export var score_card_path: NodePath           = ^"../ScoreCard"
@export var mod_manager_path: NodePath          = ^"../ModManager"
@export var shop_ui_path: NodePath              = ^"../ShopUI"
@export var game_button_ui_path: NodePath       = ^"../GameButtonUI"
@export var challenge_manager_path: NodePath    = ^"../ChallengeManager"
@export var challenge_ui_path: NodePath         = ^"../ChallengeUI"
@export var challenge_container_path: NodePath  = ^"ChallengeContainer"
@export var round_manager_path: NodePath        = ^"../RoundManager"
@export var crt_manager_path: NodePath          = ^"../CRTManager"
@export var statistics_panel_path: NodePath     = ^"../StatisticsPanel"
@export var scoring_animation_controller_path: NodePath = ^"../ScoringAnimationController"
@export var chores_manager_path: NodePath       = ^"../ChoresManager"
@export var chore_ui_path: NodePath             = ^"../ChoreUI"
@export var synergy_manager_path: NodePath      = ^"../SynergyManager"
@export var corkboard_ui_path: NodePath         = ^"../CorkboardUI"
@export var end_of_round_stats_panel_path: NodePath = ^"../EndOfRoundStatsPanel"
@export var channel_manager_path: NodePath      = ^"../ChannelManager"
@export var channel_manager_ui_path: NodePath   = ^"../ChannelManagerUI"
@export var round_winner_panel_path: NodePath   = ^"../RoundWinnerPanel"

@onready var consumable_manager: ConsumableManager = get_node(consumable_manager_path)
@onready var consumable_ui: ConsumableUI = get_node(consumable_ui_path)
@onready var consumable_container: Node  = get_node(consumable_container_path)
@onready var dice_hand: DiceHand         = get_node(dice_hand_path) as DiceHand
@onready var turn_tracker: TurnTracker   = get_node(turn_tracker_path) as TurnTracker
@onready var pu_manager: PowerUpManager  = get_node(power_up_manager_path) as PowerUpManager
@onready var powerup_ui: PowerUpUI       = get_node(power_up_ui_path) as PowerUpUI
@onready var power_up_container: Node    = get_node(power_up_container_path)
@onready var score_card_ui: ScoreCardUI  = get_node(score_card_ui_path) as ScoreCardUI
@onready var debuff_ui: DebuffUI         = get_node(debuff_ui_path) as DebuffUI
@onready var debuff_container: Node      = get_node(debuff_container_path)
@onready var debuff_manager: DebuffManager = get_node(debuff_manager_path) as DebuffManager
@onready var scorecard: ScoreCard          = get_node(score_card_path) as ScoreCard
@onready var mod_manager: ModManager       = get_node(mod_manager_path) as ModManager
@onready var shop_ui: ShopUI               = get_node(shop_ui_path) as ShopUI
@onready var game_button_ui: Control       = get_node(game_button_ui_path)
@onready var challenge_manager: ChallengeManager = get_node(challenge_manager_path) as ChallengeManager
@onready var challenge_ui: ChallengeUI     = get_node(challenge_ui_path) as ChallengeUI
@onready var challenge_container: Node     = get_node(challenge_container_path)
@onready var round_manager: RoundManager   = get_node_or_null(round_manager_path)
@onready var crt_manager: CRTManager       = get_node_or_null(crt_manager_path)
@onready var statistics_panel: Control = get_node_or_null(statistics_panel_path)
@onready var corkboard_ui = get_node_or_null(corkboard_ui_path)
@onready var scoring_animation_controller = get_node_or_null(scoring_animation_controller_path)
@onready var chores_manager = get_node_or_null(chores_manager_path)
@onready var chore_ui = get_node_or_null(chore_ui_path)
@onready var synergy_manager = get_node_or_null(synergy_manager_path)
@onready var end_of_round_stats_panel = get_node_or_null(end_of_round_stats_panel_path)
@onready var channel_manager = get_node_or_null(channel_manager_path)
@onready var channel_manager_ui = get_node_or_null(channel_manager_ui_path)
@onready var round_winner_panel = get_node_or_null(round_winner_panel_path)

# Mom dialog popup (instantiated when needed)
var _mom_dialog = null
var _grounded_debuffs: Array[String] = []  # Debuffs from NC-17 that persist until round end

# Game Over popup
var _game_over_popup: Control = null

# Challenge celebration effect manager
var _challenge_celebration = null

const STARTING_POWER_UP_IDS := ["extra_dice", "extra_rolls"]

var _last_modded_die_index: int = -1  # Track which die received the last mod

var pending_mods: Array[String] = []
var mod_persistence_map: Dictionary = {}  # mod_id -> int tracking how many instances of each mod should persist
var _shop_tween: Tween
var _end_of_round_stats_shown: bool = false  # Track if stats panel was shown this round


func _ready() -> void:
	add_to_group("game_controller")
	print("▶ GameController._ready()")
	var debug_panel = preload("res://Scenes/UI/DebugPanel.tscn").instantiate()
	add_child(debug_panel)
	
	# Add unlock notification UI
	var unlock_notification_ui = preload("res://Scenes/UI/UnlockNotificationUI.tscn").instantiate()
	add_child(unlock_notification_ui)
	
	# Connect to ProgressManager unlock signals
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		progress_manager.items_unlocked_batch.connect(_on_items_unlocked)
		print("[GameController] Connected to ProgressManager unlock signals")
	
	# Reference the private index variable to avoid an 'unused variable' lint warning
	# This value is reserved for future mod-application tracking.
	_last_modded_die_index = _last_modded_die_index
	if dice_hand:
		dice_hand.roll_complete.connect(_on_roll_completed)
		dice_hand.dice_spawned.connect(_on_dice_spawned)
		dice_hand.die_locked.connect(_on_die_locked)
	if scorecard:
		scorecard.score_auto_assigned.connect(_on_score_auto_assigned)
		scorecard.score_assigned.connect(_on_score_manual_assigned)
		scorecard.score_auto_assigned.connect(update_double_existing_usability)
		#scorecard.score_added.connect(update_double_existing_usability)
	if game_button_ui:
		game_button_ui.connect("shop_button_pressed", _on_shop_button_pressed)	
		if not game_button_ui.is_connected("dice_rolled", _on_game_button_dice_rolled):
			game_button_ui.dice_rolled.connect(_on_game_button_dice_rolled)
			print("[GameController] Connected to dice_rolled signal from GameButtonUI")
	if shop_ui:
		print("[GameController] Setting up shop UI")
		shop_ui.hide()
		shop_ui.connect("item_purchased", _on_shop_item_purchased)
	if challenge_manager:
		challenge_manager.challenge_completed.connect(_on_challenge_completed)
		challenge_manager.challenge_failed.connect(_on_challenge_failed)
	if round_manager:
		round_manager.round_started.connect(_on_round_started)
		round_manager.round_completed.connect(_on_round_completed)
		round_manager.round_failed.connect(_on_round_failed)
		round_manager.all_rounds_completed.connect(_on_all_rounds_completed)
	if consumable_ui:
		if not consumable_ui.is_connected("consumable_used", _on_consumable_ui_used):
			consumable_ui.consumable_used.connect(_on_consumable_ui_used)
			print("[GameController] Connected to consumable_used signal from ConsumableUI via forwarding handler")
		if not consumable_ui.is_connected("consumable_sold", _on_consumable_sold):
			consumable_ui.consumable_sold.connect(_on_consumable_sold)
			print("[GameController] Connected to consumable_sold signal from ConsumableUI")
	if powerup_ui:
		if not powerup_ui.is_connected("max_power_ups_reached", _on_max_power_ups_reached):
			powerup_ui.connect("max_power_ups_reached", _on_max_power_ups_reached)
	
	# Connect to our own power_up_revoked signal to update UI
	if not is_connected("power_up_revoked", _on_power_up_revoked):
		power_up_revoked.connect(_on_power_up_revoked)
		print("[GameController] Connected power_up_revoked signal to UI handler")
	
	if challenge_ui:
		if not challenge_ui.is_connected("challenge_selected", _on_challenge_selected):
			challenge_ui.challenge_selected.connect(_on_challenge_selected)
	if debuff_ui:
		if not debuff_ui.is_connected("debuff_selected", _on_debuff_selected):
			debuff_ui.debuff_selected.connect(_on_debuff_selected)
	
	# Connect CorkboardUI signals (new unified UI)
	if corkboard_ui:
		if not corkboard_ui.is_connected("challenge_selected", _on_challenge_selected):
			corkboard_ui.challenge_selected.connect(_on_challenge_selected)
			print("[GameController] Connected to challenge_selected signal from CorkboardUI")
		if not corkboard_ui.is_connected("debuff_selected", _on_debuff_selected):
			corkboard_ui.debuff_selected.connect(_on_debuff_selected)
			print("[GameController] Connected to debuff_selected signal from CorkboardUI")
		if not corkboard_ui.is_connected("consumable_used", _on_consumable_ui_used):
			corkboard_ui.consumable_used.connect(_on_consumable_ui_used)
			print("[GameController] Connected to consumable_used signal from CorkboardUI")
		if not corkboard_ui.is_connected("consumable_sold", _on_consumable_sold):
			corkboard_ui.consumable_sold.connect(_on_consumable_sold)
			print("[GameController] Connected to consumable_sold signal from CorkboardUI")
	
	if turn_tracker:
		turn_tracker.rolls_updated.connect(update_three_more_rolls_usability)
		turn_tracker.turn_started.connect(update_three_more_rolls_usability)
		turn_tracker.rolls_exhausted.connect(update_three_more_rolls_usability)
		turn_tracker.turn_started.connect(update_double_existing_usability)
		turn_tracker.rolls_exhausted.connect(update_double_existing_usability)
		# Connect double_or_nothing usability to track when rolls are used
		turn_tracker.rolls_updated.connect(update_double_or_nothing_usability)
		turn_tracker.turn_started.connect(update_double_or_nothing_usability)
		# Reset dice states to rollable at start of new turn
		turn_tracker.turn_started.connect(_on_turn_started)
		# Handle end of game (Turn 13 reached)
		turn_tracker.game_over.connect(_on_game_over)
	
	# Initialize ChoresManager and ChoreUI (now embedded in CorkboardUI)
	if chores_manager:
		chores_manager.mom_triggered.connect(_on_mom_triggered)
		print("[GameController] Connected to ChoresManager.mom_triggered")
	if corkboard_ui and chores_manager:
		corkboard_ui.set_chores_manager(chores_manager)
		print("[GameController] Connected CorkboardUI.ChoreUI to ChoresManager")

	# Initialize SynergyManager
	if synergy_manager:
		synergy_manager.connect_to_game_controller(self)
		print("[GameController] Connected SynergyManager to GameController")

	# Initialize ChannelManager and related UI
	if channel_manager:
		channel_manager.channel_selected.connect(_on_channel_selected)
		print("[GameController] Connected to ChannelManager.channel_selected")
	if channel_manager_ui:
		channel_manager_ui.set_channel_manager(channel_manager)
		channel_manager_ui.start_pressed.connect(_on_channel_start_pressed)
		print("[GameController] ChannelManagerUI connected to ChannelManager")
	if round_winner_panel:
		round_winner_panel.set_channel_manager(channel_manager)
		round_winner_panel.next_channel_pressed.connect(_on_next_channel_pressed)
		print("[GameController] RoundWinnerPanel connected")

	# Register new consumables programmatically
	if consumable_manager:
		consumable_manager.register_consumable_def(RANDOM_POWER_UP_UNCOMMON_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(GREEN_ENVY_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(POOR_HOUSE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(EMPTY_SHELVES_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(THE_RARITIES_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(THE_PAWN_SHOP_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(ONE_EXTRA_DICE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(GO_BROKE_OR_GO_HOME_CONSUMABLE_DEF)
		# Score card upgrade consumables
		consumable_manager.register_consumable_def(ONES_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(TWOS_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(THREES_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(FOURS_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(FIVES_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(SIXES_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(THREE_OF_A_KIND_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(FOUR_OF_A_KIND_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(FULL_HOUSE_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(SMALL_STRAIGHT_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(LARGE_STRAIGHT_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(YAHTZEE_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(CHANCE_UPGRADE_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(ALL_CATEGORIES_UPGRADE_CONSUMABLE_DEF)

	## _ready()
	## Called when the GameController node enters the scene tree.
	## Responsibilities:
	## - Register self in the 'game_controller' group
	## - Connect to signals from child managers/UI (dice, scorecard, UI buttons, shop, round manager, etc.)
	## - Prepare initial UI state and deferred game start
	## Notes:
	## - Uses get_node() and get_node_or_null() lookups assigned to @onready vars above.
	## - Keep connections idempotent (checks for is_connected before connecting) to avoid duplicate handlers.
	call_deferred("_on_game_start")
	print("[GameController] Handler expects args:", _on_game_button_dice_rolled.get_argument_count())


## _on_game_start()
##
## Deferred entry point for initializing gameplay state once the scene tree is ready.
##+ Grants a couple of starter consumables and a starting power-up.
##+ Starts the RoundManager if present.
##+ Keep this lightweight; heavy startup logic should be moved into RoundManager or dedicated setup functions.
func _on_game_start() -> void:
	#grant_consumable("random_power_up_uncommon")
	#grant_consumable("poor_house")
	#apply_debuff("lock_dice")
	#activate_challenge("300pts_no_debuff")
	#grant_power_up("red_slime")
	
	# Show channel selector UI at game start
	if channel_manager_ui and channel_manager:
		channel_manager.reset()  # Reset to Channel 1 on new game
		channel_manager_ui.show_channel_selector()
		print("[GameController] Showing channel selector - waiting for player to start")
	elif round_manager:
		# Fallback: start game immediately if no channel system
		round_manager.start_game()


## _on_channel_selected(channel: int) -> void
##
## Called when player confirms their channel selection. Starts the game.
func _on_channel_selected(channel: int) -> void:
	print("[GameController] Channel", channel, "selected, starting game...")
	if round_manager:
		round_manager.start_game()


## _on_channel_start_pressed(channel: int) -> void
##
## Called when player presses Start on channel selector UI.
func _on_channel_start_pressed(channel: int) -> void:
	print("[GameController] Channel start pressed for channel:", channel)
	# channel_selected signal will be emitted by ChannelManager.select_channel()


## _on_next_channel_pressed() -> void
##
## Called when player presses "Next Channel" on the RoundWinnerPanel.
## Advances to next channel and restarts the game loop.
func _on_next_channel_pressed() -> void:
	print("[GameController] Next channel requested")
	
	if channel_manager:
		channel_manager.advance_to_next_channel()
		print("[GameController] Advanced to Channel", channel_manager.current_channel)
	
	# Restart the game loop at Round 1
	_restart_game_for_new_channel()


## _restart_game_for_new_channel() -> void
##
## Resets game state and starts Round 1 for the new channel.
## Does NOT reset the channel number (keeps current channel).
func _restart_game_for_new_channel() -> void:
	print("[GameController] Restarting game for new channel...")
	
	# Clear active challenges, debuffs, etc.
	_clear_active_challenges()
	_clear_active_debuffs()
	
	# Reset end of round stats shown flag
	_end_of_round_stats_shown = false
	
	# Start new game session
	if round_manager:
		round_manager.start_game()
		print("[GameController] Game restarted for new channel")


## _clear_active_challenges() -> void
##
## Removes all active challenges for new channel start.
func _clear_active_challenges() -> void:
	for id in active_challenges.keys():
		var challenge = active_challenges[id]
		if challenge:
			challenge.queue_free()
	active_challenges.clear()
	print("[GameController] Cleared all active challenges")


## _clear_active_debuffs() -> void
##
## Removes all active debuffs for new channel start.
func _clear_active_debuffs() -> void:
	for id in active_debuffs.keys():
		var debuff = active_debuffs[id]
		if debuff:
			debuff.queue_free()
	active_debuffs.clear()
	_grounded_debuffs.clear()
	print("[GameController] Cleared all active debuffs")




## _process(delta)
##
## Frame tick handler. Currently only listens for the quit input action.
##+ Prefer not to add gameplay logic here; use specific signals or timers instead.
func _process(_delta):
	## _process(_delta)
	# Per-frame tick. Currently listens for the 'quit_game' input and exits the tree.
	# Keep this minimal: avoid heavy game logic here. Use signals or timers for gameplay timing.
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()



## spawn_starting_powerups()
##
## Create the default starting power-up icons and spawn their PowerUp instances without auto-applying them.
##+ This is a convenience used during development. Use `grant_power_up()` for full grant + activate behavior.
func spawn_starting_powerups() -> void:
	for id in ["extra_dice", "extra_rolls"]:
		var def: PowerUpData = pu_manager.get_def(id)
		if def:
			var icon = powerup_ui.add_power_up(def)
			# Connect the signals from the icon
			icon.power_up_selected.connect(_on_power_up_selected)
			icon.power_up_deselected.connect(_on_power_up_deselected)

			# Create the power up but don't apply it yet
			var pu: PowerUp = pu_manager.spawn_power_up(id, power_up_container)
			if pu:
				active_power_ups[id] = pu
			else:
				push_error("No PowerUpData for '%s'" % id)



## grant_power_up(id)
##
##+ High-level helper to spawn, create UI, register, and auto-activate a power-up.
##+ Side-effects:
##+ - Adds UI via `PowerUpUI.add_power_up`
##+ - Stores the runtime instance in `active_power_ups`
##+ - Emits `power_up_granted` signal
##+ - Calls `_activate_power_up` to immediately apply the effect
##+ Notes:
##+ - Aborts if `powerup_ui` reports the maximum number of power-ups reached.
func grant_power_up(id: String) -> void:
	print("\n=== Granting Power-Up: ", id, " ===")
	
	# Check if we already own this power-up
	if active_power_ups.has(id):
		print("[GameController] PowerUp '", id, "' is already owned. Cannot grant duplicate.")
		return
	
	# Check if we've reached the maximum number of power-ups
	if powerup_ui and powerup_ui.has_max_power_ups():
		print("[GameController] Maximum number of power-ups reached. Cannot add more.")
		return
	
	# 1) Spawn logic via scene manager
	var pu := pu_manager.spawn_power_up(id, power_up_container) as PowerUp
	if pu == null:
		push_error("[GameController] Failed to spawn PowerUp '%s'" % id)
		return

	# Create and connect UI first
	var def: PowerUpData = pu_manager.get_def(id)
	if def:
		var icon = powerup_ui.add_power_up(def)
		if icon:
			print("[GameController] Connecting power-up signals for:", id)
			# Connect the sell signal
			if not powerup_ui.is_connected("power_up_sold", _on_power_up_sold):
				powerup_ui.connect("power_up_sold", _on_power_up_sold)
		else:
			push_error("[GameController] Failed to create UI icon for power-up:", id)
			
	# Store the power-up reference
	active_power_ups[id] = pu
	emit_signal("power_up_granted", id, pu)
	print("[GameController] Power-up granted and ready:", id)
	
	# Automatically activate the power-up
	_activate_power_up(id)


## _activate_power_up(power_up_id)
##
##+ Internal helper that applies a spawned PowerUp instance to its intended target(s).
##+ This does the type-specific `apply()` calls and wires signals for dynamic description/effect updates.
##+ Notes:
##+ - PowerUp instances are expected to implement `apply(target)` and `remove(target)`.
##+ - For power-ups that emit runtime updates (randomizer, description changes), this function connects relevant signals.
func _activate_power_up(power_up_id: String) -> void:
	print("\n=== Power-up Auto-Activated ===")
	print("[GameController] Activating power-up:", power_up_id)
	
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("[GameController] No PowerUp found for id:", power_up_id)
		return
	
	# Connect to description_updated signal if the power-up has one
	if power_up_id == "upper_bonus_mult" or power_up_id == "consumable_cash" or power_up_id == "evens_no_odds" or power_up_id == "bonus_money" or power_up_id == "money_multiplier" or power_up_id == "full_house_bonus" or power_up_id == "step_by_step" or power_up_id == "perfect_strangers" or power_up_id == "green_monster" or power_up_id == "red_power_ranger" or power_up_id == "wild_dots" or power_up_id == "pin_head" or power_up_id == "money_well_spent" or power_up_id == "highlighted_score" or power_up_id == "the_consumer_is_always_right":
		# Disconnect first to avoid duplicates
		if pu.is_connected("description_updated", _on_power_up_description_updated):
			pu.description_updated.disconnect(_on_power_up_description_updated)
		
		# Then connect
		pu.description_updated.connect(_on_power_up_description_updated)
		print("[GameController] Connected to description_updated signal")
	
	# Connect to effect_updated signal for randomizer power-up
	if power_up_id == "randomizer":
		if pu.is_connected("effect_updated", _on_randomizer_effect_updated):
			pu.effect_updated.disconnect(_on_randomizer_effect_updated)
		
		pu.effect_updated.connect(_on_randomizer_effect_updated)
		print("[GameController] Connected to randomizer effect_updated signal")
	
	# Special handling for different power-ups
	match power_up_id:
		"foursome":
			if scorecard:
				pu.apply(scorecard)
				scorecard.debug_multiplier_function()
			else:
				push_error("[GameController] No scorecard available for Foursome power-up")
		"upper_bonus_mult":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied UpperBonusMult to scorecard")
			else:
				push_error("[GameController] No scorecard available for UpperBonusMult power-up")
		"chance520":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied Chance520 to scorecard")
			else:
				push_error("[GameController] No scorecard available for Chance520 power-up")
		"evens_no_odds":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied EvensNoOdds to scorecard")
			else:
				push_error("[GameController] No scorecard available for EvensNoOdds power-up")
		"extra_dice":
			pu.apply(dice_hand)
			#enable_debuff("lock_dice") # Removing this line to allow locking with extra dice
		"wild_dots":
			pu.apply(dice_hand)
		"yahtzee_bonus_mult":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied YahtzeeBonusMult to scorecard")
			else:
				push_error("[GameController] No scorecard available for YahtzeeBonusMult power-up")
		"extra_rolls":
			pu.apply(turn_tracker)
		"consumable_cash":
			pu.apply(self)
			print("[GameController] Applied ConsumableCash power-up")
		"bonus_money":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied BonusMoneyPowerUp to scorecard")
			else:
				push_error("[GameController] No scorecard available for BonusMoneyPowerUp")
		"randomizer":
			pu.apply(self)
			print("[GameController] Applied Randomizer power-up")
		"money_multiplier":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied MoneyMultiplierPowerUp to scorecard")
			else:
				push_error("[GameController] No scorecard available for MoneyMultiplierPowerUp")
		"full_house_bonus":
			pu.apply(self)
			print("[GameController] Applied FullHousePowerUp")
		"step_by_step":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied StepByStepPowerUp to scorecard")
			else:
				push_error("[GameController] No scorecard available for StepByStepPowerUp")
		"perfect_strangers":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied PerfectStrangersPowerUp to scorecard")
			else:
				push_error("[GameController] No scorecard available for PerfectStrangersPowerUp")
		"green_monster":
			pu.apply(self)
			print("[GameController] Applied GreenMonsterPU")
		"red_power_ranger":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied RedPowerRangerPowerUp to scorecard")
			else:
				push_error("[GameController] No scorecard available for RedPowerRangerPowerUp")
		"pin_head":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied PinHeadPowerUp to scorecard")
			else:
				push_error("[GameController] No scorecard available for PinHeadPowerUp")
		"money_well_spent":
			pu.apply(self)
			print("[GameController] Applied MoneyWellSpentPowerUp")
		"highlighted_score":
			if scorecard:
				pu.apply(scorecard)
				print("[GameController] Applied HighlightedScorePowerUp to scorecard")
			else:
				push_error("[GameController] No scorecard available for HighlightedScorePowerUp")
		"the_consumer_is_always_right":
			pu.apply(self)
			print("[GameController] Applied TheConsumerIsAlwaysRightPowerUp")
		"green_slime":
			pu.apply(self)
			print("[GameController] Applied GreenSlimePowerUp")
		"red_slime":
			pu.apply(self)
			print("[GameController] Applied RedSlimePowerUp")
		"purple_slime":
			pu.apply(self)
			print("[GameController] Applied PurpleSlimePowerUp")
		"blue_slime":
			pu.apply(self)
			print("[GameController] Applied BlueSlimePowerUp")
		_:
			push_error("[GameController] Unknown power-up type:", power_up_id)

## _on_power_up_sold(power_up_id)
##
## Handles selling a power-up from the shop/UI. Gives a partial refund and removes the power-up
## from both runtime and UI. Performs an animated removal when the UI supports it.
func _on_power_up_sold(power_up_id: String) -> void:
	print("[GameController] Selling power-up:", power_up_id)

	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("[GameController] No PowerUp found for id:", power_up_id)
		return

	var def = pu_manager.get_def(power_up_id)
	if def:
		var refund = def.price / 2.0  # Half price
		print("[GameController] Refunding", refund, "coins for power-up:", power_up_id)
		PlayerEconomy.add_money(refund)

	# Animate the icon if it exists, then remove
	if powerup_ui:
		powerup_ui.animate_power_up_removal(power_up_id, func():
			_deactivate_power_up(power_up_id)
			revoke_power_up(power_up_id)
			powerup_ui.remove_power_up(power_up_id)
			print("[GameController] Power-up removed from UI:", power_up_id)
		)
	else:
		_deactivate_power_up(power_up_id)
		revoke_power_up(power_up_id)
		if powerup_ui:
			powerup_ui.remove_power_up(power_up_id)


## _on_power_up_revoked(power_up_id)
##
## Handler for power_up_revoked signal - removes PowerUp from UI when revoked programmatically.
func _on_power_up_revoked(power_up_id: String) -> void:
	print("[GameController] PowerUp revoked, removing from UI:", power_up_id)
	if powerup_ui:
		powerup_ui.remove_power_up(power_up_id)
		print("[GameController] PowerUp removed from UI:", power_up_id)


## _deactivate_power_up(power_up_id)
##
## Performs type-specific removal logic for an active power-up without freeing the instance.
## This is used for animated removals or temporary deactivation.
func _deactivate_power_up(power_up_id: String) -> void:
	print("[GameController] DEACTIVATING PowerUp:", power_up_id)
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("[GameController] No PowerUp found for id:", power_up_id)
		return

	match power_up_id:
		"extra_dice":
			pu.remove(dice_hand)
			disable_debuff("lock_dice")
		"extra_rolls":
			pu.remove(turn_tracker)
		"wild_dots":
			print("[GameController] Removing wild_dots PowerUp")
			pu.remove(dice_hand)
		"foursome":
			print("[GameController] Removing foursome PowerUp")
			pu.remove(scorecard)
		"upper_bonus_mult":
			print("[GameController] Removing upper_bonus_mult PowerUp")
			pu.remove(scorecard)
		"bonus_money":
			print("[GameController] Removing bonus_money PowerUp")
			pu.remove(scorecard)
		"consumable_cash":
			print("[GameController] Removing consumable_cash PowerUp")
			pu.remove(self)
		"randomizer":
			print("[GameController] Removing randomizer PowerUp")
			pu.remove(self)
		"money_multiplier":
			print("[GameController] Removing money_multiplier PowerUp")
			pu.remove(scorecard)
		"wild_dots":
			pu.remove(dice_hand)
		"full_house_bonus":
			print("[GameController] Removing full_house_bonus PowerUp")
			pu.remove(self)
		"step_by_step":
			print("[GameController] Removing step_by_step PowerUp")
			pu.remove(scorecard)
		"perfect_strangers":
			print("[GameController] Removing perfect_strangers PowerUp")
			pu.remove(scorecard)
		"green_monster":
			print("[GameController] Removing green_monster PowerUp")
			pu.remove(self)
		"red_power_ranger":
			print("[GameController] Removing red_power_ranger PowerUp")
			pu.remove(scorecard)
		"pin_head":
			print("[GameController] Removing pin_head PowerUp")
			pu.remove(scorecard)
		"money_well_spent":
			print("[GameController] Removing money_well_spent PowerUp")
			pu.remove(self)
		"highlighted_score":
			print("[GameController] Removing highlighted_score PowerUp")
			pu.remove(scorecard)
		"the_consumer_is_always_right":
			print("[GameController] Removing the_consumer_is_always_right PowerUp")
			pu.remove(self)
		"green_slime":
			print("[GameController] Removing green_slime PowerUp")
			pu.remove(self)
		"red_slime":
			print("[GameController] Removing red_slime PowerUp")
			pu.remove(self)
		"purple_slime":
			print("[GameController] Removing purple_slime PowerUp")
			pu.remove(self)
		"blue_slime":
			print("[GameController] Removing blue_slime PowerUp")
			pu.remove(self)
		_:
			push_error("[GameController] Unknown power-up type:", power_up_id)


## revoke_power_up(power_up_id)
##
## Fully removes and frees a power-up instance, performing any necessary `.remove()` call for the
## expected target. Emits `power_up_revoked` when done.
func revoke_power_up(power_up_id: String) -> void:
	if not active_power_ups.has(power_up_id):
		return

	var pu := active_power_ups[power_up_id] as PowerUp
	if pu:
		# Pass the correct target based on power-up type
		match power_up_id:
			"extra_dice":
				pu.remove(dice_hand)
			"extra_rolls":
				pu.remove(turn_tracker)
			"foursome":
				pu.remove(scorecard)
			"bonus_money":
				pu.remove(scorecard)
			"consumable_cash":
				pu.remove(self)
			"randomizer":
				pu.remove(self)
			"money_multiplier":
				pu.remove(scorecard)
			"full_house_bonus":
				pu.remove(self)
			"step_by_step":
				pu.remove(scorecard)
			"perfect_strangers":
				pu.remove(scorecard)
			"green_monster":
				pu.remove(self)
			"red_power_ranger":
				pu.remove(scorecard)
			"pin_head":
				pu.remove(scorecard)
			"money_well_spent":
				pu.remove(self)
			"highlighted_score":
				pu.remove(scorecard)
			"the_consumer_is_always_right":
				pu.remove(self)
			"green_slime":
				pu.remove(self)
			"red_slime":
				pu.remove(self)
			"purple_slime":
				pu.remove(self)
			"blue_slime":
				pu.remove(self)
			_:
				# For unknown types, use the stored reference in the PowerUp itself
				pu.remove(pu)

		pu.queue_free()
	active_power_ups.erase(power_up_id)
	emit_signal("power_up_revoked", power_up_id)


## _on_power_up_selected(power_up_id)
##
## Callback when the player selects a power-up icon. Applies the chosen power-up to its target.
func _on_power_up_selected(power_up_id: String) -> void:
	print("\n=== Power-up Selected ===")
	print("[GameController] Activating power-up:", power_up_id)

	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("[GameController] No PowerUp found for id:", power_up_id)
		return

	match power_up_id:
		"extra_dice":
			pu.apply(dice_hand)
			enable_debuff("lock_dice")
		"extra_rolls":
			pu.apply(turn_tracker)
		"foursome":
			print("[GameController] Applying Foursome to scorecard:", scorecard)
			pu.apply(scorecard)
		_:
			push_error("[GameController] Unknown power-up type:", power_up_id)


## _on_power_up_deselected(power_up_id)
##
## Callback when a power-up icon is deselected by the player. Reverses the selected effect.
func _on_power_up_deselected(power_up_id: String) -> void:
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("No PowerUp found for id: %s" % power_up_id)
		return

	match power_up_id:
		"extra_dice":
			pu.remove(dice_hand)
			disable_debuff("lock_dice")
		"extra_rolls":
			pu.remove(turn_tracker)
		"foursome":
			pu.remove(scorecard)
		_:
			push_error("Unknown target for power-up: %s" % power_up_id)


## grant_consumable(id)
##
## Spawns a consumable instance, registers it in `active_consumables`, and adds a UI spine/icon.
## Notes:
## - UI spines no longer handle usage directly; usability is computed when the UI fan is opened.
## - Now supports multiple instances of the same consumable type using a count system.
func grant_consumable(id: String) -> void:
	# Check if we already have this consumable type
	if active_consumables.has(id):
		# Increment the count instead of creating a new instance
		consumable_counts[id] = consumable_counts.get(id, 1) + 1
		print("[GameController] Incremented consumable count for '%s' to %d" % [id, consumable_counts[id]])
		
		# Update the UI to show the new count
		# Try CorkboardUI first, fall back to old ConsumableUI
		if corkboard_ui:
			corkboard_ui.update_consumable_count(id, consumable_counts[id])
		elif consumable_ui:
			consumable_ui.update_consumable_count(id, consumable_counts[id])
		return
	
	var consumable := consumable_manager.spawn_consumable(id, consumable_container) as Consumable
	if consumable == null:
		push_error("[GameController] Failed to spawn Consumable '%s'" % id)
		return

	active_consumables[id] = consumable
	consumable_counts[id] = 1  # Initialize count

	# Add to UI with null checks - now returns spine instead of icon
	var def: ConsumableData = consumable_manager.get_def(id)
	if not def:
		push_error("[GameController] No ConsumableData found for '%s'" % id)
		return

	# Try CorkboardUI first, fall back to old ConsumableUI
	var spine = null
	if corkboard_ui:
		spine = corkboard_ui.add_consumable(def)
	elif consumable_ui:
		spine = consumable_ui.add_consumable(def)  # Returns ConsumableSpine now
	
	if not spine:
		push_error("[GameController] Failed to create UI spine for consumable '%s'" % id)
		return

	# NOTE: No longer connect signals to spine or set usability on spine
	# Spines only handle clicking/hovering for fan display
	# Usability is handled when icons are fanned out via update_consumable_usability()

	print("[GameController] Consumable granted with spine:", id)

## update_consumable_usability()
##
## Recomputes and updates the usability state for all consumables displayed in the fan UI.
## This should be called whenever game state that affects usability changes (scores, rolls left, etc.).
func update_consumable_usability() -> void:
	# Try CorkboardUI first, fall back to old ConsumableUI
	if corkboard_ui:
		corkboard_ui.update_consumable_usability()
	elif consumable_ui:
		consumable_ui.update_consumable_usability()

## set_consumable_usability(consumable_id, can_use)
##
## Updates a single consumable's usability state while the consumable UI is in the fanned state.
func set_consumable_usability(consumable_id: String, can_use: bool) -> void:
	# Only works when consumables are in fanned state
	if consumable_ui and consumable_ui._current_state == ConsumableUI.State.FANNED:
		var icon = consumable_ui.get_fanned_icon(consumable_id)
		if icon and icon.has_method("set_useable"):
			icon.set_useable(can_use)


## _on_consumable_used(consumable_id)
##
## Handles the actual effect of a consumable when the player uses it. Applies the consumable's
## effect, updates relevant UI events, and decrements/removes the consumable when consumed.
func _on_consumable_used(consumable_id: String) -> void:
	var consumable = active_consumables.get(consumable_id)
	print("\n=== Using Consumable: ", consumable_id, " ===")
	if not consumable:
		push_error("No Consumable found for id: %s" % consumable_id)
		return
	
	# Track consumable usage in statistics
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		stats.record_item_usage("consumable")
		print("[GameController] Tracked consumable usage in statistics")
	
	# Helper function to handle consumable removal with count system
	var remove_consumable_instance = func():
		var current_count = consumable_counts.get(consumable_id, 1)
		if current_count > 1:
			# Decrement count
			consumable_counts[consumable_id] = current_count - 1
			# Try CorkboardUI first, fall back to old ConsumableUI
			if corkboard_ui:
				corkboard_ui.update_consumable_count(consumable_id, consumable_counts[consumable_id])
			elif consumable_ui:
				consumable_ui.update_consumable_count(consumable_id, consumable_counts[consumable_id])
			print("[GameController] Decremented %s count to %d" % [consumable_id, consumable_counts[consumable_id]])
		else:
			# Remove entirely
			active_consumables.erase(consumable_id)
			consumable_counts.erase(consumable_id)
			# Try CorkboardUI first, fall back to old ConsumableUI
			if corkboard_ui:
				corkboard_ui.remove_consumable(consumable_id)
			elif consumable_ui:
				consumable_ui.remove_consumable(consumable_id)
			print("[GameController] Completely removed %s" % consumable_id)

	match consumable_id:
		"score_reroll":
			if score_card_ui:
				consumable.apply(self)
				score_card_ui.activate_score_reroll()
				remove_consumable_instance.call()
				if not score_card_ui.is_connected("score_rerolled", _on_score_rerolled):
					score_card_ui.connect("score_rerolled", _on_score_rerolled)
			else:
				push_error("GameController: score_card_ui not found!")
		"double_existing":
			if score_card_ui:
				consumable.apply(self)
				remove_consumable_instance.call()
				if not score_card_ui.is_connected("score_doubled", _on_score_doubled):
					score_card_ui.connect("score_doubled", _on_score_doubled)
			else:
				push_error("GameController: score_card_ui not found!")
		"add_max_power_up":
			consumable.apply(self)
			remove_consumable_instance.call()
		"three_more_rolls":
			consumable.apply(self)
			remove_consumable_instance.call()
		"power_up_shop_num":
			consumable.apply(self)
			remove_consumable_instance.call()
		"quick_cash":
			consumable.apply(self)
			remove_consumable_instance.call()
		"any_score":
			if score_card_ui:
				consumable.apply(self)
				# Note: AnyScore consumable handles its own completion via hand_scored signal
				remove_consumable_instance.call()
			else:
				push_error("GameController: score_card_ui not found!")
		"random_power_up_uncommon":
			consumable.apply(self)
			remove_consumable_instance.call()
			active_consumables.erase(consumable_id)
		"green_envy":
			consumable.apply(self)
			remove_consumable_instance.call()
		"poor_house":
			consumable.apply(self)
			remove_consumable_instance.call()
		"empty_shelves":
			consumable.apply(self)
			remove_consumable_instance.call()
		"double_or_nothing":
			consumable.apply(self)
			remove_consumable_instance.call()
		"the_rarities":
			consumable.apply(self)
			remove_consumable_instance.call()
		"the_pawn_shop":
			consumable.apply(self)
			remove_consumable_instance.call()
		"one_extra_dice":
			consumable.apply(self)
			remove_consumable_instance.call()
		"go_broke_or_go_home":
			consumable.apply(self)
			remove_consumable_instance.call()
		# Score card upgrade consumables
		"ones_upgrade", "twos_upgrade", "threes_upgrade", "fours_upgrade", "fives_upgrade", "sixes_upgrade", \
		"three_of_a_kind_upgrade", "four_of_a_kind_upgrade", "full_house_upgrade", \
		"small_straight_upgrade", "large_straight_upgrade", "yahtzee_upgrade", "chance_upgrade", \
		"all_categories_upgrade":
			consumable.apply(self)
			remove_consumable_instance.call()
		_:
			push_error("Unknown consumable type: %s" % consumable_id)


## _on_consumable_ui_used(consumable_id)
##
## Forwarding handler triggered by the UI when a consumable is used. Updates statistics first,
## then emits a GameController-level signal for PowerUps to listen, then invokes the internal consumable handler.
func _on_consumable_ui_used(consumable_id: String) -> void:
	print("[GameController] _on_consumable_ui_used called for:", consumable_id)
	
	# FIRST: Update statistics so PowerUps see the updated count
	print("[GameController] About to call _on_consumable_used (which updates stats)")
	_on_consumable_used(consumable_id)
	print("[GameController] _on_consumable_used completed")
	
	# THEN: Forward consumable_used signal for PowerUps to listen (now with updated stats)
	var consumable = active_consumables.get(consumable_id)
	print("[GameController] About to emit consumable_used signal AFTER stats update")
	emit_signal("consumable_used", consumable_id, consumable)
	print("[GameController] consumable_used signal emitted")


## _on_score_rerolled(_section, _category, _score)
##
## Callback for when the score reroll flow completes in the ScoreCard UI. Completes the
## consumable's reroll lifecycle and removes it from active consumables.
func _on_score_rerolled(_section: Scorecard.Section, _category: String, _score: int) -> void:
	var reroll = get_active_consumable("score_reroll") as ScoreRerollConsumable
	if reroll:
		reroll.complete_reroll()
		remove_consumable("score_reroll")


## _on_score_doubled(_section, _category, _new_score)
##
## Callback when a score has been doubled via the ScoreCard UI. Signals completion for the
## `double_existing` consumable and removes it.
func _on_score_doubled(_section: Scorecard.Section, _category: String, _new_score: int) -> void:
	var double_consumable = get_active_consumable("double_existing") as DoubleExistingConsumable
	if double_consumable:
		double_consumable.complete_double()
		remove_consumable("double_existing")


## _on_score_auto_assigned(_section, _category, _score, _breakdown_info)
##
## Triggered when the ScoreCard auto-assigns a score.
## Auto-scoring provides complete breakdown info, so we use it directly.
func _on_score_auto_assigned(_section: int, _category: String, _score: int, _breakdown_info: Dictionary = {}) -> void:
	if not scorecard:
		push_error("No scorecard reference found")
		return
	
	# Trigger scoring animations if controller is available - auto-scoring provides breakdown
	if scoring_animation_controller and _score > 0:
		scoring_animation_controller.start_scoring_animation(_score, _category, _breakdown_info)
	
	_handle_post_scoring_effects(_section, _category, _score, _breakdown_info)

## _on_score_manual_assigned(_section, _category, _score, _breakdown_info)
##
## Triggered when the ScoreCard registers a manual score.
## Manual scoring lacks breakdown info, so we create it ourselves.
func _on_score_manual_assigned(_section: int, _category: String, _score: int, _breakdown_info: Dictionary = {}) -> void:
	if not scorecard:
		push_error("No scorecard reference found")
		return
	
	# Only trigger animations if this is not an auto-scoring call
	# (Auto-scoring internally calls manual scoring, but we only want animation from auto path)
	# Check if breakdown_info is empty - that indicates a true manual scoring action
	if scoring_animation_controller and _score > 0 and _breakdown_info.is_empty():
		var enhanced_breakdown_info = _create_manual_breakdown_info(_category)
		print("[GameController] Created manual breakdown info: " + str(enhanced_breakdown_info))
		scoring_animation_controller.start_scoring_animation(_score, _category, enhanced_breakdown_info)
	
	_handle_post_scoring_effects(_section, _category, _score, _breakdown_info)

## _handle_post_scoring_effects(_section, _category, _score, _breakdown_info)
##
## Common post-scoring logic shared between auto and manual scoring.
## Sets all dice to DISABLED state to prevent further interaction until next turn.
func _handle_post_scoring_effects(_section: int, _category: String, _score: int, _breakdown_info: Dictionary = {}) -> void:
	# Disable all dice after scoring
	if dice_hand:
		dice_hand.set_all_dice_disabled()
		print("[GameController] Disabled all dice after scoring")
	
	# Check if chore task was completed
	if chores_manager:
		var dice_values = []
		if dice_hand:
			dice_values = dice_hand.get_current_dice_values()
		
		var context = {
			"category": _category,
			"dice_values": dice_values,
			"score": _score,
			"was_yahtzee": _category == "yahtzee" and _score > 0,
			"consumable_used": false,  # TODO: Track from consumable usage
			"locked_count": _count_locked_dice() if dice_hand else 0,
			"was_scratch": _score == 0
		}
		chores_manager.check_task_completion(context)
	
	# Track statistics for scoring
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		stats.increment_turns()
		if _score > 0:
			stats.record_hand_scored(_category, _score)
			stats.update_highest_score(_score)
			# Track which colored dice were scored
			if dice_hand:
				var dice_array = dice_hand.get_all_dice()
				#print("[GameController] DEBUG: Tracking dice scored - count: %d" % dice_array.size())
				for i in range(dice_array.size()):
					var die = dice_array[i]
					if die:
						var _color_name = DiceColor.get_color_name(die.color) if die.color != null else "null"
						#print("[GameController] DEBUG: Die %d - value: %d, color: %s (type: %s)" % [i, die.value, color_name, typeof(die.color)])
				stats.track_dice_array_scored(dice_array)
		else:
			stats.record_failed_hand()

	# Show randomizer effect after scoring
	if active_power_ups.has("randomizer"):
		var randomizer = active_power_ups["randomizer"] as RandomizerPowerUp
		if randomizer and randomizer.has_method("show_effect_after_scoring"):
			randomizer.show_effect_after_scoring()

	# Show dice color effects after scoring
	if DiceColorManager and DiceColorManager.are_colors_enabled() and dice_hand:
		var dice_array = dice_hand.get_all_dice()
		var color_description = DiceColorManager.get_current_effects_description(dice_array)
		if score_card_ui and score_card_ui.has_method("update_extra_info"):
			score_card_ui.update_extra_info(color_description)
			print("[GameController] Displayed dice color effects:", color_description)

	if scorecard.has_any_scores():
		# Update score reroll usability through the new system
		if consumable_ui and consumable_ui.has_consumable("score_reroll"):
			consumable_ui.update_consumable_usability()
			print("[GameController] Score reroll usability updated")
		else:
			print("[GameController] No score reroll consumable found")
	else:
		print("[GameController] No scores yet, reroll remains disabled")

## _create_manual_breakdown_info(category)
##
## Create breakdown info for manual scoring with active powerups and consumables.
func _create_manual_breakdown_info(category: String = "") -> Dictionary:
	var breakdown_info = {}
	
	# Get active powerups from GameController's active_power_ups dictionary
	var active_powerups_list = []
	for powerup_id in active_power_ups.keys():
		active_powerups_list.append(powerup_id)
	breakdown_info["active_powerups"] = active_powerups_list
	
	# Get active consumables from GameController's active_consumables dictionary 
	var active_consumables_list = []
	for consumable_id in active_consumables.keys():
		active_consumables_list.append(consumable_id)
	breakdown_info["active_consumables"] = active_consumables_list
	
	# Add category level from scorecard for upgrade system
	if scorecard and category != "":
		var category_level = scorecard.get_category_level_by_name(category)
		breakdown_info["category_level"] = category_level
		if category_level > 1:
			print("[GameController] Manual breakdown: category '%s' at level %d" % [category, category_level])
	else:
		breakdown_info["category_level"] = 1
	
	# Add dice information if we have dice hand
	if dice_hand and category != "":
		var dice_values = dice_hand.get_current_dice_values()
		var dice_array = dice_hand.get_all_dice()
		
		# Calculate which dice are used for this category (import the method from scorecard)
		var used_dice_indices = _get_used_dice_for_category_manual(category, dice_values, dice_array)
		
		breakdown_info["dice_values"] = dice_values.duplicate()
		breakdown_info["used_dice_indices"] = used_dice_indices.duplicate()
	else:
		breakdown_info["dice_values"] = []
		breakdown_info["used_dice_indices"] = []
	
	# Determine section for this category to help powerups register appropriately
	var section = _get_section_for_category(category)
	
	# Ask all active powerups to ensure their modifiers are registered for this context
	for powerup_id in active_power_ups.keys():
		var powerup_node = active_power_ups[powerup_id]
		if powerup_node and powerup_node.has_method("ensure_additive_for_context"):
			powerup_node.ensure_additive_for_context(category, section)
	
	# Get detailed breakdown from ScoreModifierManager for animation system
	var score_modifier = get_node_or_null("/root/ScoreModifierManager")
	if score_modifier:
		# Create additive sources array
		var additive_sources = []
		var active_additive_names = score_modifier.get_active_additive_sources()
		for source_name in active_additive_names:
			var additive_value = score_modifier.get_additive(source_name)
			additive_sources.append({
				"name": source_name,
				"value": additive_value,
				"category": "powerup"  # Assume powerup for now
			})
		breakdown_info["additive_sources"] = additive_sources
		
		# Create multiplier sources array
		var multiplier_sources = []
		var active_multiplier_names = score_modifier.get_active_sources()
		for source_name in active_multiplier_names:
			var multiplier_value = score_modifier.get_multiplier(source_name)
			multiplier_sources.append({
				"name": source_name,
				"value": multiplier_value,
				"category": "powerup"  # Assume powerup for now
			})
		breakdown_info["multiplier_sources"] = multiplier_sources
	
	return breakdown_info

## _get_section_for_category(category)
##
## Determine which section a category belongs to
func _get_section_for_category(category: String) -> Scorecard.Section:
	var upper_categories = ["ones", "twos", "threes", "fours", "fives", "sixes"]
	if category in upper_categories:
		return Scorecard.Section.UPPER
	else:
		return Scorecard.Section.LOWER

## _get_used_dice_for_category_manual(category, dice_values, dice_list)
##
## Manual implementation of the scorecard method for determining which dice contribute to score
func _get_used_dice_for_category_manual(category: String, dice_values: Array, _dice_list: Array) -> Array[int]:
	var used_indices: Array[int] = []
	
	# For most categories, all dice contribute to the score
	# Special cases where only some dice are used:
	match category.to_lower():
		"ones":
			# Only dice with value 1 are used
			for i in range(dice_values.size()):
				if dice_values[i] == 1:
					used_indices.append(i)
		"twos":
			# Only dice with value 2 are used
			for i in range(dice_values.size()):
				if dice_values[i] == 2:
					used_indices.append(i)
		"threes":
			# Only dice with value 3 are used
			for i in range(dice_values.size()):
				if dice_values[i] == 3:
					used_indices.append(i)
		"fours":
			# Only dice with value 4 are used
			for i in range(dice_values.size()):
				if dice_values[i] == 4:
					used_indices.append(i)
		"fives":
			# Only dice with value 5 are used
			for i in range(dice_values.size()):
				if dice_values[i] == 5:
					used_indices.append(i)
		"sixes":
			# Only dice with value 6 are used
			for i in range(dice_values.size()):
				if dice_values[i] == 6:
					used_indices.append(i)
		"three_of_a_kind", "four_of_a_kind":
			# All dice are used (sum of all dice)
			for i in range(dice_values.size()):
				used_indices.append(i)
		"full_house", "small_straight", "large_straight", "yahtzee":
			# Pattern-based: all dice must be considered but none are "scored" individually
			# For now, consider all dice as used
			for i in range(dice_values.size()):
				used_indices.append(i)
		"chance":
			# All dice are used (sum of all dice)
			for i in range(dice_values.size()):
				used_indices.append(i)
		_:
			# Default: all dice are used
			for i in range(dice_values.size()):
				used_indices.append(i)
	
	return used_indices


## apply_debuff(id)
##
## Spawns and applies a debuff effect to the appropriate target. Also registers the debuff with UI.
func apply_debuff(id: String) -> void:
	print("[GameController] Attempting to apply debuff:", id)

	# Check if this debuff is already active
	if active_debuffs.has(id) and active_debuffs[id] != null:
		print("[GameController] Debuff already active:", id)
		return

	var debuff := debuff_manager.spawn_debuff(id, debuff_container) as Debuff
	if debuff == null:
		push_error("[GameController] Failed to spawn Debuff '%s'" % id)
		return

	active_debuffs[id] = debuff

	# Add to UI with null checks
	var def: DebuffData = debuff_manager.get_def(id)
	if not def:
		push_error("[GameController] No DebuffData found for '%s'" % id)
		return

	# Add the debuff icon to the UI with proper signal connections
	# Try CorkboardUI first, fall back to old DebuffUI
	var icon = null
	if corkboard_ui:
		icon = corkboard_ui.add_debuff(def, debuff)
	elif debuff_ui:
		icon = debuff_ui.add_debuff(def, debuff)
	
	if not icon:
		push_error("[GameController] Failed to create UI icon for debuff '%s'" % id)
		return

	print("[GameController] Debuff icon added to UI:", id)

	# Apply the debuff effect
	match id:
		"lock_dice":
			debuff.target = dice_hand
			debuff.start()
		"disabled_twos":
			debuff.target = dice_hand
			debuff.start()
		"roll_score_minus_one":
			debuff.target = self  
			debuff.start()
		"costly_roll":  
			debuff.target = self  
			debuff.start()
		"the_division":
			debuff.target = self  
			debuff.start()
		_:
			push_error("[GameController] Unknown debuff type: %s" % id)


## enable_debuff(id)
##
## Ensures the given debuff is active. If it was previously spawned but paused, restarts it.
func enable_debuff(id: String) -> void:
	if not is_debuff_active(id):
		apply_debuff(id)
	else:
		var debuff = active_debuffs[id]
		if debuff and debuff.target:
			debuff.start()


## disable_debuff(id)
##
## Deactivates a debuff, optionally animating removal via the UI. Ensures cleanup of stored references.
func disable_debuff(id: String) -> void:
	if is_debuff_active(id):
		var debuff = active_debuffs[id]
		if debuff:
			debuff.end()

			# Animate the debuff removal
			# Try CorkboardUI first, fall back to old DebuffUI
			if corkboard_ui:
				corkboard_ui.animate_debuff_removal(id, func():
					# Remove after animation completes
					active_debuffs.erase(id)
					print("[GameController] Debuff removed after animation:", id)
				)
			elif debuff_ui:
				debuff_ui.animate_debuff_removal(id, func():
					# Remove after animation completes
					active_debuffs.erase(id)
					debuff_ui.remove_debuff(id)
					print("[GameController] Debuff removed after animation:", id)
				)
			else:
				# If no UI, remove immediately
				active_debuffs.erase(id)
				print("[GameController] Debuff removed immediately (no UI):", id)
	else:
		print("[GameController] No active debuff to disable with ID:", id)



## is_debuff_active(id) -> bool
##
## Returns true when a debuff with the given id is present and non-null in `active_debuffs`.
func is_debuff_active(id: String) -> bool:
	return active_debuffs.has(id) and active_debuffs[id] != null

# Add this function after other consumable-related functions

## get_active_consumable(id) -> Consumable
##
## Helper to retrieve a consumable instance by id from `active_consumables` or null if not present.
func get_active_consumable(id: String) -> Consumable:
	if active_consumables.has(id):
		return active_consumables[id]
	return null


## remove_consumable(id)
##
## Safely frees and unregisters a consumable and ensures UI removal.
func remove_consumable(id: String) -> void:
	if active_consumables.has(id):
		var consumable = active_consumables[id]
		if consumable:
			consumable.queue_free()
		active_consumables.erase(id)

		# Remove from UI if it exists
		if consumable_ui:
			consumable_ui.remove_consumable(id)
		else:
			push_error("No consumable_ui found when trying to remove consumable icon")


## grant_mod(id)
##
## Grants a mod to the player. Stores it for persistence and attempts to apply it to an available die.
## If no suitable die exists, the mod is queued in `pending_mods` and will be applied when dice spawn.
## Prevents granting more mods than available dice (5 dice = 5 mods max, 6 dice = 6 mods max).
func grant_mod(id: String) -> void:
	print("[GameController] Attempting to grant mod:", id)

	# Check if we have reached the dice count limit for mods
	if dice_hand and dice_hand.dice_list.size() > 0:
		var current_mod_count = _get_total_active_mod_count()
		var dice_count = dice_hand.dice_list.size()
		
		if current_mod_count >= dice_count:
			print("[GameController] Cannot grant mod - limit reached! (%d mods applied to %d dice)" % [current_mod_count, dice_count])
			return

	# Get the mod definition
	var def: ModData = mod_manager.get_def(id)
	if not def:
		push_error("[GameController] No ModData found for:", id)
		return

	# Store reference for later use
	active_mods[id] = def

	# Track this mod for persistence between rounds (increment count)
	if mod_persistence_map.has(id):
		mod_persistence_map[id] += 1
	else:
		mod_persistence_map[id] = 1

	print("[GameController] Mod persistence map updated:", mod_persistence_map)

	if dice_hand and dice_hand.dice_list.size() > 0:
		if _apply_mod_to_available_die(id):
			print("[GameController] Mod", id, "applied successfully")
		else:
			# Couldn't find a suitable die, add to pending
			print("[GameController] No suitable die found, adding to pending mods")
			if not pending_mods.has(id):
				pending_mods.append(id)
	else:
		# No dice available, add to pending
		print("[GameController] No dice available - adding to pending mods")
		if not pending_mods.has(id):
			pending_mods.append(id)

# Helper function to find and apply a mod to an available die

## _apply_mod_to_available_die(mod_id) -> bool
##
## Attempts to spawn and apply a mod to the first suitable die. Returns true when applied.
func _apply_mod_to_available_die(mod_id: String) -> bool:
	# Try to find a die WITHOUT ANY mod
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		if die.active_mods.size() == 0:
			var mod = mod_manager.spawn_mod(mod_id, die)
			if mod and active_mods.has(mod_id):
				die.add_mod(active_mods[mod_id])
				print("[GameController] Applied mod", mod_id, "to empty die at index", i)
				return true
			elif mod:
				push_error("[GameController] Spawned mod but no ModData found in active_mods for: " + mod_id)

	# If no empty die found, try to find one without this specific mod
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		if not die.has_mod(mod_id):
			var mod = mod_manager.spawn_mod(mod_id, die)
			if mod and active_mods.has(mod_id):
				die.add_mod(active_mods[mod_id])
				print("[GameController] Applied mod", mod_id, "to die at index", i)
				return true
			elif mod:
				push_error("[GameController] Spawned mod but no ModData found in active_mods for: " + mod_id)

	# No suitable die found
	return false


## _get_total_active_mod_count() -> int
##
## Counts the total number of mods currently applied to all dice. Used for dice count limit validation.
func _get_total_active_mod_count() -> int:
	if not dice_hand or dice_hand.dice_list.size() == 0:
		return 0
	
	var total_count = 0
	for die in dice_hand.dice_list:
		total_count += die.active_mods.size()
	
	return total_count


## _get_expected_dice_count() -> int
##
## Gets the expected number of dice considering the base dice count and any active power-ups that modify dice count.
## This is used for mod limit validation before dice are actually spawned.
func _get_expected_dice_count() -> int:
	if not dice_hand:
		return 5  # Default fallback
	
	# Start with the current dice count setting (which may have been modified by power-ups)
	return dice_hand.dice_count

## grant_colored_dice(id)
##
## Processes the purchase of a colored dice type, making it available for the current game session.
func grant_colored_dice(id: String) -> void:
	print("[GameController] Attempting to grant colored dice:", id)
	
	# Get the colored dice data
	var colored_dice_data = DiceColorManager.get_colored_dice_data(id)
	if not colored_dice_data:
		push_error("[GameController] No ColoredDiceData found for:", id)
		return
	
	# Check if player can afford it
	if PlayerEconomy.money < colored_dice_data.price:
		print("[GameController] Insufficient money for colored dice:", id, "Cost:", colored_dice_data.price, "Have:", PlayerEconomy.money)
		return
	
	# Deduct the cost
	PlayerEconomy.remove_money(colored_dice_data.price, "colored_dice")
	print("[GameController] Spent $%d on %s" % [colored_dice_data.price, colored_dice_data.display_name])
	
	# Purchase the colored dice type through DiceColorManager
	if DiceColorManager.purchase_colored_dice(id):
		print("[GameController] Successfully purchased %s for this game session" % colored_dice_data.display_name)
		
		# Optional: Show a notification or effect
		_show_colored_dice_purchase_notification(colored_dice_data)
	else:
		# Refund if purchase failed
		PlayerEconomy.add_money(colored_dice_data.price)
		push_error("[GameController] Failed to purchase colored dice:", id)

## _show_colored_dice_purchase_notification(data)
##
## Shows a notification when a colored dice type is purchased
func _show_colored_dice_purchase_notification(data) -> void:
	# This could be expanded to show visual effects or notifications
	print("[GameController] 🎲 %s purchased! New dice will have a chance to be %s." % [data.display_name, data.get_color_name()])


## _on_roll_completed()
##
## Called when a dice roll completes. All dice should now be in ROLLED state and ready for
## player interaction (locking or scoring). Applies any 'lock_dice' debuff effect if active.
func _on_roll_completed() -> void:
	print("[GameController] Roll completed - dice are now in ROLLED state")
	
	if is_debuff_active("lock_dice"):
		var debuff = active_debuffs["lock_dice"]
		if debuff and dice_hand:
			debuff.apply(dice_hand)
	# Note: Removed enable_all_dice() call here since state machine handles input control
	
	# Print dice states for debugging
	if dice_hand:
		dice_hand.print_dice_states()

## _on_turn_started()
##
## Called when a new turn begins. Resets all dice to ROLLABLE state.
func _on_turn_started() -> void:
	print("[GameController] New turn started - resetting dice to ROLLABLE state")
	if dice_hand:
		dice_hand.set_all_dice_rollable()

## _on_game_over()
##
## Called when max turns (13) is reached. Shows Game Over popup with results.
func _on_game_over() -> void:
	print("[GameController] Game over - max turns reached")
	
	# Get final score and challenge status
	var final_score = scorecard.get_total_score() if scorecard else 0
	var challenge_completed = round_manager and round_manager.is_challenge_completed
	var target_score = 0
	if round_manager:
		var round_data = round_manager.get_current_round_data()
		if round_data and round_data.has("target_score"):
			target_score = round_data["target_score"]
	
	# Save progress if challenge was completed
	if challenge_completed:
		print("[GameController] Challenge completed at game end - saving progress")
		var progress_manager = get_node("/root/ProgressManager")
		if progress_manager:
			progress_manager.end_game_tracking(final_score, true)
			print("[GameController] Progress saved with score: %d" % final_score)
	
	# Show Game Over popup
	_show_game_over_popup(final_score, target_score, challenge_completed)


## _show_game_over_popup()
##
## Creates and displays the Game Over popup with final score and options.
##
## Parameters:
##   final_score: int - player's final total score
##   target_score: int - the challenge target score
##   challenge_completed: bool - whether the challenge was completed
func _show_game_over_popup(final_score: int, target_score: int, challenge_completed: bool) -> void:
	if _game_over_popup and is_instance_valid(_game_over_popup):
		_game_over_popup.queue_free()
	
	# Create dark overlay
	var overlay = ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	
	# Create popup panel
	var popup = PanelContainer.new()
	popup.name = "GameOverPopup"
	popup.custom_minimum_size = Vector2(400, 300)
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.z_index = 101
	
	# Style the popup
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.1, 0.98)
	style.border_color = Color(0.8, 0.6, 0.2, 1.0) if challenge_completed else Color(0.6, 0.2, 0.2, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 8
	popup.add_theme_stylebox_override("panel", style)
	
	# Create content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Title label
	var title_label = RichTextLabel.new()
	title_label.bbcode_enabled = true
	title_label.fit_content = true
	title_label.scroll_active = false
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if challenge_completed:
		title_label.text = "[center][color=gold][shake rate=10 level=5]CHALLENGE COMPLETE![/shake][/color][/center]"
	else:
		title_label.text = "[center][color=red][wave amp=30 freq=3]GAME OVER[/wave][/color][/center]"
	title_label.add_theme_font_size_override("normal_font_size", 32)
	vbox.add_child(title_label)
	
	# Score display
	var score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.text = "Final Score: %d" % final_score
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vbox.add_child(score_label)
	
	# Goal status
	var goal_label = Label.new()
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if target_score > 0:
		goal_label.text = "Goal: %d pts" % target_score
		if challenge_completed:
			goal_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))
		else:
			goal_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1))
	else:
		goal_label.text = ""
	goal_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(goal_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Button container
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 20)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# New Game button
	var new_game_button = Button.new()
	new_game_button.text = "New Game"
	new_game_button.custom_minimum_size = Vector2(120, 40)
	new_game_button.pressed.connect(_on_new_game_pressed)
	button_container.add_child(new_game_button)
	
	# Continue button (only if challenge completed)
	if challenge_completed:
		var continue_button = Button.new()
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = Vector2(120, 40)
		continue_button.pressed.connect(_on_continue_after_game_over)
		button_container.add_child(continue_button)
	
	# Quit button
	var quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(120, 40)
	quit_button.pressed.connect(_on_quit_game_pressed)
	button_container.add_child(quit_button)
	
	vbox.add_child(button_container)
	popup.add_child(vbox)
	
	# Add to tree
	overlay.add_child(popup)
	add_child(overlay)
	_game_over_popup = overlay
	
	# Center popup after adding to tree
	await get_tree().process_frame
	var viewport_size = get_tree().root.get_viewport().get_visible_rect().size
	popup.position = (viewport_size - popup.size) / 2.0
	
	# Animate popup in
	popup.scale = Vector2(0.5, 0.5)
	popup.modulate.a = 0
	var tween = create_tween().set_parallel()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.2)


## _on_new_game_pressed()
##
## Handler for New Game button - restarts the entire game.
func _on_new_game_pressed() -> void:
	print("[GameController] New Game requested")
	if _game_over_popup and is_instance_valid(_game_over_popup):
		_game_over_popup.queue_free()
		_game_over_popup = null
	get_tree().reload_current_scene()


## _on_continue_after_game_over()
##
## Handler for Continue button after completing challenge - opens shop for next round.
func _on_continue_after_game_over() -> void:
	print("[GameController] Continue after game over - opening shop")
	if _game_over_popup and is_instance_valid(_game_over_popup):
		_game_over_popup.queue_free()
		_game_over_popup = null
	_on_shop_button_pressed()


## _on_quit_game_pressed()
##
## Handler for Quit button - exits the game.
func _on_quit_game_pressed() -> void:
	print("[GameController] Quit Game requested")
	get_tree().quit()

## _on_dice_spawned()
##
## Called whenever dice are (re)spawned. Responsible for re-applying persistent mods and
## processing any pending mods. Attempts to distribute mods across dice while respecting
## the per-mod persistence counts stored in `mod_persistence_map`.
func _on_dice_spawned() -> void:
	print("[GameController] mod_persistence_map:", mod_persistence_map)
	if not dice_hand:
		return

	# Connect mod sell signals for each die
	for die in dice_hand.dice_list:
		if not die.is_connected("mod_sell_requested", _on_mod_sold):
			die.mod_sell_requested.connect(_on_mod_sold)

	print("[GameController] New dice spawned, checking for mods to apply")
	print("[GameController] Mod persistence map:", mod_persistence_map)

	# Track already applied mod types to prevent duplicates on a single die
	var applied_mod_counts = {}

	# First apply any pending mods (these are more recent)
	var mods_to_process = pending_mods.duplicate()
	pending_mods.clear()

	# Then add all persistent mods that should be reapplied
	for mod_id in mod_persistence_map:
		# Add each mod type the correct number of times
		var count = mod_persistence_map[mod_id]
		for i in range(count):
			mods_to_process.append(mod_id)

	print("[GameController] Total mods to process:", mods_to_process.size())
	print("[GameController] Mods to process:", mods_to_process)

	# Loop through all dice in order
	for die_index in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[die_index]

		# Skip dice that already have mods
		if die.active_mods.size() >= 1:
			print("[GameController] Dice at index", die_index, "already has mods, skipping")
			continue

		# Try to apply any available mod that hasn't been applied yet
		for i in range(mods_to_process.size()):
			var mod_id = mods_to_process[i]

			# Check if we've already applied the maximum number for this type
			if not applied_mod_counts.has(mod_id):
				applied_mod_counts[mod_id] = 0

			# Skip if we've already applied the maximum for this type
			if applied_mod_counts[mod_id] >= mod_persistence_map.get(mod_id, 1):
				continue

			var def = active_mods[mod_id]
			if def and not die.has_mod(mod_id):
				var mod = mod_manager.spawn_mod(mod_id, die)
				if mod:
					die.add_mod(def)
					# Record that we've applied an instance of this mod
					applied_mod_counts[mod_id] += 1
					print("[GameController] Applied mod", mod_id, "to die at index", die_index, 
						  "- count", applied_mod_counts[mod_id], "of", mod_persistence_map.get(mod_id, 1))

					# Remove this mod from the processing list
					mods_to_process.remove_at(i)
					break

		# If we've applied all available mods, we can stop
		if mods_to_process.is_empty():
			break

	# Add any mods that couldn't be applied back to pending_mods
	for mod_id in mods_to_process:
		print("[GameController] Couldn't apply mod", mod_id, ", adding to pending_mods")
		if not pending_mods.has(mod_id):
			pending_mods.append(mod_id)

## _on_die_locked(die)
##
## Called when a die is locked. Tracks dice locking statistics.
func _on_die_locked(die) -> void:
	print("[GameController] Die locked:", die.value)
	Statistics.track_dice_lock()

## _on_shop_button_pressed()
##
## Handles the shop button press. If challenge was completed, shows the End of Round
## Statistics Panel first with bonus calculations, then opens the shop after player
## clicks "Head to Shop". Otherwise toggles the shop directly.
func _on_shop_button_pressed() -> void:
	# Check if challenge was completed - show stats panel first (only once)
	if round_manager and round_manager.is_challenge_completed and not _end_of_round_stats_shown:
		print("[GameController] Challenge completed - showing end of round stats panel")
		
		# Save progress
		var progress_manager = get_node("/root/ProgressManager")
		if progress_manager:
			var current_score = scorecard.get_total_score() if scorecard else 0
			progress_manager.end_game_tracking(current_score, true)
			print("[GameController] Progress saved with score: %d" % current_score)
		
		# Show stats panel if available
		if end_of_round_stats_panel:
			_end_of_round_stats_shown = true  # Mark as shown
			_show_end_of_round_stats()
			return
		else:
			print("[GameController] No stats panel found - opening shop directly")
	
	# If no stats panel or challenge not completed or already shown, open shop directly
	_open_shop_ui()


## _show_end_of_round_stats()
##
## Shows the end of round statistics panel with bonus calculations.
## Calculates and awards bonuses, then connects to panel signal to open shop after.
func _show_end_of_round_stats() -> void:
	print("[GameController] Showing end of round stats panel")
	
	# Get current round data
	var current_round_num = round_manager.get_current_round_number() if round_manager else 1
	var target_score = round_manager.get_current_challenge_target_score() if round_manager else 0
	var final_score = scorecard.get_total_score() if scorecard else 0
	
	# Prepare data for the stats panel
	var stats_data = {
		"round_number": current_round_num,
		"challenge_target": target_score,
		"final_score": final_score,
		"scorecard": scorecard
	}
	
	# Connect to panel's continue signal (one-shot)
	if not end_of_round_stats_panel.is_connected("continue_to_shop_pressed", _on_stats_panel_continue):
		end_of_round_stats_panel.continue_to_shop_pressed.connect(_on_stats_panel_continue, CONNECT_ONE_SHOT)
	
	# Show the panel - it will calculate bonuses internally
	end_of_round_stats_panel.show_stats(stats_data)


## _on_stats_panel_continue()
##
## Called when player clicks "Head to Shop" on the stats panel.
## Awards the calculated bonuses and opens the shop.
func _on_stats_panel_continue() -> void:
	print("[GameController] Stats panel continue pressed - awarding bonuses and opening shop")
	
	# Award bonuses via PlayerEconomy
	if end_of_round_stats_panel:
		var total_bonus = end_of_round_stats_panel.get_total_bonus()
		var empty_bonus = end_of_round_stats_panel.get_empty_categories_bonus()
		var score_bonus = end_of_round_stats_panel.get_score_above_bonus()
		
		if total_bonus > 0:
			PlayerEconomy.add_money(total_bonus)
			print("[GameController] Awarded end of round bonuses: $%d (empty: $%d, score: $%d)" % [total_bonus, empty_bonus, score_bonus])
			
			# Track in statistics
			Statistics.total_money_earned += total_bonus
	
	# Complete the round
	if round_manager:
		round_manager.complete_round()
	
	# Open the shop
	_open_shop_ui()


## _open_shop_ui()
##
## Opens the shop UI with animated tween. Disables CRT effect while shop is visible.
func _open_shop_ui() -> void:
	if not shop_ui:
		return
	
	if not shop_ui.visible:
		# Disable CRT when opening shop
		if crt_manager:
			crt_manager.disable_crt()

		# Cancel any existing tween
		if _shop_tween and _shop_tween.is_valid():
			_shop_tween.kill()

		# 1. Show label immediately
		shop_ui.show()
		shop_ui.visible = true
		shop_ui.modulate.a = 0.0
		shop_ui.scale = Vector2(0.1, 0.1)

		# 2. Create new tween
		_shop_tween = get_tree().create_tween()

		# 3. Fade in (faster)
		_shop_tween.tween_property(
			shop_ui, "modulate:a", 1.0, 0.1
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# 4. Bounce scale (faster)
		_shop_tween.tween_property(
			shop_ui, "scale", Vector2(1.0, 1.0), 0.85
		).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

		# 5. Settle scale (faster)
		_shop_tween.tween_property(
			shop_ui, "scale", Vector2.ONE, 0.05
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		shop_ui.scale = Vector2(1.0, 1.0)
		# Cancel any existing tween
		if _shop_tween and _shop_tween.is_valid():
			_shop_tween.kill()
		# 2. Create new tween
		_shop_tween = get_tree().create_tween()

		# 3. Fade in (faster)
		_shop_tween.tween_property(
			shop_ui, "modulate:a", 1.0, 0.1
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# 4. Bounce scale (faster)
		_shop_tween.tween_property(
			shop_ui, "scale", Vector2(0.001, 0.001), 0.55
		).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

		await _shop_tween.finished
		shop_ui.hide()

		# Re-enable CRT when closing shop
		if crt_manager:
			crt_manager.enable_crt()


## _on_shop_item_purchased(item_id, item_type)
##
# Processes shop purchases by delegating to the appropriate grant_* helper.
func _on_shop_item_purchased(item_id: String, item_type: String) -> void:
	print("[GameController] Processing purchase:", item_id, "type:", item_type)
	match item_type:
		"power_up":
			print("[GameController] Granting power-up:", item_id)
			grant_power_up(item_id)
		"consumable":
			print("[GameController] Granting consumable:", item_id)
			grant_consumable(item_id)
		"mod":
			print("[GameController] Granting mod:", item_id)
			grant_mod(item_id)
		"colored_dice":
			print("[GameController] Granting colored dice:", item_id)
			grant_colored_dice(item_id)
		_:
			push_error("[GameController] Unknown item type purchased:", item_type)


## activate_challenge(id)
##
# Spawns and activates a challenge for the current round. Sets the challenge target to the
# GameController so challenges can interact with central systems. Registers the challenge in UI.
func activate_challenge(id: String) -> void:
	print("[GameController] Activating challenge:", id)

	if active_challenges.has(id):
		print("[GameController] Challenge already active:", id)
		return

	var challenge = challenge_manager.spawn_challenge(id, challenge_container) as Challenge
	if challenge == null:
		push_error("[GameController] Failed to spawn challenge:", id)
		return

	active_challenges[id] = challenge

	# Get challenge data
	var def = challenge_manager.get_def(id)
	if not def:
		push_error("[GameController] No challenge data for:", id)
		return

	var round_data = round_manager.get_current_round_data()
	var round_number = round_data.get("round_number", 1)

	if challenge and def and challenge.has_method("set_target_score_from_resource"):
		challenge.set_target_score_from_resource(def, round_number)
		
		# Apply channel difficulty multiplier to target score
		if channel_manager:
			var base_target = challenge.get_target_score()
			var scaled_target = channel_manager.get_scaled_target_score(base_target)
			challenge._target_score = scaled_target
			# Also update rounds_data to keep in sync
			if round_manager:
				round_manager.set_current_challenge_target_score(scaled_target)
			print("[GameController] Channel", channel_manager.current_channel, "scaled target:", base_target, "->", scaled_target, "(%.2fx)" % channel_manager.get_difficulty_multiplier())

	# Apply to game controller to access all needed systems
	challenge.target = self
	challenge.start()

	# Add to UI with properly connected signals
	# Try CorkboardUI first (new unified UI), fall back to old ChallengeUI
	if corkboard_ui:
		var icon = corkboard_ui.add_challenge(def, challenge)
		if icon:
			print("[GameController] Challenge added to CorkboardUI:", id)
		else:
			push_error("[GameController] Failed to add challenge to CorkboardUI:", id)
	elif challenge_ui:
		var icon = challenge_ui.add_challenge(def, challenge)
		if icon:
			# Set up any additional properties if needed
			print("[GameController] Challenge UI created for:", id)
		else:
			push_error("[GameController] Failed to create UI for challenge:", id)
	else:
		push_error("[GameController] No challenge_ui or corkboard_ui reference")


## _on_challenge_completed(id)
##
## Handles the successful completion of a challenge: awards any rewards,
## triggers celebration animation, animates UI removal, and frees the challenge instance.
func _on_challenge_completed(id: String) -> void:
	print("[GameController] Challenge completed:", id)

	# Grant reward if specified
	var def = challenge_manager.get_def(id)
	if def and def.reward_money > 0:
		print("[GameController] Granting reward:", def.reward_money)
		PlayerEconomy.add_money(def.reward_money)

	# Trigger celebration fireworks
	_trigger_challenge_celebration()

	# Animate challenge completion before removing
	# Try CorkboardUI first, fall back to old ChallengeUI
	if corkboard_ui:
		corkboard_ui.animate_challenge_removal(id, func():
			# Clean up challenge after animation
			if active_challenges.has(id):
				var challenge = active_challenges[id]
				if challenge:
					challenge.queue_free()
				active_challenges.erase(id)
		)
	elif challenge_ui:
		challenge_ui.animate_challenge_removal(id, func():
			# Clean up challenge after animation
			if active_challenges.has(id):
				var challenge = active_challenges[id]
				if challenge:
					challenge.queue_free()
				active_challenges.erase(id)
				challenge_ui.remove_challenge(id)
		)
	else:
		# Clean up challenge immediately if no UI
		if active_challenges.has(id):
			var challenge = active_challenges[id]
			if challenge:
				challenge.queue_free()
			active_challenges.erase(id)

	# Show notification
	# NotificationSystem.show_notification("Challenge Completed: " + def.display_name)


## _trigger_challenge_celebration()
##
## Triggers firework particle effects at the challenge spine location.
func _trigger_challenge_celebration() -> void:
	# Create celebration manager if needed
	if _challenge_celebration == null:
		_challenge_celebration = ChallengeCelebrationScript.new()
		add_child(_challenge_celebration)
	
	# Get position from CorkboardUI challenge spine
	var celebration_position := Vector2(150, 100)  # Default fallback position
	if corkboard_ui and corkboard_ui.has_method("get_challenge_spine_position"):
		celebration_position = corkboard_ui.get_challenge_spine_position()
	elif corkboard_ui:
		# Try to find the challenge spine directly
		var challenge_spine = corkboard_ui.get_node_or_null("Panel/ChallengeSpine")
		if challenge_spine:
			celebration_position = challenge_spine.global_position + Vector2(60, 60)
		else:
			# Use CorkboardUI position with offset
			celebration_position = corkboard_ui.global_position + Vector2(80, 80)
	
	print("[GameController] Triggering challenge celebration at: %s" % str(celebration_position))
	_challenge_celebration.trigger_celebration(celebration_position, get_tree().current_scene)


## _on_challenge_failed(id)
##
# Handles failure of a challenge: animates removal and frees the instance. Optionally posts a
# notification (currently commented out).
func _on_challenge_failed(id: String) -> void:
	print("[GameController] Challenge failed:", id)

	# Get challenge data for notification
	var def = challenge_manager.get_def(id)
	var _display_name = def.display_name if def else id

	# Animate challenge failure before removing
	# Try CorkboardUI first, fall back to old ChallengeUI
	if corkboard_ui:
		corkboard_ui.animate_challenge_removal(id, func():
			# Clean up challenge after animation
			if active_challenges.has(id):
				var challenge = active_challenges[id]
				if challenge:
					challenge.queue_free()
				active_challenges.erase(id)
		)
	elif challenge_ui:
		challenge_ui.animate_challenge_removal(id, func():
			# Clean up challenge after animation
			if active_challenges.has(id):
				var challenge = active_challenges[id]
				if challenge:
					challenge.queue_free()
				active_challenges.erase(id)
				challenge_ui.remove_challenge(id)
		)
	else:
		# Clean up challenge immediately if no UI
		if active_challenges.has(id):
			var challenge = active_challenges[id]
			if challenge:
				challenge.queue_free()
			active_challenges.erase(id)

	# Show notification
	# NotificationSystem.show_notification("Challenge Failed: " + _display_name)



## _on_challenge_selected(id)
##
# Called when a player selects a challenge in the UI. Currently highlights the challenge icon briefly.
func _on_challenge_selected(id: String) -> void:
	print("[GameController] Challenge selected:", id)

	# Handle challenge selection - could show details, focus the challenge, etc.
	var challenge = active_challenges.get(id)
	if challenge:
		# You could potentially focus on this challenge or show details
		print("[GameController] Found challenge:", id)

		# Example: Highlight the challenge icon
		var icon = challenge_ui.get_challenge_icon(id) as ChallengeIcon
		if icon:
			icon.set_active(true)

			# Reset after a short delay
			await get_tree().create_timer(0.5).timeout
			icon.set_active(false)
	else:
		push_error("[GameController] Challenge not found:", id)

# Add this method to handle the dice_rolled signal from GameButtonUI
func _on_game_button_dice_rolled(dice_values: Array) -> void:
	print("[GameController] Dice roll button pressed, values:", dice_values)
	
	# Track roll statistics
	RollStats.track_roll()
	var stats = get_node_or_null("/root/Statistics")
	if stats:
		stats.increment_rolls()
	
	# Track individual dice values and colors if available
	if dice_hand and stats:
		for i in range(dice_values.size()):
			if i < dice_hand.dice_list.size():
				var die = dice_hand.dice_list[i]
				var color = "white"  # Default color
				if die.has_method("get_color"):
					var color_type = die.get_color()
					color = DiceColor.get_color_name(color_type)
				stats.track_dice_roll(color, dice_values[i])
	
	# Check for snake eyes (all ones)
	if stats:
		stats.check_snake_eyes(dice_values)
	
	# Check if we can afford to roll (for costly_roll debuff)
	if is_debuff_active("costly_roll"):
		var cost = active_debuffs["costly_roll"].roll_cost
		PlayerEconomy.remove_money(cost, "debuff")
		print("[GameController] Paid", cost, "coins to roll dice")
	
	# Increment chores progress on each roll
	if chores_manager:
		chores_manager.increment_progress(1)
	
	# Update PowerUps that depend on dice values
	_update_power_ups_for_dice(dice_values)

# Add this new method to game_controller.gd
func _update_power_ups_for_dice(dice_values: Array) -> void:
	print("[GameController] Updating PowerUps for dice values:", dice_values)
	
	# Update FoursomePowerUp if active
	if active_power_ups.has("foursome"):
		var foursome_pu = active_power_ups["foursome"] as FoursomePowerUp
		if foursome_pu and foursome_pu.has_method("update_multiplier_for_dice"):
			foursome_pu.update_multiplier_for_dice(dice_values)
	
	# Add other dice-dependent PowerUps here as needed
	

# Add these methods to handle the missing signal connections

func _on_round_completed(round_number: int) -> void:
	print("[GameController] Round", round_number, "completed successfully")
	
	# Award round completion bonus
	if round_manager:
		var round_data = round_manager.get_current_round_data()
		if round_data and round_data.has("reward_money") and round_data.reward_money > 0:
			PlayerEconomy.add_money(round_data.reward_money)
			print("[GameController] Awarded", round_data.reward_money, "coins for completing round", round_number)

func _on_round_failed(round_number: int) -> void:
	print("[GameController] Round", round_number, "failed")
	
	# Handle round failure - maybe apply a penalty or give a smaller consolation reward
	# You could also add UI feedback for the player here

func _on_all_rounds_completed() -> void:
	print("[GameController] All rounds completed! Game win condition reached.")
	
	# Show the RoundWinnerPanel with stats
	if round_winner_panel and round_manager:
		var current_channel = 1
		if channel_manager:
			current_channel = channel_manager.current_channel
		
		var final_score = 0
		var target_score = 0
		if scorecard:
			final_score = scorecard.get_total_score()
		if round_manager:
			target_score = round_manager.get_current_challenge_target_score()
		
		var turns_used = 0
		if turn_tracker:
			turns_used = turn_tracker.current_turn
		
		var winner_data = {
			"final_score": final_score,
			"target_score": target_score,
			"turns_used": turns_used,
			"current_channel": current_channel,
			"rounds_completed": 6
		}
		
		round_winner_panel.show_winner_panel(winner_data)
		print("[GameController] Showing RoundWinnerPanel for Channel", current_channel)
	else:
		print("[GameController] No RoundWinnerPanel - game complete!")

func _on_consumable_sold(consumable_id: String) -> void:
	print("[GameController] Selling consumable:", consumable_id)
	
	var consumable = active_consumables.get(consumable_id)
	if not consumable:
		push_error("[GameController] No Consumable found for id:", consumable_id)
		return
		
	var def = consumable_manager.get_def(consumable_id)
	if def:
		var refund = def.price / 2.0  # Half price
		print("[GameController] Refunding", refund, "coins for consumable:", consumable_id)
		PlayerEconomy.add_money(refund)
	
	# Remove from UI
	if corkboard_ui:
		corkboard_ui.remove_consumable(consumable_id)
	elif consumable_ui:
		consumable_ui.remove_consumable(consumable_id)
	
	# Remove from game data
	if active_consumables.has(consumable_id):
		var consumable_to_remove = active_consumables[consumable_id]
		if consumable_to_remove:
			consumable_to_remove.queue_free()
		active_consumables.erase(consumable_id)
		print("[GameController] Removed consumable from game data:", consumable_id)

## _on_mod_sold(mod_id, dice)
##
## Handles selling a mod. Gives a partial refund (half price) and removes the mod
## from the dice, active_mods dictionary, and mod_persistence_map.
func _on_mod_sold(mod_id: String, dice: Dice) -> void:
	print("[GameController] MOD SELLING INITIATED:", mod_id, "from dice:", dice.name)
	
	# Get the mod definition for price calculation
	var def: ModData = mod_manager.get_def(mod_id)
	if def:
		var refund = def.price / 2.0  # Half price
		print("[GameController] Refunding", refund, "coins for mod:", mod_id)
		PlayerEconomy.add_money(refund)
	
	# Remove the mod from the dice
	dice.remove_mod(mod_id)
	
	# Remove from active mods
	if active_mods.has(mod_id):
		active_mods.erase(mod_id)
	
	# Decrease the persistence count or remove completely
	if mod_persistence_map.has(mod_id):
		mod_persistence_map[mod_id] -= 1
		if mod_persistence_map[mod_id] <= 0:
			mod_persistence_map.erase(mod_id)
		print("[GameController] Updated mod persistence map:", mod_persistence_map)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F10:
			_toggle_statistics_panel()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check for outside clicks to hide mod sell buttons
		if dice_hand:
			for die in dice_hand.dice_list:
				die.check_mod_outside_clicks(event.global_position)

## _toggle_statistics_panel()
## 
## Toggle the visibility of the statistics panel.
func _toggle_statistics_panel():
	if statistics_panel:
		statistics_panel.toggle_visibility()
	else:
		print("[GameController] ERROR: No StatisticsPanel reference found!")
		# Try to find it manually
		var manual_panel = get_node_or_null("../StatisticsPanel")
		if manual_panel:
			print("[GameController] Found StatisticsPanel manually at ../StatisticsPanel")
			statistics_panel = manual_panel
			statistics_panel.toggle_visibility()
		else:
			print("[GameController] Could not find StatisticsPanel anywhere")

func _on_max_power_ups_reached() -> void:
	print("[GameController] Maximum number of power-ups reached")
	
	# Show feedback to the player that they can't add more power-ups
	# For example, you could show a notification or play a sound

func _on_round_started(round_number: int) -> void:
	print("[GameController] Round", round_number, "started")
	
	# Reset end of round stats flag for new round
	_end_of_round_stats_shown = false
	
	# Update round-based scaling for scorecard and chores manager
	if scorecard:
		scorecard.update_round(round_number)
		print("[GameController] Scorecard round updated to", round_number)
	
	if chores_manager:
		chores_manager.update_round(round_number)
		print("[GameController] Chores manager round updated to", round_number)
	
	# Enable CRT for active gameplay
	if crt_manager:
		crt_manager.enable_crt()
	
	# Reset scorecard state for new round - ensure buttons are unlocked
	if score_card_ui:
		score_card_ui.turn_scored = false
		score_card_ui.enable_all_score_buttons()
		# Refresh UI to show updated scaling values
		score_card_ui.update_all()
		print("[GameController] Scorecard unlocked for new round")
	
	update_three_more_rolls_usability()
	update_double_existing_usability()
	
	# Clear grounded debuffs from previous round (NC-17 consequences)
	_clear_grounded_debuffs()
	
	# Activate this round's challenge
	print("[GameController] Checking for challenge activation...")
	print("[GameController] round_manager:", round_manager)
	if round_manager:
		var round_data = round_manager.get_current_round_data()
		print("[GameController] round_data:", round_data)
		print("[GameController] round_data has challenge_id:", round_data.has("challenge_id"))
		if round_data.has("challenge_id"):
			print("[GameController] challenge_id value:", round_data.challenge_id)
			print("[GameController] challenge_id is_empty:", round_data.challenge_id.is_empty())
		if round_data.has("challenge_id") and not round_data.challenge_id.is_empty():
			activate_challenge(round_data.challenge_id)
			print("[GameController] Activated challenge:", round_data.challenge_id)
		else:
			push_warning("[GameController] No challenge_id in round_data!")
	else:
		push_error("[GameController] round_manager is null!")
	
	# Reset shop for new round
	if shop_ui:
		shop_ui.reset_for_new_round()
		print("[GameController] Shop reset for new round")

func _on_debuff_selected(id: String) -> void:
	print("[GameController] Debuff selected:", id)
	
	var debuff = active_debuffs.get(id)
	if debuff:
		# Provide visual feedback about the debuff
		var icon = debuff_ui.get_debuff_icon(id)
		if icon:
			# Highlight the debuff icon temporarily
			icon.set_active(true)
			
			# Show a brief description or effect of the debuff
			var def = debuff_manager.get_def(id)
			if def:
				print("[GameController] Debuff effect:", def.description)
				
			# Reset after a short delay
			await get_tree().create_timer(0.5).timeout
			# Only reset if still active (might have been removed)
			if is_debuff_active(id):
				icon.set_active(false)
	else:
		push_error("[GameController] Debuff not found:", id)

# In game_controller.gd - Update the update_three_more_rolls_usability function

## update_three_more_rolls_usability(_rolls_left)
##
# Called when rolls remaining changes—the parameter is unused currently but kept for signal
# compatibility. Updates the three_more_rolls consumable usability state in the UI.
func update_three_more_rolls_usability(_rolls_left: int = 0) -> void:
	if consumable_ui and consumable_ui.has_consumable("three_more_rolls"):
		consumable_ui.update_consumable_usability()
		print("[GameController] Three more rolls usability updated")
	else:
		print("[GameController] No three more rolls consumable found")

# Add this function to game_controller.gd

## update_double_existing_usability(_section, _category, _score, _breakdown_info)
##
# Triggered after score assignment or roll changes. Parameters mirror the ScoreCard signal but
# are unused here. Refreshes `double_existing` consumable usability in the UI.
func update_double_existing_usability(_section: int = 0, _category: String = "", _score: int = 0, _breakdown_info: Dictionary = {}) -> void:
	if consumable_ui and consumable_ui.has_consumable("double_existing"):
		consumable_ui.update_consumable_usability()
		print("[GameController] Double existing usability updated")
	else:
		print("[GameController] No double existing consumable found")

## update_double_or_nothing_usability(_rolls_left)
##
# Called when rolls remaining changes. Updates the double_or_nothing consumable usability 
# state in the UI. Can be used after the turn starts (auto-roll) but before manual rolls (when rolls_left >= MAX_ROLLS - 1).
func update_double_or_nothing_usability(_rolls_left: int = 0) -> void:
	if consumable_ui and consumable_ui.has_consumable("double_or_nothing"):
		consumable_ui.update_consumable_usability()
		print("[GameController] Double or nothing usability updated")
	else:
		print("[GameController] No double or nothing consumable found")

func _on_power_up_description_updated(power_up_id: String, new_description: String) -> void:
	print("[GameController] Received description update for:", power_up_id)
	print("[GameController] New description:", new_description)
	
	if powerup_ui:
		var icon = powerup_ui.get_power_up_icon(power_up_id)
		if icon and icon.hover_label:
			icon.hover_label.text = new_description
			print("[GameController] Updated hover label text for power-up icon")

func _on_randomizer_effect_updated(effect_type: String, value_text: String) -> void:
	print("[GameController] Randomizer effect updated - Type:", effect_type, "Value:", value_text)
	
	# Update the ExtraInfo display in score_card_ui
	if score_card_ui:
		var effect_description = "Random Effect: %s %s" % [effect_type.capitalize(), value_text]
		score_card_ui.update_extra_info(effect_description)
		print("[GameController] Updated ExtraInfo with randomizer effect")

## _on_items_unlocked(item_ids)
##
## Signal handler for when items are unlocked by the ProgressManager.
## Shows unlock notifications to the player.
func _on_items_unlocked(item_ids: Array[String]) -> void:
	print("[GameController] Items unlocked: %v" % [item_ids])
	
	# Find the unlock notification UI
	var unlock_ui = get_tree().get_first_node_in_group("unlock_notification_ui")
	if unlock_ui and unlock_ui.has_method("show_unlock_notifications"):
		unlock_ui.show_unlock_notifications(item_ids)
	else:
		print("[GameController] UnlockNotificationUI not found or missing method")

# Add this helper method to retrieve active power-ups
func get_active_power_up(id: String) -> PowerUp:
	if active_power_ups.has(id):
		return active_power_ups[id]
	return null

## _on_mom_triggered()
##
## Handler for when chores progress reaches 100 and Mom appears.
## Checks for R and NC-17 rated PowerUps and applies consequences.
## Also checks if player completed any chores (0 = $100 fine or debuff).
## Mom's mood affects rewards (mood 1) or enhanced punishments (mood 10).
func _on_mom_triggered() -> void:
	print("[GameController] Mom triggered!")
	
	# Get chores completed count and Mom's mood from ChoresManager
	var chores_completed_count = 0
	var mom_mood = 5  # Default neutral
	if chores_manager:
		chores_completed_count = chores_manager.tasks_completed
		mom_mood = chores_manager.mom_mood
		print("[GameController] Chores completed this cycle: %d" % chores_completed_count)
		print("[GameController] Mom's mood: %d/10" % mom_mood)
	
	# Check for special mood-based rewards/punishments
	if mom_mood == 1:
		# Mom is very happy - grant rewards!
		print("[GameController] Mom is VERY HAPPY! Granting rewards!")
		_grant_mom_reward()
	elif mom_mood >= 10:
		# Mom is furious - enhanced punishments
		print("[GameController] Mom is FURIOUS! Enhanced punishments!")
		_apply_enhanced_mom_punishment()
	
	# Perform the standard Mom check with chores info and active debuffs
	var result = MomLogicHandlerScript.trigger_mom_check(self, chores_completed_count, active_debuffs)
	
	# Show Mom dialog
	_show_mom_dialog(result)


## _grant_mom_reward()
##
## Grants a random reward when Mom's mood reaches 1 (very happy).
## Possible rewards: money ($50-150), consumable, or power-up.
func _grant_mom_reward() -> void:
	var reward_type = randi() % 3
	match reward_type:
		0:
			# Grant money (allowance)
			var amount = randi_range(50, 150)
			PlayerEconomy.add_money(amount)
			print("[GameController] Mom gave allowance: $%d" % amount)
		1:
			# Grant random consumable
			var consumable_ids = ["random_power_up_uncommon", "green_envy", "the_rarities"]
			var random_id = consumable_ids[randi() % consumable_ids.size()]
			grant_consumable(random_id)
			print("[GameController] Mom gave consumable: %s" % random_id)
		2:
			# Grant random power-up (from a safe list)
			var powerup_ids = ["extra_rolls", "bonus_money", "full_house_bonus"]
			var random_id = powerup_ids[randi() % powerup_ids.size()]
			if not active_power_ups.has(random_id):
				grant_power_up(random_id)
				print("[GameController] Mom gave power-up: %s" % random_id)
			else:
				# Fallback to money if already have the power-up
				var amount = randi_range(75, 125)
				PlayerEconomy.add_money(amount)
				print("[GameController] Mom gave allowance instead: $%d" % amount)


## _apply_enhanced_mom_punishment()
##
## Applies enhanced punishment when Mom's mood reaches 10 (furious).
## Multiple debuffs and higher fines.
func _apply_enhanced_mom_punishment() -> void:
	# Apply 2-3 random debuffs
	var debuff_ids = ["lock_dice", "costly_roll", "disabled_twos", "the_division"]
	var num_debuffs = randi_range(2, 3)
	var applied_debuffs: Array[String] = []
	
	for i in range(num_debuffs):
		var random_id = debuff_ids[randi() % debuff_ids.size()]
		if random_id not in applied_debuffs and not active_debuffs.has(random_id):
			apply_debuff(random_id)
			applied_debuffs.append(random_id)
			_grounded_debuffs.append(random_id)
			print("[GameController] Mom applied debuff: %s" % random_id)
	
	# Higher fine ($200-300)
	var fine = randi_range(200, 300)
	PlayerEconomy.subtract_money(fine)
	print("[GameController] Mom imposed fine: $%d" % fine)

## _show_mom_dialog(result)
##
## Shows the Mom dialog popup with appropriate expression and text.
## Waits for dialog to close before applying consequences.
func _show_mom_dialog(result) -> void:
	# Create Mom dialog if needed
	if _mom_dialog == null:
		var mom_scene = preload("res://Scenes/UI/mom_dialog_popup.tscn")
		_mom_dialog = mom_scene.instantiate()
		add_child(_mom_dialog)
	
	# Show dialog with result
	await _mom_dialog.show_dialog(result.expression, result.dialog_text)
	
	# Wait for dialog to close
	await _mom_dialog.dialog_closed
	
	# Apply consequences after dialog closes
	MomLogicHandlerScript.apply_consequences(self, result)
	
	# Track grounded debuffs (NC-17) for removal at round end
	for debuff_id in result.applied_debuffs:
		if debuff_id not in _grounded_debuffs:
			_grounded_debuffs.append(debuff_id)
	
	# Reset chores progress
	if chores_manager:
		chores_manager.reset_progress()

## check_chore_task_completion(context)
##
## Called after scoring to check if the current chore task was completed.
## The context dictionary should contain scoring information.
func check_chore_task_completion(context: Dictionary) -> void:
	if chores_manager:
		chores_manager.check_task_completion(context)

## _count_locked_dice()
##
## Helper to count how many dice are currently locked.
## Returns: int - number of locked dice
func _count_locked_dice() -> int:
	if not dice_hand:
		return 0
	var count = 0
	for die in dice_hand.dice_list:
		if die is Dice and die.is_locked:
			count += 1
	return count

## _clear_grounded_debuffs()
##
## Removes all debuffs that were applied by Mom (NC-17 consequences).
## Called at the start of a new round.
func _clear_grounded_debuffs() -> void:
	print("[GameController] Clearing grounded debuffs: %s" % [_grounded_debuffs])
	for debuff_id in _grounded_debuffs:
		disable_debuff(debuff_id)
	_grounded_debuffs.clear()
