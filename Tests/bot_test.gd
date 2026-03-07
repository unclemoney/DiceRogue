extends Node2D

## bot_test.gd
##
## Scene script for the BotTest scene.
## Wires the BotController to all game nodes and starts automated play-testing.

# Preloads for LSP scope resolution
const BotControllerScript := preload("res://Scripts/Bot/bot_controller.gd")
const BotConfigScript := preload("res://Scripts/Bot/BotConfig.gd")

@onready var dice_hand: DiceHand = $DiceHand
@onready var score_card: Scorecard = $ScoreCard
@onready var score_card_ui: Control = $ScoreCardUI
@onready var turn_tracker: TurnTracker = $TurnTracker
@onready var game_button_ui: Control = $GameButtonUI
@onready var game_controller: GameController = $GameController
@onready var round_manager: RoundManager = $RoundManager
@onready var channel_manager = $ChannelManager
@onready var shop_ui: Control = $ShopUI
@onready var chores_manager = $ChoresManager
@onready var consumable_ui: ConsumableUI = $ConsumableUI
@onready var consumable_manager: ConsumableManager = $ConsumableManager
@onready var mod_manager: ModManager = $ModManager
@onready var debuff_manager: DebuffManager = $DebuffManager
@onready var challenge_manager: ChallengeManager = $ChallengeManager
@onready var bot_controller: BotController = $BotController
@onready var bot_results_panel: Control = $BotResultsPanel

# Exported config resource — assign in Inspector or via default
@export var bot_config: BotConfig


func _ready() -> void:
	# Bind scorecard UI
	score_card_ui.bind_scorecard(score_card)

	# Bind VCR tracker if present
	var vcr_ui = get_node_or_null("VCRTurnTrackerUI")
	if vcr_ui and turn_tracker:
		vcr_ui.bind_tracker(turn_tracker)

	# Wire bot controller to game nodes
	bot_controller.dice_hand = dice_hand
	bot_controller.score_card = score_card
	bot_controller.score_card_ui = score_card_ui
	bot_controller.turn_tracker = turn_tracker
	bot_controller.game_button_ui = game_button_ui
	bot_controller.game_controller = game_controller
	bot_controller.round_manager = round_manager
	bot_controller.channel_manager = channel_manager
	bot_controller.shop_ui = shop_ui
	bot_controller.chores_manager = chores_manager
	bot_controller.consumable_ui = consumable_ui
	bot_controller.consumable_manager = consumable_manager
	bot_controller.mod_manager = mod_manager
	bot_controller.round_winner_panel = get_node_or_null("RoundWinnerPanel")
	bot_controller.bot_results_panel = bot_results_panel

	# Connect bot signals to results panel
	if bot_results_panel:
		bot_controller.bot_status_changed.connect(bot_results_panel._on_status_changed)
		bot_controller.bot_all_runs_completed.connect(bot_results_panel._on_runs_completed)

	# Use provided config or create default
	if not bot_config:
		bot_config = BotConfigScript.new()

	print("[BotTest] Scene ready — starting bot after scene tree settles")

	# IMPORTANT: Override GameController's normal _on_game_start so we control the flow
	# GameController calls _on_game_start via call_deferred in its _ready, which would
	# show the channel selector. We need to intercept that flow.
	# The bot_controller.start() is deferred to run AFTER game_controller._on_game_start
	await get_tree().create_timer(0.3).timeout

	# Hide channel selector if it appeared
	var channel_ui = get_node_or_null("ChannelManagerUI")
	if channel_ui and channel_ui.has_method("hide"):
		channel_ui.hide()

	# Start the bot
	bot_controller.start(bot_config)
