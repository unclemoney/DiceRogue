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
const RANDOM_POWER_UP_UNCOMMON_CONSUMABLE_DEF := preload("res://Scripts/Consumable/RandomPowerUpUncommonConsumable.tres")
const GREEN_ENVY_CONSUMABLE_DEF := preload("res://Scripts/Consumable/GreenEnvyConsumable.tres")

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

const STARTING_POWER_UP_IDS := ["extra_dice", "extra_rolls"]

var _last_modded_die_index: int = -1  # Track which die received the last mod

var pending_mods: Array[String] = []
var mod_persistence_map: Dictionary = {}  # mod_id -> int tracking how many instances of each mod should persist
var _shop_tween: Tween


func _ready() -> void:
	add_to_group("game_controller")
	print("▶ GameController._ready()")
	var debug_panel = preload("res://Scenes/UI/DebugPanel.tscn").instantiate()
	add_child(debug_panel)
	# Reference the private index variable to avoid an 'unused variable' lint warning
	# This value is reserved for future mod-application tracking.
	_last_modded_die_index = _last_modded_die_index
	if dice_hand:
		dice_hand.roll_complete.connect(_on_roll_completed)
		dice_hand.dice_spawned.connect(_on_dice_spawned)
	if scorecard:
		scorecard.score_auto_assigned.connect(_on_score_assigned)
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
		if not consumable_ui.is_connected("consumable_used", _on_consumable_used):
			consumable_ui.consumable_used.connect(_on_consumable_used)
			print("[GameController] Connected to consumable_used signal from ConsumableUI")
	if powerup_ui:
		if not powerup_ui.is_connected("max_power_ups_reached", _on_max_power_ups_reached):
			powerup_ui.connect("max_power_ups_reached", _on_max_power_ups_reached)
	if challenge_ui:
		if not challenge_ui.is_connected("challenge_selected", _on_challenge_selected):
			challenge_ui.challenge_selected.connect(_on_challenge_selected)
	if debuff_ui:
		if not debuff_ui.is_connected("debuff_selected", _on_debuff_selected):
			debuff_ui.debuff_selected.connect(_on_debuff_selected)
	if turn_tracker:
		turn_tracker.rolls_updated.connect(update_three_more_rolls_usability)
		turn_tracker.turn_started.connect(update_three_more_rolls_usability)
		turn_tracker.rolls_exhausted.connect(update_three_more_rolls_usability)
		turn_tracker.turn_started.connect(update_double_existing_usability)
		turn_tracker.rolls_exhausted.connect(update_double_existing_usability)

	# Register new consumables programmatically
	if consumable_manager:
		consumable_manager.register_consumable_def(RANDOM_POWER_UP_UNCOMMON_CONSUMABLE_DEF)
		consumable_manager.register_consumable_def(GREEN_ENVY_CONSUMABLE_DEF)

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
	#grant_consumable("power_up_shop_num")
	#apply_debuff("the_division")
	#activate_challenge("300pts_no_debuff")
	grant_power_up("perfect_strangers")
	if round_manager:
		round_manager.start_game()




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
	if power_up_id == "upper_bonus_mult" or power_up_id == "consumable_cash" or power_up_id == "evens_no_odds" or power_up_id == "bonus_money" or power_up_id == "money_multiplier" or power_up_id == "full_house_bonus" or power_up_id == "step_by_step" or power_up_id == "perfect_strangers":
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
			enable_debuff("lock_dice")
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
		"full_house_bonus":
			print("[GameController] Removing full_house_bonus PowerUp")
			pu.remove(self)
		"step_by_step":
			print("[GameController] Removing step_by_step PowerUp")
			pu.remove(scorecard)
		"perfect_strangers":
			print("[GameController] Removing perfect_strangers PowerUp")
			pu.remove(scorecard)
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
		if consumable_ui:
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

	var spine = consumable_ui.add_consumable(def)  # Returns ConsumableSpine now
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
	if not consumable_ui:
		return

	# This replaces the individual set_useable calls in grant_consumable
	# It will be called when consumables are fanned out
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
		
	# Helper function to handle consumable removal with count system
	var remove_consumable_instance = func():
		var current_count = consumable_counts.get(consumable_id, 1)
		if current_count > 1:
			# Decrement count
			consumable_counts[consumable_id] = current_count - 1
			if consumable_ui:
				consumable_ui.update_consumable_count(consumable_id, consumable_counts[consumable_id])
			print("[GameController] Decremented %s count to %d" % [consumable_id, consumable_counts[consumable_id]])
		else:
			# Remove entirely
			active_consumables.erase(consumable_id)
			consumable_counts.erase(consumable_id)
			if consumable_ui:
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
		_:
			push_error("Unknown consumable type: %s" % consumable_id)


## _on_consumable_ui_used(consumable_id)
##
## Forwarding handler triggered by the UI when a consumable is used. Emits a GameController-level
## signal and then invokes the internal consumable handler.
func _on_consumable_ui_used(consumable_id: String) -> void:
	# Forward consumable_used signal for PowerUps to listen
	var consumable = active_consumables.get(consumable_id)
	emit_signal("consumable_used", consumable_id, consumable)
	# Optionally call the original handler if needed
	_on_consumable_used(consumable_id)


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


