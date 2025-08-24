# GameController.gd
extends Node
class_name GameController

signal power_up_granted(id: String, power_up: PowerUp)
signal power_up_revoked(id: String)
signal consumable_used(id: String, consumable: Consumable)

# Active power-ups and consumables in the game dictionaries
var active_power_ups: Dictionary = {}  # id -> PowerUp
var active_consumables: Dictionary = {}  # id -> Consumable
var active_debuffs: Dictionary = {}  # id -> Debuff

const ScoreCardUI := preload("res://Scripts/UI/score_card_ui.gd")
const DebuffManager := preload("res://Scripts/Managers/DebuffManager.gd")
const DebuffUI := preload("res://Scripts/UI/debuff_ui.gd")
const ScoreCard := preload("res://Scenes/ScoreCard/score_card.gd")

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
@export var mod_manager_path: NodePath = ^"../ModManager"

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
@onready var scorecard: ScoreCard 		   = get_node(score_card_path) as ScoreCard
@onready var mod_manager: ModManager = get_node(mod_manager_path) as ModManager

const STARTING_POWER_UP_IDS := ["extra_dice", "extra_rolls"]

func _ready() -> void:
	print("▶ GameController._ready()")
	if dice_hand:
		dice_hand.roll_complete.connect(_on_roll_completed)
		dice_hand.dice_spawned.connect(_on_dice_spawned)
	if scorecard:
		scorecard.score_auto_assigned.connect(_on_score_assigned)
	call_deferred("_on_game_start")

func _on_game_start() -> void:
	spawn_starting_powerups()
	grant_consumable("score_reroll")
	#apply_debuff("lock_dice")

func _process(delta):
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()


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
			enable_debuff("lock_dice")
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
			disable_debuff("lock_dice")
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

func _on_score_rerolled(_section: Scorecard.Section, _category: String, _score: int) -> void:
	var reroll = get_active_consumable("score_reroll") as ScoreRerollConsumable
	if reroll:
		reroll.complete_reroll()
		remove_consumable("score_reroll")

func _on_score_assigned(_section: int, _category: String, _score: int) -> void:
	print("Score assigned, checking if reroll should be enabled")
	if not scorecard:
		push_error("No scorecard reference found")
		return
		
	if scorecard.has_any_scores():
		print("First score detected, enabling reroll consumable")
		var reroll_icon = consumable_ui.get_consumable_icon("score_reroll")
		if reroll_icon:
			reroll_icon.set_useable(true)
		else:
			print("No reroll icon found")
	else:
		print("No scores yet, reroll remains disabled")

func apply_debuff(id: String) -> void:
	print("Applying debuff:", id)
	
	var debuff := debuff_manager.spawn_debuff(id, debuff_container) as Debuff
	if debuff == null:
		push_error("Failed to spawn Debuff '%s'" % id)
		return

	active_debuffs[id] = debuff
	
	# Add to UI with null checks
	var def: DebuffData = debuff_manager.get_def(id)
	if not def:
		push_error("No DebuffData found for '%s'" % id)
		return
		
	var icon = debuff_ui.add_debuff(def, debuff)
	if not icon:
		push_error("Failed to create UI icon for debuff '%s'" % id)
		return

	# Apply the debuff effect
	match id:
		"lock_dice":
			debuff.target = dice_hand
			debuff.start()
		_:
			push_error("Unknown debuff type: %s" % id)

func enable_debuff(id: String) -> void:
	print("Enabling debuff:", id)
	if not is_debuff_active(id):
		apply_debuff(id)
	else:
		var debuff = active_debuffs[id]
		if debuff and debuff.target:
			debuff.start()

func disable_debuff(id: String) -> void:
	print("Disabling debuff:", id)
	if is_debuff_active(id):
		var debuff = active_debuffs[id]
		if debuff:
			debuff.end()
			active_debuffs.erase(id)
			# Remove the icon from UI
			if debuff_ui:
				debuff_ui.remove_debuff(id)
			else:
				push_error("No debuff_ui found when trying to remove debuff icon")


func is_debuff_active(id: String) -> bool:
	return active_debuffs.has(id) and active_debuffs[id] != null

# Add this function after other consumable-related functions

func get_active_consumable(id: String) -> Consumable:
	if active_consumables.has(id):
		return active_consumables[id]
	return null

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

func _on_roll_completed() -> void:
	print("Roll completed")
	if is_debuff_active("lock_dice"):
		print("Lock dice debuff active - reapplying")
		var debuff = active_debuffs["lock_dice"]
		if debuff and dice_hand:
			debuff.apply(dice_hand)
	else:
		print("No lock dice debuff active - dice can be locked")
		if dice_hand:
			dice_hand.enable_all_dice()

func _on_dice_spawned() -> void:
	print("Dice spawned, attempting to add wildcard mod")
	if dice_hand and dice_hand.dice_list.size() > 0:
		var first_die = dice_hand.dice_list[0]
		if first_die and mod_manager:
			print("Adding wildcard mod to first die")
			var mod = mod_manager.spawn_mod("wildcard", first_die)
			if mod:
				first_die.add_mod(mod_manager.get_def("wildcard"))
				print("Wildcard mod spawned successfully")
			else:
				print("Wildcard mod spawned failed")
				push_error("Failed to spawn wildcard mod")
		else:
			push_error("Failed to add wildcard mod - missing die or mod manager")
		var second_die = dice_hand.dice_list[1]
		if second_die and mod_manager:
			print("Adding wildcard mod to second die")
			var mod = mod_manager.spawn_mod("wildcard", second_die)
			if mod:
				second_die.add_mod(mod_manager.get_def("wildcard"))
				print("Wildcard mod spawned successfully")
			else:
				print("Wildcard mod spawned failed")
				push_error("Failed to spawn wildcard mod")
		else:
			push_error("Failed to add wildcard mod - missing die or mod manager")
		var third_die = dice_hand.dice_list[2]
		if third_die and mod_manager:
			print("Adding wildcard mod to third die")
			var mod = mod_manager.spawn_mod("wildcard", third_die)
			if mod:
				third_die.add_mod(mod_manager.get_def("wildcard"))
				print("Wildcard mod spawned successfully")
			else:
				print("Wildcard mod spawned failed")
				push_error("Failed to spawn wildcard mod")
		else:
			push_error("Failed to add wildcard mod - missing die or mod manager")
