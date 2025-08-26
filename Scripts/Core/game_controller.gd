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
var active_mods: Dictionary = {}  # id -> Mod

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
@export var shop_ui_path: NodePath = ^"../ShopUI"
@export var game_button_ui_path: NodePath = ^"../GameButtonUI"

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
@onready var shop_ui: ShopUI = get_node(shop_ui_path) as ShopUI
@onready var game_button_ui: Control = get_node(game_button_ui_path)

const STARTING_POWER_UP_IDS := ["extra_dice", "extra_rolls"]

var _last_modded_die_index: int = -1  # Track which die received the last mod

func _ready() -> void:
	print("▶ GameController._ready()")
	if dice_hand:
		dice_hand.roll_complete.connect(_on_roll_completed)
		dice_hand.dice_spawned.connect(_on_dice_spawned)
	if scorecard:
		scorecard.score_auto_assigned.connect(_on_score_assigned)
	if game_button_ui:
		game_button_ui.connect("shop_button_pressed", _on_shop_button_pressed)	
	if shop_ui:
		print("[GameController] Setting up shop UI")
		shop_ui.hide()
		shop_ui.connect("item_purchased", _on_shop_item_purchased)
	call_deferred("_on_game_start")

func _on_game_start() -> void:
	#spawn_starting_powerups()
	#grant_consumable("score_reroll")
	#apply_debuff("lock_dice")
	pass

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
		push_error("[GameController] Failed to spawn PowerUp '%s'" % id)
		return

	# Create and connect UI first
	var def: PowerUpData = pu_manager.get_def(id)
	if def:
		var icon = powerup_ui.add_power_up(def)
		if icon:
			print("[GameController] Connecting power-up signals for:", id)
			# Connect the signals from the icon
			icon.power_up_selected.connect(_on_power_up_selected)
			icon.power_up_deselected.connect(_on_power_up_deselected)
		else:
			push_error("[GameController] Failed to create UI icon for power-up:", id)
			
	# Store the power-up reference
	active_power_ups[id] = pu
	emit_signal("power_up_granted", id, pu)
	print("[GameController] Power-up granted and ready:", id)

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
	var consumable := consumable_manager.spawn_consumable(id, consumable_container) as Consumable
	if consumable == null:
		push_error("[GameController] Failed to spawn Consumable '%s'" % id)
		return

	active_consumables[id] = consumable
	
	# Add to UI with null checks
	var def: ConsumableData = consumable_manager.get_def(id)
	if not def:
		push_error("[GameController] No ConsumableData found for '%s'" % id)
		return
		
	var icon = consumable_ui.add_consumable(def, consumable)
	if not icon:
		push_error("[GameController] Failed to create UI icon for consumable '%s'" % id)
		return

	# Connect signals and set initial state
	icon.consumable_used.connect(_on_consumable_used)
	
	# Set initial usability state
	match id:
		"score_reroll":
			# Score reroll is only useable if we have scores
			var can_use = scorecard and scorecard.has_any_scores()
			icon.set_useable(can_use)
			print("[GameController] Score reroll consumable added, useable:", can_use)
		_:
			# Other consumables are useable by default
			icon.set_useable(true)
			print("[GameController] Consumable granted and ready:", id)

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
	if not scorecard:
		push_error("No scorecard reference found")
		return
		
	if scorecard.has_any_scores():
		var reroll_icon = consumable_ui.get_consumable_icon("score_reroll")
		if reroll_icon:
			reroll_icon.set_useable(true)
		else:
			print("No reroll icon found")
	else:
		print("No scores yet, reroll remains disabled")

func apply_debuff(id: String) -> void:
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
	if not is_debuff_active(id):
		apply_debuff(id)
	else:
		var debuff = active_debuffs[id]
		if debuff and debuff.target:
			debuff.start()

func disable_debuff(id: String) -> void:
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

func grant_mod(id: String) -> void:
	print("[GameController] Attempting to grant mod:", id)
	
	# Get the mod definition
	var def: ModData = mod_manager.get_def(id)
	if not def:
		push_error("[GameController] No ModData found for:", id)
		return
		
	# Store reference for later use
	active_mods[id] = def
	
	if dice_hand and dice_hand.dice_list.size() > 0:
		var applied = false
		# Try to find a die without this mod type
		for i in range(dice_hand.dice_list.size()):
			var die = dice_hand.dice_list[i]
			if not die.has_mod(id):
				var mod = mod_manager.spawn_mod(id, die)
				if mod:
					die.add_mod(def)
					_last_modded_die_index = i
					applied = true
					print("[GameController] Mod", id, "applied to die:", die.name)
					break
		
		if not applied:
			print("[GameController] All current dice have mod", id, "- will apply to next spawned die")
	else:
		print("[GameController] No dice available - mod will be applied to next die")

func _on_roll_completed() -> void:
	if is_debuff_active("lock_dice"):
		var debuff = active_debuffs["lock_dice"]
		if debuff and dice_hand:
			debuff.apply(dice_hand)
	else:
		if dice_hand:
			dice_hand.enable_all_dice()

func _on_dice_spawned() -> void:
	if not dice_hand:
		return
		
	print("[GameController] New dice spawned, checking for mods to apply")
	
	# Get the newly spawned die (should be the last one in the list)
	if dice_hand.dice_list.size() > 0:
		var new_die = dice_hand.dice_list[-1]
		
		# Apply any active mods that aren't already on other dice
		for mod_id in active_mods:
			var def = active_mods[mod_id]
			# Check if this mod type is already on this die
			if def and not new_die.has_mod(mod_id):
				var mod = mod_manager.spawn_mod(mod_id, new_die)
				if mod:
					new_die.add_mod(def)
					print("[GameController] Applied mod", mod_id, "to new die:", new_die.name)
				else:
					push_error("[GameController] Failed to spawn mod", mod_id, "for new die")

func _on_shop_button_pressed() -> void:
	if shop_ui:
		if not shop_ui.visible:
			shop_ui.show()
		else:
			shop_ui.hide()

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