## _on_score_assigned(_section, _category, _score)
##
## Triggered when the ScoreCard auto-assigns or registers a score.
## - Triggers any post-score power-up behavior (randomizer effect)
## - Updates consumable usability for score-related consumables (e.g., score_reroll)
func _on_score_assigned(_section: int, _category: String, _score: int) -> void:
	if not scorecard:
		push_error("No scorecard reference found")
		return

	# Show randomizer effect after scoring
	if active_power_ups.has("randomizer"):
		var randomizer = active_power_ups["randomizer"] as RandomizerPowerUp
		if randomizer and randomizer.has_method("show_effect_after_scoring"):
			randomizer.show_effect_after_scoring()

	if scorecard.has_any_scores():
		# Update score reroll usability through the new system
		if consumable_ui and consumable_ui.has_consumable("score_reroll"):
			consumable_ui.update_consumable_usability()
			print("[GameController] Score reroll usability updated")
		else:
			print("[GameController] No score reroll consumable found")
	else:
		print("[GameController] No scores yet, reroll remains disabled")


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
	var icon = debuff_ui.add_debuff(def, debuff)
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
			if debuff_ui:
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
			if mod:
				die.add_mod(active_mods[mod_id])
				print("[GameController] Applied mod", mod_id, "to empty die at index", i)
				return true

	# If no empty die found, try to find one without this specific mod
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		if not die.has_mod(mod_id):
			var mod = mod_manager.spawn_mod(mod_id, die)
			if mod:
				die.add_mod(active_mods[mod_id])
				print("[GameController] Applied mod", mod_id, "to die at index", i)
				return true

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


## _on_roll_completed()
##
## Called when a dice roll completes. Applies any 'lock_dice' debuff effect, otherwise ensures all dice
## are enabled for player interaction.
func _on_roll_completed() -> void:
	if is_debuff_active("lock_dice"):
		var debuff = active_debuffs["lock_dice"]
		if debuff and dice_hand:
			debuff.apply(dice_hand)
	else:
		if dice_hand:
			dice_hand.enable_all_dice()


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


## _on_shop_button_pressed()
##
# Toggles the shop UI with an animated tween and temporarily disables the CRT effect while the shop
# is visible. Uses `get_tree().create_tween()` for animation sequencing.
func _on_shop_button_pressed() -> void:
	if shop_ui:
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

	# Apply to game controller to access all needed systems
	challenge.target = self
	challenge.start()

	# Add to UI with properly connected signals
	if challenge_ui:
		var icon = challenge_ui.add_challenge(def, challenge)
		if icon:
			# Set up any additional properties if needed
			print("[GameController] Challenge UI created for:", id)
		else:
			push_error("[GameController] Failed to create UI for challenge:", id)
	else:
		push_error("[GameController] No challenge_ui reference")


## _on_challenge_completed(id)
##
# Handles the successful completion of a challenge: awards any rewards, animates UI removal,
# and frees the challenge instance.
func _on_challenge_completed(id: String) -> void:
	print("[GameController] Challenge completed:", id)

	# Grant reward if specified
	var def = challenge_manager.get_def(id)
	if def and def.reward_money > 0:
		print("[GameController] Granting reward:", def.reward_money)
		PlayerEconomy.add_money(def.reward_money)

	# Animate challenge completion before removing
	if challenge_ui:
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
	if challenge_ui:
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
	
	# Check if we can afford to roll (for costly_roll debuff)
	if is_debuff_active("costly_roll"):
		var cost = active_debuffs["costly_roll"].roll_cost
		PlayerEconomy.remove_money(cost)
		print("[GameController] Paid", cost, "coins to roll dice")
	
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
	
	# Handle game completion
	# This could trigger an end game screen, final rewards, etc.

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
	
	# Animate the icon if it exists, then remove
	if consumable_ui:
		consumable_ui.animate_consumable_removal(consumable_id, func():
			remove_consumable(consumable_id)
		)
	else:
		remove_consumable(consumable_id)

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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check for outside clicks to hide mod sell buttons
		if dice_hand:
			for die in dice_hand.dice_list:
				die.check_mod_outside_clicks(event.global_position)

func _on_max_power_ups_reached() -> void:
	print("[GameController] Maximum number of power-ups reached")
	
	# Show feedback to the player that they can't add more power-ups
	# For example, you could show a notification or play a sound

func _on_round_started(round_number: int) -> void:
	print("[GameController] Round", round_number, "started")
	
	# Enable CRT for active gameplay
	if crt_manager:
		crt_manager.enable_crt()
	
	update_three_more_rolls_usability()
	update_double_existing_usability()
	
	# Activate this round's challenge
	if round_manager:
		var round_data = round_manager.get_current_round_data()
		if not round_data.challenge_id.is_empty():
			activate_challenge(round_data.challenge_id)
			print("[GameController] Activated challenge:", round_data.challenge_id)
	
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

## update_double_existing_usability(_section, _category, _score)
##
# Triggered after score assignment or roll changes. Parameters mirror the ScoreCard signal but
# are unused here. Refreshes `double_existing` consumable usability in the UI.
func update_double_existing_usability(_section: int = 0, _category: String = "", _score: int = 0) -> void:
	if consumable_ui and consumable_ui.has_consumable("double_existing"):
		consumable_ui.update_consumable_usability()
		print("[GameController] Double existing usability updated")
	else:
		print("[GameController] No double existing consumable found")

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
	else:
		push_error("[GameController] score_card_ui not found for randomizer effect update")
			
			# If currently hovering, ensure label is visible

# Add this helper method to retrieve active power-ups
func get_active_power_up(id: String) -> PowerUp:
	if active_power_ups.has(id):
		return active_power_ups[id]
	return null
