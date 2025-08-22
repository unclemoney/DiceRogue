# GameController.gd
extends Node

signal power_up_granted(id: String, power_up: PowerUp)
signal power_up_revoked(id: String)
signal consumable_used(id: String, consumable: Consumable)

# Active power-ups and consumables in the game dictionaries
var active_power_ups: Dictionary = {}  # id -> PowerUp
var active_consumables: Dictionary = {}  # id -> Consumable

# Centralized, explicit NodePaths (tweak in Inspector if scene changes)
@export var dice_hand_path: NodePath          = ^"../DiceHand"
@export var turn_tracker_path: NodePath       = ^"../TurnTracker"
@export var power_up_manager_path: NodePath   = ^"../PowerUpManager"
@export var power_up_ui_path: NodePath        = ^"../PowerUpUI"
@export var power_up_container_path: NodePath = ^"PowerUpContainer"
@export var consumable_manager_path: NodePath = ^"../ConsumableManager"
@export var consumable_ui_path: NodePath      = ^"../ConsumableUI"
@export var consumable_container_path: NodePath = ^"ConsumableContainer"
@export var score_card_ui_path: NodePath = ^"../ScoreCardUI"

@onready var consumable_manager: ConsumableManager = get_node(consumable_manager_path)
@onready var consumable_ui: ConsumableUI = get_node(consumable_ui_path)
@onready var consumable_container: Node  = get_node(consumable_container_path)
@onready var dice_hand: DiceHand         = get_node(dice_hand_path) as DiceHand
@onready var turn_tracker: TurnTracker   = get_node(turn_tracker_path) as TurnTracker
@onready var pu_manager: PowerUpManager  = get_node(power_up_manager_path) as PowerUpManager
@onready var powerup_ui: PowerUpUI       = get_node(power_up_ui_path) as PowerUpUI
@onready var power_up_container: Node    = get_node(power_up_container_path)
@onready var score_card_ui = get_node(score_card_ui_path)

const STARTING_POWER_UP_IDS := ["extra_dice", "extra_rolls"]

func _ready() -> void:
	print("▶ GameController._ready()")
	call_deferred("_on_game_start")

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

func _on_game_start() -> void:
	spawn_starting_powerups()
	grant_consumable("score_reroll")

func grant_power_up(id: String) -> void:
	# 1) Spawn logic via scene manager
	var pu := pu_manager.spawn_power_up(id, power_up_container) as PowerUp
	if pu == null:
		push_error("Failed to spawn PowerUp '%s'" % id)
		return

	pu.apply(self)
	active_power_ups[id] = pu
	emit_signal("power_up_granted", id, pu)

	# 2) Show in UI
	var def: PowerUpData = pu_manager.get_def(id)
	if def:
		powerup_ui.add_power_up(def)

func revoke_power_up(power_up_id: String) -> void:
	if not active_power_ups.has(power_up_id):
		return

	var pu := active_power_ups[power_up_id] as PowerUp
	if pu:
		pu.remove(self)
		pu.queue_free()
	active_power_ups.erase(power_up_id)
	emit_signal("power_up_revoked", power_up_id)

func _on_power_up_selected(power_up_id: String) -> void:
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("No PowerUp found for id: %s" % power_up_id)
		return
		
	match power_up_id:
		"extra_dice":
			pu.apply(dice_hand)
		"extra_rolls":
			pu.apply(turn_tracker)
		_:
			push_error("Unknown target for power-up: %s" % power_up_id)

func _on_power_up_deselected(power_up_id: String) -> void:
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("No PowerUp found for id: %s" % power_up_id)
		return
		
	match power_up_id:
		"extra_dice":
			pu.remove(dice_hand)
		"extra_rolls":
			pu.remove(turn_tracker)
		_:
			push_error("Unknown target for power-up: %s" % power_up_id)

func grant_consumable(id: String) -> void:
	print("Granting consumable:", id)
	
	var consumable := consumable_manager.spawn_consumable(id, consumable_container) as Consumable
	if consumable == null:
		push_error("Failed to spawn Consumable '%s'" % id)
		return

	active_consumables[id] = consumable
	
	# Add to UI with null checks
	var def: ConsumableData = consumable_manager.get_def(id)
	if not def:
		push_error("No ConsumableData found for '%s'" % id)
		return
		
	var icon = consumable_ui.add_consumable(def, consumable)  # Pass the consumable instance
	if not icon:
		push_error("Failed to create UI icon for consumable '%s'" % id)
		return

	icon.consumable_used.connect(_on_consumable_used)

func _on_consumable_used(consumable_id: String) -> void:
	var consumable = active_consumables.get(consumable_id)
	if not consumable:
		push_error("No Consumable found for id: %s" % consumable_id)
		return
		
	match consumable_id:
		"score_reroll":
			if score_card_ui:
				# Activate reroll mode
				consumable.apply(self)
				score_card_ui.activate_score_reroll()
				# Connect to score_rerolled signal for cleanup
				if not score_card_ui.is_connected("score_rerolled", _on_score_rerolled):
					score_card_ui.connect("score_rerolled", _on_score_rerolled)
			else:
				push_error("GameController: score_card_ui not found!")
		_:
			push_error("Unknown consumable type: %s" % consumable_id)

func _on_score_rerolled(_section, _category, _score) -> void:
	print("GameController: Score rerolled, cleaning up consumable")
	var consumable = active_consumables.get("score_reroll")
	if consumable:
		consumable.complete_reroll()
		consumable.consume()
		active_consumables.erase("score_reroll")
		emit_signal("consumable_used", "score_reroll", consumable)
	else:
		push_error("No active score_reroll consumable found!")
